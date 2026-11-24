import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// GigaViewer's 4x4 page scramble (mirrors the upstream `ImageInterceptor`).
///
/// Some GigaViewer chapters are served with their 16 tiles transposed: tile
/// `e` is drawn at slot `(e % 4) * 4 + (e ~/ 4)`. That permutation is an
/// involution, so applying it again restores the page. The reader marks such
/// images with a `#scramble` URL fragment; both the image widget and the
/// downloader undo the shuffle before decoding.
abstract final class GigaScramble {
  static const int _divide = 4;
  static const int _multiple = 8;

  /// Whether [url] carries the fragment the viewer adds to scrambled pages.
  static bool isScrambledUrl(String url) => url.endsWith('#scramble');

  /// Returns the unscrambled page as PNG, or null when it cannot be decoded.
  static Uint8List? unscramble(Uint8List bytes) {
    try {
      final source = img.decodeImage(bytes);
      if (source == null) return null;
      final width = source.width;
      final height = source.height;

      // The tile size is rounded down to a multiple of 8, exactly as in the
      // upstream Bitmap interceptor. Anything past the 4x4 grid is left alone.
      final blockWidth = (width ~/ (_divide * _multiple)) * _multiple;
      final blockHeight = (height ~/ (_divide * _multiple)) * _multiple;
      if (blockWidth <= 0 || blockHeight <= 0) return img.encodePng(source);

      final rgba = source.convert(numChannels: 4);
      final result = img.Image.from(rgba, noAnimation: true);
      for (var e = 0; e < _divide * _divide; e++) {
        final slot = (e % _divide) * _divide + (e ~/ _divide);
        final srcX = (e % _divide) * blockWidth;
        final srcY = (e ~/ _divide) * blockHeight;
        final dstX = (slot % _divide) * blockWidth;
        final dstY = (slot ~/ _divide) * blockHeight;
        for (var y = 0; y < blockHeight; y++) {
          for (var x = 0; x < blockWidth; x++) {
            result.setPixel(
              dstX + x,
              dstY + y,
              rgba.getPixel(srcX + x, srcY + y),
            );
          }
        }
      }
      return img.encodePng(result);
    } catch (_) {
      return null;
    }
  }
}
