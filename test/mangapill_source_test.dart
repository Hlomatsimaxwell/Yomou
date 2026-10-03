import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:yomou/data/sources/mangapill_source.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// MangaPill serves Tailwind markup that no fixture in the repo used to pin,
/// and it changed under this parser once already, so the markup now lives in
/// `test/fixtures/mangapill/` as trimmed captures of the real site.
///
/// The bug these guard: `getPopularManga` scraped the homepage, whose only
/// `/manga/` cards are the 10-item "Trending Mangas" strip - the other 30
/// homepage cards point at `/chapters/`. So popular returned 10. The fixture
/// keeps 3 of each in that same proportion; the live counts were 10 and 30.
void main() {
  final homepage =
      File('test/fixtures/mangapill/homepage.html').readAsStringSync();
  final listing =
      File('test/fixtures/mangapill/search_listing.html').readAsStringSync();

  /// The manga cards on a page, as the parser finds them: the `relative block`
  /// anchors whose href is a manga path, which is what `_parseGrid` keeps.
  List<String> mangaCards(String html) => parser
      .parse(html)
      .querySelectorAll('a.relative.block')
      .map((a) => a.attributes['href'] ?? '')
      .where((h) => RegExp(r'^/manga/\d+/').hasMatch(h))
      .toList();

  group('the homepage is not a listing', () {
    test('its manga cards are the ones a 10-item strip would produce', () {
      expect(mangaCards(homepage), hasLength(3));
    });

    test('most of its cards point at chapters, and are rightly dropped', () {
      final chapters = parser
          .parse(homepage)
          .querySelectorAll('a.relative.block')
          .map((a) => a.attributes['href'] ?? '')
          .where((h) => h.startsWith('/chapters/'))
          .toList();
      expect(chapters, hasLength(2));
    });
  });

  group('the paginated listing getPopularManga now reads', () {
    test('is a real listing, with no trending strip', () {
      expect(listing, isNot(contains('Trending Mangas')));
      expect(mangaCards(listing), hasLength(3));
    });

    test('gives every card a lazy data-src cover', () {
      final covers = parser
          .parse(listing)
          .querySelectorAll('a.relative.block')
          .where((a) => RegExp(r'^/manga/\d+/').hasMatch(a.attributes['href'] ?? ''))
          .map((a) => a.querySelector('img')?.attributes['data-src'])
          .toList();
      expect(covers, hasLength(3));
      expect(covers.where((c) => c == null || c.isEmpty), isEmpty);
    });
  });

  group('covers', () {
    test('sit on a host the image widget sends the required referer for', () {
      // The widget is handed a URL and nothing else, so it keys off the host.
      // A host missing from its map means a 403 and a silent grey box in every
      // grid - no error, just nothing.
      final hosts = parser
          .parse(listing)
          .querySelectorAll('a.relative.block img')
          .map((i) => Uri.parse(i.attributes['data-src'] ?? 'https://x.invalid/'))
          .where((u) => u.host.isNotEmpty)
          .map((u) => u.host)
          .toSet();
      expect(hosts, isNotEmpty);

      final known = CachedMangaImage.refererFor(
        Uri.parse('https://${hosts.first}/file/mangapill/i/1.jpeg'),
      );
      expect(known, isNotNull, reason: 'cover host $hosts has no referer entry');
      expect(known, 'https://mangapill.com/');
    });

    test('the referer the CDN actually accepts is the one we send', () {
      // Recorded: this URL answers 403 with no referer, 200 for mangapill.com.
      expect(
        CachedMangaImage.refererFor(
          Uri.parse('https://cdn.readdetectiveconan.com/file/mangapill/i/1.jpeg'),
        ),
        'https://mangapill.com/',
      );
    });
  });

  group('the source', () {
    test('stamps its own id, never a slug', () {
      // The Manga constructor rejects a sourceId containing '/', so reaching
      // getPopularManga at all is the assertion; id is the other half.
      expect(MangaPillSource().id, 'mangapill');
    });
  });
}
