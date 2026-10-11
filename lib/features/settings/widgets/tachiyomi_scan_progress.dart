import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/backup/tachiyomi_backup.dart';
import 'package:yomou/core/backup/tachiyomi_import_resolver.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/content_preferences/providers/content_preferences_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Scans the reader's enabled sources for the Tachiyomi entries whose original
/// source Yomou doesn't carry, showing a small floating pill with the search's
/// progress while it runs.
///
/// The scan is network-bound, and how long it takes depends on how many
/// entries are missing, so it reports itself as a heads-up style notification
/// rather than a modal dialog: the reader can keep using the app while the
/// sources are searched. When there is nothing to scan the parsed result is
/// returned as-is.
Future<TachiyomiImportResult> scanTachiyomiMissingWithProgress(
  BuildContext context,
  WidgetRef ref,
  TachiyomiImportResult parsed,
) async {
  if (parsed.missingMangas.isEmpty) return parsed;
  // The selection loads from prefs asynchronously; wait so the rescue knows the
  // reader's languages (and the source rows reflect them) before searching.
  await ref.read(contentPreferencesProvider.notifier).loaded;
  if (!context.mounted) return parsed;
  final sources = boundVariantFamilies(
    resolveActiveSources(ref.read(visibleSourceRowsProvider)),
  );
  final preferredLanguages = ref.read(contentPreferencesProvider).languages;

  final progress = ValueNotifier<({int done, int total})>(
    (done: 0, total: parsed.missingMangas.length),
  );
  // Insert above the app's own overlay (which a bottom sheet also lives on) so
  // the pill floats over whatever screen is showing.
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _TachiyomiScanPill(progress: progress));
  overlay.insert(entry);
  try {
    return await resolveTachiyomiMissing(
      parsed,
      sources,
      preferredLanguages: preferredLanguages,
      onProgress: (done, total) => progress.value = (done: done, total: total),
    );
  } finally {
    entry.remove();
  }
}

/// A pill-shaped heads-up progress card: a capsule bottom notification with a
/// circular progress indicator that fills as titles are resolved.
class _TachiyomiScanPill extends StatelessWidget {
  const _TachiyomiScanPill({required this.progress});

  final ValueListenable<({int done, int total})> progress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onInverseSurface;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                child: Material(
                  color: scheme.inverseSurface,
                  elevation: 6,
                  shadowColor: Colors.black45,
                  shape: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: fg,
                            backgroundColor: fg.withValues(alpha: 0.18),
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}