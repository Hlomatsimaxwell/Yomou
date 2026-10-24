import '../models/madara_site_config.dart';
import 'madara_source.dart';

class ApollComicsSource extends MadaraSource {
  @override
  String get languageCode => 'es';
  ApollComicsSource()
      : super(
          const MadaraSiteConfig(
            id: 'apollcomics',
            name: 'Apoll Comics',
            baseUrl: 'https://apollcomics.es',
            language: 'Manga, Spanish',
            iconUrl: 'https://apollcomics.es/favicon.ico',
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
}
