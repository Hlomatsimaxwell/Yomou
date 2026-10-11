import 'dart:io';

import 'package:flutter/services.dart';
import 'package:yomou/core/cache/app_cache.dart';
import 'package:yomou/core/image_url.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// How a save attempt ended, so the UI can say the useful thing.
enum CoverSaveOutcome { saved, permissionDenied, failed }

const MethodChannel _channel = MethodChannel('com.hlomatsi.yomou/gallery');

/// Saves the full-size cover behind [imageUrl] into the device's photo gallery.
///
/// The bytes go through the same cache manager and referer headers the viewer
/// already used, so hotlink-protected hosts still answer, and the full-size
/// original is preferred over the 256px/`-193x278` thumbnail the source lists
/// (see [fullSizedImageUrl]).
Future<CoverSaveOutcome> saveCoverToGallery({
  required String imageUrl,
  required String title,
}) async {
  // Prefer the full-size original, but a source might not keep one beside the
  // thumbnail. Fall back to exactly what is on screen rather than fail.
  final full = fullSizedImageUrl(imageUrl);
  var url = full;
  var bytes = await _readBytes(full);
  if ((bytes == null || bytes.isEmpty) && full != imageUrl) {
    url = imageUrl;
    bytes = await _readBytes(imageUrl);
  }
  if (bytes == null || bytes.isEmpty) return CoverSaveOutcome.failed;
  try {
    await _channel.invokeMethod<String>('saveImage', {
      'bytes': bytes,
      'name': _fileName(title, url),
      'mime': _mimeFor(url),
    });
    return CoverSaveOutcome.saved;
  } on PlatformException catch (e) {
    return e.code == 'permission'
        ? CoverSaveOutcome.permissionDenied
        : CoverSaveOutcome.failed;
  } on MissingPluginException {
    return CoverSaveOutcome.failed;
  } catch (_) {
    return CoverSaveOutcome.failed;
  }
}

/// The image bytes, from the app's own storage when the cover is a
/// `local://` override, otherwise from the shared image cache (downloading on
/// the way if the viewer has not already fetched it).
Future<Uint8List?> _readBytes(String imageUrl) async {
  try {
    if (imageUrl.startsWith(CachedMangaImage.localScheme)) {
      final file = File(imageUrl.substring(CachedMangaImage.localScheme.length));
      return await file.exists() ? file.readAsBytes() : null;
    }
    final uri = Uri.tryParse(imageUrl);
    final referer = uri == null ? null : CachedMangaImage.refererFor(uri);
    final file = await AppImageCache.instance.manager.getSingleFile(
      imageUrl,
      headers: referer == null ? null : {'Referer': referer},
    );
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

String _mimeFor(String url) {
  return switch (_extension(url)) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'avif' => 'image/avif',
    _ => 'image/jpeg',
  };
}

/// A readable file name from the title, with the image's own extension. Falls
/// back to "cover" when the title has nothing usable, and clips to a length
/// every filesystem accepts.
String _fileName(String title, String url) {
  final clean = title
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s._-]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final base = clean.isEmpty ? 'cover' : clean;
  final clipped = base.length > 80 ? base.substring(0, 80).trim() : base;
  return '$clipped.${_extension(url)}';
}

String _extension(String url) {
  final path = Uri.tryParse(url)?.path ?? '';
  final dot = path.lastIndexOf('.');
  final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'png' || 'webp' || 'gif' || 'avif' => ext,
    'jpg' || 'jpeg' || 'jpe' => 'jpg',
    _ => 'jpg',
  };
}
