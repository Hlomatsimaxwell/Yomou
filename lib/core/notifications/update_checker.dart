import 'dart:convert';
import 'dart:isolate';

import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/data/providers/sources_provider.dart';

/// A library entry enriched with its live chapter count from its source.
///
/// Shared by the in-app updates feed and the background notification check so
/// both agree on how many chapters are new.
class LibraryStatus {
  const LibraryStatus({
    required this.mangaId,
    required this.title,
    required this.coverUrl,
    required this.sourceId,
    required this.liveTotal,
    required this.storedTotal,
    required this.lastNotifiedChapters,
    required this.lastSeenChapters,
    required this.latestChapterTitle,
    required this.latestChapterDate,
    required this.isFavorite,
  });

  final String mangaId;
  final String title;
  final String coverUrl;
  final String sourceId;

  /// Chapter count reported by the source right now.
  final int liveTotal;

  /// Chapter count stored the last time the user read/synced this manga.
  final int storedTotal;

  /// Chapter total that was last included in a notification (0 = never).
  final int lastNotifiedChapters;

  /// Chapter total the last time the user opened this manga's detail screen
  /// (0 = never opened since it was added). Drives the per-manga "new" dot.
  final int lastSeenChapters;

  final String latestChapterTitle;
  final DateTime? latestChapterDate;
  final bool isFavorite;

  /// Chapters newer than what the user has seen in the app.
  int get newSinceRead => liveTotal - storedTotal;

  /// Chapters newer than the last notification (0 when never notified).
  int get newSinceNotified =>
      lastNotifiedChapters <= 0 ? 0 : liveTotal - lastNotifiedChapters;

  /// Whether a "you haven't opened this since it updated" dot should show:
  /// the manga has chapters newer than read AND newer than last opened.
  bool get hasUnseenUpdate =>
      newSinceRead > 0 && liveTotal > lastSeenChapters;

