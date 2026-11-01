import 'package:flutter/services.dart';

/// Asks the native Manga Deck widget to reload.
///
/// The widget reads the reading history straight from the app database and
/// downloads its own covers, so all the app has to do is tell it to refresh.
class WidgetService {
  static const _channel = MethodChannel('com.hlomatsi.yomou/widget');

  static Future<void> refresh() async {
    try {
      await _channel.invokeMethod('updateWidget');
    } catch (_) {
      // Not Android, or no widget on the home screen: nothing to do.
    }
  }
}
