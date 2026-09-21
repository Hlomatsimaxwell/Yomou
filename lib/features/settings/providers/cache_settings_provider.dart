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
  });

  factory CacheSettings.defaults() => const CacheSettings(
        staleDays: 30,
        maxCacheObjects: 200,
        precacheNextChapter: true,
      );

  final int staleDays;
  final int maxCacheObjects;
  final bool precacheNextChapter;

  CacheSettings copyWith({int? staleDays, int? maxCacheObjects, bool? precacheNextChapter}) =>
      CacheSettings(
        staleDays: staleDays ?? this.staleDays,
        maxCacheObjects: maxCacheObjects ?? this.maxCacheObjects,
        precacheNextChapter: precacheNextChapter ?? this.precacheNextChapter,
      );
}

class _CacheSettingsPersistence {
  static const _prefix = 'cache.';
  static const _staleDays = '${_prefix}staleDays';
  static const _maxObjects = '${_prefix}maxObjects';
  static const _precacheNext = '${_prefix}precacheNext';

  static Future<CacheSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return CacheSettings(
      staleDays: p.getInt(_staleDays) ?? 30,
      maxCacheObjects: p.getInt(_maxObjects) ?? 200,
      precacheNextChapter: p.getBool(_precacheNext) ?? true,
    );
  }

  static Future<void> save(CacheSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_staleDays, s.staleDays);
    await p.setInt(_maxObjects, s.maxCacheObjects);
    await p.setBool(_precacheNext, s.precacheNextChapter);
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

  Future<void> _persist() async {
    await _CacheSettingsPersistence.save(state);
    await applyToCache();
  }
}

final cacheSettingsProvider =
    StateNotifierProvider<CacheSettingsNotifier, CacheSettings>(
        (ref) => CacheSettingsNotifier());

/// Human-readable image-cache disk usage (e.g. "124.5 MB") recomputed on demand.
final appCacheUsageLabelProvider = FutureProvider<String>(
  (ref) => AppImageCache.instance.usageLabel(),
);

/// Drops the entire image cache and invalidates the usage label above.
Future<void> clearAppCache() async {
  await AppImageCache.instance.emptyCache();
}