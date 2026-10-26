import 'package:flutter/services.dart';

/// Maps the two supported app icon variants to their native alias names.
enum AppIconVariant { dark, light }

/// Thin wrapper around the native activity-alias toggle. The default (no
/// alias set) is the dark icon; switching to light enables `AliasLight`.
class AppIconService {
  AppIconService._();

  static const _channel = MethodChannel('com.hlomatsi.yomou/app_icon');

  /// Whether dynamic switching is supported on this device. Defaults to true
  /// on Android (the platform channel is only wired for Android); iOS would
  /// need its own implementation and is out of scope for now.
  static bool get isSupported => true;

  static Future<AppIconVariant> current() async {
    try {
      final value = await _channel.invokeMethod<String>('getAlias');
      return value == 'light' ? AppIconVariant.light : AppIconVariant.dark;
    } catch (_) {
      return AppIconVariant.dark;
    }
  }

  static Future<bool> set(AppIconVariant variant) async {
    try {
      await _channel.invokeMethod<bool>('setAlias', {
        'alias': variant == AppIconVariant.light ? 'light' : 'dark',
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}