import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import '../models/manga_translation.dart';
import 'mangafire_vrf.dart';
import 'source_network.dart';
import 'webview_fetcher.dart';
import 'captcha_gate.dart';

/// MangaFire (mangafire.to) — one entry per language branch, mirroring
/// Kotatsu's MangaFire English / Spanish / Spanish (Latin) / French / Japanese
/// / Portuguese / Portuguese (Brazil) sources. Each variant shares the domain
/// but only reads its own language's chapter branches.
///
/// The site is a client-rendered SPA behind a Cloudflare JavaScript challenge:
/// plain requests receive an empty shell (no cards) and the JSON API answers
/// `403 {"message":"Missing token."}`. Pages are therefore rendered in a
/// hidden WebView (see [WebViewFetcher]), which executes the challenge and
/// yields the real markup.
/// A parsed title page.
class _MangaFireDetail {
  _MangaFireDetail({
    required this.title,
    required this.cover,
    required this.description,
    required this.authors,
    required this.tags,
    required this.status,
    required this.translations,
  });

  final String title;
  final String cover;
  final String description;
  final List<String> authors;
  final List<String> tags;
  final String status;
  final List<MangaTranslation> translations;
}

class MangaFireSource extends DioSource implements MangaSource {
  /// Source id, e.g. `mangafire-en`.
  final String sourceId;

  /// Language branch to read (en / es / fr / ja / pt / pt-br / es-la).
  final String langCode;

  MangaFireSource({required this.sourceId, required this.langCode});

  @override
  String get networkSourceId => id;

  @override
  String get id => sourceId;
  @override
  String get name => _nameFor(sourceId);
  @override
  String get baseUrl => 'https://mangafire.to';

  /// MangaFire is a client-rendered SPA, so the front page always answers even
  /// when the listings are blocked. Test the listing endpoint instead.
  @override
  String get testUrl => '$baseUrl/filter';
  @override
  String get readerBaseUrl => 'https://mangafire.to';
  @override
  String get languageCode => langCode;

  // Kept while the rendered page still shows the challenge/last stage only, so
  // we do not hand back a shell that parses to nothing.
  static const String _shellMarker = 'app-root';

  /// Fetches a MangaFire page, rendering it in the hidden WebView when the
  /// plain request comes back as the empty SPA shell.
  ///
  /// [expect] is a substring the finished page must contain (e.g. a card
  /// class); when even the rendered page lacks it the caller's normal
  /// "no results" path runs.
  Future<String> _page(
    String url, {
    String? expect,
    Map<String, String>? extraHeaders,
  }) async {
    final plain = await grabText(url, extraHeaders: extraHeaders);
    if (_hasContent(plain, expect)) {
      debugPrint('[mangafire] $id plain ok (${plain.length}b) $url');
      return plain;
    }

    try {
      final rendered = await WebViewFetcher.instance.render(
        url,
        sourceId: id,
        expected: expect == 'card' ? 'title-grid__link' : null,
      );
      debugPrint(
        '[mangafire] $id rendered ${rendered.length}b '
        'want=$expect has=${_hasContent(rendered, expect)} $url',
      );
      if (_hasContent(rendered, expect)) return rendered;
      // A partially rendered page is still better than the shell.
      if (!_isShell(rendered)) return rendered;
    } on CaptchaRequiredException {
      // The rendered page was a Cloudflare interstitial, not a page that
      // happened to be empty. Swallowing this as a generic failure gave the
      // caller an empty grid and no captcha banner, which reads as "this source
      // has no results" rather than "this source needs solving once".
      rethrow;
    } catch (e) {
      debugPrint('[mangafire] render failed for $url: $e');
    }
    debugPrint('[mangafire] $id falling back to shell for $url');
    return plain;
  }

  bool _isShell(String html) =>
      html.isEmpty || (html.contains(_shellMarker) && !html.contains('card'));

  bool _hasContent(String html, String? expect) {
    if (html.isEmpty) return false;
    if (expect == null) return !_isShell(html);
    return html.contains(expect);
  }

