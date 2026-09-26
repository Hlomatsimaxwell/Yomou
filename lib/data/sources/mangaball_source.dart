import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/chapter.dart';
import '../models/manga.dart';
import '../models/manga_details.dart';
import '../models/manga_filter.dart';
import '../models/manga_source.dart';
import '../models/manga_translation.dart';
import 'source_network.dart';
import 'package:yomou/core/diagnostics/diag_log.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'captcha_gate.dart';
import 'webview_fetcher.dart';

/// MangaBall (https://mangaball.com).
///
/// The site sits behind a Cloudflare interstitial, so the first request of a
/// session throws [CaptchaRequiredException] and the user clears it once in
/// the captcha solver; the clearance cookie is then replayed by [DioSource].
///
/// Past the challenge it is a JSON API guarded by a CSRF token that is read
/// from any rendered page (`meta[name=csrf-token]`), plus an adult-content
/// cookie. Every language variant is the same site filtered by
/// `filters[translatedLanguage][]`, which is why each variant is only a
/// different [langCode].
class MangaBallSource extends DioSource implements MangaSource {
  MangaBallSource({
    required this.sourceId,
    required this.displayName,
    required this.langCode,
  });

  final String sourceId;
  final String displayName;

  /// Site language code, e.g. `en`, `pt`, `zh`.
  final String langCode;

  @override
  String get id => sourceId;

  @override
  String get name => displayName;

  @override
  /// All 42 variants are the same site behind the same Cloudflare clearance, so
  /// they share one network profile: solving the challenge once covers every
  /// language instead of needing 42 captchas. Bookmarks, progress and caches
  /// still key off the distinct source ids.
  String get networkSourceId => 'mangaball';

  @override
  String get baseUrl => 'https://mangaball.com';

  /// The API paths are written without a trailing slash on purpose: the
  /// canonical host answers the slashed form with a 301, and a redirected POST
  /// is downgraded to a GET, which silently drops the filter body and returns
  /// the unfiltered first page.

  @override
  String get readerBaseUrl => 'https://mangaball.com';

  @override
  String get iconUrl => 'https://mangaball.com/favicon.ico';

  /// Read from a page once per session; the API rejects requests without it.

