/// Buildable/parseable deep links that re-open a manga inside Yomou:
///
/// `yomou://manga?source=<sourceId>&id=<mangaId>&name=<title>&url=<website page>`
///
/// The custom `yomou` scheme is registered as a VIEW target on Android, so
/// sharing this link lets anyone with Yomou installed open the manga straight
/// from the system "open with" chooser. The params mirror the fields a
/// Kotatsu-style share link carries: which source the manga came from, the
/// manga's id in that source, a display name, and the source's website page.
library;

class YomouMangaLink {
  final String sourceId;
  final String mangaId;
  final String title;
  final String websiteUrl;

  const YomouMangaLink({
    required this.sourceId,
    required this.mangaId,
    this.title = '',
    this.websiteUrl = '',
  });

  /// Parses a `yomou://manga` link, or returns null when the string is not
  /// one (wrong scheme, wrong host, or a missing source/id).
  static YomouMangaLink? tryParse(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'yomou' || uri.host != 'manga') {
      return null;
    }
    final sourceId = uri.queryParameters['source'] ?? '';
    final mangaId = uri.queryParameters['id'] ?? '';
    if (sourceId.isEmpty || mangaId.isEmpty) return null;
    return YomouMangaLink(
      sourceId: sourceId,
      mangaId: mangaId,
      title: uri.queryParameters['name'] ?? '',
      websiteUrl: uri.queryParameters['url'] ?? '',
    );
  }

  @override
  String toString() => '#<YomouMangaLink $sourceId/$mangaId>';
}

/// Builds the shareable deep link for a manga: which source it lives in, its
/// id there, its display title, and the source's website page it came from.
String buildYomouMangaLink({
  required String sourceId,
  required String mangaId,
  String title = '',
  String websiteUrl = '',
}) {
  final query = Uri(queryParameters: {
    'source': sourceId,
    'id': mangaId,
    if (title.isNotEmpty) 'name': title,
    if (websiteUrl.isNotEmpty) 'url': websiteUrl,
  });
  return 'yomou://manga$query';
}

/// The https landing page that forwards into the app (see docs/yomou.html).
///
/// Chat apps only linkify http(s) URLs, so the raw `yomou://` link is dead
/// text on WhatsApp/SMS/Gmail. This page is the tappable front door: it is
/// hosted (any static host; the default is GitHub Pages from this repo's
/// /docs folder) and carries the real link, encoded, in its `u` query param.
const String yomouShareBaseUrl =
    'https://hlomatsimaxwell.github.io/Yomou/yomou.html';

/// The string the share sheet copies for "Link to manga in Yomou": an https
/// URL that renders as a tappable link everywhere, and opens the manga in the
/// app when tapped (through the landing page above).
String buildYomouShareLink({
  required String sourceId,
  required String mangaId,
  String title = '',
  String websiteUrl = '',
}) {
  final deep = buildYomouMangaLink(
    sourceId: sourceId,
    mangaId: mangaId,
    title: title,
    websiteUrl: websiteUrl,
  );
  return '$yomouShareBaseUrl?u=${Uri.encodeComponent(deep)}';
}
