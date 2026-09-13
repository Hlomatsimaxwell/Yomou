import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/data/providers/sources_provider.dart';

/// A manga from the user's library that has new chapters available.
class MangaUpdate {
  final String mangaId;
  final String title;
  final String coverUrl;
  final String sourceId;
  final int newCount;
  final String latestChapterTitle;
  final DateTime? latestChapterDate;
  final bool isFavorite;

  const MangaUpdate({
    required this.mangaId,
    required this.title,
    required this.coverUrl,
    required this.sourceId,
    required this.newCount,
    required this.latestChapterTitle,
    this.latestChapterDate,
    required this.isFavorite,
  });

  /// The latest chapter's publish date (falls back to now when unknown).
  DateTime get sortKey => latestChapterDate ?? DateTime.now();

  /// Human-readable date group label for the feed, e.g. "Today".
  String get dateGroup {
    final date = sortKey;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(that).inDays;
    if (diffDays <= 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) return '$diffDays days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Merges history + favorites into one map keyed by mangaId.
Future<Map<String, Map<String, dynamic>>> _getLibraryManga() async {
  final history = await DatabaseHelper.instance.getHistory();
  final favorites = await DatabaseHelper.instance.getFavorites();
  final merged = <String, Map<String, dynamic>>{};
  for (final row in [...history, ...favorites]) {
    merged[row['mangaId']] = row;
  }
  return merged;
}

/// Fetches manga from the user's library that have new chapters since the
/// last time the user read them. Compares the live chapter count with the
/// stored count, then grabs each updated manga's latest chapter info.
/// Each manga is checked against the source it was read from (its stored
/// `sourceId`), falling back to the currently-active source for rows with no
/// source recorded.
final updatesProvider = FutureProvider<List<MangaUpdate>>((ref) async {
  final library = await _getLibraryManga();

  final entries = library.entries.toList();
  final results = await Future.wait(
    entries.map((e) async {
      try {
        final row = e.value;
        final storedTotal = (row['totalChapters'] as int?) ?? 0;
        if (storedTotal <= 0) return null;

        final mangaSourceId = row['sourceId']?.toString() ?? '';
        final source = getSourceBySourceId(mangaSourceId) ??
            ref.read(currentSourceProvider);
        if (source == null) return null;

        final liveTotal = await source.getTotalChapters(e.key);
        final newCount = liveTotal - storedTotal;
        if (newCount <= 0) return null;

        final latest = await source.getLatestChapter(e.key);

        return MangaUpdate(
          mangaId: e.key,
          title: row['title']?.toString() ?? 'Unknown',
          coverUrl: row['coverUrl']?.toString() ?? '',
          sourceId: row['sourceId']?.toString() ?? '',
          newCount: newCount,
          latestChapterTitle: latest?.$1 ?? 'New chapter',
          latestChapterDate: latest?.$2,
          isFavorite: (row['isFavorite'] as int? ?? 0) == 1,
        );
      } catch (_) {
        return null;
      }
    }),
  );

  final updates = results.whereType<MangaUpdate>().toList()
    ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
  return updates;
});

/// Total number of new chapters across all updated manga (drives the badge).
final updatesCountProvider = Provider<int>((ref) {
  final updates = ref.watch(updatesProvider);
  return updates.when(
    data: (list) => list.fold<int>(0, (sum, u) => sum + u.newCount),
    loading: () => 0,
    error: (_, __) => 0,
  );
});
