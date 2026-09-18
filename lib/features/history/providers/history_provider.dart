import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/database_helper.dart';
import '../../library/providers/downloads_provider.dart';

List<Map<String, dynamic>> mapHistoryRows(
  List<Map<String, dynamic>> rows, {
  Set<String> downloadedMangaIds = const {},
}) {
  return rows.map((row) {
    final lastReadChapter = (row['lastReadChapter'] as num? ?? -1).toDouble();
    final total = (row['totalChapters'] as int? ?? 0);
    final progress = total > 0
        ? ((lastReadChapter.clamp(0, total.toDouble()) / total) * 100)
              .round()
              .clamp(0, 100)
              .toInt()
        : 0;
    final lastTrayTotal = (row['lastTrayTotalChapters'] as int?) ?? 0;
    final newChapters = (lastTrayTotal > 0 && total > lastTrayTotal)
        ? total - lastTrayTotal
        : 0;

    return <String, dynamic>{
      'mangaId': row['mangaId'],
      'title': row['title'],
      'coverUrl': row['coverUrl'] ?? '',
      'sourceId': row['sourceId'],
      'lastReadChapter': lastReadChapter.floor(),
      'lastReadPage': (row['lastReadPage'] as int?) ?? 0,
      'totalReleasedChapters': total,
      'lastReadAt': row['lastReadAt'] ?? DateTime.now().toIso8601String(),
      'progress': progress,
      'newChapters': newChapters,
      'hasDownloadedChapters': downloadedMangaIds.contains(row['mangaId']),
      'isFavorite': (row['isFavorite'] as int? ?? 0) == 1,
      'tags': row['tags'] ?? '[]',
    };
  }).toList();
}

// Holds a revision counter. Bumped whenever reading progress changes,
// so the history provider knows to refetch from the database.
final historyRevisionProvider = StateProvider<int>((ref) => 0);

// Fetches + maps history from the database. Depends on the revision so it
// automatically refreshes whenever progress is saved.
final historyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(historyRevisionProvider);
  ref.watch(downloadsRevisionProvider);
  final rows = await DatabaseHelper.instance.getHistory();
  final downloaded = await DatabaseHelper.instance.getMangaIdsWithDownloads();
  return mapHistoryRows(rows, downloadedMangaIds: downloaded);
});

// Call this after the reader saves progress to make history refresh.
void bumpHistoryRevision(dynamic ref) {
  ref.read(historyRevisionProvider.notifier).state++;
}
