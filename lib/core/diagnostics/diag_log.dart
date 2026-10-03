import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Appends diagnostics to a file on the device's external app storage.
///
/// Logcat cannot be used for this: the device filters this app's Dart output,
/// so requests made on the user's behalf are invisible through it. The file
/// lives beside the WebView dumps and is readable over adb.
///
/// Cookie values are never written — only names, and only to tell a missing
/// cookie apart from a rejected one.
String? _lastFile;

/// Serialises appends: several sources log at once, and independent handles
/// opening the same file in append mode interleave into unreadable fragments.
Future<void> _queue = Future<void>.value();

Future<void> diag(String message) {
  _queue = _queue.then((_) => _write(message)).catchError((_) {});
  return _queue;
}

Future<void> _write(String message) async {
  try {
    var file = _lastFile == null ? null : File(_lastFile!);
    if (file == null) {
      final dir = await _logDir();
      if (dir == null) return;
      // Clearing the app's data removes this directory, and an append to a
      // file whose parent is gone fails: the log would then stay silent for
      // the rest of the session.
      if (!await dir.exists()) await dir.create(recursive: true);
      file = File('${dir.path}/diag.log');
      _lastFile = file.path;
    }
    await file.writeAsString(
      '${DateTime.now().toIso8601String()} $message\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {
    // Diagnostics must never break a request path.
  }
}

/// Where the log goes.
///
/// `getExternalStorageDirectory` is not implemented on desktop, so it returned
/// null there and the one line that would have explained a bad `sourceId` was
/// silently dropped -- which is exactly the case it exists for. The
/// application-support directory is implemented on every platform this app
/// runs on, so it is the fallback rather than the primary.
Future<Directory?> _logDir() async {
  try {
    return await getExternalStorageDirectory() ??
        await getApplicationSupportDirectory();
  } catch (_) {
    return null;
  }
}

/// Fire-and-forget variant for synchronous call sites.
void diagSoon(String message) => unawaited(diag(message));
