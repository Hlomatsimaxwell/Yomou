import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/cache/app_cache.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/notifications/background_tasks.dart';
import 'package:yomou/features/reader/services/download_scheduler.dart';
import 'package:yomou/features/settings/providers/download_settings_provider.dart';

/// A group of related settings that "Reset settings" can clear together.
///
/// The groups mirror the Settings hub: a reader picks the areas to restore to
/// their defaults, and everything else -- most importantly the library and
/// history -- is left alone.
enum SettingsGroup {
  appearance,
  contentPreferences,
  reader,
  notifications,
  storage,
  sources,
}

extension SettingsGroupMatcher on SettingsGroup {
  /// Whether [key] belongs to this group. Keys are grouped by their
  /// SharedPreferences prefix (each settings provider owns one) plus a handful
  /// of one-off keys that predate the prefixes.
  bool matches(String key) {
    switch (this) {
      case SettingsGroup.appearance:
        return key.startsWith('appearance.') ||
            key == 'manga_grid_list_mode' ||
            key == 'suggestions_list_mode' ||
            key == 'history_list_mode' ||
            key == 'history_is_grouped' ||
            key == 'history_sorting_order';
      case SettingsGroup.contentPreferences:
        return key == 'onboarding.languages' ||
            key == 'onboarding.formats' ||
            key.startsWith('sourcePresets');
      case SettingsGroup.reader:
        return key.startsWith('rs.');
      case SettingsGroup.notifications:
        return const {
          'new_chapter_notifications',
          'notify_frequency',
          'notify_nsfw',
          'wifi_only',
          'look_for_updates_favorites',
          'look_for_updates_history',
          'auto_download',
          'favorite_categories',
          'last_suggested_sent_ms',
        }.contains(key);
      case SettingsGroup.storage:
        return key.startsWith('cache.') || key.startsWith('dl.');
      case SettingsGroup.sources:
        return key == 'pinned_sources_list' ||
            key.startsWith('source_filter_') ||
            key.startsWith('source_network_');
    }
  }
}

/// Removes the stored values behind [groups], returning the group-aware count
/// of keys cleared.
///
/// The welcome flag and the last-seen changelog version are deliberately never
/// touched here: "Reset settings" restores defaults, it does not re-run first
/// launch. Use [eraseAllData] for that.
Future<int> resetSettings(Set<SettingsGroup> groups) async {
  if (groups.isEmpty) return 0;
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs
      .getKeys()
      .where((key) => groups.any((group) => group.matches(key)))
      .toList();
  for (final key in keys) {
    await prefs.remove(key);
  }
  return keys.length;
}

/// Restores the app to a fresh install: preferences, the database, cached
/// images, custom covers and downloaded chapters.
///
/// Backups the reader wrote out (to a folder they chose) are left alone -- they
/// are the one thing that can undo an accidental erase. The caller is expected
/// to restart the app afterwards so the widget tree and providers are rebuilt
/// from empty (which also brings the welcome sheet back, since the onboarding
/// flag is cleared with everything else).
Future<void> eraseAllData() async {
  // Stop the background jobs first: an update check or download that fires
  // mid-wipe would otherwise repopulate the tables we are about to clear.
  await _cancelBackgroundWork();

  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  await DatabaseHelper.instance.wipeAllData();
  await AppImageCache.instance.emptyCache();

  await _deleteDirectory(await _customCoversDirectory());
  await _deleteDirectory(await DownloadSettings.chaptersRoot());
}

Future<void> _cancelBackgroundWork() async {
  try {
    await cancelUpdateCheckTask();
  } catch (_) {}
  try {
    await DownloadScheduler.cancelAll();
  } catch (_) {}
}

Future<Directory> _customCoversDirectory() async {
  final dir = await getApplicationDocumentsDirectory();
  return Directory(p.join(dir.path, 'custom_covers'));
}

/// Deletes [dir] and everything under it, staying quiet when it is already gone
/// or the filesystem refuses (the app is still usable without the space back).
Future<void> _deleteDirectory(Directory dir) async {
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {}
}
