import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// App-wide image cache manager.
///
/// A single [CacheManager] instance is shared by every `CachedNetworkImage`,
/// the reader's prefetch and download retries. It uses the same storage key
/// as flutter_cache_manager's default (`libCachedImageData`) so the on-disk
/// cache folder and its sqlite index from previous runs stay valid, but the
/// stale period and object-count limit are configurable from Settings.
class AppImageCache {
  AppImageCache._();

  static final AppImageCache instance = AppImageCache._();

  static const key = 'libCachedImageData';

  CacheManager? _manager;

  /// The active cache manager. Built lazily so the first images can reuse the
  /// existing on-disk cache without waiting for settings to load.
  CacheManager get manager => _manager ??= _build(staleDays: 30, maxCacheObjects: 200);

  CacheManager _build({required int staleDays, required int maxCacheObjects}) =>
      CacheManager(
        Config(
          key,
          stalePeriod: Duration(days: staleDays),
          maxNrOfCacheObjects: maxCacheObjects,
        ),
      );

  /// Applies a new stale period / size limit. The current manager is swapped
  /// out and disposed; sqflite shares the same path so no data is re-downloaded.
  Future<void> reconfigure({required int staleDays, required int maxCacheObjects}) async {
    final old = _manager;
    if (old != null &&
        old.config.stalePeriod == Duration(days: staleDays) &&
        old.config.maxNrOfCacheObjects == maxCacheObjects) {
      return;
    }
    _manager = _build(staleDays: staleDays, maxCacheObjects: maxCacheObjects);
    if (old != null) {
      try {
        await old.dispose();
      } catch (_) {}
    }
  }

  /// Drops every cached page/cover file and its index entries.
  Future<void> emptyCache() async {
    try {
      await manager.emptyCache();
    } catch (_) {}
  }

  /// Total bytes currently held by the image cache folder.
  Future<int> usageBytes() async {
    try {
      final base = await getTemporaryDirectory();
      final dir = Directory(p.join(base.path, key));
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Human readable usage label, e.g. "12.4 MB" or "890 KB".
  Future<String> usageLabel() async {
    final bytes = await usageBytes();
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}