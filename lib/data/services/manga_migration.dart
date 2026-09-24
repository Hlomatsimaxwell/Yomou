import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/providers/sources_provider.dart';

/// Carries a manga's progress over from one source's copy to another source's
/// copy of the same work ("migration"), the way Kotatsu's Alternatives screen
/// does it: the library entry is re-bound to the new source's manga id and its
/// reading progress is mapped to the closest matching chapter on the new source.
///
/// The return value is the new last-read chapter number (or the old one when
/// no mapping was possible), used for the post-migration message.
Future<double> migrateManga({
  required String oldMangaId,
  required String newMangaId,
  required String newSourceId,
  required String newTitle,
  required String newCoverUrl,
  required String newSourceName,
}) async {
  final db = DatabaseHelper.instance;
  final row = await db.getManga(oldMangaId);
  if (row == null) return -1;

  final oldChapter =
      row['lastReadChapter'] is num ? (row['lastReadChapter'] as num).toDouble() : -1.0;
  final oldTotal = (row['totalChapters'] as int? ?? 0) > 0
      ? (row['totalChapters'] as int)
      : (row['lastTrayTotalChapters'] as int? ?? 0);

  // Best-effort: map the old progress onto the nearest chapter on the new
  // source. When the chapter list can't be fetched (offline/rate limit) we keep
  // the old chapter number unchanged.
  var newChapter = oldChapter;
  var newTotal = oldTotal;
  final source = getSourceBySourceId(newSourceId) ??
      getSourceByName(newSourceName);
  try {
    final chapters = await source.getChapters(newMangaId);
    newTotal = chapters.length;
    if (oldChapter >= 0 && chapters.isNotEmpty) {
      newChapter = _mapChapterNumber(chapters, oldChapter, oldTotal);
    }
  } catch (_) {}

  await db.rebindManga(
    oldMangaId: oldMangaId,
    newMangaId: newMangaId,
    sourceId: newSourceId,
    title: newTitle,
    coverUrl: newCoverUrl,
    totalChapters: newTotal,
    lastReadChapter: newChapter,
  );
  return newChapter;
}

/// Finds the chapter on [chapters] whose number is closest to [oldChapter] and
/// returns its number. When the numbers are entirely incommensurable (e.g. the
/// old source counts linearly while the new one uses volume-scoped numbers), it
/// falls back to a proportional mapping based on total counts.
double _mapChapterNumber(List<Chapter> chapters, double oldChapter, int oldTotal) {
  double? closest;
  double? bestDiff;
  for (final c in chapters) {
    final n = double.tryParse(c.chapterNumber);
    if (n == null) continue;
    final d = (n - oldChapter).abs();
    if (bestDiff == null || d < bestDiff) {
      bestDiff = d;
      closest = n;
    }
  }
  if (closest != null && (bestDiff ?? 0) <= 2.0) return closest;

  if (oldTotal > 0) {
    final target = ((oldChapter / oldTotal) * chapters.length)
        .round()
        .clamp(0, chapters.length - 1);
    final parsed = double.tryParse(chapters[target].chapterNumber);
    if (parsed != null) return parsed;
  }
  return closest ?? oldChapter;
}