import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';

List<Manga> mapFavoritesRows(List<Map<String, dynamic>> rows) {
  return rows.map((row) {
    return Manga(
      id: row['mangaId'] as String,
      title: row['title'] as String,
      coverUrl: row['coverUrl']?.toString() ?? '',
      sourceId: row['sourceId']?.toString() ?? '0',
    );
  }).toList();
}

final favoritesRevisionProvider = StateProvider<int>((ref) => 0);

final favoritesProvider = FutureProvider<List<Manga>>((ref) async {
  ref.watch(favoritesRevisionProvider);
  final rows = await DatabaseHelper.instance.getFavorites();
  return mapFavoritesRows(rows);
});

final favoritesDetailProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(favoritesRevisionProvider);
  ref.watch(downloadsRevisionProvider);
  final rows = await DatabaseHelper.instance.getFavorites();
  final downloaded = await DatabaseHelper.instance.getMangaIdsWithDownloads();
  return rows.map((row) {
    final lastReadChapter = (row['lastReadChapter'] as num? ?? -1).toDouble();
    final total = (row['totalChapters'] as int? ?? 0);
    final lastTrayTotal = (row['lastTrayTotalChapters'] as int?) ?? 0;
    final newChapters = (lastTrayTotal > 0 && total > lastTrayTotal)
        ? total - lastTrayTotal
        : 0;
    final progress = total > 0
        ? ((lastReadChapter.clamp(0, total.toDouble()) / total) * 100)
              .round()
              .clamp(0, 100)
              .toInt()
        : 0;
    return <String, dynamic>{
      'mangaId': row['mangaId'],
      'title': row['title'],
      'coverUrl': row['coverUrl'] ?? '',
      'sourceId': row['sourceId'],
      'totalReleasedChapters': total,
      'lastReadChapter': lastReadChapter,
      'progress': progress,
      'newChapters': newChapters,
      'hasDownloadedChapters': downloaded.contains(row['mangaId']),
      'isPinned': (row['isPinned'] as int? ?? 0) == 1,
    };
  }).toList();
});

final pinnedFavoritesProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(favoritesRevisionProvider);
  return DatabaseHelper.instance.getPinnedFavoriteIds();
});

void bumpFavoritesRevision(dynamic ref) {
  ref.read(favoritesRevisionProvider.notifier).state++;
}