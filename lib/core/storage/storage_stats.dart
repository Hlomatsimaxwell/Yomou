import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Free/total byte counts for a directory path, read on the native side via
/// `StatFs`. Used by the Local manga directories screen for the storage bars.
class StorageStats {
  const StorageStats({required this.totalBytes, required this.freeBytes});

  final int totalBytes;
  final int freeBytes;

  int get usedBytes => totalBytes - freeBytes;
  double get usedFraction =>
      totalBytes <= 0 ? 0 : (usedBytes / totalBytes).clamp(0.0, 1.0);
}

const _channel = MethodChannel('com.hlomatsi.yomou/storage');

/// Returns capacity stats for [path], or null when the path is not a real
/// file-system directory (e.g. a SAF tree URI) or the call fails.
Future<StorageStats?> getStorageStats(String path) async {
  if (path.isEmpty) return null;
  try {
    final map = await _channel.invokeMapMethod<String, int>('getStats', path);
    if (map == null) return null;
    return StorageStats(
      totalBytes: map['total'] ?? 0,
      freeBytes: map['free'] ?? 0,
    );
  } catch (_) {
    return null;
  }
}

/// The real shared Downloads folder (e.g. `/storage/emulated/0/Download`).
///
/// Deliberately not `path_provider`'s `getDownloadsDirectory()`: without legacy
/// storage permission that resolves to an app-scoped external directory, so the
/// "Public downloads" row would point at a private folder the user can't see.
/// Falls back to [getDownloadsDirectory] so the option is never lost if the
/// native call is unavailable. Returns null when neither resolves.
Future<String?> getPublicDownloadsPath() async {
  try {
    final path = await _channel.invokeMethod<String>('getPublicDownloadsPath');
    if (path != null && path.isNotEmpty) return path;
  } catch (_) {
    // Fall through to the path_provider value below.
  }
  try {
    return (await getDownloadsDirectory())?.path;
  } catch (_) {
    return null;
  }
}