  /// A manga id may carry a `.language` suffix addressing one translation of
  /// the work (MangaFire publishes the same title in several language
  /// branches): `berserk.5134.es` = the Spanish translation.
  String _baseId(String mangaId) => MangaLanguage.baseIdOf(mangaId);

  /// The language branch a manga id refers to (its suffix, else this source's).
  String _langOf(String mangaId) => MangaLanguage.suffixOf(mangaId) ?? langCode;
  @override
  String get iconUrl => 'https://mangafire.to/assets/mangafire/logo.png';

  static String _nameFor(String sourceId) {
    const names = {
      'mangafire-en': 'MangaFire English',
      'mangafire-es': 'MangaFire Spanish',
      'mangafire-esla': 'MangaFire Spanish Latin',
      'mangafire-fr': 'MangaFire French',
      'mangafire-ja': 'MangaFire Japanese',
      'mangafire-pt': 'MangaFire Portuguese',
      'mangafire-ptbr': 'MangaFire Portuguese Brazil',
    };
    return names[sourceId] ?? 'MangaFire';
  }

  @override
  Map<String, String>? get headers => {
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
  };

  String _abs(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    return '$baseUrl$url';
  }

  /// The canonical page of a title.
  ///
  /// The current site addresses titles as `/title/<slug>`; the id a listing
  /// yields already *is* that slug, so it must not be appended to the bare
  /// domain (which 404s and leaves the page without chapters).
  String _mangaUrl(String mangaId) => '$baseUrl/title/${_baseId(mangaId)}';

  /// Listings come from the `/filter` page. The current site is a React SPA
  /// whose rendered grid is a list of `a.title-grid__link` cards:
  ///
  /// ```html
  /// <a class="title-grid__link" href="/title/<slug>">
  ///   <div class="card manga-card">
  ///     <div class="card__poster manga-card__poster">
  ///       <img class="manga-card__img" alt="Title" src="...@280.jpg">
  ///     ...
  ///     <div class="card__title manga-card__title">Title</div>
  /// ```
  ///
  /// The slug is the manga id (the old `slug.38922` numeric ids are gone, and
  /// with them the `/ajax/read/{numericId}` chapter endpoint).
  List<Manga> _parseFilter(String html) {
    final document = parser.parse(html);
    final result = <Manga>[];
    final seen = <String>{};
    for (final a in document.querySelectorAll('a[href^="/title/"]')) {
      final href = a.attributes['href'] ?? '';
      final path = href
          .replaceFirst(RegExp(r'^/title/'), '')
          .split(RegExp(r'[?#]'))
          .first
          .trim();
      if (path.isEmpty || seen.contains(path)) continue;
      final titleEl = a.querySelector('.card__title');
      final img = a.querySelector('img');
      final title = (titleEl?.text.trim().isNotEmpty ?? false)
          ? titleEl!.text.trim()
          : (img?.attributes['alt']?.trim() ?? '');
      if (title.isEmpty) continue;
      seen.add(path);
      result.add(
        Manga(
          id: path,
          title: title,
          coverUrl: _abs(img?.attributes['src'] ?? ''),
          sourceId: id,
        ),
      );
    }
    return result;
  }

  /// Builds the `/filter` URL for a browse page (order + tags + keyword).
  String _filterUrl({
    int page = 1,
    String sort = 'most_viewed',
    String? keyword,
    List<String>? genres,
    List<String>? excludeGenres,
  }) {
    final params = <String>['page=$page', 'language[]=$langCode', 'sort=$sort'];
    if (keyword != null && keyword.isNotEmpty) {
      final parts = keyword
          .trim()
          .split(RegExp(r'\s+'))
          .map((p) => Uri.encodeQueryComponent(p))
          .join('+');
      params.add('keyword=$parts');
      params.add('vrf=${MfVrf.generate(keyword.trim())}');
    }
    for (final g in genres ?? const <String>[]) {
      params.add('genre[]=${Uri.encodeQueryComponent(g)}');
    }
    for (final g in excludeGenres ?? const <String>[]) {
      params.add('genre[]=-${Uri.encodeQueryComponent(g)}');
    }
    return '$baseUrl/filter?${params.join('&')}';
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) =>
      _listing(_filterUrl(page: page));

