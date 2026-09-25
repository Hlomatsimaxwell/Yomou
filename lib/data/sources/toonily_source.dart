import '../models/madara_site_config.dart';
import 'madara_source.dart';

/// Toonily — a stock Madara/WordPress manga theme, so the shared Madara
/// source covers listing/search/detail/chapters. Reader images are
/// hotlink-protected, so the Referer header is advertised for image requests.
class ToonilySource extends MadaraSource {
  ToonilySource()
      : super(
    const MadaraSiteConfig(
      id: 'toonily',
      name: 'Toonily',
      baseUrl: 'https://toonily.com',
      language: 'Manhwa, Manhua, English',
      iconUrl: 'https://static.tnlycdn.com/2017/10/toonily_favicon2-300x300.png',
      popularPath: 'webtoons/?m_orderby=trending',
      searchPath: '?s={query}&post_type=wp-manga',
      mangaCardSelector: '.page-item-detail',
      imagesNeedReferer: true,
    ),
  );
}