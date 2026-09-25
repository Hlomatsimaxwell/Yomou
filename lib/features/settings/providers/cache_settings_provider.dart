import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/cache/app_cache.dart';

/// Image-cache configuration surfaced in Settings > Storage and network.
///
/// [maxCacheObjects] mirrors flutter_cache_manager's `maxNrOfCacheObjects`
/// (the maximum number of page/cover files kept before the least-recently-used
/// entries are evicted; the historical default is 200). [staleDays] sets the
/// `stalePeriod` after which an unused entry is treated as old and refreshed
/// on its next read.
class CacheSettings {
  const CacheSettings({
    required this.staleDays,
    required this.maxCacheObjects,
    required this.precacheNextChapter,
    required this.backupFrequency,
    required this.enablePeriodicBackups,
    required this.backupsOutputDirectory,
    required this.deleteOldBackups,
    required this.maxNumberOfBackups,
    required this.lastBackupAt,
    required this.disableNsfw,
    required this.sourceSortOrder,
    required this.showSourcesInGrid,
    required this.enableAllSources,
    required this.chooseMirrorAutomatically,
    required this.handleLinks,
    required this.incognitoMode,
    required this.suggestionsRefreshMinutes,
  });

  factory CacheSettings.defaults() => const CacheSettings(
        staleDays: 30,
        maxCacheObjects: 200,
        precacheNextChapter: true,
        backupFrequency: '1d',
        enablePeriodicBackups: false,
        backupsOutputDirectory: '',
        deleteOldBackups: true,
        maxNumberOfBackups: 8,
        lastBackupAt: 0,
        disableNsfw: false,
        sourceSortOrder: 'manual',
        showSourcesInGrid: false,
        enableAllSources: false,
        chooseMirrorAutomatically: false,
        handleLinks: false,
        incognitoMode: 'ask',
        suggestionsRefreshMinutes: 720,
      );

  final int staleDays;
  final int maxCacheObjects;
  final bool precacheNextChapter;
  final String backupFrequency;
  final bool enablePeriodicBackups;
  final String backupsOutputDirectory;
  final bool deleteOldBackups;
  final int maxNumberOfBackups;

  /// Milliseconds since epoch of the last successful backup, or 0 when the
  /// app has never completed one.
  final int lastBackupAt;

  /// When true, sources flagged as NSFW are hidden from discovery surfaces.
  final bool disableNsfw;

  /// Source list sort: 'manual' (pinned-first, as ordered) or 'name'.
  final String sourceSortOrder;

  /// Whether the source-management screen shows a grid instead of a row list.
  final bool showSourcesInGrid;

  /// When toggled on, every source in the registry is enabled.
  final bool enableAllSources;

  /// Mirrors for a source are picked automatically rather than manually.
  final bool chooseMirrorAutomatically;

  /// Whether the app should handle source link intents.
  final bool handleLinks;

  /// Incognito prompt for NSFW manga: 'enable', 'ask', or 'disable'.
  final String incognitoMode;

  /// How often (in minutes) the suggestions feed and the Explore featured
  /// carousel re-roll themselves automatically while the app is open.
  final int suggestionsRefreshMinutes;

  CacheSettings copyWith({
    int? staleDays,
    int? maxCacheObjects,
    bool? precacheNextChapter,
    String? backupFrequency,
    bool? enablePeriodicBackups,
    String? backupsOutputDirectory,
    bool? deleteOldBackups,
    int? maxNumberOfBackups,
    int? lastBackupAt,
    bool? disableNsfw,
    String? sourceSortOrder,
    bool? showSourcesInGrid,
    bool? enableAllSources,
    bool? chooseMirrorAutomatically,
    bool? handleLinks,
    String? incognitoMode,
    int? suggestionsRefreshMinutes,
  }) => CacheSettings(
        staleDays: staleDays ?? this.staleDays,
        maxCacheObjects: maxCacheObjects ?? this.maxCacheObjects,
        precacheNextChapter: precacheNextChapter ?? this.precacheNextChapter,
        backupFrequency: backupFrequency ?? this.backupFrequency,
        enablePeriodicBackups: enablePeriodicBackups ?? this.enablePeriodicBackups,
        backupsOutputDirectory: backupsOutputDirectory ?? this.backupsOutputDirectory,
        deleteOldBackups: deleteOldBackups ?? this.deleteOldBackups,
        maxNumberOfBackups: maxNumberOfBackups ?? this.maxNumberOfBackups,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
        disableNsfw: disableNsfw ?? this.disableNsfw,
        sourceSortOrder: sourceSortOrder ?? this.sourceSortOrder,
        showSourcesInGrid: showSourcesInGrid ?? this.showSourcesInGrid,
        enableAllSources: enableAllSources ?? this.enableAllSources,
        chooseMirrorAutomatically: chooseMirrorAutomatically ?? this.chooseMirrorAutomatically,
        handleLinks: handleLinks ?? this.handleLinks,
        incognitoMode: incognitoMode ?? this.incognitoMode,
        suggestionsRefreshMinutes:
            suggestionsRefreshMinutes ?? this.suggestionsRefreshMinutes,
      );
}

