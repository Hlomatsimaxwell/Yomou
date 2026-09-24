import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/backup/saf_directory_picker.dart';
import 'package:yomou/core/utils/relative_time.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/settings/screens/frequency_selection_dialog.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

class PeriodicBackupsScreen extends ConsumerStatefulWidget {
  const PeriodicBackupsScreen({super.key});

  @override
  ConsumerState<PeriodicBackupsScreen> createState() =>
      _PeriodicBackupsScreenState();
}

class _PeriodicBackupsScreenState extends ConsumerState<PeriodicBackupsScreen> {
  String _frequencyLabel(String code) {
    switch (code) {
      case '6h':
        return 'Every 6 hours';
      case '1d':
        return 'Every day';
      case '2d':
        return 'Every 2 days';
      case '1w':
        return 'Once per week';
      case '2w':
        return 'Twice per month';
      case '1m':
        return 'Once per month';
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(cacheSettingsProvider);
    final notifier = ref.read(cacheSettingsProvider.notifier);

    return Scaffold(
      appBar: SettingsAppBar(title: l.periodicBackups),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        children: [
          _ToggleCard(
            title: l.enablePeriodicBackups,
            value: settings.enablePeriodicBackups,
            onChanged: (bool value) {
              notifier.setEnablePeriodicBackups(value);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          _OutputDirectorySection(
            title: l.backupsOutputDirectory,
            path: settings.backupsOutputDirectory.isEmpty
                ? l.backupsOutputDirectoryNone
                : settings.backupsOutputDirectory,
            onTap: () async {
              final uri = await pickBackupDirectory();
              if (uri == null || !mounted) return;
              notifier.setBackupsOutputDirectory(uri);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          _BuildRow(
            icon: RemixIcons.time_line,
            title: l.backupCreationFrequency,
            subtitle: _frequencyLabel(settings.backupFrequency),
            onTap: () {
              showFrequencySelectionSheet(context, ref);
            },
          ),
          _BuildRow(
            icon: RemixIcons.delete_bin_line,
            title: l.deleteOldBackups,
            subtitle:
                'Auto remove backups older than ${settings.maxNumberOfBackups}',
            trailing: _CustomSwitch(
              value: settings.deleteOldBackups,
              onChanged: (bool value) {
                notifier.setDeleteOldBackups(value);
                setState(() {});
              },
            ),
          ),
          _BuildRow(
            icon: RemixIcons.archive_line,
            title: l.maxNumberOfBackups,
            subtitle: 'Maximum number of backups to keep',
            trailing: Text(
              '${settings.maxNumberOfBackups}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: _PillSlider(
              value: settings.maxNumberOfBackups,
              min: 1,
              max: 30,
              onChanged: (int value) {
                notifier.setMaxNumberOfBackups(value);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  RemixIcons.information_line,
                  size: 18,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    settings.lastBackupAt <= 0
                        ? l.lastSuccessfulBackupTime(l.backupNever)
                        : l.lastSuccessfulBackupTime(relativeTimeLabel(
                            l,
                            DateTime.fromMillisecondsSinceEpoch(
                              settings.lastBackupAt,
                            ),
                          )),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends ConsumerWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          _CustomSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _OutputDirectorySection extends StatelessWidget {
  final String title;
  final String path;
  final VoidCallback onTap;

  const _OutputDirectorySection({
    required this.title,
    required this.path,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              path,
              style: TextStyle(
                fontSize: 12,
                color: color.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _BuildRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

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
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: trailing,
    );
  }
}

class _CustomSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final isActive = value;

    return GestureDetector(
      onTap: () => onChanged(!value),
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

class _PillSlider extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _PillSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  _PillSliderState createState() => _PillSliderState();
}

class _PillSliderState extends State<_PillSlider> {
  double _position(double dx, double width) {
    final range = widget.max - widget.min;
    final t = ((dx / width).clamp(0.0, 1.0));
    return widget.min + (t * range);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final fraction =
        (widget.value - widget.min) / (widget.max - widget.min);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return SizedBox(
          height: 32,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              widget.onChanged(_position(details.localPosition.dx, width).round());
            },
            onHorizontalDragUpdate: (details) {
              widget.onChanged(_position(details.localPosition.dx, width).round());
            },
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: color.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  height: 6,
                  width: width * fraction,
                  decoration: BoxDecoration(
                    color: color.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Positioned(
                  left: width * fraction - 14,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.primary,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}