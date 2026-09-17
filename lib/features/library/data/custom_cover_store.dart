import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists user-picked cover images into the app's documents directory so
/// they survive restarts, returning a `local://<path>` url for the database.
class CustomCoverStore {
  /// URL prefix stored in the DB for covers that live on local storage.
  static const String prefix = 'local://';

  /// Copies [sourcePath] (e.g. an `image_picker` temp file) into
  /// `custom_covers/<mangaId><ext>` and returns the `local://` url, or null
  /// when the copy fails.
  static Future<String?> savePickedCover({
    required String mangaId,
    required String sourcePath,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(dir.path, 'custom_covers'));
      if (!await coversDir.exists()) await coversDir.create(recursive: true);

      final ext = p.extension(sourcePath).toLowerCase();
      final safeExt = ext.isEmpty ? '.jpg' : ext;
      final destPath = p.join(coversDir.path, '$mangaId$safeExt');

      final source = File(sourcePath);
      if (!await source.exists()) return null;
      await source.copy(destPath);
      return '$prefix$destPath';
    } catch (_) {
      return null;
    }
  }

  /// Resolves a `local://` url back to a filesystem path (or the url itself
  /// when it isn't local).
  static String resolve(String url) {
    if (url.startsWith(prefix)) return url.substring(prefix.length);
    return url;
  }
}
