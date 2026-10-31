import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class WidgetService {
  static const _channel = MethodChannel('com.hlomatsi.yomou/widget');

  static Future<void> updateMangaDeck(List<Map<String, String?>> recentManga) async {
    final dir = await getApplicationDocumentsDirectory();
    final widgetDir = Directory('${dir.path}/widget_covers');
    if (!await widgetDir.exists()) {
      await widgetDir.create(recursive: true);
    }
    // Use shared_preferences directly with the native key
    // Actually use MethodChannel to save to native prefs
    final coverPaths = <String?>[];
    final mangaIds = <String?>[];

    for (int i = 0; i < 4; i++) {
      if (i < recentManga.length) {
        final manga = recentManga[i];
        final coverUrl = manga['coverPath'];
        final id = manga['id'];
        mangaIds.add(id);

        String? localPath;
        if (coverUrl != null && coverUrl.isNotEmpty) {
          try {
            final file = File('${widgetDir.path}/cover_$i.jpg');
            if (!await file.exists()) {
              final response = await Dio().get<List<int>>(
                coverUrl,
                options: Options(responseType: ResponseType.bytes),
              );
              if (response.data != null) {
                await file.writeAsBytes(response.data!);
              }
            }
            if (await file.exists()) {
              localPath = file.path;
            }
          } catch (_) {
            localPath = null;
          }
        }
        coverPaths.add(localPath);
      } else {
        coverPaths.add(null);
        mangaIds.add(null);
      }
    }

    // Save to native SharedPreferences via method channel
    await _channel.invokeMethod('saveWidgetData', {
      'coverPaths': coverPaths,
      'mangaIds': mangaIds,
    });
    await _channel.invokeMethod('updateWidget');
  }
}
