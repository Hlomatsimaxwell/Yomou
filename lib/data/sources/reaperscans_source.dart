import '../models/madara_site_config.dart';
import 'madara_source.dart';

/// Reaper Scans — a Madara/WordPress theme on top of Cloudflare. The site is
/// Cloudflare-fronted (some networks/time get a 522 challenge page, which the
/// shared source reports as an empty miss). Reader images are hotlink-
/// protected, hence the advertised Referer header.
class ReaperScansSource extends MadaraSource {
  ReaperScansSource()
      : super(
    const MadaraSiteConfig(
      id: 'reaperscans',
      name: 'Reaper Scans',
      baseUrl: 'https://reaperscans.com',
      language: 'Manhwa, Manhua, English',
      iconUrl: 'https://reaperscans.com/favicon.ico',
      mangaCardSelector: '.page-item-detail',
      imagesNeedReferer: true,
    ),
  );
}