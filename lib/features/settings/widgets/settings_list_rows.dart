import 'package:flutter/material.dart';

/// A small heading above a run of rows on a settings screen.
///
/// Shared by the Backup and restore screen and the Accounts and sync screen,
/// which are both lists of actions rather than preference groups.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color.primary,
        ),
      ),
    );
  }
}

/// A tappable settings row with an icon, a title and an optional subtitle.
///
/// A null [onTap] renders the row disabled, which is how features that are not
/// available yet ("coming soon") are shown.
class SettingsListRow extends StatelessWidget {
  const SettingsListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final disabled = onTap == null;

    return ListTile(
      enabled: !disabled,
      leading: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Icon(icon, size: 26, color: color.onSurfaceVariant),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: color.onSurfaceVariant,
                ),
              ),
            ),
      onTap: onTap,
    );
  }
}
