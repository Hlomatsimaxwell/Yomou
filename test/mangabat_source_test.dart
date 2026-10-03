import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:yomou/data/sources/mangabat_source.dart';

/// MangaBat's cards link to the full origin, `https://www.mangabats.com/manga/
/// martial-peak`. Stripping that origin leaves `manga/martial-peak`, and the
/// parser's old `replaceAll('/manga/', '')` could not remove the segment -
/// there was no leading slash left to match. The `manga/` prefix then survived
/// into the id, and every caller that prefixes `/manga/` again asked for
/// `/manga/manga/...`.
///
/// That failed quietly: the chapters API answers the doubled path with an HTML
/// error page, `json.decode` throws, and the empty catch reports it as a title
/// with no chapters at all.
void main() {
  final hot =
      File('test/fixtures/mangabat/hot_manga.html').readAsStringSync();
  final source = MangaBatSource();

  /// The card hrefs exactly as the site wrote them, so the transform is pinned
  /// to real markup rather than a hand-typed approximation of it.
  List<String> cardHrefs() => parser
      .parse(hot)
      .querySelectorAll('div.list-comic-item-wrap h3 a')
      .map((a) => a.attributes['href'] ?? '')
      .where((h) => h.isNotEmpty)
      .toList();

  group('idFromHref', () {
    test('turns the site\'s own card links into bare slugs', () {
      final hrefs = cardHrefs();
      expect(hrefs, hasLength(4));
      expect(
        hrefs.map(source.idFromHref),
        [
          'martial-peak',
          'tales-of-demons-and-gods',
          'solo-leveling',
          'versatile-mage',
        ],
      );
    });

    test('never leaves a manga/ segment behind', () {
      // The bug in one assertion: any id that still carries the segment makes
      // every /manga/ prefix double.
      for (final href in cardHrefs()) {
        final id = source.idFromHref(href);
        expect(id, isNot(contains('/manga/')));
        expect(id.startsWith('manga/'), isFalse);
      }
    });

    test('is idempotent, so a doubled path cannot come back', () {
      for (final href in cardHrefs()) {
        final once = source.idFromHref(href);
        expect(source.idFromHref(once), once);
        expect(source.idFromHref('/$once'), once);
      }
    });

    test('handles relative and absolute forms alike', () {
      expect(source.idFromHref('/manga/martial-peak'), 'martial-peak');
      expect(source.idFromHref('manga/martial-peak'), 'martial-peak');
      expect(
        source.idFromHref('https://www.mangabats.com/manga/martial-peak'),
        'martial-peak',
      );
    });

    test('drops a trailing slash rather than leaving an empty segment', () {
      expect(
        source.idFromHref('https://www.mangabats.com/manga/martial-peak/'),
        'martial-peak',
      );
    });
  });

  group('slugFromId', () {
    test('leaves a clean slug alone', () {
      expect(MangaBatSource.slugFromId('martial-peak'), 'martial-peak');
      expect(MangaBatSource.slugFromId('solo-leveling'), 'solo-leveling');
    });

    test('removes the redundant prefix old rows were saved with', () {
      expect(MangaBatSource.slugFromId('manga/martial-peak'), 'martial-peak');
      expect(MangaBatSource.slugFromId('/manga/martial-peak'), 'martial-peak');
    });

    test('removes it from a chapter id, leaving the chapter in place', () {
      expect(
        MangaBatSource.slugFromId('manga/martial-peak/chapter-3862'),
        'martial-peak/chapter-3862',
      );
      expect(
        MangaBatSource.slugFromId('martial-peak/chapter-3862'),
        'martial-peak/chapter-3862',
      );
    });

    test('is idempotent, so a double prefix cannot survive', () {
      expect(
        MangaBatSource.slugFromId('manga/manga/martial-peak'),
        'martial-peak',
      );
    });

    test('leaves a slug that merely contains the word alone', () {
      // A real slug, not a doubled path: only a leading segment is removed.
      expect(MangaBatSource.slugFromId('manga-martial-peak'), 'manga-martial-peak');
      expect(MangaBatSource.slugFromId('my-manga-odyssey'), 'my-manga-odyssey');
    });
  });
}