class _CacheSettingsPersistence {
  static const _prefix = 'cache.';
  static const _staleDays = '${_prefix}staleDays';
  static const _maxObjects = '${_prefix}maxObjects';
  static const _precacheNext = '${_prefix}precacheNext';
  static const _backupFrequency = '${_prefix}backupFrequency';
  static const _enablePeriodic = '${_prefix}enablePeriodic';
  static const _outputDirectory = '${_prefix}outputDirectory';
  static const _deleteOld = '${_prefix}deleteOld';
  static const _maxBackups = '${_prefix}maxBackups';
  static const _lastBackup = '${_prefix}lastBackup';
  static const _disableNsfw = '${_prefix}disableNsfw';
  static const _sourceSortOrder = '${_prefix}sourceSortOrder';
  static const _showSourcesInGrid = '${_prefix}showSourcesInGrid';
  static const _enableAllSources = '${_prefix}enableAllSources';
  static const _chooseMirror = '${_prefix}chooseMirror';
  static const _handleLinks = '${_prefix}handleLinks';
  static const _incognitoMode = '${_prefix}incognitoMode';
  static const _suggestionsRefresh = '${_prefix}suggestionsRefresh';

  static Future<CacheSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return CacheSettings(
      staleDays: p.getInt(_staleDays) ?? 30,
      maxCacheObjects: p.getInt(_maxObjects) ?? 200,
      precacheNextChapter: p.getBool(_precacheNext) ?? true,
      backupFrequency: p.getString(_backupFrequency) ?? '1d',
      enablePeriodicBackups: p.getBool(_enablePeriodic) ?? false,
      backupsOutputDirectory: p.getString(_outputDirectory) ?? '',
      deleteOldBackups: p.getBool(_deleteOld) ?? true,
      maxNumberOfBackups: p.getInt(_maxBackups) ?? 8,
      lastBackupAt: p.getInt(_lastBackup) ?? 0,
      disableNsfw: p.getBool(_disableNsfw) ?? false,
      sourceSortOrder: p.getString(_sourceSortOrder) ?? 'manual',
      showSourcesInGrid: p.getBool(_showSourcesInGrid) ?? false,
      enableAllSources: p.getBool(_enableAllSources) ?? false,
      chooseMirrorAutomatically: p.getBool(_chooseMirror) ?? false,
      handleLinks: p.getBool(_handleLinks) ?? false,
      incognitoMode: p.getString(_incognitoMode) ?? 'ask',
      suggestionsRefreshMinutes: p.getInt(_suggestionsRefresh) ?? 720,
    );
  }

  static Future<void> save(CacheSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_staleDays, s.staleDays);
    await p.setInt(_maxObjects, s.maxCacheObjects);
    await p.setBool(_precacheNext, s.precacheNextChapter);
    await p.setString(_backupFrequency, s.backupFrequency);
    await p.setBool(_enablePeriodic, s.enablePeriodicBackups);
    await p.setString(_outputDirectory, s.backupsOutputDirectory);
    await p.setBool(_deleteOld, s.deleteOldBackups);
    await p.setInt(_maxBackups, s.maxNumberOfBackups);
    await p.setInt(_lastBackup, s.lastBackupAt);
    await p.setBool(_disableNsfw, s.disableNsfw);
    await p.setString(_sourceSortOrder, s.sourceSortOrder);
    await p.setBool(_showSourcesInGrid, s.showSourcesInGrid);
    await p.setBool(_enableAllSources, s.enableAllSources);
    await p.setBool(_chooseMirror, s.chooseMirrorAutomatically);
    await p.setBool(_handleLinks, s.handleLinks);
    await p.setString(_incognitoMode, s.incognitoMode);
    await p.setInt(_suggestionsRefresh, s.suggestionsRefreshMinutes);
  }
}

class CacheSettingsNotifier extends StateNotifier<CacheSettings> {
  CacheSettingsNotifier() : super(CacheSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    state = await _CacheSettingsPersistence.load();
    await applyToCache();
  }

  // Keep the app-wide cache manager in sync with the persisted values so the
  // stale period / size limit take effect immediately (not just on restart).
  Future<void> applyToCache() async {
    await AppImageCache.instance.reconfigure(
      staleDays: state.staleDays,
      maxCacheObjects: state.maxCacheObjects,
    );
  }

  Future<void> setStaleDays(int days) async {
    state = state.copyWith(staleDays: days);
    await _persist();
  }

  Future<void> setMaxCacheObjects(int objects) async {
    state = state.copyWith(maxCacheObjects: objects);
    await _persist();
  }

  Future<void> togglePrecacheNextChapter() async {
    state = state.copyWith(precacheNextChapter: !state.precacheNextChapter);
    await _persist();
  }

