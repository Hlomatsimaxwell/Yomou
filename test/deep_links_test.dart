import 'package:flutter_test/flutter_test.dart';

import 'package:yomou/core/deep_links.dart';

void main() {
  group('buildYomouMangaLink / YomouMangaLink.tryParse', () {
    test('round-trips source, id, name and website url', () {
      final raw = buildYomouMangaLink(
        sourceId: 'asura-scans',
        mangaId: 'nano-machine',
        title: 'Nano Machine',
        websiteUrl: 'https://asurascans.com/comics/nano-machine-9a7a1ac5',
      );
      expect(raw, startsWith('yomou://manga?'));

      final link = YomouMangaLink.tryParse(raw);
      expect(link, isNotNull);
      expect(link!.sourceId, 'asura-scans');
      expect(link.mangaId, 'nano-machine');
      expect(link.title, 'Nano Machine');
      expect(
        link.websiteUrl,
        'https://asurascans.com/comics/nano-machine-9a7a1ac5',
      );
    });

    test('omits optional params when empty', () {
      final raw = buildYomouMangaLink(sourceId: 'mangadex', mangaId: 'abc-123');
      expect(raw, 'yomou://manga?source=mangadex&id=abc-123');
      expect(raw.contains('name='), isFalse);
      expect(raw.contains('url='), isFalse);
    });

    test('encodes spaces and reserved characters', () {
      final raw = buildYomouMangaLink(
        sourceId: 'mangadex',
        mangaId: 'a b/ü?',
        title: 'Title & More: Part 1',
        websiteUrl: 'https://mangadex.org/title/uuid?lang=en&dl=1',
      );
      final link = YomouMangaLink.tryParse(raw);
      expect(link, isNotNull);
      expect(link!.mangaId, 'a b/ü?');
      expect(link.title, 'Title & More: Part 1');
      expect(link.websiteUrl, 'https://mangadex.org/title/uuid?lang=en&dl=1');
    });

    test('rejects foreign schemes, wrong hosts and missing params', () {
      expect(YomouMangaLink.tryParse('https://asurascans.com/comics/x'), isNull);
      expect(YomouMangaLink.tryParse('yomou://reader?source=a&id=b'), isNull);
      expect(YomouMangaLink.tryParse('yomou://manga?source=only'), isNull);
      expect(YomouMangaLink.tryParse('yomou://manga?id=only'), isNull);
      expect(YomouMangaLink.tryParse(''), isNull);
      expect(YomouMangaLink.tryParse('not-a-uri'), isNull);
    });
  });

  group('buildYomouShareLink', () {
    test('is an https link carrying the deep link in the u param', () {
      final raw = buildYomouShareLink(
        sourceId: 'asurascans',
        mangaId: 'nano-machine',
        title: 'Nano Machine',
        websiteUrl: 'https://asurascans.com/comics/nano-machine-9a7a1ac5',
      );
      expect(raw, startsWith('$yomouShareBaseUrl?u='));

      final uri = Uri.parse(raw);
      expect(uri.scheme, 'https');
      // One query parameter, fully encoded: no raw ampersands to confuse the
      // linkifiers in chat apps.
      expect(uri.queryParameters.length, 1);

      final deep = uri.queryParameters['u']!;
      expect(
        deep,
        buildYomouMangaLink(
          sourceId: 'asurascans',
          mangaId: 'nano-machine',
          title: 'Nano Machine',
          websiteUrl: 'https://asurascans.com/comics/nano-machine-9a7a1ac5',
        ),
      );
      // And the carried link still opens the manga, end to end.
      final link = YomouMangaLink.tryParse(deep);
      expect(link!.mangaId, 'nano-machine');
      expect(link.sourceId, 'asurascans');
    });

    test('keeps the shared string free of literal & characters', () {
      final raw = buildYomouShareLink(
        sourceId: 'mangadex',
        mangaId: 'abc-123',
        title: 'A & B',
        websiteUrl: 'https://mangadex.org/title/uuid?lang=en',
      );
      expect(raw.contains('&'), isFalse);
    });
  });
}