  /// Fetches a listing and only accepts a response that actually yields
  /// titles.
  ///
  /// A substring check cannot tell a rendered grid from a page that merely
  /// mentions the word (the SPA shell and the Cloudflare interstitial both
  /// ship CSS/JS full of it), so the plain response is accepted only when it
  /// parses; otherwise the page is rendered in the hidden WebView and the
  /// *rendered* markup decides.
  Future<List<Manga>> _listing(String url) async {
    final plain = await grabText(url);
    if (!_isShell(plain)) {
      final list = _parseFilter(plain);
      if (list.isNotEmpty) {
        debugPrint('[mangafire] $id listing plain ok (${list.length}) $url');
        return list;
      }
    }
    try {
      final rendered = await WebViewFetcher.instance.render(
        url,
        sourceId: id,
        expected: 'title-grid__link',
      );
      final list = _parseFilter(rendered);
      debugPrint('[mangafire] $id listing rendered -> ${list.length} $url');
      return list;
    } on CaptchaRequiredException {
      // As in [_page]: a challenge has to reach the screen that can solve it.
      rethrow;
    } catch (e) {
      debugPrint('[mangafire] $id render failed for $url: $e');
      return const [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    return _listing(_filterUrl(page: page, keyword: query));
  }

  @override
  Future<List<Manga>> searchWithFilter(
    MangaFilter filter, {
    int page = 1,
  }) async {
    return searchMangaByTags(filter.genres, page: page);
  }

  @override
  Future<List<String>> getAvailableTags() async {
    try {
      final html = await _page('$baseUrl/filter', expect: 'card');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final tags = <String>[];
      for (final li in document.querySelectorAll('.genres > li')) {
        final label = li.querySelector('label')?.text.trim() ?? '';
        if (label.isNotEmpty && !tags.contains(label)) tags.add(label);
      }
      return tags;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await _page(_mangaUrl(mangaId), expect: _detailMarker);
      if (html.isEmpty) return null;
      final document = parser.parse(html);
      final info = _parseDetail(document, mangaId);
      if (info == null) return null;
      return MangaDetails(
        id: mangaId,
        title: info.title,
        coverUrl: info.cover,
        sourceId: id,
        description: info.description,
        author: info.authors.join(', '),
        status: info.status,
        tags: info.tags,
        language: _langOf(mangaId),
        translations: info.translations,
      );
    } catch (e) {
      debugPrint('[mangafire] $id details failed for $mangaId: $e');
      return null;
    }
  }

  /// Marker of a rendered title page: the chapter panel only exists there.
  static const String _detailMarker = 'title-detail__chapters';

  /// Reads the rendered title page (`/title/<slug>`).
  ///
  /// ```html
  /// <div class="title-detail__poster"><img src=".../cover.jpg"></div>
  /// <h1 class="title-detail__title">Title</h1>
  /// <span class="title-detail__alt-line">Other title</span>
  /// <a class="title-detail__tag" href="/browse?genres_in=1">Action</a>
  /// <a class="title-detail__credit-link" href="/browse?authors=1">Author</a>
  /// <div class="title-detail__synopsis"><p>...</p></div>
  /// <span class="badge badge--status">Releasing</span>
  /// ```
  _MangaFireDetail? _parseDetail(dynamic document, String mangaId) {
    final title =
        document.querySelector('h1.title-detail__title')?.text.trim() ?? '';
    if (title.isEmpty) return null;

    final cover = _abs(
      document.querySelector('.title-detail__poster img')?.attributes['src'] ??
          '',
    );

    final altTitles = <String>[];
    for (final el in document.querySelectorAll('.title-detail__alt-line')) {
      final t = el.text.trim();
      if (t.isNotEmpty && t != title && !altTitles.contains(t)) {
        altTitles.add(t);
      }
    }

    final synopsis = document.querySelector('.title-detail__synopsis');
    var description = synopsis?.text.trim() ?? '';
    if (description.length > 4000) {
      description = '${description.substring(0, 4000)}…';
    }

    final tags = <String>[];
    for (final a in document.querySelectorAll('a.title-detail__tag')) {
      final t = a.text.trim();
      if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
    }

    final authors = <String>[];
    for (final a in document.querySelectorAll('a.title-detail__credit-link')) {
      final t = a.text.trim();
      if (t.isNotEmpty && !authors.contains(t)) authors.add(t);
    }

    var status = '';
    final statusEl = document.querySelector('.badge--status');
    if (statusEl != null) {
      status = switch (statusEl.text.trim().toLowerCase()) {
        'releasing' => 'ongoing',
        'completed' => 'completed',
        'discontinued' => 'discontinued',
        'hiatus' || 'on hiatus' => 'on hiatus',
        final other => other,
      };
    }

    return _MangaFireDetail(
      title: title,
      cover: cover,
      description: description,
      authors: authors,
      tags: tags,
      status: status,
      translations: _translationsFrom(document, mangaId, altTitles),
    );
  }

  /// The language branches the title is published in.
  ///
  /// The page lists every alternate title it knows, but the branch a reader
  /// can actually open is not linked in the markup (the language picker is a
  /// JS dropdown), so the site's own chapter branches are the source of
  /// truth: each chapter row carries the language it belongs to. Titles whose
  /// alternate names exist are still recorded so the picker can show them.
  List<MangaTranslation> _translationsFrom(
    dynamic document,
    String mangaId,
    List<String> altTitles,
  ) {
    final baseId = _baseId(mangaId);
    final codes = <String>{langCode};
    for (final flag in document.querySelectorAll('.title-detail__row-flag')) {
      final code = (flag.attributes['title'] ?? '').trim().toLowerCase();
      if (code.isNotEmpty) codes.add(_normalizeLang(code));
    }
    return [
      for (var i = 0; i < codes.length; i++)
        MangaTranslation(
          language: codes.elementAt(i),
          mangaId: MangaLanguage.withSuffix(baseId, codes.elementAt(i)),
          title: i == 0 && altTitles.isNotEmpty ? altTitles.first : '',
        ),
    ];
  }

  /// MangaFire branch codes are not always the ISO ones we track
  /// (`pt-br`, `es-la`, ...).
  String _normalizeLang(String code) => switch (code) {
    'pt-br' || 'ptbr' => 'pt-br',
    'es-la' || 'esla' => 'es-la',
    _ => code,
  };

  @override
  Future<List<MangaTranslation>> getTranslations(String mangaId) async {
    final html = await _page(_mangaUrl(mangaId), expect: _detailMarker);
    if (html.isEmpty) return [];
    final detail = _parseDetail(parser.parse(html), mangaId);
    return detail?.translations ?? const [];
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final html = await _page(_mangaUrl(mangaId), expect: _detailMarker);
      if (html.isEmpty) return [];
      return _parseChapters(parser.parse(html), mangaId);
    } catch (e) {
      debugPrint('[mangafire] $id chapters failed for $mangaId: $e');
      return [];
    }
  }

  /// `"Ch. 164"` -> `"164"`, so sorting and grouping work on numbers.
  static String _chapterNumber(String label) {
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(label);
    return m?.group(1) ?? '';
  }

  /// `/title/<slug>/chapter/9451645` -> `<slug>`.
  static String? _slugFromChapterHref(String href) {
    final m = RegExp(r'/title/([^/]+)/chapter/\d+').firstMatch(href);
    return m?.group(1);
  }

  /// Reads the rendered chapter list.
  ///
  /// ```html
  /// <div class="title-detail__list">
  ///   <div class="title-detail__row">
  ///     <span class="title-detail__row-flag" title="en">🇬🇧</span>
  ///     <a class="title-detail__row-link"
  ///        href="/title/<slug>/chapter/9451645">
  ///       <span class="title-detail__row-num">Ch. 164</span>
  ///     </a>
  ///     <span class="title-detail__row-date">15h ago</span>
  /// ```
  ///
  /// A chapter is addressed as `/title/<slug>/chapter/<id>`, so the chapter id
  /// is that trailing number.
  List<Chapter> _parseChapters(dynamic document, String mangaId) {
    final result = <Chapter>[];
    final seen = <String>{};
    for (final a in document.querySelectorAll('a.title-detail__row-link')) {
      final href = a.attributes['href'] ?? '';
      final m = RegExp(r'/chapter/(\d+)').firstMatch(href);
      if (m == null) continue;
      final id = m.group(1)!;
      if (!seen.add(id)) continue;

      final row = a.parent?.parent;
      final number =
          a.querySelector('.title-detail__row-num')?.text.trim() ??
          a.text.trim();
      final flag = row?.querySelector('.title-detail__row-flag');
      final date = row?.querySelector('.title-detail__row-date')?.text.trim();
      final chapterLang = _normalizeLang(
        (flag?.attributes['title'] ?? '').trim().toLowerCase(),
      );

      // The reader route needs the title slug (`/title/<slug>/chapter/<id>`)
      // but only the id is handed to [getPageUrls], and the id is also used as
      // a directory name when downloading — so the slug travels with it,
      // separated by a character a slug can never contain.
      final slug = _slugFromChapterHref(href);

      result.add(
        Chapter(
          id: slug == null ? id : '$slug~$id',
          title: number.isEmpty ? 'Chapter $id' : number,
          chapterNumber: _chapterNumber(number),
          url: _abs(href),
          releaseDate: (date ?? '').isEmpty ? null : date,
          scanlator: chapterLang,
        ),
      );
    }
    return result;
  }

  /// Chapter pages are rendered in the hidden WebView too: the page is a
  /// client-rendered reader and its image list never appears in plain HTML.
  ///
  /// The chapter id is the trailing number of
  /// `/title/<slug>/chapter/<id>`, but the reader needs the slug as well, so
  /// the chapter url recorded while listing is replayed.
  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    final url = _chapterPageUrl(chapterId);
    if (url == null || url.isEmpty) return [];
    try {
      final html = await _page(url, expect: 'chapter-reader');
      return _parsePageUrls(html);
    } catch (e) {
      debugPrint('[mangafire] $id pages failed for $chapterId: $e');
      return [];
    }
  }

