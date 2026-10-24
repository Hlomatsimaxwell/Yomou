import '../models/madara_site_config.dart';
import 'madara_source.dart';
import 'webview_fetcher.dart';

/// BegaTranslation — assumes a stock Madara/WordPress theme like the majority
/// of Spanish sources. If the rendered HTML differs, the config here can be
/// tuned without touching the parser.
class BegaTranslationSource extends MadaraSource {
  BegaTranslationSource()
      : super(
          const MadaraSiteConfig(
            id: 'begatranslation',
            name: 'Bega Translation',
            baseUrl: 'https://begatranslation.com',
            language: 'Manga, Spanish',
            iconUrl: 'https://begatranslation.com/favicon.ico',
            popularPath: '?m_orderby=views',
            searchPath: '?s={query}&post_type=wp-manga',
            mangaCardSelector: '.page-item-detail',
            mangaTitleSelector: '.post-title a',
            mangaCoverSelector: 'img',
            coverAttr: 'data-src',
            detailDescriptionSelector: '.summary__content',
            detailAuthorsSelector: '.author-content a',
            detailGenresSelector: '.genres-content a',
            detailStatusSelector: '.post-status .summary-content',
            chapterListSelector: 'ul.main li.wp-manga-chapter, li.wp-manga-chapter',
            chapterLinkSelector: 'a',
            pageExtractor: MadaraPageExtractor.inline,
            readerImageSelector: '.wp-manga-chapter-img',
            readerImageAttr: 'data-src',
            imagesNeedReferer: false,
          ),
        );
  @override
  String get languageCode => 'es';

  @override
  Future<String> grabText(
    String url, {
    Map<String, String>? extraHeaders,
    bool useBaseUrl = true,
    bool saveCookies = false,
  }) async {
    try {
      return await WebViewFetcher.instance.render(url, sourceId: id);
    } catch (_) {
      return '';
    }
  }
}
