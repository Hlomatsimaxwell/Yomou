import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:yomou/core/image/cover_accent.dart';

Uint8List _png(void Function(img.Image) paint, {int width = 64, int height = 96}) {
  final image = img.Image(width: width, height: height);
  paint(image);
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('a strongly coloured cover yields a matching accent', () {
    final bytes = _png((image) {
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixel(x, y, img.ColorRgb8(190, 40, 35));
        }
      }
    });

    final argb = sampleCoverAccent(bytes);

    expect(argb, isNotNull);
    final r = (argb! >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    expect(r, greaterThan(140));
    expect(g, lessThan(90));
    expect(b, lessThan(90));
  });

  test('a monochrome cover yields no accent', () {
    final bytes = _png((image) {
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final v = (x * 4) % 256;
          image.setPixel(x, y, img.ColorRgb8(v, v, v));
        }
      }
    });

    expect(sampleCoverAccent(bytes), isNull);
  });

  test('a white-margined cover still finds the coloured art', () {
    final bytes = _png((image) {
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          // A wide white band around a small colourful centre.
          final inside = x > 16 && x < 48 && y > 24 && y < 72;
          image.setPixel(
            x,
            y,
            inside ? img.ColorRgb8(30, 150, 200) : img.ColorRgb8(255, 255, 255),
          );
        }
      }
    });

    final argb = sampleCoverAccent(bytes);

    expect(argb, isNotNull);
    final b = argb! & 0xFF;
    final r = (argb >> 16) & 0xFF;
    expect(b, greaterThan(140));
    expect(r, lessThan(110));
  });

  test('undecodable bytes yield no accent', () {
    expect(sampleCoverAccent(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
