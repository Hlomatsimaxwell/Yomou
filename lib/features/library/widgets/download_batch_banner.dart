import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/features/reader/services/download_job.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// In-app progress banner for a live download batch.
///
/// The ongoing notification is the authoritative, always-visible report — this
/// banner is the convenience layer while the manga screen is open, so a
/// multi-minute batch doesn't need the shade pulled down to check on.
///
/// It reports aggregate page progress, which is exactly what the job row
/// records. Per-chapter fractions are not available (see
/// [ChapterJobState]), and faking them would be worse than showing nothing.
class DownloadBatchBanner extends StatelessWidget {
  const DownloadBatchBanner({
    super.key,
    required this.job,
    required this.pendingCount,
    required this.onPause,
    required this.onCancel,
  });

  final DownloadJob? job;

  /// N chapters still being queued (page lists resolved one by one).
  final int pendingCount;
  final VoidCallback onPause;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // The pre-job window: chapters are still being resolved, so there is no
    // job row to read progress from yet.
    if (job == null) {
      if (pendingCount == 0) return const SizedBox.shrink();
      return _Shell(
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.dlgDownloadPreparingChapters(pendingCount),
                style: TextStyle(color: cs.onSurface, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final total = job!.totalChapters;
    final saved = job!.doneChapters;
    final fraction = job!.totalPages == 0 ? 0.0 : job!.progress;
    final paused = job!.status == DownloadJobStatus.paused;
    final queued = job!.status == DownloadJobStatus.queued;

    return _Shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  paused
                      ? l.dlgDownloadPaused
                      : queued
                      ? l.dlgDownloadQueued
                      : l.dlgDownloadChapterOf(
                          (saved + 1).clamp(1, total == 0 ? 1 : total),
                          total,
                        ),
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (job!.totalPages > 0)
                Text(
                  '${(fraction * 100).round()}%',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              _BannerButton(
                icon: paused
                    ? RemixIcons.play_line
                    : RemixIcons.pause_line,
                label: paused ? l.dlgDownloadResume : l.dlgDownloadPause,
                onTap: onPause,
              ),
              _BannerButton(
                icon: RemixIcons.close_line,
                label: l.dlgDownloadCancel,
                onTap: onCancel,
                tint: dark ? Colors.white70 : const Color(0xFF49454F),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              // Indeterminate while the total page count is still unknown.
              value: job!.totalPages == 0 || paused ? null : fraction,
              minHeight: 5,
              backgroundColor: cs.onSurface.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            job!.totalPages > 0
                ? l.dlgDownloadPages(job!.donePages, job!.totalPages)
                : l.dlgDownloadPartialBody(saved, total),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Surface the banner sits on. Uses the app's elevated-card treatment rather
/// than a Material banner so it doesn't read as a system element.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2A2E) : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withValues(alpha: dark ? 0.35 : 0.18),
        ),
      ),
      child: child,
    );
  }
}

/// Icon-only action inside the banner header. 32dp keeps it tappable without
/// competing with the status text for attention.
class _BannerButton extends StatelessWidget {
  const _BannerButton({
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
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      color: tint ?? cs.onSurfaceVariant,
      icon: Icon(icon),
    );
  }
}
