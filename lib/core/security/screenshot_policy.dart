import 'package:flutter/services.dart';

const _channel = MethodChannel('com.hlomatsi.yomou/secure');

/// Applies the app's screenshot policy to the native window. Blocking enables
/// FLAG_SECURE, which blanks screenshots and the recents preview; allowing
/// clears it so the screen can be captured.
Future<void> applyScreenshotPolicy({required bool block}) async {
  try {
    await _channel.invokeMethod('setScreenshotBlocked', block);
  } catch (_) {
    // Non-Android platforms or an unavailable channel: nothing to do.
  }
}