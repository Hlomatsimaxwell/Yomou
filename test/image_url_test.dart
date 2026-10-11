import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/image_url.dart';

/// Sources list a cover thumbnail and keep the original beside it. The viewer
/// only has the thumbnail URL to work from, so these pin the two shapes the
/// sources use and, just as importantly, what must be left untouched.
void main() {
  group('fullSizedImageUrl', () {
    test('lifts a MangaDex size suffix to the original', () {
      expect(
        fullSizedImageUrl(
          'https://uploads.mangadex.org/covers/abc/def.jpg.256.jpg',
        ),
        'https://uploads.mangadex.org/covers/abc/def.jpg',
      );
      expect(
        fullSizedImageUrl(
          'https://uploads.mangadex.org/covers/abc/def.png.512.png',
        ),
        'https://uploads.mangadex.org/covers/abc/def.png',
      );
    });

    test('strips a WordPress/Madara thumbnail size', () {
      expect(
        fullSizedImageUrl(
          'https://manhuaplus.com/wp-content/uploads/2020/07/cover-193x278.jpg',
        ),
        'https://manhuaplus.com/wp-content/uploads/2020/07/cover.jpg',
      );
      expect(
        fullSizedImageUrl('https://x.test/a/thumbbbbb-175x238.webp'),
        'https://x.test/a/thumbbbbb.webp',
      );
    });

    test('leaves an already-original URL alone', () {
      const comick = 'https://cdn1.comicknew.pictures/a/covers/101b409e.webp';
      expect(fullSizedImageUrl(comick), comick);
      const mangadexFull =
          'https://uploads.mangadex.org/covers/abc/def.jpg';
      expect(fullSizedImageUrl(mangadexFull), mangadexFull);
    });

    test('never rewrites a URL carrying a query string', () {
      const signed = 'https://x.test/cover-100x150.jpg?token=abc';
      expect(fullSizedImageUrl(signed), signed);
    });

    test('leaves a local override and an empty URL alone', () {
      const local = 'local:///data/user/0/app/files/cover.jpg';
      expect(fullSizedImageUrl(local), local);
      expect(fullSizedImageUrl(''), '');
    });

    test('does not mistake a versioned name for a thumbnail', () {
      // One digit is not a thumbnail size; the original would be wrong.
      const url = 'https://x.test/chapter-1.5.jpg';
      expect(fullSizedImageUrl(url), url);
    });
  });
}
