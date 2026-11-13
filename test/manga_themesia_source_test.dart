import 'package:flutter_test/flutter_test.dart';

import 'package:yomou/data/models/manga_themesia_site_config.dart';
import 'package:yomou/data/sources/manga_themesia_source.dart';

/// The generic engine is driven by per-site config and parses untyped HTML, so
/// these tests pin the bugs that surfaced on real themed sites.
void main() {
  final source = MangaThemesiaSource(
    const MangaThemesiaSiteConfig(
      id: 'example',
      name: 'Example',
      baseUrl: 'https://example.com',
      mangaUrlDirectory: '/manga',
    ),
  );

  group('searchMangaParse covers', () {
    test('takes the cover, not the language-flag image before it', () {
      const html = '''
<div class="listupd"><div class="bs"><div class="bsx">
  <a href="https://example.com/manga/foo/" title="Foo">
    <div class="limit">
      <img src="https://example.com/flags/jp.svg" alt="Japanese">
      <img class="ts-post-image wp-post-image"
           src="https://example.com/uploads/foo.jpg" alt="Foo">
    </div>
  </a>
</div></div></div>
''';
      final list = source.searchMangaParse(
        html,
        pageUrl: 'https://example.com/manga/?page=1',
      );
      expect(list, hasLength(1));
      expect(list.single.id, 'manga/foo');
      expect(list.single.coverUrl, 'https://example.com/uploads/foo.jpg');
    });
  });

  group('searchMangaParse past the last page', () {
    test('returns nothing when the theme says there are no posts', () {
      // WordPress renders a normal page for an out-of-range page number: an
      // empty result list plus the sidebar's popular-series links. Those links
      // look like cards, so the fallback scan used to repeat them forever.
      const html = '''
<div class="listupd">
  <center class="noresult">-- No se encontraron publicaciones --</center>
</div>
<div id="sidebar">
  <a href="https://example.com/manga/list-mode">Vista de texto</a>
  <a href="https://example.com/manga/popular-one" title="Popular One">Popular</a>
</div>
''';
      final list = source.searchMangaParse(
        html,
        pageUrl: 'https://example.com/manga/?page=3',
      );
      expect(list, isEmpty);
    });
  });

  group('chapterListParse numbers', () {
    String numberFor(String title, String href) {
      final html = '''
<div class="bxcl"><ul><li><div class="chbox"><div class="eph-num">
  <a href="$href"><span class="chapternum">$title</span></a>
</div></div></li></ul></div>
''';
      return source.chapterListParse(html).single.chapterNumber;
    }

    test('parses Thai, Japanese and Korean markers', () {
      expect(
        numberFor(
          'ตอนที่ 214 (ตอนจบ)',
          'https://example.com/manga/foo-214/',
        ),
        '214',
      );
      expect(
        numberFor('第 87 話', 'https://example.com/manga/foo-87/'),
        '87',
      );
      expect(
        numberFor('214화', 'https://example.com/manga/foo-214/'),
        '214',
      );
    });

    test('falls back to the trailing number in custom-skin slugs', () {
      expect(
        numberFor(
          'Volume 30',
          'https://example.com/sawako-volume-30/',
        ),
        '30',
      );
    });
  });
}
