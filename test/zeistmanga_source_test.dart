import 'package:flutter_test/flutter_test.dart';

import 'package:yomou/data/models/zeistmanga_site_config.dart';
import 'package:yomou/data/sources/zeistmanga_source.dart';

/// The generic ZeistManga engine is driven by config and parses Blogger JSON
/// plus several unrelated chapter/page markup variants, so the parsing is
/// pinned here without touching the network.
void main() {
  const config = ZeistMangaSiteConfig(
    id: '7487319247633385575',
    name: 'Comic Verse',
    baseUrl: 'https://arcomixverse.blogspot.com',
    langCode: 'ar',
  );
  final source = ZeistMangaSource(config);

  group('identity and feed URLs', () {
    test('uses the generated config for ids and URLs', () {
      expect(source.id, '7487319247633385575');
      expect(source.name, 'Comic Verse');
      expect(source.baseUrl, 'https://arcomixverse.blogspot.com');
      expect(source.languageCode, 'ar');
      expect(
        source.websiteMangaUrl('https://arcomixverse.blogspot.com/2026/01/x.html'),
        'https://arcomixverse.blogspot.com/2026/01/x.html',
      );
    });

    test('builds a Blogger feed with search and paging', () {
      expect(
        config.feedUrl('Series', maxResults: 21, startIndex: 21, query: 'One Piece'),
        contains('start-index=21'),
      );
      final uri = Uri.parse(
        config.feedUrl('Series', maxResults: 21, query: 'One Piece'),
      );
      expect(uri.queryParameters['alt'], 'json');
      expect(uri.queryParameters['max-results'], '21');
      expect(uri.queryParameters['q'], 'label:Series One Piece');
      expect(
        Uri.parse(config.feedUrl('O Fantasma Lamentoso', maxResults: 10)).path,
        contains('O%20Fantasma%20Lamentoso'),
      );
    });
  });

  group('parseFeed', () {
    test('reads title, alternate link and thumbnail, replacing the size token', () {
      const body = '''
{"feed":{"entry":[
 {"title":{"\$t":"Blue Lock"},"link":[
   {"rel":"self","href":"https://x/self"},
   {"rel":"alternate","href":"https://x/2026/01/blue-lock.html"}],
  "media\$thumbnail":{"url":"https://lh3.googleusercontent.com/-abc/s1600-c/photo.jpg"}},
 {"title":{"\$t":"One Piece"},"link":[
   {"rel":"alternate","href":"https://x/2026/01/one-piece.html"}],
  "content":{"\$t":"<div><img src='https://img.example/cover.jpg'/></div>"}}
]}}
''';
      final list = source.parseFeed(body);
      expect(list, hasLength(2));
      expect(list[0].id, 'https://x/2026/01/blue-lock.html');
      expect(list[0].title, 'Blue Lock');
      expect(list[0].coverUrl, 'https://lh3.googleusercontent.com/-abc/w600/photo.jpg');
      expect(list[1].coverUrl, 'https://img.example/cover.jpg');
      expect(list.every((m) => m.sourceId == config.id), isTrue);
    });

    test('returns nothing for junk, an empty feed or a missing entry list', () {
      expect(source.parseFeed('not json'), isEmpty);
      expect(source.parseFeed('{"feed":{}}'), isEmpty);
      expect(source.parseFeed('{}'), isEmpty);
    });
  });

  group('extractChapterLabel', () {
    test('recognises the script variants the theme uses', () {
      expect(
        source.extractChapterLabel("clwd.run('Chapter%20Blue%20Lock');"),
        'Chapter Blue Lock',
      );
      expect(
        source.extractChapterLabel("var label = 'Capitulos';"),
        'Capitulos',
      );
      expect(
        source.extractChapterLabel('label_chapter = "Episodes";'),
        'Episodes',
      );
      expect(
        source.extractChapterLabel(
          '<script src="/feeds/posts/default/-/Series?alt=json"></script>',
        ),
        'Series',
      );
      expect(source.extractChapterLabel('<html></html>'), isNull);
    });
  });

  group('parseChapterFeed', () {
    const body = '''
{"feed":{"entry":[
 {"title":{"\$t":"Chapter 2"},"published":{"\$t":"2026-03-02T10:00:00Z"},
  "link":[{"rel":"alternate","href":"https://x/2026/03/chapter-2.html"}]},
 {"title":{"\$t":"Chapter 1"},"published":{"\$t":"2026-03-01T10:00:00Z"},
  "link":[{"rel":"alternate","href":"https://x/2026/03/chapter-1.html"}]},
 {"title":{"\$t":"Blue Lock"},"published":{"\$t":"2026-01-01T10:00:00Z"},
  "link":[{"rel":"alternate","href":"https://x/2026/01/blue-lock.html"}]}
]}}
''';

    test('reverses Blogger order and skips the manga post itself', () {
      final chapters = source.parseChapterFeed(
        body,
        mangaId: 'https://arcomixverse.blogspot.com/2026/01/blue-lock.html',
      );
      expect(chapters, hasLength(2));
      expect(chapters[0].title, 'Chapter 1');
      expect(chapters[0].chapterNumber, '1');
      expect(chapters[0].releaseDate, '2026-03-01');
      expect(chapters[1].title, 'Chapter 2');
      expect(chapters[1].chapterNumber, '2');
    });
  });

  group('parsePageImages', () {
    test('reads the plain chapterImage array', () {
      const html = '<script>var chapterImage = ["https://img/1.jpg",'
          '"https://img/2.jpg"];</script>';
      expect(source.parsePageImages(html), [
        'https://img/1.jpg',
        'https://img/2.jpg',
      ]);
    });

    test('reads the UlasComic config array', () {
      const html = """<script>config['chapterImage'] = ["https://img/a.jpg",\n"""
          """"https://img/b.jpg"];</script>""";
      expect(source.parsePageImages(html), [
        'https://img/a.jpg',
        'https://img/b.jpg',
      ]);
    });

    test('reads the escaped template form', () {
      final html = r'''<script>const content = `<img src\x3d\x22https://img/x.jpg\x22>`;</script>''';
      expect(source.parsePageImages(html), ['https://img/x.jpg']);
    });

    test('falls back to markup with the configured selector', () {
      final custom = ZeistMangaSource(
        const ZeistMangaSiteConfig(
          id: 'x',
          name: 'X',
          baseUrl: 'https://x.example',
          pageSelector: '#reader div.separator img',
        ),
      );
      const html = '''
<div id="reader"><div class="separator">
  <img src="https://img/one.jpg">
  <img data-src="https://img/two.jpg">
</div></div>
<div class="post-body"><img src="https://img/not-a-page.jpg"></div>
''';
      expect(custom.parsePageImages(html), [
        'https://img/one.jpg',
        'https://img/two.jpg',
      ]);
    });
  });
}
