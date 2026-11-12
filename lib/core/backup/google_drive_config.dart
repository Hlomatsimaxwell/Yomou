import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether this build has the OAuth client Google Sign-In needs.
///
/// On iOS a missing `GIDClientID` makes the native SDK raise an Objective-C
/// exception, which cannot be caught in Dart and takes the app down. The UI
/// asks this first and shows setup instructions instead of opening the flow.
/// Android reads its client from `google-services.json`, which either exists
/// in the build or fails with a catchable PlatformException, so it is left
/// alone.
class GoogleDriveConfig {
  GoogleDriveConfig._();

  static const _channel = MethodChannel('com.hlomatsi.yomou/google_config');

  static Future<bool> isSignInConfigured() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;
    try {
      return await _channel.invokeMethod<bool>('isSignInConfigured') ?? false;
    } catch (_) {
      // The channel is registered by AppDelegate; if it is missing this is not
      // a build we can safely sign in from.
      return false;
    }
  }
}
