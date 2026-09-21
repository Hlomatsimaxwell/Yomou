import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/features/settings/screens/appearance_settings_screen.dart';
import 'package:yomou/features/settings/screens/notification_settings_screen.dart';
import 'package:yomou/features/settings/screens/storage_settings_screen.dart';
import 'package:yomou/widgets/m3_components.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
            icon: RemixIcons.bookmark_3_line,
            title: l.settingsMangaSources,
            subtitle: l.settingsMangaSourcesSubtitle,
            onTap: () {},
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
            icon: RemixIcons.pie_chart_2_line,
            title: l.settingsStorage,
            subtitle: l.settingsStorageSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StorageSettingsScreen(),
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
                  builder: (_) => const NotificationSettingsScreen(),
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
            onTap: () {},
          ),
          _buildSettingTile(
            context: context,
            icon: RemixIcons.information_line,
            title: l.settingsAbout,
            subtitle: l.settingsAboutSubtitle,
            onTap: () {},
          ),
        ],
      ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Icon(icon, size: 26),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle),
      ),
      onTap: onTap,
    );
  }
}