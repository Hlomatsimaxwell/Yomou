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