import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/data/models/manga_filter.dart';
import 'package:yomou/data/sources/seimanga_source.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// SeiManga answers plain HTTP, so these tests pin the parsing against trimmed
/// captures of the real pages:
///
/// - the `/api/catalog/search` JSON listing/search response,
/// - a server-rendered title page (hero, meta description, status, tags and the
///   chapter table),
/// - a reader page with its inline `rm_h.readerInit(...)` page list,
/// - the advanced-search page with `window.__FILTERS` (genres + year bounds).
///
/// The source fetches bytes and decodes UTF-8 itself (the shared [DioSource]
/// helper decodes as Latin-1), so the stub overrides `grabBytes`.
class _StubSei extends SeiMangaSource {
  _StubSei(this.respond);

  final String Function(String url) respond;

  /// Every URL the source asked for, so the tests can pin the query it built.
  final List<String> urls = [];

  @override
  Future<List<int>?> grabBytes(
    String url, {
    Map<String, String>? extraHeaders,
  }) async {
    urls.add(url);
    final body = respond(url);
    return body.isEmpty ? null : utf8.encode(body);
  }
}

String _fixture(String name) =>
    File('test/fixtures/seimanga/$name').readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final search = _fixture('search.json');
  final detail = _fixture('detail.html');
  final reader = _fixture('reader.html');
  final filters = _fixture('filters.html');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  _StubSei source() => _StubSei((url) {
    if (url.contains('/api/catalog/search')) return search;
    if (url.contains('/search/advanced')) return filters;
    if (url.contains('?mtr=true')) return reader;
    if (url.contains('/legenda_o_hentai_geroe_iz_drugogo_mira')) return detail;
    return '';
  });

  test('identifies as the seimanga source', () {
    final s = SeiMangaSource();
    expect(s.id, 'seimanga');
    expect(s.name, 'SeiManga');
    expect(s.baseUrl, 'https://1.seimanga.me');
    expect(s.languageCode, 'ru');
  });

  group('the popular listing', () {
    test('parses the catalogue rows and their genres', () async {
      final mangas = await source().getPopularManga();
      expect(mangas, hasLength(3));
      expect(mangas.first.id, 'zajgi_moi_instinkt');
      expect(mangas.first.title, 'Зажги мой инстинкт');
      expect(
        mangas.first.coverUrl,
        'https://sei.one-way.work/uploads/pics/00/91/424.webp',
      );
      expect(mangas.first.tags, contains('дзёсэй'));
      for (final manga in mangas) {
        expect(manga.sourceId, 'seimanga');
      }
    });

    test('pages the JSON API in 50-item blocks', () async {
      final stub = source();
      await stub.getPopularManga(page: 3);
      final url = stub.urls.single;
      expect(url, contains('/api/catalog/search?'));
      expect(url, contains('sortType=POPULARITY'));
      expect(url, contains('offset=100'));
    });
  });

  group('search', () {
    test('sends the query through the catalogue endpoint', () async {
      final stub = source();
      await stub.searchByTitle('Ведьма');
      expect(
        stub.urls.single,
        contains('q=${Uri.encodeComponent('Ведьма')}'),
      );
    });

    test('a blank query never hits the network', () async {
      final stub = source();
      expect(await stub.searchByTitle('   '), isEmpty);
      expect(stub.urls, isEmpty);
    });
  });

  group('the cover host', () {
    test('sends the referer its CDN demands', () {
      // Recorded: this host answers 403 with no referer (or a foreign one) and
      // 200 for the mirror. Every catalogue cover is served from it, so a
      // missing entry in the referer table is a wall of blank tiles.
      expect(
        CachedMangaImage.refererFor(
          Uri.parse('https://sei.one-way.work/uploads/pics/00/91/424.webp'),
        ),
        'https://1.seimanga.me/',
      );
    });
  });

  group('the details lookup', () {
    test('reads the hero, status, year, author and synopsis', () async {
      final details = await source().getMangaDetails(
        'legenda_o_hentai_geroe_iz_drugogo_mira',
      );
      expect(details, isNotNull);
      expect(details!.title, 'Легенда о хентай-герое из другого мира');
      expect(
        details.coverUrl,
        'https://sei.one-way.work/uploads/pics/01/17/562.webp',
      );
      expect(details.description, startsWith('Пробуждение чувственной силы'));
      expect(details.status, 'ongoing');
      expect(details.year, '2025');
      expect(details.author, 'Ойкава Тору');
      expect(details.tags, contains('исэкай'));
      expect(details.tags, contains('эротика'));
      expect(details.totalChapters, 3);
      expect(details.language, 'ru');
    });

    test('a dead slug (no hero markup) yields null', () async {
      final stub = _StubSei((url) => '<html><title>404</title></html>');
      expect(await stub.getMangaDetails('nope'), isNull);
    });
  });

  group('the chapter list', () {
    test('is handed back oldest first with its reader path as the id',
        () async {
      final chapters = await source().getChapters(
        'legenda_o_hentai_geroe_iz_drugogo_mira',
      );
      expect(chapters.map((c) => c.chapterNumber), ['15.3', '15.4', '15.5']);
      expect(
        chapters.first.id,
        'legenda_o_hentai_geroe_iz_drugogo_mira/vol1/15.3',
      );
      expect(
        chapters.first.url,
        'https://1.seimanga.me/legenda_o_hentai_geroe_iz_drugogo_mira/vol1/15.3',
      );
      expect(chapters.first.releaseDate, startsWith('2026-09-21'));
    });

    test('getTotalChapters counts the table rows', () async {
      expect(
        await source().getTotalChapters(
          'legenda_o_hentai_geroe_iz_drugogo_mira',
        ),
        3,
      );
    });

    test('getLatestChapter reads the first row and its date', () async {
      final latest = await source().getLatestChapter(
        'legenda_o_hentai_geroe_iz_drugogo_mira',
      );
      expect(latest, isNotNull);
      expect(latest!.$1, 'Chapter 15.5');
      expect(latest.$2, DateTime(2026, 9, 21, 19, 43, 4, 582));
    });
  });

  group('the reader', () {
    test('rebuilds the page URLs from rm_h.readerInit and drops the signature',
        () async {
      final stub = source();
      final pages = await stub.getPageUrls(
        'legenda_o_hentai_geroe_iz_drugogo_mira/vol1/1.1',
      );
      expect(pages, hasLength(10));
      expect(
        pages.first,
        'https://sei.one-way.work/auto/44/86/53/1.webp',
      );
      expect(pages.last, 'https://sei.one-way.work/auto/44/86/53/10.webp');
      expect(stub.urls.single, endsWith('?mtr=true'));
    });

    test('a page without readerInit yields no pages', () async {
      final stub = _StubSei((url) => '<html>age gate</html>');
      expect(await stub.getPageUrls('slug/vol1/1'), isEmpty);
    });
  });

  group('the filter sheet', () {
    test('lists the catalogue genres', () async {
      final tags = await source().getAvailableTags();
      expect(tags, contains('исэкай'));
      expect(tags, contains('эротика'));
    });

    test('maps the filter onto element ids, status, year and sort', () async {
      final stub = source();
      await stub.searchWithFilter(
        const MangaFilter(
          sort: 'alphabetical',
          genres: ['дзёсэй'],
          status: ['finished'],
          yearFrom: 2018,
        ),
      );
      final url = stub.urls.last;
      expect(url, contains('includeElementIds=1349'));
      expect(url, contains('includeProductionStatuses=FINISHED'));
      expect(url, contains('years=2018,2026'));
      expect(url, contains('sortType=NAME'));
    });
  });
}
