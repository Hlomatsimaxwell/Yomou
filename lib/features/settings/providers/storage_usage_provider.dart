import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yomou/core/cache/app_cache.dart';
import 'package:yomou/core/storage/storage_stats.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/reader/services/chapter_downloader.dart';

/// The four buckets the Storage and network pane's usage bar splits a device
/// into, following Kotatsu-Redo's `StorageUsage`.
///
/// Every figure is a count of bytes on disk, so the bar can be drawn from the
/// same numbers the rows quote and stay in step with them after a download or
/// a cache clear.
class StorageUsage {
  const StorageUsage({
    required this.savedManga,
    required this.pagesCache,
    required this.otherCache,
    required this.available,
  });

  /// Chapter pages saved for offline reading.
  final int savedManga;

  /// The image cache: pages and covers already fetched by the reader and the
  /// library. Kotatsu-Redo keeps its pages and its network cache apart; there
  /// is one cache manager here, so those are one bucket.
  final int pagesCache;

  /// Everything else in the app's temporary directory.
  final int otherCache;

  /// Free space left on the volume the app lives on.
  final int available;
}

/// What the usage bar is drawn from.
///
/// Refreshes when a download is added or removed, since that is what changes
/// the saved-manga bucket. Clearing the cache has to be followed by a manual
/// [Ref.invalidate] from the screen that cleared it: the cache manager holds no
/// provider the screen could watch instead.
final storageUsageProvider = FutureProvider<StorageUsage>((ref) async {
  final ids = await ref.watch(downloadedMangasProvider.future);

  var savedManga = 0;
  for (final id in ids) {
    // One unreadable or half-deleted directory must not blank out the bar: the
    // rest of the figures are still worth showing.
    savedManga += await _bytesOrZero(() => ChapterDownloader.getDownloadSize(id));
  }

  final pagesCache = await AppImageCache.instance.usageBytes();

  return StorageUsage(
    savedManga: savedManga,
    pagesCache: pagesCache,
    otherCache: await _otherCacheBytes(pagesCache),
    available: await _availableBytes(),
  );
});

Future<int> _bytesOrZero(Future<int> Function() measure) async {
  try {
    return await measure();
  } catch (_) {
    return 0;
  }
}

/// The temporary directory minus [pagesCache], which is the part of it that is
/// already accounted for. Both come from the same folder, so subtracting keeps
/// the two buckets from double-counting a cached page.
Future<int> _otherCacheBytes(int pagesCache) async {
  try {
    final total = await _dirBytes(await getTemporaryDirectory());
    return total > pagesCache ? total - pagesCache : 0;
  } catch (_) {
    return 0;
  }
}

/// Free space on the volume holding [getApplicationSupportDirectory], read on
/// the native side through the same `StatFs` channel the directories screen
/// uses. Unavailable off a device, which reads as an empty bucket rather than
/// a failed pane.
Future<int> _availableBytes() async {
  try {
    final base = await getApplicationSupportDirectory();
    final stats = await getStorageStats(base.path);
    return stats?.freeBytes ?? 0;
  } catch (_) {
    return 0;
  }
}

Future<int> _dirBytes(Directory dir) async {
  var total = 0;
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File) {
      total += await entity.length();
    }
  }
  return total;
}
