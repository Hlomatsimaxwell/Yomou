import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/models/manga_filter.dart';
import 'package:yomou/data/sources/atsumoe_source.dart';

/// Atsumaru is a React SPA over a same-origin JSON API that answers plain
/// HTTP, so these tests pin the parsing against trimmed captures of the real
/// answers:
///
/// - the Typesense listing/search response (`hits[].document`),
/// - `/api/manga/page?id=` with the poster, authors, genres and newest rows,
/// - `/api/manga/info?mangaId=` with the full per-scanlator chapter list,
/// - `/api/read/chapter?...` with the page images,
/// - `/api/explore/availableFilters` with the genre list.
class _StubAtsu extends AtsuMoeSource {
  _StubAtsu(this.respond);

  final String Function(String url) respond;

  /// Every URL the source asked for, so the tests can pin the query it built.
  final List<String> urls = [];

  @override
  Future<String> grabText(
    String url, {
    Map<String, String>? extraHeaders,
    bool useBaseUrl = true,
    bool saveCookies = false,
  }) async {
    urls.add(url);
    return respond(url);
  }
}

String _fixture(String name) =>
    File('test/fixtures/atsumoe/$name.json').readAsStringSync();

void main() {
  final search = _fixture('search');
  final detail = _fixture('detail');
  final info = _fixture('info');
  final chapter = _fixture('chapter');
  final filters = _fixture('filters');

  _StubAtsu source() => _StubAtsu((url) {
        if (url.contains('/api/manga/page')) return detail;
        if (url.contains('/api/manga/info')) return info;
        if (url.contains('/api/read/chapter')) return chapter;
        if (url.contains('/api/explore/availableFilters')) return filters;
        if (url.contains('/collections/manga/documents/search')) return search;
        return '';
      });

  test('identifies as the atsumaru source', () {
    final s = AtsuMoeSource();
    expect(s.id, 'atsu');
    expect(s.name, 'Atsumaru');
    expect(s.baseUrl, 'https://atsu.moe');
  });

  group('the popular listing', () {
    test('parses the hits and serves covers from the CDN', () async {
      final mangas = await source().getPopularManga();
      expect(mangas, hasLength(3));
      expect(mangas.first.id, '2VgNt');
      expect(mangas.first.title, 'Witch Hat Atelier');
      expect(
        mangas.first.coverUrl,
        'https://cdn.atsu.moe/static/posters/N3HO30V76uWZV9iG.jpg',
      );
      for (final manga in mangas) {
        expect(manga.sourceId, 'atsu');
        expect(manga.coverUrl, startsWith('https://cdn.atsu.moe/'));
      }
    });

    test('asks the JSON API with the listing query', () async {
      final stub = source();
      await stub.getPopularManga(page: 2);
      expect(stub.urls.single, contains('/collections/manga/documents/search?'));
      expect(stub.urls.single, contains('q=*'));
      expect(stub.urls.single, contains('page=2'));
    });
  });

  group('search', () {
    test('sends the term as the query and parses the hits', () async {
      final stub = source();
      final mangas = await stub.searchByTitle('witch hat');
      expect(mangas, hasLength(3));
      expect(mangas.first.id, '2VgNt');
      expect(stub.urls.single, contains('q=witch%20hat'));
    });

    test('a blank term is never sent', () async {
      final stub = source();
      expect(await stub.searchByTitle('   '), isEmpty);
      expect(stub.urls, isEmpty);
    });
  });

  group('details', () {
    test('parses the page, dedupes authors and maps the poster', () async {
      final details = await source().getMangaDetails('2VgNt');
      expect(details, isNotNull);
      expect(details!.title, 'Witch Hat Atelier');
      expect(details.author, 'Kamome Shirahama');
      expect(details.status, 'ongoing');
      expect(details.year, '2016');
      expect(details.totalChapters, 99);
      expect(details.language, 'en');
      expect(details.tags, contains('Adventure'));
      expect(
        details.coverUrl,
        'https://cdn.atsu.moe/static/posters/N3HO30V76uWZV9iG.jpg',
      );
      expect(details.description, contains('Coco'));
    });
  });

  group('chapters', () {
    test('dedupes the scanlator rows to distinct chapter numbers', () async {
      final chapters = await source().getChapters('2VgNt');
      expect(chapters, hasLength(4));
      expect(chapters.first.id, '2VgNt/vJly4Skj');
      expect(chapters.first.chapterNumber, '1');
      expect(chapters.first.url, 'https://atsu.moe/read/2VgNt/vJly4Skj');
      expect(chapters.map((c) => c.chapterNumber), ['1', '2', '3', '4']);
    });

    test('getTotalChapters counts the deduped rows', () async {
      expect(await source().getTotalChapters('2VgNt'), 4);
    });
  });

  group('the reader', () {
    test('splits the packed id and maps the page images to the CDN',
        () async {
      final stub = source();
      final pages = await stub.getPageUrls('2VgNt/mzO0tF');
      expect(pages, hasLength(3));
      expect(
        pages.first,
        'https://cdn.atsu.moe/static/pages/mzO0tF/0.webp',
      );
      expect(stub.urls.single, contains('mangaId=2VgNt'));
      expect(stub.urls.single, contains('chapterId=mzO0tF'));
    });

    test('a chapter id without a manga id yields no pages', () async {
      final stub = source();
      expect(await stub.getPageUrls('mzO0tF'), isEmpty);
      expect(stub.urls, isEmpty);
    });
  });

  test('getLatestChapter reads the newest row and its date', () async {
    final latest = await source().getLatestChapter('2VgNt');
    expect(latest, isNotNull);
    expect(latest!.$1, 'Chapter 99');
    expect(latest.$2.year, 2026);
  });

  group('the filter sheet', () {
    test('lists the genres it can filter on', () async {
      final tags = await source().getAvailableTags();
      expect(tags, ['Adventure', 'Comedy', 'Action']);
    });

    test('maps the filter onto genre ids, status, year and sort', () async {
      final stub = source();
      await stub.searchWithFilter(
        const MangaFilter(
          sort: 'alphabetical',
          genres: ['Adventure'],
          status: ['finished'],
          yearFrom: 2020,
        ),
      );
      final url = stub.urls.last;
      expect(url, contains('genreIds%3A%3D%5B37%5D'));
      expect(url, contains('status%3A%3D%5BCompleted%5D'));
      expect(url, contains('year%3A%3E%3D2020'));
      expect(url, contains('sort_by=title%3Aasc'));
    });
  });
}
