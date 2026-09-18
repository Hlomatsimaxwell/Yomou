import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';
import 'package:yomou/widgets/safe_image.dart';

/// Timestamped history of background check runs and posted suggestions
/// (Kotatsu's "Checking for new chapters log").
class NotificationLogScreen extends StatefulWidget {
  const NotificationLogScreen({super.key});

  @override
  State<NotificationLogScreen> createState() => _NotificationLogScreenState();
}

class _NotificationLogScreenState extends State<NotificationLogScreen> {
  List<Map<String, dynamic>>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await DatabaseHelper.instance.getNotificationLogs();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: SettingsAppBar(title: l.notificationLog),
      body: _entries == null
          ? const Center(child: CircularProgressIndicator())
          : _entries!.isEmpty
          ? Center(
              child: Text(
                l.notificationLogEmpty,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _entries!.length,
              itemBuilder: (context, index) {
                final entry = _entries![index];
                final at = DateTime.tryParse(entry['at']?.toString() ?? '');
                return _LogTile(
                  entry: entry,
                  timeLabel: at == null ? '' : _formatTime(at),
                );
              },
            ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry, required this.timeLabel});

  final Map<String, dynamic> entry;
  final String timeLabel;

  Map<String, dynamic> _summary() {
    try {
      final s = jsonDecode(entry['summary']?.toString() ?? '{}');
      return s is Map<String, dynamic> ? s : {};
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final type = entry['type']?.toString() ?? 'check';
    final summary = _summary();

    final String title;
    String? subtitle;
    String? coverUrl;

    if (type == 'suggestion') {
      title = l.notificationLogSuggested(summary['title'] ?? '');
      coverUrl = summary['coverUrl']?.toString();
    } else {
      final scanned = (summary['scanned'] as int?) ?? 0;
      final series = (summary['seriesCount'] as int?) ?? 0;
      final chapters = (summary['totalNew'] as int?) ?? 0;
      title = l.notificationLogChecked(scanned);
      subtitle = l.notificationLogFound(series, chapters);
    }

    return ListTile(
      leading: coverUrl != null && coverUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SafeNetworkImage(
                imageUrl: coverUrl,
                width: 44,
                height: 62,
                fit: BoxFit.cover,
              ),
            )
          : Container(
              width: 44,
              height: 62,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                type == 'suggestion'
                    ? RemixIcons.sparkling_2_line
                    : RemixIcons.file_list_3_line,
                color: cs.onSurfaceVariant,
              ),
            ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          if (timeLabel.isNotEmpty)
            Text(
              timeLabel,
              style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}