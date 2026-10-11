import 'dart:convert';

import '../models/chapter.dart';
import '../models/manga.dart';
import '../models/manga_details.dart';
import '../models/manga_filter.dart';
import '../models/manga_source.dart';
import 'source_network.dart';

/// SeiManga — 1.seimanga.me, a Russian adult catalogue running the "ressei"
/// front end shared by the Grouple mirror family.
///
/// The site profiles its visitors: a plain request without a session is shown
/// an age gate on adult pages, but the gate is skipped by the `?mtr=true`
/// query the site appends once a visitor has confirmed. Every HTML request
/// here carries it. Listings and search answer a same-origin JSON API
/// (`/api/catalog/search`), a title page is server rendered and carries both
/// its metadata and its whole chapter table, and the reader page embeds its
/// page list in an inline `rm_h.readerInit(...)` call.
///
/// The scans themselves live on a separate host (`sei.one-way.work`) that
/// only answers when the site is sent as `Referer`, so [headers] pins both a
/// desktop user agent and that referer — the reader hands [headers] straight
/// to its image loader, which is why they must stay a plain map of strings.
///
/// The catalogue is UTF-8 but [DioSource.grabText] decodes response bytes as
/// Latin-1, which mangles every Cyrillic title, so this source fetches bytes
/// and decodes them itself.
class SeiMangaSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'seimanga';

  @override
  String get name => 'SeiManga';

  @override
  String get baseUrl => 'https://1.seimanga.me';

  @override
  String websiteMangaUrl(String mangaId) => '$websiteUrl/$mangaId';

  @override
  String get readerBaseUrl => 'https://1.seimanga.me';

  @override
  String get iconUrl => 'https://1.seimanga.me/favicon.ico';

  @override
  String get languageCode => 'ru';

  /// No login is needed: the adult gate is cleared with `?mtr=true`, not an
  /// account, so the in-app sign-in flow has nothing to capture.
  @override
  bool get supportsSignIn => false;

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  @override
  Map<String, String>? get headers => {
    'User-Agent': _userAgent,
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,'
        'image/avif,image/webp,*/*;q=0.8',
    // The scan host refuses image requests that arrive without it.
    'Referer': '$baseUrl/',
  };

  /// Asks the catalogue API rather than the SPA shell, so the connectivity
  /// check fails when the API (not just the static bundle) is unreachable.
  @override
  String get testUrl =>
      '$baseUrl/api/catalog/search?offset=0&q=&sortType=RATING'
      '&years=1950,2026';

  /// The API pages in fixed 50-item blocks; `limit` in a request is ignored.
  static const int _pageSize = 50;

  /// Production status codes mapped onto the detail screen's vocabulary.
  static const Map<String, String> _productionStatus = {
    'PROGRESS': 'ongoing',
    'FINISHED': 'completed',
    'PLANNED': 'upcoming',
    'POSTPONED': 'hiatus',
    'CANCELED': 'cancelled',
    'NON_FINISHED': 'ongoing',
  };

  /// The filter sheet's publication states mapped onto the site's own values.
  /// The sheet has no "hiatus", so POSTPONED is never asked for.
  static const Map<String, String> _filterStatus = {
    'finished': 'FINISHED',
    'dropped': 'CANCELED',
    'upcoming': 'PLANNED',
  };

  /// Genre name -> catalogue element id, cached for the session. Null until
  /// the advanced-search page has been read.
  Map<String, String>? _genreIds;

  /// The year bounds the site advertises, used to fill a filter's open range.
  int _yearMin = 1950;
  int? _yearMax;

  /// The last title page read, so the details/chapters/total/latest trip only
  /// fetches the (often large) HTML once.
  String? _detailId;
  String? _detailHtml;

  /// Fetches [path] (relative to the effective base URL, or absolute) and
  /// decodes it as UTF-8. Returns an empty string on any miss.
  Future<String> _get(String path) async {
    final base = await effectiveBaseUrl;
    final url = path.startsWith('http') ? path : '$base$path';
    final bytes = await grabBytes(url);
    if (bytes == null || bytes.isEmpty) return '';
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Reads and caches a title page keyed by [mangaId].
  Future<String> _detailPage(String mangaId) async {
    if (_detailId == mangaId && _detailHtml != null) return _detailHtml!;
    final html = await _get('/$mangaId');
    _detailId = mangaId;
    _detailHtml = html;
    return html;
  }

  /// Runs a `/api/catalog/search` query. Repeated element/status keys are built
  /// by hand because a map cannot express them.
  Future<List<Manga>> _catalogSearch({
    required String query,
    int page = 1,
    String sortType = 'POPULARITY',
    int? yearFrom,
    int? yearTo,
    List<String> includeIds = const [],
    List<String> excludeIds = const [],
    List<String> statuses = const [],
  }) async {
    final offset = (page - 1).clamp(0, 1 << 20) * _pageSize;
    final from = yearFrom ?? _yearMin;
    final to = yearTo ?? _yearMax ?? DateTime.now().year;
    final buffer = StringBuffer('/api/catalog/search?offset=')
      ..write(offset)
      ..write('&q=')
      ..write(Uri.encodeComponent(query))
      ..write('&sortType=')
      ..write(sortType)
      ..write('&years=')
      ..write(from)
      ..write(',')
      ..write(to);
    for (final elementId in includeIds) {
      buffer.write('&includeElementIds=$elementId');
    }
    for (final elementId in excludeIds) {
      buffer.write('&excludeElementIds=$elementId');
    }
    for (final status in statuses) {
      buffer.write('&includeProductionStatuses=$status');
    }
    final body = await _get(buffer.toString());
    if (body.isEmpty) return const [];
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final list = decoded['list'];
    if (list is! List) return const [];
    final result = <Manga>[];
    for (final item in list) {
      if (item is! Map) continue;
      final manga = _mangaFromCatalog(item.cast<String, dynamic>());
      if (manga != null) result.add(manga);
    }
    return result;
  }

  Manga? _mangaFromCatalog(Map<String, dynamic> item) {
    final element = item['elementId'];
    final mangaId = element is Map
        ? element['linkName']?.toString() ?? ''
        : '';
    if (mangaId.isEmpty) return null;
    return Manga(
      id: mangaId,
      title: (item['name'] ?? '').toString(),
      coverUrl: (item['picUrl'] ?? '').toString(),
      sourceId: id,
      tags: _catalogGenres(item['elements']),
    );
  }

  /// Pulls the genre names out of a catalogue item's mixed `elements` list.
  List<String> _catalogGenres(Object? elements) {
    if (elements is! List) return const [];
    final out = <String>[];
    for (final element in elements) {
      if (element is! Map) continue;
      if (element['typeName']?.toString() != 'genre') continue;
      final name = element['name']?.toString() ?? '';
      if (name.isNotEmpty) out.add(name);
    }
    return out;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) {
    return _catalogSearch(query: '', page: page, sortType: 'POPULARITY');
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) {
    final term = query.trim();
    if (term.isEmpty) return Future.value(const []);
    return _catalogSearch(query: term, page: page, sortType: 'POPULARITY');
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    final html = await _detailPage(mangaId);
    // A dead slug answers 200 with the site's "page not found" shell, which
    // carries none of the hero markup.
    if (html.isEmpty || !html.contains('cr-hero-names__main')) return null;
    final title = _heroTitle(html) ?? mangaId;
    return MangaDetails(
      id: mangaId,
      title: title,
      coverUrl: _heroCover(html) ?? '',
      sourceId: id,
      description: _description(html, title),
      author: _anchors(html, 'person').join(', '),
      status: _status(html),
      year: _year(html),
      tags: _tags(html),
      totalChapters: _chapterRows(html).length,
      language: 'ru',
    );
  }

  String? _heroTitle(String html) {
    final match = RegExp(
      r'<h1[^>]*class="cr-hero-names__main[^"]*"[^>]*>(.*?)</h1>',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    final text = _stripTags(match.group(1) ?? '');
    return text.isEmpty ? null : text;
  }

  /// The first hero poster. Titles with several covers repeat the class; the
  /// primary one comes first and carries `src`, though some are lazy and only
  /// offer `data-src`.
  String? _heroCover(String html) {
    final tag = RegExp(
      r'<img[^>]*cr-hero-poster__img[^>]*>',
    ).firstMatch(html)?.group(0);
    if (tag == null) return null;
    final data = RegExp(r'data-src="([^"]+)"').firstMatch(tag)?.group(1);
    final src = RegExp(r'[\s"]src="([^"]+)"').firstMatch(tag)?.group(1);
    final url = (src != null && src.isNotEmpty) ? src : data;
    return (url == null || url.isEmpty) ? null : url;
  }

  /// The synopsis is only server rendered inside the meta description, as
  /// `Описание манги <title>: <synopsis>`.
  String _description(String html, String title) {
    final match = RegExp(
      r'<meta name="description" content="([^"]*)"',
    ).firstMatch(html);
    final text = _unescape(match?.group(1) ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final prefix = 'Описание манги $title:';
    if (title.isNotEmpty && text.startsWith(prefix)) {
      return text.substring(prefix.length).trim();
    }
    // The site pads the label with extra spaces, so fall back to dropping
    // whatever precedes the first colon.
    const label = 'Описание манги ';
    final colon = text.indexOf(':');
    if (text.startsWith(label) && colon > 0) {
      return text.substring(colon + 1).trim();
    }
    return text;
  }

  /// The status text is redundant; the `data-production-status` code is not.
  String _status(String html) {
    final code = RegExp(
      r'data-production-status="([^"]*)"',
    ).firstMatch(html)?.group(1);
    return _productionStatus[code] ?? '';
  }

  String _year(String html) {
    final match = RegExp(r'href="/list/year/(\d{4})"').firstMatch(html);
    return match?.group(1) ?? '';
  }

  /// Genre and tag names, read from the title page's link list and deduped.
  List<String> _tags(String html) {
    final out = <String>[];
    final seen = <String>{};
    for (final name in [..._anchors(html, 'genre'), ..._anchors(html, 'tag')]) {
      if (seen.add(name)) out.add(name);
    }
    return out;
  }

  /// The text of every `/list/<section>/...` link, deduped in page order.
  List<String> _anchors(String html, String section) {
    final re = RegExp(
      '<a[^>]*href="/list/$section/[^"]*"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    final out = <String>[];
    final seen = <String>{};
    for (final match in re.allMatches(html)) {
      final text = _stripTags(match.group(1) ?? '').replaceFirst(
        RegExp(r'^#\s*'),
        '',
      );
      if (text.isNotEmpty && seen.add(text)) out.add(text);
    }
    return out;
  }

  Iterable<RegExpMatch> _chapterRows(String html) {
    return RegExp(r'<tr class="item-row"[^>]*>(.*?)</tr>', dotAll: true)
        .allMatches(html);
  }

  List<Chapter> _chapters(String html) {
    final result = <Chapter>[];
    for (final row in _chapterRows(html)) {
      final rowHtml = row.group(1) ?? '';
      final href = RegExp(r'href="([^"]+)"').firstMatch(rowHtml)?.group(1);
      if (href == null || href.isEmpty) continue;
      // The link carries `?mtr=true`; the chapter id is the bare path so
      // getPageUrls can rebuild the reader URL.
      final path = href.split('?').first.replaceFirst(RegExp(r'^/'), '');
      if (path.isEmpty) continue;
      final rawDate = RegExp(
        r'data-date-raw="([^"]*)"',
      ).firstMatch(rowHtml)?.group(1);
      final label = RegExp(
        r'class="chapter-link[^"]*"[^>]*>(.*?)</a>',
        dotAll: true,
      ).firstMatch(rowHtml)?.group(1);
      final number = RegExp(
        r'(\d+(?:[.,]\d+)?)\s*$',
      ).firstMatch(_stripTags(label ?? ''))?.group(1);
      result.add(
        Chapter(
          id: path,
          title: '',
          chapterNumber: number ?? '',
          releaseDate: (rawDate == null || rawDate.isEmpty) ? null : rawDate,
          url: '$baseUrl/$path',
        ),
      );
    }
    // The table lists newest first; hand chapters back oldest first.
    return result.reversed.toList();
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    return _chapters(await _detailPage(mangaId));
  }

  @override
  Future<int> getTotalChapters(String mangaId) async {
    return _chapterRows(await _detailPage(mangaId)).length;
  }

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async {
    final rows = _chapterRows(await _detailPage(mangaId)).toList();
    if (rows.isEmpty) return null;
    final rowHtml = rows.first.group(1) ?? '';
    final rawDate = RegExp(
      r'data-date-raw="([^"]*)"',
    ).firstMatch(rowHtml)?.group(1);
    if (rawDate == null || rawDate.isEmpty) return null;
    final date = DateTime.tryParse(rawDate);
    if (date == null) return null;
    final label = RegExp(
      r'class="chapter-link[^"]*"[^>]*>(.*?)</a>',
      dotAll: true,
    ).firstMatch(rowHtml)?.group(1);
    final number = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*$',
    ).firstMatch(_stripTags(label ?? ''))?.group(1);
    if (number == null || number.isEmpty) return null;
    return ('Chapter $number', date);
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    final path = chapterId.split('?').first.trim();
    if (path.isEmpty) return const [];
    final html = await _get('/$path?mtr=true');
    if (html.isEmpty) return const [];
    final start = html.indexOf('rm_h.readerInit(');
    if (start < 0) return const [];
    // Each page is `['<host>','',"<path>?<signature>",<w>,<h>,'']`; the
    // site's own reader strips the signature before requesting the scan.
    final tuple = RegExp(
      r"""\[\s*'(https?://[^']+)'\s*,\s*'[^']*'\s*,\s*["']([^"']+)["']""",
    );
    final result = <String>[];
    final seen = <String>{};
    for (final match in tuple.allMatches(html.substring(start))) {
      final url = '${match.group(1)}${match.group(2)}';
      final query = url.indexOf('?');
      final clean = query >= 0 ? url.substring(0, query) : url;
      if (seen.add(clean)) result.add(clean);
    }
    return result;
  }

  /// Loads (and caches) the genre table and year bounds the filter sheet needs.
  Future<Map<String, String>> _loadGenres() async {
    final cached = _genreIds;
    if (cached != null) return cached;
    final html = await _get('/search/advanced');
    final map = <String, String>{};
    final genreBlock = RegExp(
      r'window\.__FILTERS\.genre\s*=\s*(\{.*?\});',
      dotAll: true,
    ).firstMatch(html);
    if (genreBlock != null) {
      final decoded = jsonDecode(genreBlock.group(1) ?? '{}');
      if (decoded is Map) {
        decoded.forEach((key, value) {
          final genreId = key.toString();
          final name = value.toString();
          if (genreId.isNotEmpty && name.isNotEmpty) map[name] = genreId;
        });
      }
    }
    final years = RegExp(
      r'window\.__FILTERS\.years\s*=\s*\{\s*min:\s*(\d+)\s*,\s*max:\s*'
      r'(\d+)\s*\}',
    ).firstMatch(html);
    if (years != null) {
      _yearMin = int.tryParse(years.group(1) ?? '') ?? _yearMin;
      _yearMax = int.tryParse(years.group(2) ?? '');
    }
    return _genreIds = map;
  }

  @override
  Future<List<String>> getAvailableTags() async {
    return (await _loadGenres()).keys.toList();
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    final map = await _loadGenres();
    final ids = <String>[];
    for (final tag in tags) {
      final elementId = map[tag];
      if (elementId != null) ids.add(elementId);
    }
    if (ids.isEmpty) return const [];
    return _catalogSearch(query: '', page: page, includeIds: ids);
  }

  @override
  Future<List<Manga>> searchWithFilter(
    MangaFilter filter, {
    int page = 1,
  }) async {
    final map = await _loadGenres();
    final includeIds = <String>[];
    for (final genre in filter.genres) {
      final elementId = map[genre];
      if (elementId != null) includeIds.add(elementId);
    }
    final excludeIds = <String>[];
    for (final genre in filter.excludeGenres) {
      final elementId = map[genre];
      if (elementId != null) excludeIds.add(elementId);
    }
    final statuses = <String>[];
    for (final status in filter.status) {
      final mapped = _filterStatus[status];
      if (mapped != null) statuses.add(mapped);
    }
    return _catalogSearch(
      query: '',
      page: page,
      sortType: _sortFor(filter.sort),
      yearFrom: filter.yearFrom ?? _yearMin,
      yearTo: filter.yearTo ?? _yearMax,
      includeIds: includeIds,
      excludeIds: excludeIds,
      statuses: statuses,
    );
  }

  String _sortFor(String sort) {
    switch (sort) {
      case 'alphabetical':
        return 'NAME';
      case 'popularity':
        return 'POPULARITY';
      case 'updated':
        return 'DATE_UPDATE';
      // The site has no chapter-count sort; newest is the closest stable one.
      case 'chapterCount':
      default:
        return 'DATE_UPDATE';
    }
  }

  /// Collapses an HTML fragment to its visible text.
  String _stripTags(String html) {
    return _unescape(
      html
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    );
  }

  /// Decodes the handful of entities the catalogue actually emits.
  String _unescape(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&laquo;', '«')
        .replaceAll('&raquo;', '»')
        .replaceAll('&amp;', '&');
  }
}
