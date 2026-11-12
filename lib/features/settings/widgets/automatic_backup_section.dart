import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/backup/backup_schedule.dart';
import 'package:yomou/core/utils/relative_time.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/settings/screens/frequency_selection_dialog.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Schedule and retention for backups uploaded to Google Drive.
///
/// The run itself happens on launch and on resume (see
/// `PeriodicBackupService`), so everything here is only configuration; there
/// is no "start" button because there is nothing to start in the background.
class AutomaticBackupSection extends ConsumerWidget {
  const AutomaticBackupSection({super.key, required this.signedIn});

  /// Turning the schedule on without a session would only produce runs that
  /// skip themselves, so the toggle waits for sign-in.
  final bool signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme;
    final settings = ref.watch(cacheSettingsProvider);
    final notifier = ref.read(cacheSettingsProvider.notifier);

    final interval = backupIntervalFor(settings.backupFrequency);
    final last = settings.lastBackupAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(settings.lastBackupAt)
        : null;
    final overdue = settings.enablePeriodicBackups &&
        last != null &&
        DateTime.now().difference(last) > interval * 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Automatic backups',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        _ToggleCard(
          title: 'Back up automatically',
          value: settings.enablePeriodicBackups,
          enabled: signedIn,
          onChanged: (value) => notifier.setEnablePeriodicBackups(value),
        ),
        if (!signedIn)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Sign in to Google Drive to turn this on.',
              style: TextStyle(fontSize: 12, color: color.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 8),
        _Row(
          icon: MdiIcons.clockOutline,
          title: l.backupCreationFrequency,
          subtitle: backupFrequencyLabel(settings.backupFrequency),
          onTap: () => showFrequencySelectionSheet(context, ref),
        ),
        _Row(
          icon: MdiIcons.deleteOutline,
          title: l.deleteOldBackups,
          subtitle:
              'Auto remove backups older than ${settings.maxNumberOfBackups}',
          trailing: _Switch(
            value: settings.deleteOldBackups,
            onChanged: (value) => notifier.setDeleteOldBackups(value),
          ),
        ),
        _Row(
          icon: MdiIcons.archiveOutline,
          title: l.maxNumberOfBackups,
          subtitle: 'Maximum number of backups to keep',
          trailing: Text(
            '${settings.maxNumberOfBackups}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color.primary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 46),
          child: Slider(
            value: settings.maxNumberOfBackups.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: (value) =>
                notifier.setMaxNumberOfBackups(value.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(
                MdiIcons.informationOutline,
                size: 18,
                color: color.outline,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  settings.lastBackupAt <= 0
                      ? l.lastSuccessfulBackupTime(l.backupNever)
                      : l.lastSuccessfulBackupTime(
                          relativeTimeLabel(l, last!),
                        ),
                  style: TextStyle(
                    fontSize: 12,
                    color: color.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (overdue)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Automatic backups are overdue.',
              style: TextStyle(fontSize: 12, color: color.error),
            ),
          ),
        if (settings.lastBackupError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Last automatic backup failed: ${settings.lastBackupError}',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color.error),
            ),
          ),
      ],
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Icon(icon, size: 26, color: color.onSurfaceVariant),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: color.onSurfaceVariant),
        ),
      ),
      trailing: trailing,
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final isActive = value;

    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isActive
              ? color.primary
              : color.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
