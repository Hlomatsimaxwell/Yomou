import 'dart:convert';
import 'package:html/parser.dart' as parser;
import '../models/madara_site_config.dart';
import '../models/manga.dart';
import 'madara_source.dart';
import 'source_network.dart';

class InfraFandubSource extends MadaraSource {
  @override
  String get languageCode => 'es';

  InfraFandubSource()
      : super(
          const MadaraSiteConfig(
            id: 'infrafandub',
            name: 'InfraFandub',
            baseUrl: 'https://infrafandub.com',
            language: 'Manga, Spanish',
            iconUrl: 'https://infrafandub.com/favicon.ico',
            popularPath: '?m_orderby=views',
            searchPath: '?s={query}&post_type=wp-manga',
            mangaCardSelector: '.manga-item',
            mangaTitleSelector: '.title a',
            mangaCoverSelector: 'img',
            coverAttr: 'src',
            detailDescriptionSelector: '.summary__content, .description-summary',
            detailAuthorsSelector: '.author-content a',
            detailGenresSelector: '.genres-content a',
            detailStatusSelector: '.manga-status',
            chapterListSelector: 'a.chapter-item',
            chapterLinkSelector: '',
            pageExtractor: MadaraPageExtractor.inline,
            readerImageSelector: '.wp-manga-chapter-img, img.wp-manga-chapter-img',
            readerImageAttr: 'data-src',
            imagesNeedReferer: false,
          ),
        );

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    if (query.isEmpty) return getPopularManga(page: page);
    try {
      final html = await postText(
        '$baseUrl/wp-admin/admin-ajax.php',
        rawBody: 'action=madara_custom_search&keyword=${Uri.encodeQueryComponent(query)}',
      );
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final mangas = <Manga>[];
      final seen = <String>{};
      for (final a in document.querySelectorAll('a[href*="/manga/"]')) {
        final href = a.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        final id = href.replaceFirst(baseUrl, '').replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/$'), '');
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        final img = a.querySelector('img');
        final cover = img?.attributes['src'] ?? '';
        final title = a.querySelector('span')?.text.trim() ?? a.text.trim();
        if (title.isEmpty) continue;
        mangas.add(Manga(id: id, title: title, coverUrl: cover, sourceId: this.id));
      }
      return mangas.isNotEmpty ? mangas : getPopularManga(page: page);
    } catch (_) {
      return getPopularManga(page: page);
    }
  }
}
