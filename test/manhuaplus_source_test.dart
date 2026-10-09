import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/sources/manhuaplus_source.dart';

/// ManhuaPlus is a stock Madara theme driven entirely by its
/// [MadaraSiteConfig]. These pin that config against trimmed captures of the
/// real markup, driving the shared engine rather than a copy of its parsing:
///
/// - the card grid uses `.page-item-detail` with a `data-src` cover,
/// - the detail cover lives in `.summary_image`, while the page's first <img>
///   is the header logo,
/// - `.post-status` lists Release before Status, so the status has to be read
///   from the row labelled "Status" or the release year comes back,
/// - the chapter list is the theme's `ul.main li.wp-manga-chapter`, and
/// - reader images sit under `class="reading-content"`, not `#reading-content`.
class _StubManhuaPlus extends ManhuaPlusSource {
  _StubManhuaPlus(this.respond);

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

void main() {
  final listing =
      File('test/fixtures/manhuaplus/listing.html').readAsStringSync();
  final detail =
      File('test/fixtures/manhuaplus/detail.html').readAsStringSync();
  final chapter =
      File('test/fixtures/manhuaplus/chapter.html').readAsStringSync();

  _StubManhuaPlus source() => _StubManhuaPlus((url) {
        if (url.contains('chapter-1301')) return chapter;
        if (url.contains('m_orderby=views')) return listing;
        if (url.contains('manga/apotheosis')) return detail;
        return '';
      });

  group('the listing', () {
    test('parses both cards with their titles and lazy covers', () async {
      final mangas = await source().getPopularManga();
      expect(mangas, hasLength(2));
      expect(
        mangas.map((m) => m.title).toList(),
        ['Martial Peak', 'Magic Emperor'],
      );
      expect(mangas.first.id, 'manga/martial-peak');
      for (final m in mangas) {
        expect(m.coverUrl, startsWith('https://manhuaplus.com/'));
        expect(
          m.coverUrl,
          isNot(contains('dflazy')),
          reason: 'the placeholder src must not win over data-src',
        );
      }
    });
  });

  group('the details', () {
    test('reads the summary cover, not the header logo', () async {
      final d = await source().getMangaDetails('manga/apotheosis');
      expect(d, isNotNull);
      expect(d!.title, 'Apotheosis');
      expect(d.coverUrl, contains('cover-193x278'));
      expect(d.coverUrl, isNot(contains('logo-1-1')));
    });

    test('reads the row labelled Status, not the release year', () async {
      final d = await source().getMangaDetails('manga/apotheosis');
      expect(d!.status, 'Ongoing');
    });

    test('reads author and genres', () async {
      final d = await source().getMangaDetails('manga/apotheosis');
      expect(d!.author, 'En Chi Jie Tuo');
      expect(d.tags, containsAll(['Action', 'Fantasy']));
    });
  });

  group('the chapters', () {
    test('lists chapters with their numbers', () async {
      final chapters = await source().getChapters('manga/apotheosis');
      expect(chapters, hasLength(3));
      expect(chapters.first.id, 'manga/apotheosis/chapter-1301');
      expect(chapters.first.chapterNumber, '1301');
    });
  });

  group('the reader', () {
    test('collects the page images under .reading-content', () async {
      final pages = await source().getPageUrls('manga/apotheosis/chapter-1301');
      expect(pages, hasLength(4));
      expect(pages, everyElement(startsWith('https://cdn.manhuaplus.com/')));
    });
  });

  test('the config points at the right site and reader container', () {
    final config = ManhuaPlusSource().config;
    expect(config.id, 'manhuaplus');
    expect(config.baseUrl, 'https://manhuaplus.com');
    expect(config.readerImageSelector, '.reading-content img');
  });
}
