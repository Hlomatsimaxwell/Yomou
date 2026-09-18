import 'dart:convert';

import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/notifications/notification_settings.dart';
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

  final String latestChapterTitle;
  final DateTime? latestChapterDate;
  final bool isFavorite;

  /// Chapters newer than what the user has seen in the app.
  int get newSinceRead => liveTotal - storedTotal;

  /// Chapters newer than the last notification (0 when never notified).
  int get newSinceNotified =>
      lastNotifiedChapters <= 0 ? 0 : liveTotal - lastNotifiedChapters;
}

/// Fetches live chapter counts for every manga in the user's library
/// (history + favorites), which is what drives both the updates feed and
/// background notifications.
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

    final merged = <String, Map<String, dynamic>>{};
    for (final row in [...history, ...favorites]) {
      final id = row['mangaId']?.toString();
      if (id != null && id.isNotEmpty) merged[id] = row;
    }

    // Sources are remote; cap concurrency so a large library does not fire
    // hundreds of requests at once (rate limits / battery).
    const concurrency = 5;
    final entries = merged.entries.toList();
    final results = <LibraryStatus>[];
    for (var i = 0; i < entries.length; i += concurrency) {
      final end = (i + concurrency) < entries.length
          ? i + concurrency
          : entries.length;
      final chunk = entries.sublist(i, end);
      final chunkResults = await Future.wait(
        chunk.map(
          (entry) => _checkEntry(
            entry,
            disabledSourceIds,
            allowedCategories,
            excludeNsfw,
          ),
        ),
      );
      results.addAll(chunkResults.whereType<LibraryStatus>());
    }

    return results;
  }

  static Future<LibraryStatus?> _checkEntry(
    MapEntry<String, Map<String, dynamic>> entry,
    Set<String> disabledSourceIds,
    Set<String> allowedCategories,
    bool excludeNsfw,
  ) async {
    try {
      final row = entry.value;
      final storedTotal = (row['totalChapters'] as int?) ?? 0;
      if (storedTotal <= 0) return null;

      final mangaSourceId = row['sourceId']?.toString() ?? '';
      if (mangaSourceId.isNotEmpty &&
          disabledSourceIds.contains(mangaSourceId)) {
        return null;
      }

      if (excludeNsfw && NotificationSettings.tagsAreNsfw(_storedTags(row))) {
        return null;
      }
      if (allowedCategories.isNotEmpty &&
          _storedTags(row).toSet().intersection(allowedCategories).isEmpty) {
        return null;
      }

      final source =
          getSourceBySourceId(mangaSourceId) ?? getSourceByName('MangaDex');

      final liveTotal = await source.getTotalChapters(entry.key);
      if (liveTotal <= 0) return null;

      final latest = await source.getLatestChapter(entry.key);

      return LibraryStatus(
        mangaId: entry.key,
        title: row['title']?.toString() ?? 'Unknown',
        coverUrl: row['coverUrl']?.toString() ?? '',
        sourceId: mangaSourceId,
        liveTotal: liveTotal,
        storedTotal: storedTotal,
        lastNotifiedChapters: (row['lastNotifiedChapters'] as int?) ?? 0,
        latestChapterTitle: latest?.$1 ?? 'New chapter',
        latestChapterDate: latest?.$2,
        isFavorite: (row['isFavorite'] as int? ?? 0) == 1,
      );
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
}