  Map<String, dynamic> toJson() => {
    'mangaId': mangaId,
    'title': title,
    'coverUrl': coverUrl,
    'sourceId': sourceId,
    'liveTotal': liveTotal,
    'storedTotal': storedTotal,
    'lastNotifiedChapters': lastNotifiedChapters,
    'lastSeenChapters': lastSeenChapters,
    'latestChapterTitle': latestChapterTitle,
    'latestChapterDate': latestChapterDate?.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory LibraryStatus.fromJson(Map<String, dynamic> json) {
    return LibraryStatus(
      mangaId: json['mangaId'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      coverUrl: json['coverUrl'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      liveTotal: json['liveTotal'] as int? ?? 0,
      storedTotal: json['storedTotal'] as int? ?? 0,
      lastNotifiedChapters: json['lastNotifiedChapters'] as int? ?? 0,
      lastSeenChapters: json['lastSeenChapters'] as int? ?? 0,
      latestChapterTitle: json['latestChapterTitle'] as String? ?? 'New chapter',
      latestChapterDate:
          json['latestChapterDate'] == null
              ? null
              : DateTime.tryParse(json['latestChapterDate'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}

/// Fetches live chapter counts for every manga in the user's library
/// (history + favorites), which is what drives both the updates feed and
/// background notifications.
///
/// The whole scan (networking + HTML/JSON parsing) runs on a background
/// isolate: it can be slow and allocation-heavy but must never stall the UI
/// thread — that triggered application-not-responding dialogs on slow devices.
class UpdateChecker {
  UpdateChecker._();

  static Future<List<LibraryStatus>> checkLibrary({
    Set<String> disabledSourceIds = const {},
    bool includeHistory = true,
    bool includeFavorites = true,
    Set<String> allowedCategories = const {},
    bool excludeNsfw = false,
  }) async {
    final history = includeHistory
        ? await DatabaseHelper.instance.getHistory()
        : <Map<String, dynamic>>[];
    final favorites = includeFavorites
        ? await DatabaseHelper.instance.getFavorites()
        : <Map<String, dynamic>>[];

    // Sources are remote; cap concurrency so a large library does not fire
    // hundreds of requests at once (rate limits / battery).
    const concurrency = 2;
    // Never scan the entire library in one burst: on slow devices a full scan
    // can saturate the phone for a minute. Scan the most recent titles only;
    // the rest get covered on later cycles.
    const maxScannedEntries = 25;
    final merged = <String, Map<String, dynamic>>{};
    for (final row in [...history, ...favorites]) {
      final id = row['mangaId']?.toString();
      if (id == null || id.isEmpty) continue;
      // Key by source + manga id so the same slug from two different sources
      // (e.g. a series read on ComicK and on Manganato) never overwrites the
      // other's update entry.
      final src = row['sourceId']?.toString() ?? '';
      merged['$src\x00$id'] = row;
    }

    // Only the fields the scan needs, reduced to JSON-safe values so the list
    // can travel across the isolate boundary. Keep a single scan bounded: on
    // slow phones a library-wide sweep saturates the device and can ANR.
    final allRows = merged.values.toList();
    final capped = allRows.length > maxScannedEntries
        ? allRows.sublist(allRows.length - maxScannedEntries)
        : allRows;
    final rows = capped.map((row) => <String, dynamic>{
      'mangaId': row['mangaId']?.toString() ?? '',
      'sourceId': row['sourceId']?.toString() ?? '',
      'title': row['title']?.toString() ?? '',
      'coverUrl': row['coverUrl']?.toString() ?? '',
      'totalChapters': (row['totalChapters'] as int?) ?? 0,
      'lastNotifiedChapters': (row['lastNotifiedChapters'] as int?) ?? 0,
      'lastSeenChapters': (row['lastSeenChapters'] as int?) ?? 0,
      'isFavorite': (row['isFavorite'] as int? ?? 0) == 1 ? 1 : 0,
      'tags': row['tags']?.toString() ?? '',
    }).toList();

    // DB rows (maps of JSON-safe values) and the filter settings cross the
    // isolate boundary; everything else — HTTP, parsing, allocations — stays
    // off the UI thread. Cap concurrency with a small breather between
    // batches to stay polite to the sources.
    final results = await Isolate.run(
      () => _scanRows(rows, concurrency, disabledSourceIds, allowedCategories,
          excludeNsfw),
    );

    return results
        .map(LibraryStatus.fromJson)
        .where((s) => s.liveTotal > 0)
        .toList();
  }

  static Future<List<Map<String, dynamic>>> _scanRows(
    List<Map<String, dynamic>> rows,
    int concurrency,
    Set<String> disabledSourceIds,
    Set<String> allowedCategories,
    bool excludeNsfw,
  ) async {
    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i += concurrency) {
      final end = (i + concurrency) < rows.length ? concurrency : rows.length - i;
      final chunk = rows.sublist(i, i + end);
      final chunkResults = await Future.wait(
        chunk.map(
          (row) => _checkEntry(
            row,
            disabledSourceIds,
            allowedCategories,
            excludeNsfw,
          ),
        ),
      );
      results.addAll(chunkResults.whereType<Map<String, dynamic>>());
      if (i + concurrency < rows.length) {
        await Future.delayed(const Duration(milliseconds: 80));
      }
    }
    return results;
  }

  static Future<Map<String, dynamic>?> _checkEntry(
    Map<String, dynamic> row,
    Set<String> disabledSourceIds,
    Set<String> allowedCategories,
    bool excludeNsfw,
  ) async {
    try {
      final mangaId = row['mangaId']?.toString() ?? '';
      if (mangaId.isEmpty) return null;

      final storedTotal = (row['totalChapters'] as int?) ?? 0;
      if (storedTotal <= 0) return null;

      final mangaSourceId = row['sourceId']?.toString() ?? '';
      if (mangaSourceId.isNotEmpty &&
          disabledSourceIds.contains(mangaSourceId)) {
        return null;
      }

      final tags = _storedTags(row);
      if (excludeNsfw && _tagsAreNsfw(tags)) return null;
      if (allowedCategories.isNotEmpty &&
          tags.toSet().intersection(allowedCategories).isEmpty) {
        return null;
      }

      final isFavorite = (row['isFavorite'] as int? ?? 0) == 1;

      final source =
          getSourceBySourceId(mangaSourceId) ?? getSourceByName('MangaDex');

      final liveTotal = await source.getTotalChapters(mangaId);
      if (liveTotal <= 0) return null;

      final latest = await source.getLatestChapter(mangaId);

      return LibraryStatus(
        mangaId: mangaId,
        title: row['title']?.toString() ?? 'Unknown',
        coverUrl: row['coverUrl']?.toString() ?? '',
        sourceId: mangaSourceId,
        liveTotal: liveTotal,
        storedTotal: storedTotal,
        lastNotifiedChapters: (row['lastNotifiedChapters'] as int?) ?? 0,
        lastSeenChapters: (row['lastSeenChapters'] as int?) ?? 0,
        latestChapterTitle: latest?.$1 ?? 'New chapter',
        latestChapterDate: latest?.$2,
        isFavorite: isFavorite,
      ).toJson();
    } catch (_) {
      return null;
    }
  }

  static List<String> _storedTags(Map<String, dynamic> row) {
    final raw = row['tags']?.toString();
    if (raw == null || raw == '[]') return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  static bool _tagsAreNsfw(List<String> tags) {
    const nsfwSet = {'hentai', 'adult', 'smut', 'r18', 'nsfw', 'porn'};
    return tags.any((t) => nsfwSet.contains(t.toLowerCase()));
  }
}