import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/features/settings/screens/appearance_settings_screen.dart';
import 'package:yomou/features/settings/screens/manga_sources_settings_screen.dart';
import 'package:yomou/features/settings/screens/backup_restore_screen.dart';
import 'package:yomou/features/settings/screens/notification_settings_screen.dart';
import 'package:yomou/features/settings/screens/storage_settings_screen.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/widgets/m3_components.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sourceRows =
        ref.watch(sourcesProvider).where((s) => s['name'] != 'Mock Source');
    final sourceList = sourceRows.toList();
    final enabledCount = sourceList.where(isSourceEnabled).length;
    final totalCount = sourceList.length;
    return Scaffold(
      appBar: SettingsAppBar(title: l.settings),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSettingTile(
            context: context,
            icon: RemixIcons.palette_line,
            title: l.settingsAppearance,
            subtitle: l.settingsAppearanceSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AppearanceSettingsScreen(),
                ),
              );
            },
          ),
          _buildSettingTile(
            context: context,
            icon: RemixIcons.window_2_line,
            title: l.settingsMangaSources,
            subtitle: l.settingsMangaSourcesSubtitle(enabledCount, totalCount),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MangaSourcesSettingsScreen(),
                ),
              );
            },
          ),
          _buildSettingTile(
            context: context,
            icon: RemixIcons.book_open_line,
            title: l.settingsReader,
            subtitle: l.settingsReaderSubtitle,
            onTap: () {},
          ),
          _buildSettingTile(
            context: context,
            icon: RemixIcons.refresh_line,
            title: l.settingsStorage,
            subtitle: l.settingsStorageSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StorageSettingsScreen(),
                ),
              );
            },
          ),
          _buildSettingTile(
            context: context,
            icon: RemixIcons.download_line,
            title: l.settingsDownloads,
            subtitle: l.settingsDownloadsSubtitle,
            onTap: () {},
          ),
          _buildSettingTile(
            context: context,
            icon: RemixIcons.rss_line,
            title: l.settingsNewChapters,
            subtitle: l.settingsNewChaptersSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          _buildSettingTile(
            context: context,
            icon: RemixIcons.puzzle_2_line,
            title: l.settingsServices,
            subtitle: l.settingsServicesSubtitle,
            onTap: () {},
          ),
          _buildSettingTile(
            context: context,
            icon: RemixIcons.history_line,
            title: l.settingsBackup,
            subtitle: l.settingsBackupSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BackupRestoreScreen(),
                ),
              );
            },
          ),
          _buildAboutTile(
            context: context,
            icon: RemixIcons.information_line,
            title: l.settingsAbout,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTile({
    required BuildContext context,
    required IconData icon,
    required String title,
  }) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final subtitle = info == null
            ? '--'
            : 'Version ${info.version} (${info.buildNumber})';
        return _buildSettingTile(
          context: context,
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: () => _showAboutDialog(context, info),
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context, PackageInfo? info) {
    final l = AppLocalizations.of(context);
    final rows = <List<String>>[
      [l.settingsAboutVersion, info?.version ?? '--'],
      [l.settingsAboutBuild, info?.buildNumber ?? '--'],
      [l.settingsAboutPackage, info?.packageName ?? '--'],
    ];
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            l.settingsAbout,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${row[0]}:  ',
                          style: TextStyle(
                            color: dark ? Colors.white54 : const Color(0xFF49454F),
                          ),
                        ),
                        TextSpan(
                          text: row[1],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: dark ? Colors.white : const Color(0xFF1C1B1F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l.filterCancel,
                style: TextStyle(
                  color: dark ? Colors.white70 : const Color(0xFF49454F),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Icon(icon, size: 26),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle),
      ),
      onTap: onTap,
    );
  }
}
