import 'package:flutter/services.dart';

const _channel = MethodChannel('com.hlomatsi.yomou/saf');

/// Opens the Android Storage Access Framework directory picker so the user
/// can choose a folder for storing backups. Returns the selected folder's
/// tree URI as a string, or null when the picker is cancelled or unavailable.
Future<String?> pickBackupDirectory() async {
  try {
    return await _channel.invokeMethod<String>('openDirectoryPicker');
  } catch (_) {
    return null;
  }
}

/// Resolves a tree URI returned by [pickBackupDirectory] into a real
/// file-system path (e.g. `/storage/emulated/0/Download`) so settings can
/// display the folder the user picked instead of a raw `content://…` URI.
/// Returns null when the volume can't be matched (e.g. an unmounted SD card).
Future<String?> resolveTreeUri(String uri) async {
  if (uri.isEmpty) return null;
  try {
    return await _channel.invokeMethod<String>('resolveTreeUri', uri);
  } catch (_) {
    return null;
  }
}