import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

/// Where a chapter sits in the live download job's queue.
enum ChapterJobState {
  /// Not part of any active batch.
  none,

  /// In the queue but not started yet.
  pending,

  /// The chapter the worker is currently writing.
  active,

  /// Fully on disk as part of this batch.
  saved,
}

/// Per-chapter marker for the live download job.
///
/// The job row stores aggregate page counts rather than a per-chapter cursor,
/// so the marker reflects queue position (see `_jobChapterState`) instead of
/// claiming a page-level fraction it can't know.
class ChapterJobIndicator extends StatelessWidget {
  const ChapterJobIndicator({
    super.key,
    required this.state,
    required this.isDark,
  });

  final ChapterJobState state;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = isDark ? Colors.white : cs.primary;

    switch (state) {
      case ChapterJobState.none:
        return const SizedBox.shrink();
      case ChapterJobState.active:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: accent,
            backgroundColor: isDark ? Colors.white24 : Colors.black12,
          ),
        );
      case ChapterJobState.pending:
        return Icon(
          RemixIcons.time_line,
          size: 18,
          color: isDark ? Colors.white38 : Colors.black38,
        );
      case ChapterJobState.saved:
        return Icon(RemixIcons.check_double_line, size: 18, color: accent);
    }
  }
}
