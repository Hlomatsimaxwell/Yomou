import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yomou/data/models/gigaviewer_site_config.dart';
import 'package:yomou/data/sources/giga_scramble.dart';
import 'package:yomou/data/sources/gigaviewer_source.dart';

/// The generic GigaViewer engine is config-driven and talks a GraphQL API, so
/// its parsing is pinned here with the response shapes captured from a live
/// site — no network access in the test.
void main() {
  const config = GigaViewerSiteConfig(
    id: '3399001455113605946',
    name: 'Comic Action',
    baseUrl: 'https://comic-action.com',
    seriesListIds: ['14079602755641808866'],
  );
  final source = GigaViewerSource(config);

  group('identity and GraphQL ids', () {
    test('uses the generated config for ids and URLs', () {
      expect(source.id, config.id);
      expect(source.name, 'Comic Action');
      expect(source.baseUrl, 'https://comic-action.com');
      expect(source.languageCode, 'ja');
      expect(config.apiPath, '/graphql');
    });

    test('encodes serial groups and genres as base64 node ids', () {
      expect(
        utf8.decode(base64.decode(GigaViewerSiteConfig.nodeId('12345'))),
        'SerialGroup:12345',
      );
      expect(
        utf8.decode(
          base64.decode(GigaViewerSiteConfig.nodeId('Genre:3269754496379892693')),
        ),
        'Genre:3269754496379892693',
      );
    });

    test('opens an episode permalink from the listing in a browser', () {
      source.parseSeriesListResponse({
        'id0': {
          'series': {
            'edges': [
              {
                'node': {
                  'databaseId': '12207421984154631284',
                  'title': 'サイクル',
                  'thumbnailUri': 'https://cdn.example/cover.jpg',
                  'firstEpisode': {
                    'permalink': 'https://comic-action.com/episode/12207421984156738902',
                  },
                  'likeCount': 1162,
                },
              },
            ],
          },
        },
      });
      expect(
        source.websiteMangaUrl('12207421984154631284'),
        'https://comic-action.com/episode/12207421984156738902',
      );
    });
  });

  group('parseSeriesListResponse', () {
    const payload = '''
{
  "id0": {"series": {"edges": [
    {"node": {"databaseId": "111", "title": "A", "thumbnailUri": "https://cdn/a.jpg",
      "firstEpisode": {"permalink": "https://comic-action.com/episode/1"},
      "likeCount": 10, "latestEpisode": {"publishedAt": "2026-11-01T03:00:00Z"}}},
    {"node": {"databaseId": "222", "title": "B", "thumbnailUri": null,
      "latestVolume": {"thumbnailUri": "https://cdn/b.jpg"},
      "firstVolume": {"permalink": "https://comic-action.com/volume/2"},
      "likeCount": 30, "latestEpisode": {"publishedAt": "2026-11-20T03:00:00Z"}}}
  ]}},
  "id1": {"series": {"edges": [
    {"node": {"databaseId": "111", "title": "A", "thumbnailUri": "https://cdn/a.jpg",
      "firstEpisode": {"permalink": "https://comic-action.com/episode/1"}, "likeCount": 10}}
  ]}}
}
''';

    test('reads titles, covers and permalinks, de-duplicating groups', () {
      final rows = source.parseSeriesListResponse(jsonDecode(payload));
      expect(rows, hasLength(2));
      expect(rows.first.id, '111');
      expect(rows.first.title, 'A');
      expect(rows.first.coverUrl, 'https://cdn/a.jpg');
      expect(rows.last.coverUrl, 'https://cdn/b.jpg');
      expect(rows.every((m) => m.sourceId == config.id), isTrue);
      expect(source.websiteMangaUrl('222'),
          'https://comic-action.com/volume/2');
    });

    test('survives empty and malformed responses', () {
      expect(source.parseSeriesListResponse(null), isEmpty);
      expect(source.parseSeriesListResponse({}), isEmpty);
      expect(source.parseSeriesListResponse({'id0': null}), isEmpty);
    });
  });

  group('parseSeriesDetails', () {
    const payload = '''
{"data":{"series":{
  "databaseId":"12207421984154631284",
  "title":"サイクル",
  "author":{"name":"あすかむ"},
  "description":"高校二年の秋。",
  "thumbnailUri":"https://cdn-img.comic-action.com/public/series-thumbnail/x",
  "firstEpisode":{"permalink":"https://comic-action.com/episode/12207421984156738902"},
  "firstVolume":null,
  "latestVolume":null,
  "episodes":{"totalCount":5},
  "volumes":{"totalCount":0}
}}}
''';

    test('reads author, description, cover and total chapter count', () {
      final details = source.parseSeriesDetails(
        (jsonDecode(payload) as Map)['data'] as Map<String, dynamic>,
      )!;
      expect(details.id, '12207421984154631284');
      expect(details.title, 'サイクル');
      expect(details.author, 'あすかむ');
      expect(details.description, contains('高校二年'));
      expect(details.coverUrl, contains('cdn-img.comic-action.com'));
      expect(details.totalChapters, 5);
      expect(details.language, 'ja');
      expect(details.sourceId, config.id);
      expect(
        details.publicUrl,
        'https://comic-action.com/episode/12207421984156738902',
      );
    });

    test('returns null when the site has no such series', () {
      expect(source.parseSeriesDetails({'series': null}), isNull);
    });
  });

  group('parseProducts', () {
    const payload = '''
[
 {"readable_product_id":"5","title":"第5話","viewer_uri":"https://comic-action.com/episode/5",
  "display_open_at":"2026-10-20T03:00:00Z","status":{"label":"is_free"},
  "purchase_info":{"can_read":true,"unavailable":false}},
 {"readable_product_id":"4","title":"第4話","viewer_uri":"https://comic-action.com/episode/4",
  "display_open_at":"2026-10-06T03:00:00Z","status":{"label":"is_free"},
  "purchase_info":{"can_read":false,"unavailable":false}},
 {"readable_product_id":"1","title":"第1巻","viewer_uri":"https://comic-action.com/volume/1",
  "display_open_at":null,"status":{"label":"show"},
  "purchase_info":{"can_read":true,"unavailable":true}}
]
''';

    test('reads ids, numbers, dates and access prefixes', () {
      final chapters = source.parseProducts(payload);
      expect(chapters, hasLength(3));
      expect(chapters[0].id, 'episode:5');
      expect(chapters[0].chapterNumber, '5');
      expect(chapters[0].releaseDate, '2026-10-20');
      expect(chapters[0].title, '第5話');
      expect(chapters[1].title, startsWith('💴 '));
      expect(chapters[2].id, 'volume:1');
      expect(chapters[2].title, startsWith('🔒 (Volume) '));
      expect(chapters[2].releaseDate, '');
    });

    test('Zenon treats a missing status as unavailable', () {
      const closed = '''
[{"readable_product_id":"9","title":"第9話","viewer_uri":"https://x/episode/9",
   "purchase_info":{"can_read":true,"unavailable":false}}]
''';
      expect(source.parseProducts(closed).first.title, '第9話');
      expect(
        source.parseProducts(closed, statusNullUnavailable: true).first.title,
        startsWith('🔒 '),
      );
    });

    test('survives junk', () {
      expect(source.parseProducts(''), isEmpty);
      expect(source.parseProducts('{}'), isEmpty);
      expect(source.parseProducts('not json'), isEmpty);
    });
  });

  group('parsePages', () {
    // The site HTML-escapes the JSON in the data-value attribute; package:html
    // unescapes it before we see it.
    const html = '''
<html><body>
<script class='js-valve' data-giga_series='42'></script>
<script id='episode-json' type='text/json' data-value='{&quot;readableProduct&quot;:{&quot;pageStructure&quot;:{&quot;choJuGiga&quot;:&quot;baku&quot;,&quot;pages&quot;:[{&quot;type&quot;:&quot;other&quot;,&quot;hide&quot;:&quot;spread&quot;},{&quot;type&quot;:&quot;link&quot;,&quot;linkPosition&quot;:&quot;front&quot;},{&quot;type&quot;:&quot;main&quot;,&quot;src&quot;:&quot;https://cdn.example/1.jpg&quot;},{&quot;type&quot;:&quot;main&quot;,&quot;src&quot;:&quot;https://cdn.example/2.jpg&quot;}]}}}'></script>
</body></html>
''';

    test('keeps only main pages and marks scrambled ones', () {
      expect(source.parsePages(html), [
        'https://cdn.example/1.jpg#scramble',
        'https://cdn.example/2.jpg#scramble',
      ]);
    });

    test('leaves unscrambled pages untouched', () {
      final plain = html.replaceFirst('&quot;baku&quot;', '&quot;nomal&quot;');
      expect(source.parsePages(plain), [
        'https://cdn.example/1.jpg',
        'https://cdn.example/2.jpg',
      ]);
    });

    test('returns nothing for a locked chapter', () {
      expect(source.parsePages('<html></html>'), isEmpty);
      expect(
        source.parsePages(
          "<script id='episode-json' data-value='{\"readableProduct\":{}}'></script>",
        ),
        isEmpty,
      );
    });
  });

  group('parseHtmlSeries', () {
    // Comic Border publishes its front page as server-rendered sections;
    // Shonen Jump+ uses a weekday schedule of plain anchors.
    const borderHtml = '''
<section class="top-series">
  <div class="top-key-image" data-src="https://cdn.example/cover.jpg"></div>
  <h3>最底辺の少女は龍神の最愛花嫁</h3>
  <ul class="top-series-nav"><li class="this-episode">
    <a href="https://comicborder.com/episode/12207421984285213350">この話を読む！</a>
  </li></ul>
</section>
<section class="top-series">
  <div class="top-key-image" data-src="https://cdn.example/cover2.jpg"></div>
  <h3>鬼役</h3>
  <ul class="top-series-nav"><li class="first-episode">
    <a href="https://comicborder.com/episode/222">この話を読む！</a>
  </li></ul>
</section>
''';

    test('reads comic border sections with nested links and background covers', () {
      final rows = source.parseHtmlSeries(
        borderHtml,
        'section.top-series',
        'h3',
        linkSelector: 'li.first-episode a, li.this-episode a',
        coverSelector: '.top-key-image',
      );
      expect(rows, hasLength(2));
      expect(rows.first.title, '最底辺の少女は龍神の最愛花嫁');
      expect(rows.first.coverUrl, 'https://cdn.example/cover.jpg');
      expect(rows.first.id, '/episode/12207421984285213350');
      expect(
        source.websiteMangaUrl(rows.first.id),
        'https://comicborder.com/episode/12207421984285213350',
      );
    });

    test('reads plain anchor lists and de-duplicates repeated links', () {
      const html = '''
<ul class="series-list">
  <li><a href="/series/1"><h2 class="series-list-title">A</h2>
    <img src="/cover-a.jpg"></a></li>
  <li><a href="/series/1"><h2 class="series-list-title">A</h2></a></li>
  <li><a href="/series/2"><h2 class="series-list-title">B</h2>
    <img data-src="//cdn.example/b.jpg"></a></li>
</ul>
''';
      final rows = source.parseHtmlSeries(
        html,
        'ul.series-list li a',
        'h2.series-list-title',
      );
      expect(rows, hasLength(2));
      expect(rows.first.coverUrl, 'https://comic-action.com/cover-a.jpg');
      expect(rows.last.coverUrl, 'https://cdn.example/b.jpg');
    });
  });

  group('GigaScramble', () {
    test('recognises the reader fragment', () {
      expect(GigaScramble.isScrambledUrl('https://cdn/a.jpg#scramble'), isTrue);
      expect(GigaScramble.isScrambledUrl('https://cdn/a.jpg'), isFalse);
    });

    test('the 4x4 tile shuffle is an involution', () {
      const width = 208;
      const height = 300;
      final original = img.Image(width: width, height: height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          original.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
        }
      }
      final bytes = img.encodePng(original);
      final reference = original.convert(numChannels: 4);
      final once = GigaScramble.unscramble(bytes)!;
      final twice = img.decodeImage(GigaScramble.unscramble(once)!)!;
      expect(twice.width, width);
      expect(twice.height, height);
      for (final (x, y) in [(0, 0), (100, 40), (207, 299), (17, 250)]) {
        expect(twice.getPixel(x, y), reference.getPixel(x, y));
      }
    });
  });
}
