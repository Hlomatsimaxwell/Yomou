import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/features/reader/services/download_job.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// A live download batch, shown above the time-grouped history.
///
/// One card is one WorkManager job is one foreground service, which is the
/// same 1:1 mapping Kotatsu uses — its per-manga card is the work item, so
/// pausing and cancelling act on a whole series' batch rather than one chapter
/// at a time.
///
/// The progress bar reports aggregate pages, which is precisely what the job
/// row stores. There is no per-chapter page fraction to show, and inventing one
/// would be a lie the user can catch.
class DownloadJobCard extends StatelessWidget {
  const DownloadJobCard({
    super.key,
    required this.job,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRemove,
  });

  final DownloadJob job;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final active = job.status.isActive;
    final paused = job.status == DownloadJobStatus.paused;
    final failed = job.status == DownloadJobStatus.failed;
    final fraction = job.totalPages == 0 ? 0.0 : job.progress;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E1E20) : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? cs.primary.withValues(alpha: dark ? 0.40 : 0.22)
              : cs.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 72,
              child: CachedMangaImage(
                imageUrl: job.coverUrl ?? '',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.mangaTitle ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusLine(l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: failed ? cs.error : cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    // Unknown page total, or a job that isn't moving, gets an
                    // indeterminate bar rather than a stalled 0%.
                    value: job.totalPages == 0 || paused || !active
                        ? (job.totalPages == 0 && active ? null : fraction)
                        : fraction,
                    minHeight: 5,
                    backgroundColor: cs.onSurface.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      failed ? cs.error : cs.primary,
                    ),
                  ),
                ),
                if (job.error != null && job.error!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    job.error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.error, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          _JobAction(
            icon: paused ? RemixIcons.play_line : RemixIcons.pause_line,
            label: paused ? l.dlgDownloadResume : l.dlgDownloadPause,
            onTap: paused ? onResume : onPause,
          ),
          _JobAction(
            icon: RemixIcons.close_line,
            label: l.dlgDownloadCancel,
            tint: cs.onSurfaceVariant,
            onTap: onCancel,
          ),
          // A finished batch only needs a way to clear itself off the list.
          if (!active)
            _JobAction(
              icon: RemixIcons.delete_bin_6_line,
              label: l.dlgDownloadRemoveJob,
              tint: cs.error,
              onTap: onRemove,
            ),
        ],
      ),
    );
  }

  /// Headline under the title: the phase first, then the concrete counts, so
  /// the user can tell "waiting on Wi-Fi" apart from "stuck at 40%".
  String _statusLine(AppLocalizations l) {
    if (job.status == DownloadJobStatus.queued) {
      return l.dlgDownloadQueued;
    }
    if (job.status == DownloadJobStatus.paused) {
      return l.dlgDownloadPaused;
    }
    if (job.status == DownloadJobStatus.cancelled) {
      return l.dlgDownloadCancelled;
    }
    if (job.totalPages == 0) return l.dlgDownloadPreparing;
    return '${l.dlgDownloadChapterOf(_currentChapter(), job.totalChapters)}'
        ' · ${l.dlgDownloadPages(job.donePages, job.totalPages)}';
  }

  /// 1-based index of the chapter being written, clamped to the batch size.
  int _currentChapter() {
    if (job.totalChapters == 0) return 0;
    return (job.doneChapters + 1).clamp(1, job.totalChapters);
  }
}

/// Compact icon action. 36dp is the minimum that stays comfortable to hit
/// without crowding the card's text column.
class _JobAction extends StatelessWidget {
  const _JobAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onTap,
      tooltip: label,
      visualDensity: VisualDensity.compact,
      iconSize: 19,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      color: tint ?? cs.primary,
      icon: Icon(icon),
    );
  }
}
