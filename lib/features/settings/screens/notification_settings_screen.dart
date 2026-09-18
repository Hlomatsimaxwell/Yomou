import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/notifications/background_tasks.dart';
import 'package:yomou/core/notifications/notification_service.dart';
import 'package:yomou/core/notifications/notification_settings.dart';
import 'package:yomou/features/settings/screens/notification_log_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  static const _batteryChannel = MethodChannel('com.hlomatsi.yomou/battery');

  bool _loading = true;
  bool _enabled = false;
  bool _wifiOnly = false;
  int _frequencyIndex = Frequency.defaultMode.index;
  bool _lookFavorites = true;
  bool _lookHistory = true;
  bool _nsfwAllowed = false;
  int _autoDownloadIndex = 0;

  bool _categoryAll = true;
  Set<String> _categorySelected = {};
  List<String> _categoryCandidates = [];

  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = NotificationService.instance;
    await service.init();
    final favorites = await DatabaseHelper.instance
        .getUserTopTags(limit: 10)
        .catchError((_) => <String>[]);
    final categoryState = await NotificationSettings.categoryState();
    final scope = await NotificationSettings.lookForUpdates();
    final results = await Future.wait([
      service.isEnabled(),
      NotificationSettings.isWifiOnly(),
      NotificationSettings.frequency().then((f) => f.index),
      NotificationSettings.nsfwAllowed(),
      NotificationSettings.autoDownload().then((a) => a.index),
    ]);
    if (!mounted) return;
    setState(() {
      _categoryCandidates = {...favorites, ...categoryState.selected}.toList()
        ..sort();
      _categoryAll = categoryState.all;
      _categorySelected = categoryState.selected;
      _enabled = results[0] as bool;
      _wifiOnly = results[1] as bool;
      _frequencyIndex = results[2] as int;
      _lookFavorites = scope.$1;
      _lookHistory = scope.$2;
      _nsfwAllowed = results[3] as bool;
      _autoDownloadIndex = results[4] as int;
      _loading = false;
    });
  }

  Future<void> _setEnabled(bool value) async {
    final service = NotificationService.instance;
    final l = AppLocalizations.of(context);
    var changed = false;

    if (value) {
      final granted = await service.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.notificationPermissionDenied),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        await service.setEnabled(true);
        await registerUpdateCheckTask();
        changed = true;
        // Establish a baseline now so enabling never dumps the whole back
        // catalogue as "new".
        unawaited(runUpdateCheck());
      }
    } else {
      await service.setEnabled(false);
      await cancelUpdateCheckTask();
      changed = true;
    }

    if (!mounted) return;
    setState(() {
      if (changed) _enabled = value;
    });
  }

  Future<void> _setFrequency(int index) async {
    await NotificationSettings.setFrequencyIndex(index);
    if (_enabled) {
      await registerUpdateCheckTask();
    }
    if (mounted) {
      setState(() => _frequencyIndex = index);
    }
  }

  Future<void> _setWifiOnly(bool value) async {
    await NotificationSettings.setWifiOnly(value);
    if (_enabled) {
      await registerUpdateCheckTask();
    }
    if (mounted) setState(() => _wifiOnly = value);
  }

  Future<void> _setNsfw(bool value) async {
    await NotificationSettings.setNsfwAllowed(!value);
    if (mounted) setState(() => _nsfwAllowed = !value);
  }

  Future<void> _setAutoDownload(int index) async {
    await NotificationSettings.setAutoDownloadIndex(index);
    if (mounted) setState(() => _autoDownloadIndex = index);
  }

  Future<void> _setScopeFavorites(bool value) async {
    await NotificationSettings.setLookForFavorites(value);
    if (mounted) setState(() => _lookFavorites = value);
  }

  Future<void> _setScopeHistory(bool value) async {
    await NotificationSettings.setLookForHistory(value);
    if (mounted) setState(() => _lookHistory = value);
  }

  Future<void> _persistCategories() async {
    final selected = _categoryAll
        ? _categoryCandidates.toSet()
        : _categorySelected;
    await NotificationSettings.setFavoriteCategories(
      selected,
      allCategories: _categoryCandidates.toSet(),
    );
    if (mounted) {
      setState(() {
        _categoryAll = _categoryCandidates.length == selected.length;
        _categorySelected = selected;
      });
    }
  }

  Future<void> _runManualCheck() async {
    if (_checking) return;
    final l = AppLocalizations.of(context);
    setState(() => _checking = true);
    try {
      await runUpdateCheck();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _checking = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.notificationCheckDone)));
  }

  void _openBatterySettings() {
    try {
      _batteryChannel.invokeMethod('openBatterySettings');
    } catch (_) {}
  }

  Future<void> _showFrequencySheet() async {
    final l = AppLocalizations.of(context);
    await _showSelectionSheet(
      title: l.notificationFrequency,
      labels: [
        l.frequencyManual,
        l.frequencyLess,
        l.frequencyDefault,
        l.frequencyMore,
      ],
      selectedIndex: _frequencyIndex,
      onSelect: _setFrequency,
    );
  }

  Future<void> _showScopeSheet() async {
    final l = AppLocalizations.of(context);
    await showM3ModalSheet(
      context,
      title: l.notificationScope,
      footer: FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l.done),
      ),
      children: [
        CheckboxListTile(
          value: _lookFavorites,
          title: Text(l.notificationScopeFavorites),
          onChanged: (v) async {
            await _setScopeFavorites(v ?? false);
            if (mounted) setState(() {});
          },
        ),
        CheckboxListTile(
          value: _lookHistory,
          title: Text(l.notificationScopeHistory),
          onChanged: (v) async {
            await _setScopeHistory(v ?? false);
            if (mounted) setState(() {});
          },
        ),
      ],
    );
  }

  Future<void> _showCategoriesSheet() async {
    final l = AppLocalizations.of(context);
    final candidates = List<String>.from(_categoryCandidates);
    var all = _categoryAll;
    var selected = Set<String>.from(_categorySelected);
    await showM3ModalSheet(
      context,
      title: l.notificationCategories,
      maxHeightFactor: 0.7,
      footer: FilledButton(
        onPressed: () async {
          await _persistCategories();
          if (!mounted) return;
          Navigator.pop(context);
        },
        child: Text(l.done),
      ),
      children: [
        if (candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.notificationCategoriesNone),
          )
        else
          for (final tag in candidates)
            CheckboxListTile(
              value: all ? true : selected.contains(tag),
              title: Text(tag),
              onChanged: (checked) {
                if (all) {
                  all = false;
                  selected = candidates.toSet()..remove(tag);
                } else if (checked == true) {
                  selected.add(tag);
                  if (selected.length == candidates.length) {
                    all = true;
                  }
                } else {
                  selected.remove(tag);
                }
                setState(() {
                  _categoryAll = all;
                  _categorySelected = selected;
                });
              },
            ),
      ],
    );
  }

  Future<void> _showAutoDownloadSheet() async {
    final l = AppLocalizations.of(context);
    await _showSelectionSheet(
      title: l.notificationDownload,
      labels: [
        l.autoDownloadNever,
        l.autoDownloadDownloaded,
        l.autoDownloadRecentlyRead,
      ],
      selectedIndex: _autoDownloadIndex,
      onSelect: _setAutoDownload,
    );
  }

  Future<void> _showSelectionSheet({
    required String title,
    required List<String> labels,
    required int selectedIndex,
    required Future<void> Function(int index) onSelect,
  }) async {
    await showM3ModalSheet(
      context,
      title: title,
      children: [
        for (var i = 0; i < labels.length; i++)
          ListTile(
            leading: Icon(
              i == selectedIndex
                  ? RemixIcons.checkbox_circle_fill
                  : RemixIcons.checkbox_circle_line,
              color: i == selectedIndex
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(labels[i]),
            onTap: () async {
              await onSelect(i);
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: SettingsAppBar(title: l.settingsNewChapters),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final scopeEnabledCount = (_lookFavorites ? 1 : 0) + (_lookHistory ? 1 : 0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SettingsAppBar(title: l.settingsNewChapters),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              l.notificationSettingsDescription,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
          ),
          SwitchListTile(
            value: _enabled,
            onChanged: _setEnabled,
            secondary: const Icon(RemixIcons.notification_3_line),
            title: Text(l.notificationSettingsEnable),
            subtitle: Text(
              _enabled ? l.notificationSettingsOn : l.notificationSettingsOff,
            ),
          ),
          if (_enabled) ...[
            M3SectionHeader(title: l.notificationOptionsSection),
            SwitchListTile(
              value: _wifiOnly,
              onChanged: _setWifiOnly,
              secondary: const Icon(RemixIcons.wifi_line),
              title: Text(l.notificationWifiOnly),
              subtitle: Text(l.notificationWifiOnlySubtitle),
            ),
            ListTile(
              leading: const Icon(RemixIcons.time_line),
              title: Text(l.notificationFrequency),
              trailing: _trailingValue(
                _frequencyLabel(l),
                onTap: _showFrequencySheet,
              ),
              onTap: _showFrequencySheet,
            ),
            ListTile(
              leading: const Icon(RemixIcons.bookmark_line),
              title: Text(l.notificationScope),
              subtitle: Text(
                scopeEnabledCount == 0
                    ? l.notificationSettingsOff
                    : l.notificationScopeSubtitle(scopeEnabledCount, 2),
              ),
              trailing: Icon(
                RemixIcons.arrow_right_s_line,
                color: cs.onSurfaceVariant,
              ),
              onTap: _showScopeSheet,
            ),
            ListTile(
              leading: const Icon(RemixIcons.price_tag_3_line),
              title: Text(l.notificationCategories),
              subtitle: Text(
                _categoryCandidates.isEmpty
                    ? l.notificationCategoriesNone
                    : l.notificationCategoriesSubtitle(
                        _categoryAll
                            ? _categoryCandidates.length
                            : _categorySelected.length,
                        _categoryCandidates.length,
                      ),
              ),
              trailing: Icon(
                RemixIcons.arrow_right_s_line,
                color: cs.onSurfaceVariant,
              ),
              onTap: _showCategoriesSheet,
            ),
            SwitchListTile(
              value: !_nsfwAllowed,
              onChanged: _setNsfw,
              secondary: const Icon(RemixIcons.eye_off_line),
              title: Text(l.notificationNsfw),
              subtitle: Text(l.notificationNsfwSubtitle),
            ),
            ListTile(
              leading: const Icon(RemixIcons.download_2_line),
              title: Text(l.notificationDownload),
              trailing: _trailingValue(
                _autoDownloadLabel(l),
                onTap: _showAutoDownloadSheet,
              ),
              onTap: _showAutoDownloadSheet,
            ),
          ],
          M3SectionHeader(title: l.notificationPreviewSection),
          ListTile(
            leading: const Icon(RemixIcons.book_read_line),
            title: Text(l.notificationPreviewNewChapters),
            trailing: Icon(
              RemixIcons.arrow_right_s_line,
              color: cs.onSurfaceVariant,
            ),
            onTap: () => NotificationService.instance.showTestNewChapters(),
          ),
          ListTile(
            leading: const Icon(RemixIcons.sparkling_2_line),
            title: Text(l.notificationPreviewSuggested),
            trailing: Icon(
              RemixIcons.arrow_right_s_line,
              color: cs.onSurfaceVariant,
            ),
            onTap: () => NotificationService.instance.showTestSuggested(),
          ),
          M3SectionHeader(title: l.notificationCheckLogSection),
          ListTile(
            leading: _checking
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(RemixIcons.refresh_line),
            title: Text(l.notificationCheckNow),
            onTap: _checking ? null : _runManualCheck,
          ),
          ListTile(
            leading: const Icon(RemixIcons.file_list_3_line),
            title: Text(l.notificationLog),
            trailing: Icon(
              RemixIcons.arrow_right_s_line,
              color: cs.onSurfaceVariant,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationLogScreen()),
            ),
          ),
          if (Platform.isAndroid) ...[
            ListTile(
              leading: const Icon(RemixIcons.battery_2_line),
              title: Text(l.notificationBattery),
              subtitle: Text(l.notificationBatterySubtitle),
              onTap: _openBatterySettings,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _trailingValue(String value, {VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
        const SizedBox(width: 4),
        Icon(RemixIcons.arrow_right_s_line, color: cs.onSurfaceVariant),
      ],
    );
  }

  String _frequencyLabel(AppLocalizations l) {
    switch (_frequencyIndex) {
      case 0:
        return l.frequencyManual;
      case 1:
        return l.frequencyLess;
      case 3:
        return l.frequencyMore;
      default:
        return l.frequencyDefault;
    }
  }

  String _autoDownloadLabel(AppLocalizations l) {
    switch (_autoDownloadIndex) {
      case 1:
        return l.autoDownloadDownloaded;
      case 2:
        return l.autoDownloadRecentlyRead;
      default:
        return l.autoDownloadNever;
    }
  }
}