import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/sources/mangago_cipher.dart';
import 'package:yomou/data/sources/mangago_source.dart';

/// Mangago serves plain HTML for its grid and detail pages and hides the
/// reader's page list in an AES-encrypted `imgsrcs` variable. These tests pin
/// that parsing (and the decryption) against trimmed captures of the real
/// pages:
///
/// - a hot-manga listing of six `div.updatesli` cards whose covers are lazy
///   `data-src` images,
/// - the search results page (same `a.thm-effect` card shape, direct `src`),
/// - the detail page: `.w-title h1`, `.left.cover` image, the `manga_right`
///   info table (Status / Author / Genre(s) / Alternative), the
///   `div.manga_summary` blurb, and `table#chapter_table` rows of
///   `<h4><a class="chico">` chapter links
/// - a reader page carrying `var imgsrcs = '<base64>'`.
///
/// The reader payload in the fixture is a real capture: `br_chapter-446478`
/// has 61 pages, the first two of which were cross-checked against the DOM the
/// site's own reader produced in headless Chrome.
class _StubMangago extends MangagoSource {
  _StubMangago(this.respond);

  final String Function(String url) respond;

  @override
  Future<String> grabText(
    String url, {
    Map<String, String>? extraHeaders,
    bool useBaseUrl = true,
    bool saveCookies = false,
  }) async =>
      respond(url);
}

String _fixture(String name) =>
    File('test/fixtures/mangago/$name.html').readAsStringSync();

void main() {
  final listing = _fixture('listing');
  final search = _fixture('search');
  final detail = _fixture('detail');
  final chapter = _fixture('chapter');

  _StubMangago source() => _StubMangago((url) {
        if (url.contains('/list/hot-manga/')) return listing;
        if (url.contains('/r/l_search/')) return search;
        if (url.contains('/read-manga/a_dragon_s_love/uu/')) return chapter;
        if (url.contains('/read-manga/a_dragon_s_love/')) return detail;
        return '';
      });

  test('identifies as the mangago source', () {
    final s = MangagoSource();
    expect(s.id, 'mangago');
    expect(s.name, 'Mangago');
    expect(s.baseUrl, 'https://www.mangago.me');
    expect(MangagoSource.idFromHref(
        'https://www.mangago.me/read-manga/hitogatana/'), 'hitogatana');
    expect(
      MangagoSource.idFromHref(
        'https://www.mangago.me/read-manga/a_dragon_s_love/uu/'
        'br_chapter-446478/pg-1/',
      ),
      'a_dragon_s_love/uu/br_chapter-446478/pg-1',
    );
  });

  group('the hot-manga listing', () {
    test('parses the cards, covers from data-src not the placeholder',
        () async {
      final mangas = await source().getPopularManga();
      expect(mangas, hasLength(6));
      expect(mangas.first.id, 'hitogatana');
      expect(mangas.first.title, '-hitogatana-');
      expect(mangas.map((m) => m.id).toSet(), hasLength(6));
      for (final m in mangas) {
        expect(m.coverUrl, startsWith('https://'));
        expect(m.coverUrl, isNot(contains('data:image/gif')),
            reason: 'the lazy placeholder must not win over data-src');
        expect(m.sourceId, 'mangago');
      }
    });
  });

  group('search', () {
    test('parses the result cards', () async {
      final mangas = await source().searchByTitle('a dragon');
      expect(mangas, hasLength(6));
      expect(mangas.first.id, 'dragon_weed_origins');
      expect(mangas.first.title, 'Dragon & Weed: Origins');
      expect(mangas[1].id, 'dragon_amp_weed_origins');
    });
  });

  group('the details', () {
    test('reads title, cover, author, status, year and genres', () async {
      final d = await source().getMangaDetails('a_dragon_s_love');
      expect(d, isNotNull);
      expect(d!.title, "A Dragon's Love (Yaoi)");
      expect(d.coverUrl, contains('/coverlink/'));
      expect(d.status, 'ongoing');
      expect(d.author, contains('Brothers Without A Tomorrow'));
      expect(d.year, '2026');
      expect(d.tags, containsAll(['Yaoi', 'Fantasy', 'Romance']));
    });

    test('reads the synopsis without the mature-content advisory', () async {
      final d = await source().getMangaDetails('a_dragon_s_love');
      expect(d!.description, startsWith('On a stormy night'));
      expect(d.description, isNot(contains('mature audiences')));
    });
  });

  group('the chapters', () {
    test('lists every row oldest-first, deduped', () async {
      final chapters = await source().getChapters('a_dragon_s_love');
      // 18 table rows; the newest chapter also appears in the "Latest" row,
      // and a distinct original-upload row duplicates Ch. 1 -- ids differ.
      expect(chapters, hasLength(18));
      expect(chapters.map((c) => c.id).toSet(), hasLength(18));
      expect(chapters.first.id,
          'a_dragon_s_love/uu/iur_chapter-1');
      expect(chapters.first.chapterNumber, '1');
      expect(chapters.first.releaseDate, 'Jul 1, 2026');
      expect(chapters[1].id, 'a_dragon_s_love/uu/br_chapter-398951');
      expect(chapters.last.id,
          'a_dragon_s_love/uu/br_chapter-446478');
      expect(chapters.last.chapterNumber, '16');
      expect(chapters.last.releaseDate, 'Oct 8, 2026');
      expect(chapters.last.url,
          'https://www.mangago.me/read-manga/a_dragon_s_love/uu/'
          'br_chapter-446478/pg-1/');
    });

    test('keeps the hiatus-note row', () async {
      final chapters = await source().getChapters('a_dragon_s_love');
      final hiatus = chapters.firstWhere(
        (c) => c.title.contains('hitaus'),
        orElse: () => throw StateError('hiatus row missing'),
      );
      expect(hiatus.id, 'a_dragon_s_love/uu/br_chapter-419283');
    });
  });

  group('the reader', () {
    test('decrypts the imgsrcs payload to the 61 known page URLs', () async {
      final pages = await source()
          .getPageUrls('a_dragon_s_love/uu/br_chapter-446478');
      expect(pages, hasLength(61));
      expect(
        pages.first,
        'https://iweb_9.mangapicgallery.com/r/newpiclink/a_dragon_s_love/'
        '446478/446478_59906180.jpg',
      );
      expect(
        pages[1],
        'https://iweb_9.mangapicgallery.com/r/newpiclink/a_dragon_s_love/'
        '446478/446478_59881200.jpg',
      );
      expect(pages, everyElement(startsWith('http')));
      // No two pages share a URL.
      expect(pages.toSet(), hasLength(61));
    });
  });

  group('MangagoCipher', () {
    test('decodes the fixture payload without the network layer', () {
      final match = RegExp("var imgsrcs = '([^']*)'").firstMatch(chapter);
      expect(match, isNotNull);
      final urls = MangagoCipher.decodeImgsrcs(match!.group(1)!);
      expect(urls, hasLength(61));
      expect(urls.first, contains('446478_59906180.jpg'));
      expect(urls.last, contains('446478_59881345.jpg'));
    });

    test('legacy removal + dorder shake does not corrupt a clean payload',
        () {
      // The current site emits straight payloads; the legacy pass must not
      // win the "most http URLs" contest against the plain decode.
      final match = RegExp("var imgsrcs = '([^']*)'").firstMatch(chapter)!;
      final urls = MangagoCipher.decodeImgsrcs(match.group(1)!);
      expect(urls.first, startsWith('https://iweb_9.mangapicgallery.com/'));
      expect(urls.every((u) => u.startsWith('http')), isTrue);
    });
  });
}