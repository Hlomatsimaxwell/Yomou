import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Shows the backup-frequency selector as a bottom sheet matching the app's
/// settings style (drag-handle sheet, list rows, check mark on the selected
/// one). Applying the choice immediately when a row is tapped.
Future<void> showFrequencySelectionSheet(
  BuildContext context,
  WidgetRef ref,
) {
  final l = AppLocalizations.of(context);
  final current = ref.read(cacheSettingsProvider).backupFrequency;
  final notifier = ref.read(cacheSettingsProvider.notifier);

  final options = <String, String>{
    'Every 6 hours': '6h',
    'Every day': '1d',
    'Every 2 days': '2d',
    'Once per week': '1w',
    'Twice per month': '2w',
    'Once per month': '1m',
  };

  return showM3ModalSheet(
    context,
    title: l.backupCreationFrequency,
    maxHeightFactor: 0.5,
    children: [
      for (final entry in options.entries)
        ListTile(
          title: Text(entry.key),
          trailing: entry.value == current
              ? Icon(
                  RemixIcons.check_line,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
          onTap: () {
            notifier.setBackupFrequency(entry.value);
            Navigator.pop(context);
          },
        ),
    ],
  );
}