  Future<void> setBackupFrequency(String frequency) async {
    state = state.copyWith(backupFrequency: frequency);
    await _persist();
  }

  Future<void> setEnablePeriodicBackups(bool enabled) async {
    state = state.copyWith(enablePeriodicBackups: enabled);
    await _persist();
  }

  Future<void> setBackupsOutputDirectory(String directory) async {
    state = state.copyWith(backupsOutputDirectory: directory);
    await _persist();
  }

  /// Records when a backup was last completed successfully. Pass the number
  /// of milliseconds since the epoch (e.g. DateTime.now()).
  Future<void> setLastBackupAt(int at) async {
    state = state.copyWith(lastBackupAt: at);
    await _persist();
  }

  Future<void> setDeleteOldBackups(bool delete) async {
    state = state.copyWith(deleteOldBackups: delete);
    await _persist();
  }

  Future<void> setMaxNumberOfBackups(int count) async {
    state = state.copyWith(maxNumberOfBackups: count);
    await _persist();
  }

  Future<void> setDisableNsfw(bool disable) async {
    state = state.copyWith(disableNsfw: disable);
    await _persist();
  }

  Future<void> setSourceSortOrder(String order) async {
    state = state.copyWith(sourceSortOrder: order);
    await _persist();
  }

  Future<void> setShowSourcesInGrid(bool show) async {
    state = state.copyWith(showSourcesInGrid: show);
    await _persist();
  }

  Future<void> setEnableAllSources(bool enable) async {
    state = state.copyWith(enableAllSources: enable);
    await _persist();
  }

  Future<void> setChooseMirrorAutomatically(bool enable) async {
    state = state.copyWith(chooseMirrorAutomatically: enable);
    await _persist();
  }

  Future<void> setHandleLinks(bool handle) async {
    state = state.copyWith(handleLinks: handle);
    await _persist();
  }

  Future<void> setIncognitoMode(String mode) async {
    state = state.copyWith(incognitoMode: mode);
    await _persist();
  }

  Future<void> setSuggestionsRefreshMinutes(int minutes) async {
    state = state.copyWith(suggestionsRefreshMinutes: minutes);
    await _persist();
  }

  Future<void> _persist() async {
    await _CacheSettingsPersistence.save(state);
    await applyToCache();
  }
}

final cacheSettingsProvider =
    StateNotifierProvider<CacheSettingsNotifier, CacheSettings>(
        (ref) => CacheSettingsNotifier());

final backupFrequencyProvider = StateProvider<String>((ref) {
  return ref.watch(cacheSettingsProvider).backupFrequency;
});

final enablePeriodicBackupsProvider = StateProvider<bool>((ref) {
  return ref.watch(cacheSettingsProvider).enablePeriodicBackups;
});

final backupsOutputDirectoryProvider = StateProvider<String>((ref) {
  return ref.watch(cacheSettingsProvider).backupsOutputDirectory;
});

final deleteOldBackupsProvider = StateProvider<bool>((ref) {
  return ref.watch(cacheSettingsProvider).deleteOldBackups;
});

final maxNumberOfBackupsProvider = StateProvider<int>((ref) {
  return ref.watch(cacheSettingsProvider).maxNumberOfBackups;
});

/// When true, NSFW-flagged sources are hidden from discovery surfaces.
final disableNsfwProvider = StateProvider<bool>((ref) {
  return ref.watch(cacheSettingsProvider).disableNsfw;
});

final sourceSortOrderProvider = StateProvider<String>((ref) {
  return ref.watch(cacheSettingsProvider).sourceSortOrder;
});

final showSourcesInGridProvider = StateProvider<bool>((ref) {
  return ref.watch(cacheSettingsProvider).showSourcesInGrid;
});

final enableAllSourcesProvider = StateProvider<bool>((ref) {
  return ref.watch(cacheSettingsProvider).enableAllSources;
});

final chooseMirrorAutomaticallyProvider = StateProvider<bool>((ref) {
  return ref.watch(cacheSettingsProvider).chooseMirrorAutomatically;
});

final handleLinksProvider = StateProvider<bool>((ref) {
  return ref.watch(cacheSettingsProvider).handleLinks;
});

final incognitoModeProvider = StateProvider<String>((ref) {
  return ref.watch(cacheSettingsProvider).incognitoMode;
});

/// How often the suggestions feed and Explore's featured carousel are
/// re-rolled automatically (minutes).
final suggestionsRefreshMinutesProvider = StateProvider<int>((ref) {
  return ref.watch(cacheSettingsProvider).suggestionsRefreshMinutes;
});

/// Human-readable image-cache disk usage (e.g. "124.5 MB") recomputed on demand.
final appCacheUsageLabelProvider = FutureProvider<String>(
  (ref) => AppImageCache.instance.usageLabel(),
);

/// Drops the entire image cache and invalidates the usage label above.
Future<void> clearAppCache() async {
  await AppImageCache.instance.emptyCache();
}