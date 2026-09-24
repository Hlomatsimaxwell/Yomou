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

    // Sources are remote; cap concurrency so a large library does not fire
    // hundreds of requests at once (rate limits / battery).
    const concurrency = 5;
    final merged = <String, ({String mangaId, Map<String, dynamic> row})>{};
    for (final row in [...history, ...favorites]) {
      final id = row['mangaId']?.toString();
      if (id == null || id.isEmpty) continue;
      // Key by source + manga id so the same slug from two different sources
      // (e.g. a series read on ComicK and on Manganato) never overwrites the
      // other's update entry.
      final src = row['sourceId']?.toString() ?? '';
      merged['$src\x00$id'] = (mangaId: id, row: row);
    }

    final entries = merged.values.toList();
    final results = <LibraryStatus>[];
    for (var i = 0; i < entries.length; i += concurrency) {
      final end = (i + concurrency) < entries.length
          ? i + concurrency
          : entries.length;
      final chunk = entries.sublist(i, end);
      final chunkResults = await Future.wait(
        chunk.map(
          (entry) => _checkEntry(
            entry.mangaId,
            entry.row,
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
    String mangaId,
    Map<String, dynamic> row,
    Set<String> disabledSourceIds,
    Set<String> allowedCategories,
    bool excludeNsfw,
  ) async {
    try {
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
