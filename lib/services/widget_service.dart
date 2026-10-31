import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class WidgetService {
  static const _channel = MethodChannel('yomou/widget');
  static const String prefsName = 'HomeWidgetPreferences';

  static Future<void> updateMangaDeck(List<Map<String, String?>> recentManga) async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < 4; i++) {
      if (i < recentManga.length) {
        final manga = recentManga[i];
        await prefs.setString('cover_path_$i', manga['coverPath'] ?? '');
        await prefs.setString('manga_id_$i', manga['id'] ?? '');
      } else {
        await prefs.remove('cover_path_$i');
        await prefs.remove('manga_id_$i');
      }
    }
    try {
      await _channel.invokeMethod('updateWidget');
    } catch (_) {}
  }
}
