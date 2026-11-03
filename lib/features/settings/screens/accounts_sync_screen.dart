import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/settings/screens/google_drive_backup_screen.dart';
import 'package:yomou/features/settings/widgets/settings_list_rows.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// The account-backed half of your data: copying the library somewhere that
/// outlives the device.
///
/// It lives apart from Backup and restore because those rows move data between
/// files on this device, while these sign in to a service and keep a copy in
/// the cloud.
class AccountsSyncScreen extends StatelessWidget {
  const AccountsSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: SettingsAppBar(title: l.settingsAccountsSync),
      body: CappedContentWidth(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SettingsSectionHeader(title: l.cloudBackup),
            SettingsListRow(
              icon: Icons.cloud,
              title: l.googleDriveBackup,
              subtitle: 'Google account',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GoogleDriveBackupScreen(),
                  ),
                );
              },
            ),
            SettingsListRow(
              icon: MdiIcons.cloudOutline,
              title: 'WebDAV backup',
              subtitle: l.comingSoon,
              onTap: null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
