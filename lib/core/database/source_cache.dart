import 'dart:convert';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_details.dart';
import 'package:sqflite/sqflite.dart';

/// Disk-backed, stale-while-revalidate cache for source fetch results.
///
/// Every source call that produces a browsable result (popular/search lists,
/// manga details, chapter lists, page URL lists, tag lists) can be routed
/// through here so the app keeps working offline with the last-seen data.
///
/// Behavior:
///  - Fresh cache (< [maxAge]) -> returned immediately, no network.
///  - Stale cache, online      -> network fetch wins and re-stores.
///  - Any cache, offline       -> fall back to it when the network fetch fails.
///  - No cache, offline        -> error propagates (screens show their usual
///    error states).
///
/// Keys are namespaced by source id + type + args, stored in the `source_cache`
/// table as JSON blobs.
class SourceCache {
  SourceCache._();

  static const _maxAgePopular = Duration(minutes: 60);
  static const _maxAgeSearch = Duration(minutes: 30);
  static const _maxAgeDetails = Duration(hours: 2);
  static const _maxAgeChapters = Duration(minutes: 30);
  static const _maxAgePageUrls = Duration(days: 7);
  static const _maxAgeTags = Duration(days: 7);

  /// Keys (prefixes) that must skip the fresh-cache shortcut on their next run
  /// (used by pull-to-refresh). A prefix applies to every key starting with it.
  static final Set<String> _forceFetchPrefixes = {};

  // --- Public cache entry points -------------------------------------------

  static Future<List<Manga>> mangaList({
    required String sourceId,
    required String kind,
    String arg = '',
    int page = 1,
    bool forceRefresh = false,
    required Future<List<Manga>> Function() fetch,
  }) async {
    return _run<List<Manga>>(
      key: '$sourceId/list/$kind/$arg/$page',
      maxAge: kind == 'popular' ? _maxAgePopular : _maxAgeSearch,
      forceRefresh: forceRefresh,
      decode: (json) {
        final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
        return list.map(Manga.fromJson).toList();
      },
      encode: (v) =>
          jsonEncode(v.map((m) => m.toJson()).toList(growable: false)),
      fetch: fetch,
      onFresh: (items) => _persistMangaList(sourceId, items),
    );
  }

  static Future<MangaDetails?> mangaDetails({
    required String sourceId,
    required String mangaId,
    bool forceRefresh = false,
    required Future<MangaDetails?> Function() fetch,
  }) async {
    return _run<MangaDetails?>(
      key: '$sourceId/details/$mangaId',
      maxAge: _maxAgeDetails,
      forceRefresh: forceRefresh,
      decode: (json) =>
          MangaDetails.fromJson(jsonDecode(json) as Map<String, dynamic>),
      encode: (v) => jsonEncode(v!.toJson()),
      fetch: fetch,
      onFresh: (details) {
        if (details != null) {
          DatabaseHelper.instance.upsertManga(
            mangaId: details.id,
            title: details.title,
            coverUrl: details.coverUrl,
            sourceId: details.sourceId,
            totalChapters: details.totalChapters,
          );
        }
      },
    );
  }

  static Future<List<Chapter>> chapters({
    required String sourceId,
    required String mangaId,
    bool forceRefresh = false,
    required Future<List<Chapter>> Function() fetch,
  }) async {
    return _run<List<Chapter>>(
      key: '$sourceId/chapters/$mangaId',
      maxAge: _maxAgeChapters,
      forceRefresh: forceRefresh,
      decode: (json) {
        final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
        return list.map(Chapter.fromJson).toList();
      },
      encode: (v) =>
          jsonEncode(v.map((c) => c.toJson()).toList(growable: false)),
      fetch: fetch,
    );
  }

  static Future<List<String>> pageUrls({
    required String sourceId,
    required String chapterId,
    bool forceRefresh = false,
    required Future<List<String>> Function() fetch,
  }) async {
    return _run<List<String>>(
      key: '$sourceId/pages/$chapterId',
      maxAge: _maxAgePageUrls,
      forceRefresh: forceRefresh,
      decode: (json) => (jsonDecode(json) as List).cast<String>(),
      encode: jsonEncode,
      fetch: fetch,
    );
  }

  static Future<List<String>> tags({
    required String sourceId,
    bool forceRefresh = false,
    required Future<List<String>> Function() fetch,
  }) async {
    return _run<List<String>>(
      key: '$sourceId/tags',
      maxAge: _maxAgeTags,
      forceRefresh: forceRefresh,
      decode: (json) => (jsonDecode(json) as List).cast<String>(),
      encode: jsonEncode,
      fetch: fetch,
    );
  }

  /// Marks every cached entry whose key starts with [prefix] for revalidation.
  /// The next lookup with such a key goes to the network even when cached, and
  /// falls back to the old cached value if the network fails.
  static void invalidatePrefix(String prefix) {
    _forceFetchPrefixes.add(prefix);
  }

  // --- Internals -----------------------------------------------------------

  static Future<T> _run<T>({
    required String key,
    required Duration maxAge,
    required bool forceRefresh,
    required T Function(String json) decode,
    required String Function(T value) encode,
    required Future<T> Function() fetch,
    void Function(T value)? onFresh,
  }) async {
    var force = forceRefresh;
    for (final prefix in _forceFetchPrefixes.toList()) {
      if (key.startsWith(prefix)) {
        _forceFetchPrefixes.remove(prefix);
        force = true;
        break;
      }
    }

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'source_cache',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    T? cached;
    var fresh = false;
    if (rows.isNotEmpty) {
      try {
        cached = decode(rows.first['json'] as String);
        if (!force) {
          final fetchedAt = DateTime.tryParse(
            rows.first['fetchedAt'] as String? ?? '',
          );
          fresh =
              fetchedAt != null &&
              DateTime.now().difference(fetchedAt) <= maxAge;
        }
      } catch (_) {
        cached = null;
      }
    }

    if (fresh) return cached as T;
    final fallback = cached;
    try {
      final value = await fetch();
      // When the source swallows network errors and returns an empty
      // result (empty list / empty map) while a valid stale cache exists,
      // preserve the stale data instead of overwriting it with empties.
      final isEmptyResult =
          (value is List && value.isEmpty) || (value is Map && value.isEmpty);
      if (isEmptyResult && fallback != null) {
        return fallback;
      }
      await db.insert('source_cache', {
        'key': key,
        'json': encode(value),
        'fetchedAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      onFresh?.call(value);
      return value;
    } catch (e) {
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  static void _persistMangaList(String sourceId, List<Manga> items) {
    for (final m in items) {
      DatabaseHelper.instance.upsertManga(
        mangaId: m.id,
        title: m.title,
        coverUrl: m.coverUrl,
        sourceId: m.sourceId.isEmpty ? sourceId : m.sourceId,
      );
    }
  }
}
