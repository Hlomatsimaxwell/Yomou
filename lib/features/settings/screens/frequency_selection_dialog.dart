import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/backup/backup_schedule.dart';
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

  return showM3ModalSheet(
    context,
    title: l.backupCreationFrequency,
    maxHeightFactor: 0.5,
    children: [
      for (final entry in backupFrequencyOptions.entries)
        ListTile(
          title: Text(entry.value),
          trailing: entry.key == current
              ? Icon(
                  MdiIcons.check,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
          onTap: () {
            notifier.setBackupFrequency(entry.key);
            Navigator.pop(context);
          },
        ),
    ],
  );
}