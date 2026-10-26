import '../models/madara_site_config.dart';
import 'madara_source.dart';

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
}