  /// Rebuilds the reader url of a chapter id.
  ///
  /// A chapter id is `<slug>~<number>` (see [_parseChapters]); the reader
  /// route needs both parts. Ids that carry only a number cannot be resolved
  /// without the slug, so they yield `null` rather than a wrong page.
  String? _chapterPageUrl(String chapterId) {
    final id = chapterId.trim();
    if (id.isEmpty) return null;

    final sep = id.indexOf('~');
    if (sep > 0 && sep < id.length - 1) {
      final slug = id.substring(0, sep);
      final num = id.substring(sep + 1);
      return '$baseUrl/title/$slug/chapter/$num';
    }

    // Tolerate an id that still carries the full route.
    final m = RegExp(r'/title/([^/]+)/chapter/(\d+)').firstMatch(id);
    if (m != null) return '$baseUrl/title/${m.group(1)}/chapter/${m.group(2)}';

    return null;
  }

  /// Collects the reader's page images.
  ///
  /// Images are CDN urls; a scrambled page is marked with a
  /// `#scrambled_<offset>` fragment, which the image widget reassembles.
  List<String> _parsePageUrls(String html) {
    if (html.isEmpty) return [];
    final document = parser.parse(html);
    final urls = <String>[];
    final seen = <String>{};
    for (final img in document.querySelectorAll('img')) {
      final src =
          img.attributes['data-src'] ??
          img.attributes['src'] ??
          img.attributes['data-original'] ??
          '';
      if (src.isEmpty) continue;
      if (!src.contains('mfcdn') && !src.contains('/i/')) continue;
      final url = _abs(src);
      if (!seen.add(url)) continue;
      urls.add(url);
    }
    return urls;
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
      return (chapters.last.title, DateTime.now());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    if (tags.isEmpty) return [];
    return _listing(_filterUrl(page: page, genres: tags));
  }
}
