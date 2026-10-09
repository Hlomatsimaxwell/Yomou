import '../models/madara_site_config.dart';
import 'madara_source.dart';

/// ManhuaPlus — a stock Madara/WordPress theme, so the shared Madara source
/// covers listing/search/detail/chapters. Two details are site-specific: card
/// covers arrive lazy-loaded through `data-src`, and the reader container is
/// `class="reading-content"` rather than the theme's usual `#reading-content`
/// id. The `.post-status` block lists Release before Status, which the shared
/// engine handles by reading the row labelled "Status".
class ManhuaPlusSource extends MadaraSource {
  ManhuaPlusSource()
      : super(
    const MadaraSiteConfig(
      id: 'manhuaplus',
      name: 'ManhuaPlus',
      baseUrl: 'https://manhuaplus.com',
      language: 'Manhua, English',
      iconUrl:
          'https://manhuaplus.com/wp-content/uploads/2020/07/cropped-manhua-vuong-den-1-192x192.jpg',
      popularPath: 'manga/?m_orderby=views',
      mangaCardSelector: '.page-item-detail',
      coverAttr: 'data-src',
      readerImageSelector: '.reading-content img',
    ),
  );
}
