import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/backup/tachiyomi_backup.dart';
import 'package:yomou/core/backup/tachiyomi_import_resolver.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/content_preferences/providers/content_preferences_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// One-line completion message for an import, e.g. "25 manga imported from
/// Tachiyomi/Mihon · 2 not imported". Shown as a toast when an import finishes.
String importFinishedMessage(
  AppLocalizations l,
  TachiyomiImportResult result,
) {
  final base = l.tachiyomiImportDone(result.imported);
  return result.skipped > 0
      ? '$base · ${l.importResultsNotImported(result.skipped)}'
      : base;
}

/// Scans the reader's enabled sources for the Tachiyomi entries whose original
/// source Yomou doesn't carry, showing a small floating pill with the search's
/// progress while it runs.
///
/// The scan is network-bound, and how long it takes depends on how many
/// entries are missing, so it reports itself as a heads-up style notification
/// rather than a modal dialog: it floats above the bottom navigation and never
/// swallows taps, so the reader can keep using the app while the sources are
/// searched. When there is nothing to scan the parsed result is returned as-is.
///
/// [onProgress] receives the same (done, total) updates the pill shows, so a
/// caller can mirror the scan into the notification shade as well.
Future<TachiyomiImportResult> scanTachiyomiMissingWithProgress(
  BuildContext context,
  WidgetRef ref,
  TachiyomiImportResult parsed, {
  void Function(int done, int total)? onProgress,
}) async {
  if (parsed.missingMangas.isEmpty) return parsed;
  // The selection loads from prefs asynchronously; wait so the rescue knows the
  // reader's languages (and the source rows reflect them) before searching.
  await ref.read(contentPreferencesProvider.notifier).loaded;
  if (!context.mounted) return parsed;
  final sources = boundVariantFamilies(
    resolveActiveSources(ref.read(visibleSourceRowsProvider)),
  );
  final preferredLanguages = ref.read(contentPreferencesProvider).languages;
  final accent = ref.read(accentProvider);

  final progress = ValueNotifier<({int done, int total})>(
    (done: 0, total: parsed.missingMangas.length),
  );
  // Insert above the app's own overlay (which a bottom sheet also lives on) so
  // the pill floats over whatever screen is showing.
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TachiyomiScanPill(progress: progress, accent: accent),
  );
  overlay.insert(entry);
  try {
    return await resolveTachiyomiMissing(
      parsed,
      sources,
      preferredLanguages: preferredLanguages,
      onProgress: (done, total) {
        progress.value = (done: done, total: total);
        onProgress?.call(done, total);
      },
    );
  } finally {
    entry.remove();
  }
}

/// A pill-shaped heads-up progress card: a capsule bottom notification with a
/// circular progress indicator that fills as titles are resolved.
///
/// Styled like the app's floating navigation pill (same surface colors and
/// corner radius) so it belongs to the theme rather than fighting it, floats
/// above the bottom bar, and is wrapped in [IgnorePointer] so it can never
/// block a tap anywhere on the screen.
class _TachiyomiScanPill extends StatelessWidget {
  const _TachiyomiScanPill({required this.progress, required this.accent});

  final ValueListenable<({int done, int total})> progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = Theme.of(context).colorScheme.onSurface;
    final pillColor = dark ? const Color(0xF21C1C1E) : Colors.white;
    final pillBorder = dark
        ? const Color(0x332C2C30)
        : Colors.black.withValues(alpha: 0.08);

    // Sits just above the floating/solid bottom bar on the tabbed screens. On
    // pushed routes that have no bar it floats a little higher, which still
    // reads as a notification.
    final bottomGap = bottomBarTopEdge(context) + 12;

    return Material(
      // Same as the toast: this pill goes straight into the root overlay, so
      // without a Material above it its text drew in Flutter's fallback style,
      // underlined in double yellow.
      type: MaterialType.transparency,
      child: IgnorePointer(
        ignoring: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomGap),
            child: ValueListenableBuilder<({int done, int total})>(
              valueListenable: progress,
              builder: (context, value, _) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * t,
                      child: child,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: pillBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: accent,
                            backgroundColor: accent.withValues(alpha: 0.18),
                            value: value.total > 0
                                ? value.done / value.total
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.importScanTitle,
                              style: TextStyle(
                                color: fg,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.importScanProgress(value.done, value.total),
                              style: TextStyle(
                                color: fg.withValues(alpha: 0.72),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}