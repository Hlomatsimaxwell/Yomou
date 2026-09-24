import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';

/// Time ranges the statistics charts can be sliced by (trailing windows).
enum StatsTimeRange { day, week, month, threeMonths, allTime }

final statsRangeProvider = StateProvider<StatsTimeRange>(
  (ref) => StatsTimeRange.week,
);

/// When true, charts and lists only include titles on the favorites list.
final statsFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

/// Estimate applied per legacy chapter-read row (before the reader started
/// measuring real session time). Keeps pre-existing history meaningful in the
/// charts without inventing per-manga numbers.
const int kLegacyMinPerChapter = 4;

/// One manga's slice in the statistics donut + legend.
class ReadingStatSlice {
  const ReadingStatSlice({
    required this.mangaId,
    required this.title,
    required this.minutes,
  });

  final String mangaId;
  final String title;
  final int minutes;
}

/// Builds per-manga reading minutes for the selected range. Real session time
/// comes from `reading_time` (measured by the reader); for (manga, day) pairs
/// that predate session tracking, distinct chapter reads are estimated via
/// [kLegacyMinPerChapter]. Watches history + favorites so the charts stay live.
final readingStatisticsProvider =
    FutureProvider<List<ReadingStatSlice>>((ref) async {
  ref.watch(historyRevisionProvider);
  final favoritesOnly = ref.watch(statsFavoritesOnlyProvider);
  final startKey = rangeStartKey(ref.watch(statsRangeProvider));

  final measured = await DatabaseHelper.instance.getReadingTime();
  final progress = await DatabaseHelper.instance.getAllReadingProgress();

  final minutesByManga = <String, int>{};
  final measuredPairs = <String>{};
  for (final row in measured) {
    final mangaId = (row['mangaId'] ?? '').toString();
    final day = (row['day'] ?? '').toString();
    if (mangaId.isEmpty || day.isEmpty) continue;
    if (startKey != null && day.compareTo(startKey) < 0) continue;
    measuredPairs.add('$mangaId|$day');
    minutesByManga[mangaId] =
        (minutesByManga[mangaId] ?? 0) + ((row['minutes'] as num?) ?? 0).toInt();
  }

  // Legacy estimate: distinct chapters read on days without any measured time.
  final seenChapterPairs = <String>{};
  final estimatedByManga = <String, int>{};
  for (final row in progress) {
    final at = DateTime.tryParse((row['lastReadAt'] ?? '').toString());
    if (at == null) continue;
    final day = at.toIso8601String().substring(0, 10);
    if (startKey != null && day.compareTo(startKey) < 0) continue;
    final mangaId = (row['mangaId'] ?? '').toString();
    final pair = '$mangaId|$day';
    if (measuredPairs.contains(pair)) continue;
    if (!seenChapterPairs.add('$pair|${row['chapterId']}')) continue;
    estimatedByManga[mangaId] = (estimatedByManga[mangaId] ?? 0) + 1;
  }
  estimatedByManga.forEach((mangaId, chapters) {
    minutesByManga[mangaId] =
        (minutesByManga[mangaId] ?? 0) + chapters * kLegacyMinPerChapter;
  });

  if (favoritesOnly) {
    final favorites = await ref.watch(favoritesProvider.future);
    final favoriteIds = favorites.map((f) => f.id).toSet();
    minutesByManga.removeWhere((id, _) => !favoriteIds.contains(id));
  }

  final entries = minutesByManga.entries
      .where((e) => e.value > 0)
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final slices = await Future.wait(entries.map((e) async {
    final row = await DatabaseHelper.instance.getManga(e.key);
    return ReadingStatSlice(
      mangaId: e.key,
      title: (row?['title'] as String?)?.isNotEmpty == true
          ? row!['title'] as String
          : 'Unknown',
      minutes: e.value,
    );
  }));

  return slices;
});

/// First day-key (inclusive) for a range, or null for all time.
String? rangeStartKey(StatsTimeRange range) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = switch (range) {
    StatsTimeRange.day => today,
    StatsTimeRange.week => today.subtract(const Duration(days: 6)),
    StatsTimeRange.month => today.subtract(const Duration(days: 29)),
    StatsTimeRange.threeMonths => today.subtract(const Duration(days: 89)),
    StatsTimeRange.allTime => null,
  };
  return start?.toIso8601String().substring(0, 10);
}