  @override
  Map<String, String>? get headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
    'Referer': '$baseUrl/',
    'X-Requested-With': 'XMLHttpRequest',
  };

  /// The adult-content flag has to ride along with the clearance cookie, so it
  /// is merged into whatever cookie header the captcha solver stored instead of
  /// being declared in [headers] (which would be overwritten by it).
  @override
  Future<Dio> get dio async {
    final client = await super.dio;
    final existing = client.options.headers['Cookie'];
    const flag = 'show18PlusContent=false';
    if (existing == null || '$existing'.isEmpty) {
      client.options.headers['Cookie'] = flag;
    } else if (!'$existing'.contains('show18PlusContent')) {
      client.options.headers['Cookie'] = '$existing; $flag';
    }
    return client;
  }

  // --- API plumbing -------------------------------------------------------

  /// POSTs a form to the API with the CSRF header attached.
  ///
  /// A 403 usually means the token went stale, so it is refreshed once and the
  /// call retried before giving up.
  Future<dynamic> _postJson(
    String path,
    Map<String, String> form, {
    Duration cap = const Duration(seconds: 25),
  }) async {
    final raw = form.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    var body = await _send(path, raw, cap: cap);
    if (body.isEmpty) {
      // Either a stale token or a challenge; try once more.
      body = await _send(path, raw, cap: cap);
    }
    if (body.isEmpty) {
      diagSoon('$id: empty answer from $path (lang=$langCode)');
      return null;
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      debugPrint('$id: bad json from $path');
      return null;
    }
  }

  /// Sends a pre-encoded form body and returns the response text.
  ///
  /// The request is issued by the hidden WebView rather than by [Dio]. A
  /// clearance cookie alone is not accepted: Cloudflare also validates the
  /// client, so a request from a non-browser HTTP stack is challenged again
  /// even with a valid cookie. Going through the page reuses the browser's
  /// fingerprint and its cookie jar, and the CSRF token is read from the live
  /// document, so it always matches the session that served it.
  Future<String> _send(
    String path,
    String rawBody, {
    Duration cap = const Duration(seconds: 25),
  }) async {
    final url = '$baseUrl$path';
    final js = _postScript(url, rawBody);
    try {
      final body = await WebViewFetcher.instance.callInPage(
        baseUrl,
        js,
        sourceId: id,
        cap: cap,
      );
      // The interstitial and a stale token both mean the same thing here: this
      // session can no longer talk to the API until it is solved again.
      if (body.contains('Just a moment') ||
          body.contains('CSRF token validation failed') ||
          body.contains('cf-mitigated')) {
        throw CaptchaRequiredException(
          sourceId: networkSourceId,
          challengeUrl: baseUrl,
        );
      }
      return body;
    } on CaptchaRequiredException {
      rethrow;
    } catch (e) {
      diagSoon('$id: in-page POST $path failed: $e');
      // A challenge inside the page means the session needs solving again.
      if (await _pageIsChallenged()) {
        throw CaptchaRequiredException(
          sourceId: networkSourceId,
          challengeUrl: baseUrl,
        );
      }
      return '';
    }
  }

  /// In-page POST, sent from the document itself so the session cookie, origin
  /// and fingerprint all match what a browser would present.
  ///
  /// The CSRF token is read from the document's own meta tag, which is the only
  /// place it is guaranteed to belong to the session making the request. Not
  /// every page carries one, so a missing token is not treated as fatal: the
  /// request goes out without the header and the server decides. Bailing out
  /// here is what used to report a captcha that was never on screen.
  ///
  /// The `Accept` header belongs to [headers] and nothing else. It used to be
  /// repeated as a property of the `fetch` options object, whose closing brace
  /// was left stranded after it, so the whole script was a syntax error: it
  /// never ran, `window.__mbDone` was never set, and every call sat out its
  /// full timeout before reporting a failure that had no cause on screen.
  static String _postScript(String url, String rawBody) {
    final u = jsonEncode(url);
    final b = jsonEncode(rawBody);
    return '''
(function () {
  var meta = document.querySelector('meta[name=csrf-token]');
  var token = meta ? (meta.getAttribute('content') || '') : '';
  var headers = {
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'X-Requested-With': 'XMLHttpRequest',
      'Accept': 'application/json, text/plain, */*'};
  if (token) headers['X-CSRF-TOKEN'] = token;
  fetch($u, {
    method: 'POST',
    credentials: 'include',
    headers: headers,
    body: $b
  }).then(function (r) {
    return r.text().then(function (t) {
      window.__mbStatus = r.status;
      window.__mbData = t;
      window.__mbDone = true;
    });
  }).catch(function (e) {
    window.__mbErr = '' + e;
    window.__mbDone = true;
  });
  return 'started';
})()
''';
  }

  /// Whether the page currently sitting in the WebView is the interstitial.
  Future<bool> _pageIsChallenged() async {
    try {
      final html = await WebViewFetcher.instance.callInPage(
        baseUrl,
        'window.__mbData = document.title + "|" + '
        '(document.querySelector("#challenge-form") ? "form" : "");'
        'window.__mbDone = true; return "probe";',
        sourceId: id,
        cap: const Duration(seconds: 12),
      );
      return html.contains('Just a moment') || html.contains('form');
    } catch (_) {
      return false;
    }
  }

  // --- Listings -----------------------------------------------------------

  Map<String, String> _searchForm({String query = '', int page = 1}) => {
    'search_input': query,
    'filters[sort]': 'updated_chapters_desc',
    'filters[page]': '$page',
    'filters[tag_included_mode]': 'and',
    'filters[tag_excluded_mode]': 'or',
    'filters[contentRating]': 'any',
    'filters[person]': 'any',
    'filters[translatedLanguage][]': langCode,
  };

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    return _postRaw(
      '/api/v1/title/search-advanced',
      _searchForm(query: query.trim(), page: page).entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&'),
    );
  }

  @override
  Future<List<Manga>> searchWithFilter(
    MangaFilter filter, {
    int page = 1,
  }) async {
    return searchMangaByTags(filter.genres, page: page);
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
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    final json = await _postJson(
      '/api/v1/title/search-advanced',
      _searchForm(page: page),
    );
    return _parseList(json);
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    if (tags.isEmpty) return getPopularManga(page: page);

    // The filter takes genre ids, not the names shown on the chips; sending a
    // name comes back as "Error parsing ObjectId string".
    final ids = await _genreIds();
    final wanted = <String>[
      for (final t in tags)
        if (ids[t.toLowerCase()] case final id?) id,
    ];
    if (wanted.isEmpty) return getPopularManga(page: page);

    // `filters[tag_included_ids][]` repeats per tag, so the body is built by
    // hand rather than through a map.
    final parts = <String>[
      'search_input=',
      'filters[sort]=updated_chapters_desc',
      'filters[page]=$page',
      'filters[tag_included_mode]=and',
      'filters[tag_excluded_mode]=or',
      'filters[contentRating]=any',
      'filters[person]=any',
      'filters[translatedLanguage][]=${Uri.encodeQueryComponent(langCode)}',
      for (final id in wanted)
        'filters[tag_included_ids][]=${Uri.encodeQueryComponent(id)}',
    ];
    return _postRaw('/api/v1/title/search-advanced', parts.join('&'));
  }

  /// POSTs a pre-encoded form body and parses the JSON answer.
  Future<List<Manga>> _postRaw(String path, String rawBody) async {
    var body = await _send(path, rawBody);
    if (body.isEmpty) {
      body = await _send(path, rawBody);
    }
    if (body.isEmpty) {
      diagSoon('$id: empty listing from $path (lang=$langCode)');
      return const [];
    }
    try {
      return _parseList(jsonDecode(body));
    } catch (_) {
      return const [];
    }
  }

  List<Manga> _parseList(dynamic json) {
    final data = json is Map ? json['data'] : null;
    if (data is! List) return [];
    final result = <Manga>[];
    for (final item in data) {
      if (item is! Map) continue;
      // The endpoint hands back the slug directly. It used to be dug out of a
      // `url` field this endpoint does not have, so every item was skipped and
      // an unparseable answer looked exactly like an empty listing.
      final slug = '${item['slug'] ?? ''}'.trim();
      if (slug.isEmpty) continue;
      result.add(
        Manga(
          id: slug,
          title: item['name']?.toString() ?? slug,
          // This payload carries no artwork of any kind - no cover, no image
          // URL - so a grid built from it shows the placeholder until the
          // detail page supplies one.
          coverUrl: '',
          sourceId: id,
        ),
      );
    }
    if (result.isEmpty && data.isNotEmpty) {
      final first = data.first;
      diagSoon(
        '$id: no slug in ${data.length} listings; '
        'keys=${first is Map ? first.keys.join(',') : '?'}',
      );
    }
    diagSoon('$id: parsed ${result.length} of ${data.length} listings');
    return result;
  }

  // --- Details ------------------------------------------------------------

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    diagSoon('$id: getMangaDetails($mangaId)');
    final slug = _baseSlug(mangaId);
    final page = await WebViewFetcher.instance.render(
      '$baseUrl/title-detail/$slug/',
      sourceId: id,
      expected: 'id="comicDetail"',
    );
    if (page.isEmpty) return null;

    // Any rendered page carries the token the API needs.
    final doc = html_parser.parse(page);
    final root = doc.querySelector('#comicDetail');
    final title =
        root?.querySelector('h6')?.text.trim() ??
        doc.querySelector('h1')?.text.trim() ??
        slug;
    if (title.isEmpty) return null;

    final altTitles = <String>[];
    for (final block in doc.querySelectorAll('div.alternate-name-container')) {
      for (final part in block.text.split('/')) {
        final t = part.trim();
        if (t.isNotEmpty) altTitles.add(t);
      }
    }

    final tags = <String>[];
    for (final span in doc.querySelectorAll('#comicDetail span[data-tag-id]')) {
      final t = span.text.trim();
      if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
    }

    final authors = <String>[];
    for (final span in doc.querySelectorAll(
      '#comicDetail span[data-person-id]',
    )) {
      final t = span.text.trim();
      if (t.isNotEmpty && !authors.contains(t)) authors.add(t);
    }

    final cover =
        doc.querySelector('img.featured-cover')?.attributes['src'] ?? '';
    final description = doc.querySelector('#descriptionContent p')?.text.trim();
    final status = doc.querySelector('span.badge-status')?.text.trim();

    // Alternate titles double as the translations the site itself groups by
    // language, so they feed the picker.
    final translations = <MangaTranslation>[
      for (var i = 0; i < altTitles.length && i < 12; i++)
        MangaTranslation(
          language: i == 0 ? langCode : '$langCode-alt$i',
          mangaId: MangaLanguage.withSuffix(
            slug,
            i == 0 ? langCode : '$langCode-alt$i',
          ),
          title: altTitles[i],
        ),
    ];

    return MangaDetails(
      id: slug,
      title: title,
      coverUrl: cover,
      sourceId: id,
      description: description ?? '',
      author: authors.join(', '),
      status: status ?? '',
      tags: tags,
      language: langCode,
      translations: translations,
    );
  }

  @override
  Future<List<MangaTranslation>> getTranslations(String mangaId) async {
    // The site exposes every language of a title through the same slug, so
    // there is nothing separate to resolve: the variants share a title page.
    return const [];
  }

  // --- Chapters -----------------------------------------------------------

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    diagSoon('$id: getChapters($mangaId)');
    final slug = _baseSlug(mangaId);
    // The API keys chapters by the trailing id of the slug.
    final titleId = slug.contains('-')
        ? slug.substring(slug.lastIndexOf('-') + 1)
        : slug;

    // This endpoint answers with every chapter of a title at once (hundreds of
    // KB for a long series), which routinely overruns the default per-request
    // budget and used to surface as "failed to load" rather than a slow list.
    final json = await _postJson(
      '/api/v1/chapter/chapter-listing-by-title-id',
      {'title_id': titleId},
      cap: const Duration(seconds: 90),
    );
    final containers = json is Map ? json['ALL_CHAPTERS'] : null;
    if (containers is! List) {
      return [];
    }


    final result = <Chapter>[];
    final seen = <String>{};
    for (final container in containers) {
      if (container is! Map) continue;
      final cMap = Map<String, dynamic>.from(container);
      final translations = container['translations'];
      if (translations is! List) continue;
      final number = _numberText(cMap['number_float']);

      for (final t in translations) {
        if (t is! Map) continue;
        final tMap = Map<String, dynamic>.from(t);
        final language = tMap['language']?.toString() ?? '';
        if (language.toLowerCase() != langCode.toLowerCase()) continue;
        final chapterId = tMap['id']?.toString() ?? '';
        if (chapterId.isEmpty || !seen.add(chapterId)) continue;

        final group = tMap['group'];
        final scanlator = group is Map
            ? (group['name']?.toString().trim() ?? '')
            : '';

        result.add(
          Chapter(
            id: chapterId,
            title: _chapterTitle(number, tMap),
            chapterNumber: number,
            releaseDate: _parseDate(tMap['date']?.toString()),
            url: '$baseUrl/chapter-detail/$chapterId/',
            scanlator: scanlator,
          ),
        );
      }
    }

    // The API lists newest first; the app sorts ascending by chapter number.
    result.sort((a, b) => _compareNumbers(a.chapterNumber, b.chapterNumber));
    return result;
  }

  String _chapterTitle(String number, Map<String, dynamic> t) {
    final name = t['name']?.toString().trim() ?? '';
    final volume = t['volume'];
    final volumeText = (volume is num && volume != 0) ? 'v$volume ' : '';
    if (name.isEmpty) return 'Ch. $volumeText$number';
    return 'Ch. $volumeText$number - $name';
  }

  static String _numberText(dynamic value) {
    if (value is num) {
      final s = value.toString();
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }
    return value?.toString() ?? '';
  }

  static int _compareNumbers(String a, String b) {
    final na = double.tryParse(a);
    final nb = double.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  }

  static String? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed == null) return null;
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  // --- Pages --------------------------------------------------------------

  /// The site reads this cookie to decide how much of a chapter to serve, and
  /// the WebView has to carry it: unlike the plain-HTTP path there are no
  /// per-request headers to attach it to.
  static bool _cookieSet = false;

  Future<void> _ensureWebViewCookie() async {
    if (_cookieSet) return;
    _cookieSet = true;
    try {
      await CookieManager.instance().setCookie(
        url: WebUri(baseUrl),
        name: 'show18PlusContent',
        value: 'false',
        domain: Uri.parse(baseUrl).host,
        path: '/',
      );
    } catch (e) {
      diagSoon('$id: could not set the content cookie: $e');
    }
  }

  Future<List<String>> getPageUrls(String chapterId) async {
    diagSoon('$id: getPageUrls($chapterId)');
    await _ensureWebViewCookie();
    var page = await WebViewFetcher.instance.render(
      '$baseUrl/chapter-detail/$chapterId/',
      sourceId: id,
    );
    var images = _parseChapterImages(page);
    if (images.isEmpty) {
      // The chapter body is painted by a script, so a load that is caught too
      // early comes back without it. Reloading is cheap next to a blank page.
      page = await WebViewFetcher.instance.render(
        '$baseUrl/chapter-detail/$chapterId/',
        sourceId: id,
      );
      images = _parseChapterImages(page);
    }
    if (images.isEmpty) {
      diagSoon(
        '$id: no page images in chapter $chapterId (len=${page.length})',
      );
      return [];
    }
    diagSoon('$id: chapter $chapterId -> ${images.length} pages');
    return images;
  }

  /// Page images live in an inline script as
  /// `const chapterImages = JSON.parse(` + backtick-delimited JSON.
  static List<String> _parseChapterImages(String html) {
    final doc = html_parser.parse(html);
    for (final script in doc.querySelectorAll('script')) {
      final text = script.text;
      if (!text.contains('chapterImages')) continue;
      final match = RegExp(
        r'''chapterImages\s*=\s*JSON\.parse\(`([\s\S]*?)`\)''',
      ).firstMatch(text);
      if (match == null) continue;
      try {
        final decoded = jsonDecode(match.group(1)!);
        if (decoded is List) {
          return decoded
              .map((e) => e?.toString() ?? '')
              .where((u) => u.isNotEmpty)
              .toList();
        }
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  // --- Tags ---------------------------------------------------------------

  @override
  Future<List<String>> getAvailableTags() async {
    final ids = await _genreIds();
    // Prefer the site's own genres, and keep the familiar order for the ones
    // it knows about.
    final known = _kGenres
        .where((g) => ids.containsKey(g.toLowerCase()))
        .toList(growable: false);
    return known.isEmpty ? ids.keys.toList() : known;
  }

  /// Genre title (lowercased) to the id the search filter expects.
  ///
  /// The site has no endpoint that lists them: the filter only accepts these
  /// ids, and a title sent in their place comes back as
  /// "Error parsing ObjectId string". The table is the site's own, so the chips
  /// and the ids can never drift apart.
  static const Map<String, String> _tags = {
    '4-koma': '685148d115e8b86aae68e4ec',
    'action': '685146c5f3ed681c80f257e3',
    'adaptation': '685148cf15e8b86aae68e4de',
    'adult': '689371f0a943baf927094f03',
    'adventure': '685146c5f3ed681c80f257e6',
    'aliens': '6851490d15e8b86aae68e5d5',
    'animals': '685148e715e8b86aae68e54b',
    'anthology': '685148e915e8b86aae68e558',
    'award winning': '685148fe15e8b86aae68e5a7',
    'boys\' love': '685148ef15e8b86aae68e573',
    'comedy': '685146c5f3ed681c80f257e5',
    'comics': '68bf09ff8fdeab0b6a9bc2b7',
    'cooking': '685148d215e8b86aae68e4f8',
    'crime': '685148da15e8b86aae68e51f',
    'crossdressing': '685148df15e8b86aae68e534',
    'delinquents': '685148d915e8b86aae68e519',
    'demons': '685146c5f3ed681c80f257e4',
    'doujinshi': '6851490e15e8b86aae68e5da',
    'drama': '685148cf15e8b86aae68e4dd',
    'ecchi': '6892a73ba943baf927094e37',
    'fan colored': '6851498215e8b86aae68e704',
    'fantasy': '685146c5f3ed681c80f257ea',
    'full color': '685148d615e8b86aae68e502',
    'genderswap': '685148d715e8b86aae68e505',
    'ghosts': '685148d615e8b86aae68e501',
    'girls\' love': '685148da15e8b86aae68e524',
    'gore': '685148d115e8b86aae68e4f3',
    'gyaru': '685148d015e8b86aae68e4e8',
    'harem': '685146c5f3ed681c80f257e8',
    'hentai': '68bfceaf4dbc442a26519889',
    'historical': '685148db15e8b86aae68e527',
    'horror': '685148da15e8b86aae68e520',
    'incest': '685148f215e8b86aae68e584',
    'isekai': '685146c5f3ed681c80f257e9',
    'loli': '685148d715e8b86aae68e506',
    'long strip': '685148d915e8b86aae68e517',
    'mafia': '685148d915e8b86aae68e518',
    'magic': '685148d715e8b86aae68e509',
    'magical girls': '6851490d15e8b86aae68e5d4',
    'manhwa 18+': '68f5f5ce5f29d3c1863dec3a',
    'martial arts': '6851490615e8b86aae68e5c2',
    'mature': '68932d11a943baf927094e7b',
    'mecha': '6851490c15e8b86aae68e5d2',
    'medical': '6851494e15e8b86aae68e66e',
    'military': '685148e215e8b86aae68e541',
    'monster girls': '685148db15e8b86aae68e52c',
    'monsters': '685146c5f3ed681c80f257e2',
    'music': '685148d015e8b86aae68e4e4',
    'mystery': '685148d215e8b86aae68e4f4',
    'ninja': '685148d715e8b86aae68e508',
    'office workers': '685148d315e8b86aae68e4fd',
    'official colored': '6851493515e8b86aae68e64a',
    'oneshot': '685148eb15e8b86aae68e56c',
    'philosophical': '685148e215e8b86aae68e544',
    'police': '6851498815e8b86aae68e714',
    'post-apocalyptic': '685148e215e8b86aae68e540',
    'psychological': '685148d715e8b86aae68e507',
    'reincarnation': '685146c5f3ed681c80f257e1',
    'reverse harem': '685148df15e8b86aae68e533',
    'romance': '685148cf15e8b86aae68e4db',
    'samurai': '6851490415e8b86aae68e5b9',
    'school life': '685148d015e8b86aae68e4e7',
    'sci-fi': '685148cf15e8b86aae68e4da',
    'self-published': '6851492e15e8b86aae68e633',
    'sexual violence': '685146c5f3ed681c80f257e7',
    'shota': '685148d115e8b86aae68e4ed',
    'shounen ai': '689f0ab1f2e66744c6091524',
    'slice of life': '685148d015e8b86aae68e4e3',
    'smut': '689371f2a943baf927094f04',
    'sports': '685148f515e8b86aae68e588',
    'superhero': '6851492915e8b86aae68e61c',
    'supernatural': '685148db15e8b86aae68e528',
    'survival': '685148cf15e8b86aae68e4dc',
    'thriller': '685148d915e8b86aae68e51e',
    'time travel': '6851490c15e8b86aae68e5d1',
    'traditional games': '6851493515e8b86aae68e645',
    'tragedy': '685148db15e8b86aae68e529',
    'user created': '68932c3ea943baf927094e77',
    'vampires': '685148f915e8b86aae68e597',
    'video games': '685148e115e8b86aae68e53c',
    'villainess': '6851492115e8b86aae68e602',
    'virtual reality': '68514a1115e8b86aae68e83e',
    'web comic': '685148d715e8b86aae68e50d',
    'wuxia': '6851490715e8b86aae68e5c3',
    'yaoi': '68932f68a943baf927094eaa',
    'yuri': '6896a885a943baf927094f66',
    'zombies': '6851490c15e8b86aae68e5d3',
  };

  Future<Map<String, String>> _genreIds() async => _tags;

  /// Strips a language suffix so translated ids resolve to the same page.
  static String _baseSlug(String mangaId) {
    final dot = mangaId.lastIndexOf('.');
    if (dot <= 0) return mangaId;
    return mangaId.substring(0, dot);
  }

  static const List<String> _kGenres = [
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Fantasy',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Supernatural',
    'Thriller',
    'Tragedy',
    'Mystery',
    'Historical',
    'Horror',
    'Psychological',
    'Seinen',
    'Shoujo',
    'Shounen',
    'Sports',
    'Martial Arts',
    'Mecha',
    'Military',
    'School Life',
    'Shota',
    'Gore',
    'Sexual Violence',
    '4-Koma',
    'Adaptation',
    'Anthology',
    'Award Winning',
    'Doujinshi',
    'Fan Colored',
    'Full Color',
    'Long Strip',
    'Official Colored',
    'Oneshot',
    'Self-Published',
    'Web Comic',
    'Adult',
    'Boys\' Love',
    'Crime',
    'Ecchi',
    'Girls\' Love',
    'Isekai',
    'Magical Girls',
    'Mature',
    'Medical',
    'Philosophical',
    'Shounen Ai',
    'Smut',
    'Superhero',
    'Wuxia',
    'Yaoi',
    'Yuri',
    'Aliens',
    'Animals',
    'Comics',
    'Cooking',
    'Crossdressing',
    'Delinquents',
    'Demons',
    'Genderswap',
    'Ghosts',
    'Gyaru',
    'Harem',
    'Hentai',
    'Incest',
    'Loli',
    'Mafia',
    'Magic',
    'Manhwa 18+',
    'Monster Girls',
    'Monsters',
    'Music',
    'Ninja',
    'Office Workers',
    'Police',
    'Post-Apocalyptic',
    'Reincarnation',
    'Reverse Harem',
    'Samurai',
    'Supernatural',
    'Survival',
    'Time Travel',
    'Traditional Games',
    'Vampires',
    'Video Games',
    'Villainess',
    'Virtual Reality',
    'Zombies',
  ];
}
