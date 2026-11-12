import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

const _channel = MethodChannel('com.hlomatsi.yomou/secure');

/// Applies the app's screenshot policy to the native window.
///
/// On Android, blocking enables FLAG_SECURE, which blanks screenshots and the
/// recents preview. iOS has no equivalent public flag, so the screen protector
/// plugin puts the app window behind a secure text field (which blanks
/// screenshots and recordings) and blurs the window for the app-switcher
/// snapshot. Allowing turns both back off.
Future<void> applyScreenshotPolicy({required bool block}) async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      if (block) {
        await ScreenProtector.preventScreenshotOn();
        await ScreenProtector.protectDataLeakageWithBlur();
      } else {
        await ScreenProtector.preventScreenshotOff();
        await ScreenProtector.protectDataLeakageWithBlurOff();
      }
    } catch (_) {
      // Plugin unavailable: leave the window as-is rather than crash.
    }
    return;
  }

  try {
    await _channel.invokeMethod('setScreenshotBlocked', block);
  } catch (_) {
    // Non-Android platforms or an unavailable channel: nothing to do.
  }
}
