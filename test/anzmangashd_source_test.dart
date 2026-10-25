import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/sources/anzmangashd_source.dart';

class _StubAnzMangasHd extends AnzMangasHdSource {
  _StubAnzMangasHd(this.respond);
  final String Function(String url) respond;

  @override
  Future<String> fetchHtml(String url) async => respond(url);
}

String _fixture(String name) =>
    File('test/fixtures/anzmangashd/$name').readAsStringSync();

void main() {
  final popular = _fixture('popular_manga.html');
  final detailsPage = _fixture('details.html');
  final chapterList = _fixture('chapter_list.html');
  final pageUrls = _fixture('page_urls.html');
  final searchResults = _fixture('search_results.json');

  group('AnzMangasHdSource - identity', () {
    test('has correct ID', () {
      final source = AnzMangasHdSource();
      expect(source.id, 'anzmangashd');
      expect(source.name, 'AnzMangasHd');
      expect(source.baseUrl, 'https://www.anzmanga25.com');
      expect(source.languageCode, 'es');
    });
  });

  group('AnzMangasHdSource - getPopularManga', () {
    test('parses the listing and drops repeated titles', () async {
      final source = _StubAnzMangasHd((url) => popular);
      final manga = await source.getPopularManga(page: 1);
      // The capture has three blocks but only two mangas.
      expect(manga, hasLength(2));
      expect(manga[0].id, 'blue-lock');
      expect(manga[0].title, 'Blue Lock');
      expect(manga[1].id, 'one-piece');
      expect(manga[1].title, 'One Piece');
    });

    test('guesses the cover path because the listing has no art', () async {
      final source = _StubAnzMangasHd((url) => popular);
      final manga = await source.getPopularManga();
      expect(
        manga[0].coverUrl,
        'https://www.anzmanga25.com/uploads/manga/blue-lock/cover/cover_250x350.jpg',
      );
    });

    test('returns an empty list when the page cannot be fetched', () async {
      final source = _StubAnzMangasHd((url) => '');
      expect(await source.getPopularManga(), isEmpty);
    });
  });

  group('AnzMangasHdSource - getMangaDetails', () {
    test('reads title, cover, summary and genres', () async {
      final source = _StubAnzMangasHd((url) => detailsPage);
      final parsed = await source.getMangaDetails('one-piece');
      expect(parsed, isNotNull);
      expect(parsed!.title, 'One Piece');
      expect(
        parsed.coverUrl,
        'https://www.anzmanga25.com/uploads/manga/one-piece/cover/cover_250x350.jpg',
      );
      expect(parsed.description, contains('Monkey D. Luffy'));
      expect(parsed.tags, ['Acción', 'Aventura', 'Shounen']);
    });
  });

  group('AnzMangasHdSource - getChapters', () {
    test('parses chapter number, title and date', () async {
      final source = _StubAnzMangasHd((url) => chapterList);
      final chapters = await source.getChapters('one-piece');
      expect(chapters, hasLength(3));
      expect(chapters[0].chapterNumber, '1196');
      expect(chapters[0].title, 'One Piece');
      expect(chapters[0].releaseDate, '15 Oct. 2026');
      // Absolute hrefs are stored as paths so the reader can rebuild them.
      expect(chapters[0].id, '/manga/one-piece/1196');
    });
  });

  group('AnzMangasHdSource - getPageUrls', () {
    test('skips the logo and placeholder, keeps scanning pages', () async {
      final source = _StubAnzMangasHd((url) => pageUrls);
      final urls = await source.getPageUrls('/manga/one-piece/954');
      expect(urls, hasLength(3));
      expect(urls[0], 'https://blogger.googleusercontent.com/img/b/one/page1.jpg');
      expect(urls[2], 'https://drive.google.com/uc?id=page3');
    });

    test('builds the chapter URL from a path id', () async {
      final requested = <String>[];
      final source = _StubAnzMangasHd((url) {
        requested.add(url);
        return pageUrls;
      });
      await source.getPageUrls('/manga/one-piece/954');
      expect(
        requested.single,
        'https://www.anzmanga25.com/manga/one-piece/954',
      );
    });
  });

  group('AnzMangasHdSource - searchByTitle', () {
    test('reads the JSON autocomplete payload', () async {
      final source = _StubAnzMangasHd((url) => searchResults);
      final manga = await source.searchByTitle('one', page: 1);
      expect(manga, hasLength(7));
      expect(manga[0].id, 'one-piece');
      expect(manga[0].title, 'One Piece');
      expect(
        manga[0].coverUrl,
        'https://www.anzmanga25.com/uploads/manga/one-piece/cover/cover_250x350.jpg',
      );
    });

    test('asks the autocomplete endpoint for the term', () async {
      final requested = <String>[];
      final source = _StubAnzMangasHd((url) {
        requested.add(url);
        return searchResults;
      });
      await source.searchByTitle('one piece');
      expect(requested.single, contains('query=one+piece'));
    });

    test('returns an empty list when nothing matches', () async {
      final source = _StubAnzMangasHd((url) => '{"suggestions":[]}');
      expect(await source.searchByTitle('zzzz'), isEmpty);
    });

    test('returns an empty list for a non-JSON body', () async {
      final source = _StubAnzMangasHd((url) => '<html>nope</html>');
      expect(await source.searchByTitle('one'), isEmpty);
    });

    test('returns an empty list for a blank query', () async {
      final source = _StubAnzMangasHd((url) => searchResults);
      expect(await source.searchByTitle('   '), isEmpty);
    });
  });
}
