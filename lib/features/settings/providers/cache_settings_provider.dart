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

/// Human-readable image-cache disk usage (e.g. "124.5 MB") recomputed on demand.
final appCacheUsageLabelProvider = FutureProvider<String>(
  (ref) => AppImageCache.instance.usageLabel(),
);

/// Drops the entire image cache and invalidates the usage label above.
Future<void> clearAppCache() async {
  await AppImageCache.instance.emptyCache();
}