import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/notifications/update_checker.dart';
import 'package:yomou/data/providers/sources_provider.dart';

/// A manga from the user's library that has new chapters available.
class MangaUpdate {
  final String mangaId;
  final String title;
  final String coverUrl;
  final String sourceId;
  final int newCount;
  final int liveTotal;
  final int lastSeenChapters;
  final String latestChapterTitle;
  final DateTime? latestChapterDate;
  final bool isFavorite;

  const MangaUpdate({
    required this.mangaId,
    required this.title,
    required this.coverUrl,
    required this.sourceId,
    required this.newCount,
    required this.liveTotal,
    required this.lastSeenChapters,
    required this.latestChapterTitle,
    this.latestChapterDate,
    required this.isFavorite,
  });

  /// Whether this manga has an update the user hasn't opened yet (drives the
  /// list dot). The entry and its count always stay visible.
  bool get hasUnseenUpdate =>
      newCount > 0 && liveTotal > lastSeenChapters;

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

/// Manga in the user's library (history + favorites) with more chapters than
/// the last count stored when they were read. Each series is checked against
/// the source it was read from; sources the user disabled are skipped.
final updatesProvider = FutureProvider<List<MangaUpdate>>((ref) async {
  // Let the first frames render before the (heavy) library scan kicks in, so
  // the app never feels frozen at launch on slower devices.
  await Future.delayed(const Duration(seconds: 2));

  final disabled = <String>{
    for (final row in ref.watch(sourcesProvider))
      if (!isSourceEnabled(row) && (row['name'] as String? ?? '').isNotEmpty)
        getSourceByName(row['name'] as String).id,
  };

  final statuses = await UpdateChecker.checkLibrary(
    disabledSourceIds: disabled,
  );

  final updates =
      statuses
          .where((status) => status.newSinceRead > 0)
          .map(
            (status) => MangaUpdate(
              mangaId: status.mangaId,
              title: status.title,
              coverUrl: status.coverUrl,
              sourceId: status.sourceId,
              newCount: status.newSinceRead,
              liveTotal: status.liveTotal,
              lastSeenChapters: status.lastSeenChapters,
              latestChapterTitle: status.latestChapterTitle,
              latestChapterDate: status.latestChapterDate,
              isFavorite: status.isFavorite,
            ),
          )
          .toList()
        ..sort((a, b) => b.sortKey.compareTo(a.sortKey));

  return updates;
});

/// Unread-chapter badge count shown on the Home/Feed tabs. It is persisted to
/// SharedPreferences by the Feed screen after every scan so the widget tree
/// never triggers the (heavy) library scan at cold start — opening the Feed
/// screen is what starts a scan.
final updatesBadgeProvider = FutureProvider<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('updatesBadgeCount') ?? 0;
});

const kUpdatesBadgePrefKey = 'updatesBadgeCount';
