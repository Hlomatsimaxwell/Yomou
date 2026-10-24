import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/text_sanitizer.dart';

void main() {
  group('sanitizeMangaText', () {
    test('clean text passes untouched', () {
      expect('One Piece'.sanitizeMangaText(), 'One Piece');
    });

    test('a mis-decoded typographic quote re-reads as its true glyph', () {
      // â € ™ are the Windows-1252 readings of the UTF-8 bytes E2 80 99,
      // which is ’; the re-read recovers the site's real character.
      expect(
        'One Piece\u00E2\u20AC\u2122s'.sanitizeMangaText(),
        'One Piece\u2019s',
      );
    });

    test('mis-decoded Spanish accents come back', () {
      // Ã ©/± are the byte pairs C3 A9 / C3 B1, mis-decoded one code point
      // per byte.
      expect(
        'Una historia \u00C3\u00A9pica de A\u00C3\u00B1os'
            .sanitizeMangaText(),
        'Una historia \u00E9pica de A\u00F1os',
      );
    });

    test('double-encoded mojibake peels off both layers', () {
      // é encoded, then mojibaked again, runs four glyphs deep: Ã ƒ Â ©
      // reads back to Ã © on the first re-read and to é on the second.
      expect(
        '\u00C3\u0192\u00C2\u00A9'.sanitizeMangaText(),
        '\u00E9',
      );
    });

    test('a pure dash artifact resolves through the re-read', () {
      // The third glyph of â € ” reads back as byte 0x94, so the triplet
      // decodes as the em dash the source originally wrote.
      expect('\u00E2\u20AC\u201D'.sanitizeMangaText(), '\u2014');
    });

    test('an artifact beside a real quote falls to the token table', () {
      // ’ from the site's own text sits outside the single-byte window a
      // re-read demands, so the line is refused wholesale and the token
      // table carries the artifact from here. A straight quote is the
      // fallback, since the dash and the right quote share every byte and
      // a bare token cannot tell one from the other.
      expect(
        'Zone\u2019s \u00E2\u20AC\u201Ds'.sanitizeMangaText(),
        'Zone\u2019s "s',
      );
    });

    test('markup wrappers and entities strip to plain words', () {
      expect(
        '<b>Boichi</b>&rsquo;s<br>Sun'.sanitizeMangaText(),
        'Boichi\u2019s\nSun',
      );
    });

    test('a stray angle in a title is left alone', () {
      // The parser would read <Jerry as an unknown tag start and eat it;
      // without a letter-sequenced tag the text is left verbatim.
      expect('Tom<Jerry'.sanitizeMangaText(), 'Tom<Jerry');
      expect('Jacked < 78'.sanitizeMangaText(), 'Jacked < 78');
    });

    test('cleaning twice changes nothing further', () {
      final once = 'Una historia \u00C3\u00A9pica'.sanitizeMangaText();
      expect(once.sanitizeMangaText(), once);
    });

    test('double-peeled output is already clean on a second pass', () {
      final once = '\u00C3\u00A2\u00E2\u201A\u00AC\u00E2\u20AC\u201Ds'
          .sanitizeMangaText();
      expect(once.sanitizeMangaText(), once);
    });
  });
}
