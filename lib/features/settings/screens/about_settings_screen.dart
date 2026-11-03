import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yomou/core/app_update/app_update_service.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/settings/screens/changelog_screen.dart';
import 'package:yomou/features/settings/screens/privacy_policy_screen.dart';
import 'package:yomou/features/settings/screens/terms_of_service_screen.dart';
import 'package:yomou/features/settings/widgets/settings_list_rows.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

const String _repoUrl = 'https://github.com/Hlomatsimaxwell/Yomou';

/// A full About page, matching the shape of Kotatsu-Redo's: the running
/// version and the changelog first, then the project links.
class AboutSettingsScreen extends ConsumerStatefulWidget {
  const AboutSettingsScreen({super.key});

  @override
  ConsumerState<AboutSettingsScreen> createState() =>
      _AboutSettingsScreenState();
}

class _AboutSettingsScreenState extends ConsumerState<AboutSettingsScreen> {
  PackageInfo? _info;
  bool _checkingForUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _info = info);
    } catch (_) {
      // A platform without package info still gets the links below.
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checkingForUpdates) return;
    setState(() => _checkingForUpdates = true);
    try {
      ref.invalidate(appUpdateProvider);
      final update = await ref.read(appUpdateProvider.future);
      if (!mounted) return;
      if (update == null) {
        showIosToast(
          context,
          message: AppLocalizations.of(context).aboutNoUpdate,
        );
        return;
      }
      final uri = Uri.parse(update.apkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } finally {
      if (mounted) setState(() => _checkingForUpdates = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _reportBug() async {
    final info = _info;
    final version = info?.version ?? '';
    final build = info?.buildNumber ?? '';
    final body = Uri.encodeComponent(
      'Version: $version+$build\n'
      'Platform: ${Theme.of(context).platform.name}\n'
      '\nDescribe the issue:\n',
    );
    await _openUrl('$_repoUrl/issues/new?title=Bug+report&body=$body');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final info = _info;
    final color = Theme.of(context).colorScheme;
    final versionTitle = info == null
        ? l.settingsAbout
        : '${l.settingsAboutVersion} ${info.version}';

    return Scaffold(
      appBar: SettingsAppBar(title: l.settingsAbout),
      body: CappedContentWidth(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SettingsListRow(
              icon: MdiIcons.informationOutline,
              title: versionTitle,
              subtitle: _checkingForUpdates
                  ? l.aboutCheckingForUpdates
                  : l.aboutCheckForUpdates,
              onTap: _checkingForUpdates ? null : _checkForUpdates,
            ),
            SettingsListRow(
              icon: MdiIcons.newBox,
              title: l.aboutChangelog,
              subtitle: l.aboutChangelogSubtitle,
              onTap: () => SettingsPaneScope.openScreen(
                context,
                const ChangelogScreen(),
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              thickness: 1,
              color: color.outlineVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            SettingsListRow(
              icon: MdiIcons.codeTags,
              title: l.aboutSourceCode,
              subtitle: _repoUrl,
              onTap: () => _openUrl(_repoUrl),
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              thickness: 1,
              color: color.outlineVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            SettingsListRow(
              icon: MdiIcons.shieldCheckOutline,
              title: l.privacyPolicy,
              subtitle: l.privacyPolicySubtitle,
              onTap: () => SettingsPaneScope.openScreen(
                context,
                const PrivacyPolicyScreen(),
              ),
            ),
            SettingsListRow(
              icon: MdiIcons.scaleBalance,
              title: l.termsOfService,
              subtitle: l.termsOfServiceSubtitle,
              onTap: () => SettingsPaneScope.openScreen(
                context,
                const TermsOfServiceScreen(),
              ),
            ),
            SettingsListRow(
              icon: MdiIcons.bugOutline,
              title: l.aboutReportBug,
              subtitle: '$_repoUrl/issues',
              onTap: _reportBug,
            ),
            if (info != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  '${l.settingsAboutBuild} ${info.buildNumber} · '
                  '${info.packageName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: color.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
