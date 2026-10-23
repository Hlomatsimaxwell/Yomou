/// The per-host referer the CDNs behind hotlink-protected sources demand.
///
/// Shared by the cover/image widget ([CachedMangaImage]) and the notification
/// large-icon fetch ([NotificationImage.bytesFor]): a cover that answers 403
/// to a bare request still has to come through when a notification needs it.
/// Recorded pairs map a cover host (or a rotating-host path prefix) to the
/// referer that host returns 200 for; see the source tests asserting them
/// against captured markup.
class ImageReferer {
  const ImageReferer._();

  /// CDN host suffix -> the referer that host expects.
  static const Map<String, String> byHost = {
    'mangahere.com': 'https://www.mangatown.com/',
    'mangahere.org': 'https://www.mangatown.com/',
    'comicknew.pictures': 'https://comick.live/',
    'comick.pictures': 'https://comick.live/',
    'likemanga.ink': 'https://likemanga.ink/',
    'mgread.io': 'https://likemanga.ink/',
    'arenascan.com': 'https://arenascan.com/',
    'asurascans.com': 'https://asurascans.com/',
    '2xstorage.com': 'https://www.manganato.gg/',
    'waitst.com': 'https://www.manganato.gg/',
    'mgeko.cc': 'https://www.mgeko.cc/',
    'imgsrv4.com': 'https://www.mgeko.cc/',
    'imgsrv5.com': 'https://www.mgeko.cc/',
    // MangaPill serves every cover through this one CDN, which 403s on a
    // missing referer and 200s for the site root.
    'readdetectiveconan.com': 'https://mangapill.com/',
    // SeiManga keeps both its covers and its scans on this host, which 403s on
    // a missing or foreign referer and 200s when the mirror is sent.
    'sei.one-way.work': 'https://1.seimanga.me/',
  };

  /// Path prefix -> the referer that host expects, for sources whose image host
  /// rotates and so cannot be listed by name.
  ///
  /// MangaBall serves its page images from a different subdomain per crawl -
  /// `bulbasaur.poke-black-and-white.net`, `chikorita.red-and-blue.net` and
  /// others - and they are all hotlink-protected: the same URL answers 403 with
  /// no referer or a foreign one, and 200 only for `https://mangaball.com/`.
  /// Every one of them serves the same `/storage/<id>/0/<n>/<site>/<lang>/`
  /// path, so the path is what identifies them. Matching on the host instead
  /// meant listing hosts that stop working the next time the site is crawled.
  ///
  /// The leading slash is what keeps `2xstorage.com` out of this: that host
  /// matches a name, never a `/storage/` path.
  static const Map<String, String> byPath = {
    '/storage/': 'https://mangaball.com/',
  };

  /// The referer [uri]'s host expects, or null when it needs none.
  static String? refererFor(Uri uri) {
    for (final entry in byHost.entries) {
      if (uri.host == entry.key || uri.host.endsWith('.${entry.key}')) {
        return entry.value;
      }
    }
    for (final entry in byPath.entries) {
      if (uri.path.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }
}
