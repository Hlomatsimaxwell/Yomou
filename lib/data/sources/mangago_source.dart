import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'captcha_gate.dart';
import 'date_parse.dart';
import 'mangago_cipher.dart';
import 'source_network.dart';
import 'webview_fetcher.dart';

/// Mangago — mangago.me.
///
/// Grid, search and detail pages are plain HTML; the reader page hides its
/// page-image list in an encrypted `var imgsrcs = '...'` payload (decoded by
/// [MangagoCipher]), and the actual images live on
/// `i(N|web_N).mangapicgallery.com`, which require a Mangago referer (sent
/// via [headers]).
///
/// The whole site sits behind a Cloudflare managed challenge that a plain
/// `dio` request cannot pass (its TLS fingerprint is not a browser's), so
/// every fetch goes through [_page]: it tries the cheap HTTP path first and
/// renders the page in the hidden [WebViewFetcher] WebView when that comes
/// back as a challenge or without the expected markup. The WebView solves the
/// challenge itself, and its clearance cookies are stored per source for the
/// cheaper path to reuse.
///
/// Card URLs are `read-manga/<slug>/`; chapter URLs add the host bucket and
/// chapter name: `read-manga/<slug>/<host>/<chapter>/pg-1/`. The ids keep the
/// full path after `read-manga/` so [getPageUrls] can rebuild the reader URL
/// without storing extra state.
class MangagoSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'mangago';
  @override
  String get name => 'Mangago';
  @override
  String get baseUrl => 'https://www.mangago.me';
  @override
  String get readerBaseUrl => 'https://www.mangago.me';
  @override
  String get iconUrl => 'https://www.mangago.me/favicon.ico';

  @override
  Map<String, String>? get headers => {
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*',
  };

  /// Mangago keys its reader layout on the user agent: the desktop identity
  /// gets the chapter's whole page list in `imgsrcs`, while the mobile one gets
  /// a paginated view carrying only the first five images. The parser handles
  /// the desktop markup (chapter table rows with `h4 a.chico`), so every fetch
  /// asks the hidden WebView for that identity.
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Fetches a page, rendering it in the hidden WebView when the plain request
  /// is challenged or does not carry [expect].
  ///
  /// The site is fronted by a Cloudflare managed challenge that answers a
  /// `dio` request (and any non-browser TLS fingerprint) with a 403 whether or
  /// not a clearance cookie is sent, so the cheap path is only good once the
  /// WebView has earned a session Cloudflare accepts. When that fails the
  /// page is rendered by a real browser engine, which solves the challenge on
  /// its own.
  ///
  /// [expect] is a substring the finished page must contain (a card class, the
  /// chapter table, the reader payload). A challenge page never contains it,
  /// so a miss routes to the WebView rather than being parsed as "no results".
  ///
  /// A challenge that survives the render is rethrown: that is a real captcha
  /// the user has to clear, not a miss the caller may swallow.
  Future<String> _page(String url, {required String expect}) async {
    var plain = '';
    try {
      plain = await grabText(url);
      if (plain.contains(expect)) return plain;
    } on CaptchaRequiredException {
      // Fall through to the WebView, which can solve it.
    } catch (e) {
      debugPrint('[mangago] plain fetch failed for $url: $e');
    }

    try {
      final rendered = await WebViewFetcher.instance.render(
        url,
        sourceId: id,
        expected: expect,
        userAgent: _desktopUserAgent,
      );
      if (rendered.contains(expect)) return rendered;
      // A partially rendered page still beats the challenge body.
      if (rendered.isNotEmpty) return rendered;
    } on CaptchaRequiredException {
      rethrow;
    } catch (e) {
      debugPrint('[mangago] render failed for $url: $e');
    }
    return plain;
  }

  /// The manga slug from a card href: everything after `read-manga/`, minus
  /// the trailing slash (`read-manga/a_dragon_s_love/` -> `a_dragon_s_love`).
  static String idFromHref(String href) {
    const marker = '/read-manga/';
    final i = href.indexOf(marker);
    if (i < 0) return href.replaceAll(RegExp(r'^/+'), '');
    final rest = href.substring(i + marker.length);
    return rest.replaceAll(RegExp(r'^/+|/+$'), '');
  }

  /// The card grid shared by the home list and the search results: both list
  /// their titles as `a.thm-effect` links to `read-manga/<slug>/`, with the
  /// cover on the image inside (lazy-loaded lists carry it in `data-src`).
  List<Manga> _parseCards(String html) {
    final document = parser.parse(html);
    final result = <Manga>[];
    final seen = <String>{};
    for (final a in document.querySelectorAll('a.thm-effect')) {
      final href = a.attributes['href'] ?? '';
      if (!href.contains('/read-manga/')) continue;
      final id = idFromHref(href);
      if (id.isEmpty || seen.contains(id)) continue;
      final title = (a.attributes['title'] ?? '').trim();
      if (title.isEmpty) continue;
      final img = a.querySelector('img');
      final cover = img?.attributes['data-src'] ??
          img?.attributes['src'] ??
          '';
      seen.add(id);
      result.add(
        Manga(id: id, title: title, coverUrl: cover, sourceId: this.id),
      );
    }
    return result;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final html = await _page(
        '$baseUrl/list/hot-manga/?page=$page',
        expect: 'thm-effect',
      );
      if (html.isEmpty) return [];
      return _parseCards(html);
    } on CaptchaRequiredException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      final q = Uri.encodeQueryComponent(query.trim());
      if (q.isEmpty) return [];
      final html = await _page(
        '$baseUrl/r/l_search/?name=$q&page=$page',
        expect: 'thm-effect',
      );
      if (html.isEmpty) return [];
      return _parseCards(html);
    } on CaptchaRequiredException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await _page(
        '$baseUrl/read-manga/$mangaId/',
        expect: 'w-title',
      );
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final title = document
              .querySelector('.w-title h1')
              ?.text
              .trim() ??
          '';
      var cover = '';
      final coverImg = document.querySelector('.left.cover img');
      cover = coverImg?.attributes['src'] ??
          coverImg?.attributes['data-src'] ??
          '';

      String status = '';
      String author = '';
      String year = '';
      final tags = <String>[];
      for (final row in document.querySelectorAll('table.left tr')) {
        final text = row.text.trim();
        if (text.startsWith('Status')) {
          // The status span sits next to an RSS link in the same cell; skip
          // any span that wraps a link so only the actual status survives.
          status = row
              .querySelectorAll('td span')
              .where((s) => s.querySelector('a') == null)
              .map((s) => s.text.trim())
              .where((t) => t.isNotEmpty)
              .join(' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
        } else if (text.startsWith('Author')) {
          final names = row
              .querySelectorAll('td a')
              .map((a) => a.text.trim())
              .where((t) => t.isNotEmpty)
              .toList();
          author = names.join(', ');
          final yearMatch = RegExp(r'(\d{4})\s+released').firstMatch(text);
          year = yearMatch?.group(1) ?? '';
        } else if (text.startsWith('Genre')) {
          for (final a in row.querySelectorAll('td a')) {
            final t = a.text.trim();
            if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
          }
        }
      }

      // The summary box opens with a fixed mature-content advisory in a
      // <font>; drop it so the description reads as the story synopsis.
      var description = '';
      final summary = document.querySelector('div.manga_summary');
      if (summary != null) {
        summary.querySelector('font')?.remove();
        description = summary.text.trim();
      }

      return MangaDetails(
        id: mangaId,
        title: title,
        coverUrl: cover,
        sourceId: id,
        description: description,
        author: author,
        status: status.toLowerCase(),
        year: year,
        tags: tags,
      );
    } on CaptchaRequiredException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Chapter rows, in both the desktop and the mobile markup.
  ///
  /// The desktop page wraps each row's link in `<h4><a class="chico">` and
  /// dates it in a `td.no`; the mobile page the WebView is served puts the link
  /// straight in a `<td>` and the date in the row's last cell. The "Latest"
  /// widget reuses `a.chico` (on desktop it is itself a `<tr>` labelled
  /// `Latest:`), so a row carrying the widget is skipped rather than read as a
  /// chapter with no date.
  List<Chapter> _parseChapters(String html) {
    final document = parser.parse(html);
    final chapters = <Chapter>[];
    final seen = <String>{};
    for (final row in document.querySelectorAll('tr')) {
      if (row.text.contains('Latest:')) continue;
      final a = row.querySelector('h4 a.chico') ?? row.querySelector('a.chico');
      if (a == null) continue;
      final href = a.attributes['href'] ?? '';
      if (!href.contains('/read-manga/')) continue;
      final id = idFromHref(href);
      // idFromHref keeps `slug/host/chapter`; drop the pg-N part if present.
      final pageIdx = id.indexOf('/pg-');
      final cleanId = pageIdx < 0 ? id : id.substring(0, pageIdx);
      if (cleanId.isEmpty || seen.contains(cleanId)) continue;
      final b = a.querySelector('b')?.text.trim() ?? '';
      final label = b.isNotEmpty ? b : a.text.trim();
      final numMatch =
          RegExp(r'Ch\.?\s*([\d]+(?:\.[\d]+)?)', caseSensitive: false)
              .firstMatch(label);
      final chapterNumber = numMatch?.group(1) ??
          RegExp(r'(\d+)(?:\.[\d]+)?$').firstMatch(cleanId)?.group(1) ??
          '';
      chapters.add(
        Chapter(
          id: cleanId,
          title: a.text.trim(),
          chapterNumber: chapterNumber,
          url: '$baseUrl/read-manga/$cleanId/pg-1/',
          releaseDate: _rowDate(row),
        ),
      );
      seen.add(cleanId);
    }
    // The table lists newest first; the app expects oldest first.
    return chapters.reversed.toList();
  }

  /// The upload date of a chapter row: the last cell that is neither the
  /// chapter link nor empty.
  ///
  /// Desktop rows are `<td>link</td><td class="no">uploader</td><td
  /// class="no">date</td>`; mobile rows are `<td>link</td><td
  /// class="uk-table-shrink"></td><td class="uk-table-shrink">date</td>`. In
  /// both, the first such cell scanning from the end is the date.
  static String _rowDate(dynamic row) {
    for (final td in row.querySelectorAll('td').toList().reversed) {
      final text = td.text.trim();
      if (text.isEmpty) continue;
      if (td.querySelector('a.chico') != null) continue;
      return text;
    }
    return '';
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final html = await _page(
        '$baseUrl/read-manga/$mangaId/',
        expect: 'w-title',
      );
      if (html.isEmpty) return [];
      return _parseChapters(html);
    } on CaptchaRequiredException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final html = await _page(
        '$baseUrl/read-manga/$chapterId/pg-1/',
        expect: 'imgsrcs',
      );
      if (html.isEmpty) return [];
      final match = RegExp("var imgsrcs = '([^']*)'").firstMatch(html);
      if (match == null) return [];
      return MangagoCipher.decodeImgsrcs(match.group(1)!);
    } on CaptchaRequiredException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<int> getTotalChapters(String mangaId) async {
    try {
      return (await getChapters(mangaId)).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async {
    try {
      final chapters = await getChapters(mangaId);
      if (chapters.isEmpty) return null;
      final newest = chapters.last;
      DateTime? date = DateTime.tryParse(newest.releaseDate ?? '');
      date ??= parseHumanChapterDate(newest.releaseDate ?? '');
      date ??= DateTime.now();
      return (newest.title, date);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    // Mangago exposes genre pages (`/genre/<name>/`) but no tag search API;
    // title search covers the common path.
    return [];
  }

  @override
  Future<List<String>> getAvailableTags() async {
    return [];
  }

  @override
  Future<List<Manga>> searchWithFilter(
    MangaFilter filter, {
    int page = 1,
  }) async {
    return searchMangaByTags(filter.genres, page: page);
  }
}