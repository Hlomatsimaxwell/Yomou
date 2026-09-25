import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// MangaFire scramble un-shuffling (mirrors Kotatsu's `MangaFireParser`).
///
/// Some chapter images are served as a grid of pieces that have been rotated
/// along the diagonals by a per-image offset. The transformation is an
/// involution (applying it twice restores the original), so "un-scrambling" is
/// the same piece-shuffle used to scramble.
abstract final class MfScramble {
  /// Maximum size of one tile in the shuffled grid.
  static const int _pieceSize = 200;

  /// Minimum number of tiles across the shorter dimension.
  static const int _minSplits = 5;

  static int _ceilDiv(int a, int b) => (a + b - 1) ~/ b;

  /// Extracts the scramble offset from a reader URL, or null when the page was
  /// served unscrambled (`#scrambled_N` suffix marks scrambled pages).
  static int? offsetFromUrl(String url) {
    final match = RegExp(r'#scrambled_(\d+)').firstMatch(url);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Returns true when [url] points at a scrambled MangaFire page.
  static bool isScrambledUrl(String url) => offsetFromUrl(url) != null;

  /// De-scrambles [bytes] and re-encodes the page as PNG. Expects the raw bytes
  /// of a scrambled page image ([offset] >= 1). Returns null if decoding fails.
  static Uint8List? unscramble(Uint8List bytes, int offset) {
    try {
      final src = img.decodeImage(bytes);
      if (src == null) return null;

      final width = src.width;
      final height = src.height;
      final pieceWidth = _pieceSize < _ceilDiv(width, _minSplits)
          ? _pieceSize
          : _ceilDiv(width, _minSplits);
      final pieceHeight = _pieceSize < _ceilDiv(height, _minSplits)
          ? _pieceSize
          : _ceilDiv(height, _minSplits);
      final xMax = _ceilDiv(width, pieceWidth) - 1;
      final yMax = _ceilDiv(height, pieceHeight) - 1;

      final rgba = src.convert(numChannels: 4);
      final dst = img.Image.from(rgba, noAnimation: true);

      for (var y = 0; y <= yMax; y++) {
        final yDst = pieceHeight * y;
        final h = pieceHeight < height - yDst ? pieceHeight : height - yDst;
        final ySrc = pieceHeight *
            (y == yMax ? y : (yMax - y + offset) % yMax);
        for (var x = 0; x <= xMax; x++) {
          final xDst = pieceWidth * x;
          final w = pieceWidth < width - xDst ? pieceWidth : width - xDst;
          final xSrc = pieceWidth *
              (x == xMax ? x : (xMax - x + offset) % xMax);
          for (var yy = 0; yy < h; yy++) {
            final srcRow = ySrc + yy;
            for (var xx = 0; xx < w; xx++) {
              dst.setPixel(xDst + xx, yDst + yy, rgba.getPixel(xSrc + xx, srcRow));
            }
          }
        }
      }

      return img.encodePng(dst);
    } catch (_) {
      return null;
    }
  }
}