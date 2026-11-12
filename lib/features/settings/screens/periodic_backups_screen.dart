import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/backup/google_drive_service.dart';
import 'package:yomou/features/settings/widgets/automatic_backup_section.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Automatic backup schedule for Google Drive backups.
///
/// Split out of `GoogleDriveBackupScreen` so the settings list isn't crowded:
/// tapping the row opens the toggle, frequency and retention controls.
class PeriodicBackupsScreen extends ConsumerWidget {
  const PeriodicBackupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final signedIn = GoogleDriveService.instance.isSignedIn;

    return Scaffold(
      appBar: SettingsAppBar(title: l.periodicBackups, contentMargin: 24),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        children: [AutomaticBackupSection(signedIn: signedIn)],
      ),
    );
  }
}
