import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The launcher icon variants shipped with the app. [gold] is the default and
/// lives on `MainActivity` itself; every other value is backed by an
/// `activity-alias` carrying that variant's artwork.
enum AppIconVariant { gold, blue, white, bw }

extension AppIconVariantInfo on AppIconVariant {
  /// Human label shown under the preview in the picker.
  String get label => switch (this) {
        AppIconVariant.gold => 'Gold',
        AppIconVariant.blue => 'Blue',
        AppIconVariant.white => 'White',
        AppIconVariant.bw => 'B&W',
      };

  /// Bundled preview, synced from `icons/<id>/android/play_store_512.png` by
  /// `tool/sync_app_icons.sh`.
  String get asset => 'assets/app_icons/variant_$name.png';
}

/// Thin wrapper around the native activity-alias toggle. Selecting a variant
/// enables exactly one launcher component and disables the rest.
class AppIconService {
  AppIconService._();

  static const _channel = MethodChannel('com.hlomatsi.yomou/app_icon');

  /// Whether dynamic switching is supported on this device. Only Android has
  /// the activity-alias toggle; iOS ships the gold icon as its only icon, so
  /// the selector is hidden there rather than offering a control that does
  /// nothing.
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  static Future<AppIconVariant> current() async {
    try {
      final value = await _channel.invokeMethod<String>('getAlias');
      return AppIconVariant.values.firstWhere(
        (variant) => variant.name == value,
        orElse: () => AppIconVariant.gold,
      );
    } catch (_) {
      return AppIconVariant.gold;
    }
  }

  static Future<bool> set(AppIconVariant variant) async {
    try {
      await _channel.invokeMethod<bool>('setAlias', {
        'alias': variant.name,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
