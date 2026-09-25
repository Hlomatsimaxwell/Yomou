import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yomou/data/sources/mangafire_vrf.dart';
import 'package:yomou/data/sources/mf_scramble.dart';

void main() {
  group('MfVrf', () {
    test('produces stable urlsafe tokens', () {
      final a = MfVrf.generate('62932@chapter@en');
      final b = MfVrf.generate('62932@chapter@en');
      expect(a, isNotEmpty);
      expect(a, b);
      expect(a.contains('='), isFalse);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(a), isTrue);

      final c = MfVrf.generate('chapter@123456');
      expect(c, isNot(a));
      expect(c.length, greaterThan(40));
    });

    test('matches the python reference implementation', () {
      expect(
        MfVrf.generate('62932@chapter@en'),
        'ZBYeRCjYBk0tkZnKW4kTuWBYw-81e-csvu6v1rUY4zcaviixua7VJ5tjX1HxtDxALxiZuhqf',
      );
      expect(
        MfVrf.generate('12345@chapter@en'),
        'ZBYeRCjYBk0tkZnKW4kTuWBYw-w1e-csvu6v1rUY4zcwviixuq7VJyxjX1HxtDxALxiZuhqf',
      );
    });
  });

  group('MfScramble', () {
    test('parses scrambled URL offsets', () {
      expect(MfScramble.offsetFromUrl('https://x.y/a.jpg'), isNull);
      expect(MfScramble.offsetFromUrl('https://x.y/a.jpg#scrambled_3'), 3);
      expect(MfScramble.isScrambledUrl('https://x.y/a.jpg#scrambled_7'), isTrue);
      expect(MfScramble.isScrambledUrl('https://x.y/a.jpg'), isFalse);
    });

    // The shuffle is an involution: applying it twice with the same offset
    // must reproduce the original page exactly.
    for (final (w, h, offset) in [
      (413, 600, 1),
      (640, 900, 3),
      (800, 1200, 5),
      (1500, 1500, 7),
      (101, 77, 2),
    ]) {
      test('round-trip $w x $h offset $offset', () {
        final original = img.Image(width: w, height: h);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            original.setPixelRgb(x, y, (x * 3) % 256, (y * 5) % 256,
                (x + y) % 197);
          }
        }
        final bytes = img.encodePng(original);

        final once = MfScramble.unscramble(bytes, offset);
        expect(once, isNotNull);
        final twice = MfScramble.unscramble(once!, offset);
        expect(twice, isNotNull);

        final back = img.decodeImage(twice!)!;
        expect(back.width, w);
        expect(back.height, h);
        for (var y = 0; y < h; y += 7) {
          for (var x = 0; x < w; x += 7) {
            final expected = original.getPixel(x, y);
            expect(back.getPixel(x, y).r, expected.r);
            expect(back.getPixel(x, y).g, expected.g);
            expect(back.getPixel(x, y).b, expected.b);
          }
        }
      });
    }

    test('returns null on garbage bytes', () {
      expect(MfScramble.unscramble(Uint8List.fromList([1, 2, 3]), 3), isNull);
    });
  });
}