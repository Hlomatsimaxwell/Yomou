import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/backup/tachiyomi_backup.dart';
import 'package:yomou/core/backup/tachiyomi_import_resolver.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Scans the reader's enabled sources for the Tachiyomi entries whose original
/// source Yomou doesn't carry, showing a blocking progress dialog while the
/// (network-bound) search runs.
///
/// Returns the enriched result (recovered entries filled in, still-unmatched
/// ones moved into `skippedMangas`). The caller then hands it to
/// `BackupRestore.applyTachiyomi`. When there is nothing to scan the parsed
/// result is returned as-is.
Future<TachiyomiImportResult> scanTachiyomiMissingWithProgress(
  BuildContext context,
  WidgetRef ref,
  TachiyomiImportResult parsed,
) async {
  if (parsed.missingMangas.isEmpty) return parsed;
  final sources = boundVariantFamilies(
    resolveActiveSources(ref.read(visibleSourceRowsProvider)),
  );

  final progress = ValueNotifier<({int done, int total})>(
    (done: 0, total: parsed.missingMangas.length),
  );
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TachiyomiScanDialog(progress: progress),
  );
  try {
    return await resolveTachiyomiMissing(
      parsed,
      sources,
      onProgress: (done, total) => progress.value = (done: done, total: total),
    );
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

class _TachiyomiScanDialog extends StatelessWidget {
  const _TachiyomiScanDialog({required this.progress});

  final ValueListenable<({int done, int total})> progress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder<({int done, int total})>(
            valueListenable: progress,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  l.importScanTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.importScanProgress(value.done, value.total),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
