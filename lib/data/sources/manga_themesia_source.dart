import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;

import '../models/chapter.dart';
import '../models/manga.dart';
import '../models/manga_details.dart';
import '../models/manga_filter.dart';
import '../models/manga_source.dart';
import '../models/manga_themesia_site_config.dart';
import 'captcha_gate.dart';
import 'source_network.dart';

/// One generic source for every MangaThemesia-themed site.
///
/// All the bundled MangaThemesia engines share one theme library
/// (`lib-multisrc/mangathemesia` in keiyoushi/extensions-source); sites differ
/// only in base URL, name, language, icon, and optional selector overrides,
/// all driven by [MangaThemesiaSiteConfig]. This mirrors the
/// [MadaraSource] / [MadaraSiteConfig] split used for Madara sites.
///
/// Ported from the theme's `MangaThemesia.kt`. The theme's jQuery-style
/// selectors (`:contains`, `:has`) have no equivalent in `package:html`, so
/// the label-based lookups below reimplement them in Dart.
class MangaThemesiaSource extends DioSource implements MangaSource {
  MangaThemesiaSource(this.config);

  final MangaThemesiaSiteConfig config;

  /// Genre display name -> filter value, filled by [getAvailableTags] so a
  /// later filtered browse can send slugs instead of labels.
  final Map<String, String> _genreValues = {};

  static const String _defaultSearchSelector =
      '.utao .uta .imgu, .listupd .bs .bsx, .listo .bs .bsx';

  static final RegExp _mangaPageIdRegex = RegExp(
    r'''(?:post_id["']?\s*:\s*|ts_dynamic_ajax_view\D*|tsUpdateView\D*)(\d+)''',
  );
  static final RegExp _chapterPageIdRegex = RegExp(r'chapter_id\s*=\s*(\d+);');
  static final RegExp _imageListRegex = RegExp(
    r'''["']?(?:images|imageUrls)["']?\s*[:=]\s*(\[.*?])''',
    dotAll: true,
  );

  // --- MangaSource interface ---

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  String get baseUrl => config.baseUrl;

  @override
  String get readerBaseUrl => config.baseUrl;

  @override
  String get languageCode => config.langCode;

  @override
  String get iconUrl => config.iconUrl;

  @override
  String get networkSourceId => config.id;

  @override
  String websiteMangaUrl(String mangaId) => config.mangaUrl(mangaId);

  @override
  Map<String, String>? get headers => {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
    // Several themed sites hotlink-protect their images: the request must
    // carry the site itself as `Referer` or the CDN answers 403 (Sushi-Scan's
    // covers and its `c*.sushiscan.net` reader pages both do). The reader sends
    // these headers on every page-image GET, so the origin is the safe value.
    'Referer': '${config.baseUrl}/',
  };

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) =>
      getSearchMangaList(page: page, order: 'popular');

  /// Latest updates (the theme's default listing order).
  Future<List<Manga>> getLatestUpdates({int page = 1}) =>
      getSearchMangaList(page: page, order: 'update');

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) {
    if (query.trim().isEmpty) return Future.value(<Manga>[]);
    return getSearchMangaList(page: page, query: query.trim());
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) {
    if (tags.isEmpty) return Future.value(<Manga>[]);
    return getSearchMangaList(page: page, genres: tags);
  }

  @override
  Future<List<Manga>> searchWithFilter(
    MangaFilter filter, {
    int page = 1,
  }) {
    final order = switch (filter.sort) {
      'alphabetical' => 'title',
      'popularity' => 'popular',
      'updated' => 'update',
      _ => null,
    };
    final status = filter.status.contains('finished')
        ? 'completed'
        : filter.status.contains('dropped')
            ? 'dropped'
            : null;
    final genres = <String>[
      for (final tag in filter.genres) _genreValue(tag),
      for (final tag in filter.excludeGenres) '-${_genreValue(tag)}',
    ];
    return getSearchMangaList(
      page: page,
      order: order,
      status: status,
      genres: genres.isEmpty ? null : genres,
      year: filter.yearFrom?.toString(),
      yearTo: filter.yearTo?.toString(),
    );
  }

  /// Search + filter listing shared by popular / latest / search / tags.
  Future<List<Manga>> getSearchMangaList({
    required int page,
    String query = '',
    String? status,
    String? type,
    String? order,
    List<String>? genres,
    String? author,
    String? year,
    String? yearTo,
  }) async {
    try {
      final url = config.listingUrl(
        page: page,
        query: query,
        status: status,
        type: type,
        order: order,
        genres: genres,
        author: author,
        year: year,
        yearTo: yearTo,
      );
      return searchMangaParse(await grabText(url), pageUrl: url);
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
      return [];
    }
  }

  /// Parse search/popular/latest/tag results from HTML.
  List<Manga> searchMangaParse(String html, {String pageUrl = ''}) {
    if (html.isEmpty) return [];
    final document = parser.parse(html);
    final base = pageUrl.isEmpty ? config.baseUrl : pageUrl;
    final selector = config.searchMangaSelector ?? _defaultSearchSelector;
    var cards = document.querySelectorAll(selector);

    final results = <Manga>[];
    final seen = <String>{};
    void addCard(dom.Element card) {
      final img = _coverImage(card);
      final cover = img == null ? '' : _imageUrl(img, base);
      final link = card.querySelector('a[href]');
      final href = link?.attributes['href'] ?? '';
      final title = (link?.attributes['title'] ?? '').trim().isNotEmpty
          ? (link!.attributes['title']!).trim()
          : (link?.text.trim() ?? '');
      if (href.isEmpty || title.isEmpty) return;
      final mangaId = _fromPath(href);
      if (mangaId.isEmpty || !seen.add(mangaId)) return;
      results.add(
        Manga(
          id: mangaId,
          title: title,
          coverUrl: cover,
          sourceId: config.id,
        ),
      );
    }

    if (cards.isEmpty) {
      // WordPress returns an ordinary themed page for a page number past the
      // last one, with an empty result list plus the sidebar's popular-series
      // links. Those links look exactly like listing cards, so without this
      // check every page past the end repeated the sidebar forever (Rakuen
      // Translations: 35 series on 2 pages, then "list-mode" + 11 repeats).
      if (document.querySelector('.noresult, .no-result, .noresults') !=
          null) {
        return [];
      }
      // Skins move the card markup around; fall back to the series links.
      cards = document.querySelectorAll('a[href]');
      for (final link in cards) {
        final href = link.attributes['href'] ?? '';
        if (!_looksLikeSeriesLink(href)) continue;
        final title =
            (link.attributes['title'] ?? '').trim().isNotEmpty
                ? link.attributes['title']!.trim()
                : link.text.trim();
        if (title.isEmpty) continue;
        final mangaId = _fromPath(href);
        if (mangaId.isEmpty || !seen.add(mangaId)) continue;
        final container = _cardFor(link);
        final img = container == null
            ? link.querySelector('img')
            : _coverImage(container);
        results.add(
          Manga(
            id: mangaId,
            title: title,
            coverUrl: img == null ? '' : _imageUrl(img, base),
            sourceId: config.id,
          ),
        );
      }
      return results;
    }

    for (final card in cards) {
      addCard(card);
    }
    return results;
  }

  bool _looksLikeSeriesLink(String href) {
    if (href.isEmpty) return false;
    final path = _fromPath(href);
    if (path.isEmpty) return false;
    final directory = config.mangaUrlDirectory.replaceAll(RegExp(r'^/+'), '');
    if (!path.startsWith(directory)) return false;
    // `/manga/<slug>` is a series, `/manga/<slug>/<chapter>` is not.
    return path.split('/').length == 2;
  }

  dom.Element? _cardFor(dom.Element link) {
    dom.Element? node = link.parent;
    for (var i = 0; i < 5 && node != null; i++) {
      if (node.querySelector('img') != null) return node;
      node = node.parent;
    }
    return null;
  }

  @override
  Future<List<String>> getAvailableTags() async {
    try {
      final url = '${config.baseUrl}${config.mangaUrlDirectory}/';
      final html = await grabText(url);
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final tags = <String>[];
      for (final item in document.querySelectorAll('ul.genrez li')) {
        final label = item.querySelector('label');
        final input = item.querySelector('input[type="checkbox"]');
        final name = label?.text.trim() ?? '';
        if (name.isEmpty) continue;
        final value = (input?.attributes['value'] ?? name).trim();
        _genreValues[name.toLowerCase()] = value;
        if (!tags.contains(name)) tags.add(name);
      }
      if (tags.isNotEmpty) return tags;
      for (final input in document.querySelectorAll(
        'form input[type="checkbox"][name="genre[]"]',
      )) {
        final label = input.parent?.text.trim() ?? '';
        final value = (input.attributes['value'] ?? '').trim();
        if (label.isEmpty || value.isEmpty) continue;
        _genreValues[label.toLowerCase()] = value;
        if (!tags.contains(label)) tags.add(label);
      }
      return tags;
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
      return [];
    }
  }

  String _genreValue(String tag) =>
      _genreValues[tag.toLowerCase()] ?? tag;

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final url = config.mangaUrl(mangaId);
      var document = parser.parse(await grabText(url));
      if (document.body == null) return null;

      // A chapter page links to its series; follow it so "Open details" from a
      // reader deep link resolves instead of parsing the chapter page.
      final seriesLink = document.querySelector('.allc a[href]');
      if (seriesLink != null) {
        final seriesUrl = _absolute(
          seriesLink.attributes['href'] ?? '',
          url,
        );
        if (seriesUrl.isNotEmpty) {
          final seriesDoc = parser.parse(await grabText(seriesUrl));
          if (seriesDoc.body != null) document = seriesDoc;
        }
      }
      return mangaDetailsParse(document, mangaId: mangaId);
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
      return null;
    }
  }

  /// Parse manga details from a series page.
  MangaDetails? mangaDetailsParse(
    dom.Document document, {
    required String mangaId,
  }) {
    final root = document.querySelector(
          config.seriesDetailsSelector ??
              'div.bigcontent, div.animefull, div.main-info, div.postbody',
        ) ??
        document.body;
    if (root == null) return null;

    final title = _firstText(root, [
      config.seriesTitleSelector ??
          '.entry-title, .ts-breadcrumb li:last-child span',
      'h1.entry-title',
      '.entry-title',
      'h1',
    ]);
    if (title.isEmpty) return null;

    final info = _infoTable(root);
    final author = _infoValue(info, const [
      'author',
      'posted by',
      'uploaded by',
      'uploader',
      'auteur',
      'autor',
      'المؤلف',
      'mangaka',
      'seniman',
      'pengarang',
      'yazar',
      'ผู้แต่ง',
      'นักเขียน',
      'story',
      'writer',
    ]);
    final authorOrArtist = author.isNotEmpty
        ? author
        : _infoValue(info, const [
            'artist',
            'artiste',
            'artista',
            'الرسام',
            'illustrator',
            'İllüstratör',
            'Çizer',
            'Sanatçı',
            'นักวาด',
          ]);

    var description = _firstText(root, [
      '.desc',
      '.entry-content[itemprop="description"]',
      '#synopsis',
      '.synp',
      '.summary__content',
      '.manga-excerpt',
    ]);
    if (description.isEmpty) {
      description = _firstText(document.documentElement!, [
        'meta[property="og:description"]',
        'meta[name="description"]',
      ]);
    }
    final altNames = _infoValue(info, const [
      'alternative',
      'alternatif',
      'الأسماء الثانوية',
      'alt name',
      'other name',
    ]);
    if (altNames.isNotEmpty) {
      final names = altNames
          .split(RegExp(r'[|/•,;]'))
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty)
          .map((n) => '- $n')
          .join('\n');
      description = description.isEmpty
          ? 'Alternative names:\n$names'
          : '$description\n\nAlternative names:\n$names';
    }

    final tags = <String>[];
    void addTag(String raw) {
      final tag = _capitalize(raw.trim());
      if (tag.isNotEmpty && !tags.contains(tag)) tags.add(tag);
    }

    for (final a in root.querySelectorAll(
      config.seriesDetailsSelector == null
          ? 'div.gnr a, .mgen a, .seriestugenre a, a[href*="/genres/"], a[href*="/genre/"], a[href*="genre="]'
          : 'a',
    )) {
      addTag(a.text);
    }
    for (final tag in _infoValue(info, const ['genre', 'التصنيف']).split(',')) {
      addTag(tag);
    }
    addTag(
      _infoValue(info, const [
        'type',
        'ประเภท',
        'النوع',
        'tipe',
        'türü',
      ]),
    );

    final statusRaw = config.statusSelector != null
        ? root.querySelector(config.statusSelector!)?.text ?? ''
        : _infoValue(info, const [
            'status',
            'statut',
            'durum',
            '連載状況',
            'estado',
            'الحالة',
            'حالة العمل',
            'สถานะ',
            'stato',
            'statüsü',
          ]);

    final thumb = root.querySelector(
          '.infomanga > div[itemprop="image"] img, .thumb img, .summary_image img, img[itemprop="image"], img.wp-post-image, .lm4-poster-image',
        ) ??
        document.querySelector('meta[property="og:image"]');
    final cover = thumb == null
        ? ''
        : thumb.localName == 'meta'
            ? (thumb.attributes['content'] ?? '').trim()
            : _imageUrl(thumb, config.mangaUrl(mangaId));

    return MangaDetails(
      id: mangaId,
      title: title,
      coverUrl: cover,
      sourceId: config.id,
      description: description,
      author: authorOrArtist,
      status: _parseStatus(statusRaw),
      year: _infoValue(info, const [
        'year',
        'released',
        'release',
        'año',
        'année',
        'Год',
        'السنة',
      ]),
      tags: tags,
      language: config.langCode,
    );
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final url = config.mangaUrl(mangaId);
      final html = await grabText(url);
      if (html.isEmpty) return [];
      return chapterListParse(html);
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
      return [];
    }
  }

  /// Parse the chapter list from a series page.
  List<Chapter> chapterListParse(String html) {
    if (html.isEmpty) return [];
    final document = parser.parse(html);
    var items = document.querySelectorAll(
      config.chapterListSelector ??
          'div.bxcl li, div.cl li, #chapterlist li',
    );
    if (items.isEmpty) {
      // Default theme markup: each chapter is a `li` holding a `.chbox` with
      // the number and a `.eph-num` with the link. `:has` cannot be expressed
      // with `package:html`, so filter in Dart.
      items = [
        for (final item in document.querySelectorAll('li'))
          if (item.querySelector('a[href]') != null &&
              (item.querySelector('.chbox') != null ||
                  item.querySelector('.eph-num') != null))
            item,
      ];
    }
    if (items.isEmpty) {
      // Custom skins (e.g. Leemiau's `.lm4-chapter-card`) keep the link itself
      // as the chapter row, so accept any anchor whose href looks like one.
      items = [
        for (final link in document.querySelectorAll(
          'a[href][data-chapter-id], a[data-lm4-chapter-link], '
          'a.lm4-chapter-link, a[href]',
        ))
          if (_looksLikeChapterLink(link.attributes['href'] ?? '')) link,
      ];
    }

    final chapters = <Chapter>[];
    final seen = <String>{};
    for (final item in items) {
      final link = item.localName == 'a' ? item : item.querySelector('a[href]');
      final href = link?.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final absoluteHref = _absolute(href, '${config.baseUrl}/');
      // Chapters that live on a mirror host (Leemiau serves its reader from
      // leer.lectovela.com) cannot be rebuilt from `baseUrl` later, so keep the
      // full URL as the id.
      final chapterId = _isSameHost(absoluteHref)
          ? _fromPath(href)
          : absoluteHref;
      if (chapterId.isEmpty || !seen.add(chapterId)) continue;

      final numberEl = _firstOf(item, [
        '.lch a',
        '.chapternum',
        '.lm4-chapter-subtitle',
        '.lm4-chapter-name',
      ]);
      final rawTitle = (numberEl?.text.trim().isNotEmpty ?? false)
          ? numberEl!.text.trim()
          : (link?.text.trim() ?? '');
      final title = rawTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (title.isEmpty) continue;

      final dateEl = item.querySelector('.chapterdate, .lm4-chapter-date');
      final dateText = dateEl?.text.trim();
      final parsedDate = config.parseChapterDate(dateText);
      final releaseDate = parsedDate == null
          ? (dateText ?? '')
          : _isoDate(parsedDate);

      chapters.add(
        Chapter(
          id: chapterId,
          title: title,
          chapterNumber: _chapterNumber(chapterId, title),
          releaseDate: releaseDate,
          url: config.chapterUrl(chapterId),
        ),
      );
    }

    // The newest chapter often has no per-row date; the theme borrows the
    // series' "Updated On" timestamp for it.
    if (chapters.isNotEmpty && (chapters.first.releaseDate ?? '').isEmpty) {
      final stamp = _updatedOn(document) ?? '';
      if (stamp.isNotEmpty) {
        chapters[0] = Chapter(
          id: chapters.first.id,
          title: chapters.first.title,
          chapterNumber: chapters.first.chapterNumber,
          releaseDate: stamp,
          url: chapters.first.url,
        );
      }
    }
    return chapters;
  }

  bool _looksLikeChapterLink(String href) {
    final path = _fromPath(href);
    if (path.isEmpty) return false;
    final last = path.split('/').last;
    final chapterLike = last.contains('chapter') ||
        RegExp(r'cap[ií]tulo', caseSensitive: false).hasMatch(last) ||
        last.contains('cap-') ||
        last.contains('ch-') ||
        RegExp(r'^(?:ep|episode)[-_]?\d+', caseSensitive: false).hasMatch(last) ||
        RegExp(r'^\d+(?:[.\-]\d+)?$').hasMatch(last);
    if (!chapterLike) return false;
    // Under the manga directory, a series page is `/manga/<slug>` and a
    // chapter adds at least one more segment. Custom skins (Leemiau) put
    // chapter URLs at the site root instead, so any other path is accepted.
    final directory = config.mangaUrlDirectory.replaceAll(RegExp(r'^/+'), '');
    if (path.startsWith('$directory/')) return path.split('/').length >= 3;
    return true;
  }

  /// Whether [url] points at the configured site (ignoring a leading `www.`).
  /// Full URLs on a different host cannot be rebuilt from [config.baseUrl].
  bool _isSameHost(String url) {
    final target = Uri.tryParse(url);
    final base = Uri.tryParse(config.baseUrl);
    if (target == null || base == null) return true;
    if (!target.hasScheme || target.host.isEmpty) return true;
    String normalize(String host) =>
        host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    return normalize(target.host) == normalize(base.host);
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
      for (final chapter in chapters) {
        final date = config.parseChapterDate(chapter.releaseDate);
        if (date != null) return (chapter.title, date);
      }
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
    }
    return null;
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final url = config.chapterUrl(chapterId);
      final html = await grabText(url);
      if (html.isEmpty) return [];
      final document = parser.parse(html);

      _sendView(_postId(document));
      final pages = _pageListParse(document, url, html);
      if (pages.isNotEmpty) return pages;

      // A few skins keep the reader outside `#readerarea`.
      final images = document.querySelectorAll(
        'img.wp-manga-chapter-img, .reading-content img, #readerarea img, img[data-lm-orig-src]',
      );
      final fallback = <String>[];
      for (final img in images) {
        final src = _imageUrl(img, url);
        if (src.isNotEmpty && !fallback.contains(src)) fallback.add(src);
      }
      return fallback;
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
      return [];
    }
  }

  /// Parse page images from chapter HTML: `div#readerarea img`, or the
  /// base64-encoded `ts_reader.run({...})` blob some skins ship instead.
  List<String> _pageListParse(
    dom.Document document,
    String pageUrl, [
    String? rawHtml,
  ]) {
    final images = document.querySelectorAll(
      config.pageSelector ?? 'div#readerarea img',
    );
    final pages = <String>[];
    for (final img in images) {
      final src = _imageUrl(img, pageUrl);
      if (src.isNotEmpty && !pages.contains(src)) pages.add(src);
    }
    if (pages.isNotEmpty) return pages;

    final script = document.querySelector(
      'script[src^="data:text/javascript;base64,dHNfcmVhZGVyLnJ1bih7"]',
    );
    // `Document.toString()` is a debug label, not markup, so the inline
    // `ts_reader.run({...})` blob has to be scanned from the response body.
    var docString = rawHtml ?? document.outerHtml;
    final srcAttr = script?.attributes['src'];
    if (srcAttr != null && srcAttr.isNotEmpty) {
      final encoded = _substringAfter(srcAttr, 'base64,');
      if (encoded.isNotEmpty) {
        try {
          docString = utf8.decode(base64Decode(encoded));
        } catch (_) {
          // Not valid base64 after all; scan the HTML instead.
        }
      }
    }

    final match = _imageListRegex.firstMatch(docString);
    if (match == null) return [];
    final inner = match.group(1)!;
    try {
      final decoded = jsonDecode(inner);
      if (decoded is List) {
        final urls = <String>[];
        for (final item in decoded) {
          final url = _absolute('$item', pageUrl);
          if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
        }
        if (urls.isNotEmpty) return urls;
      }
    } catch (_) {
      // Single-quoted JS array: fall back to the quoted strings.
    }
    final urls = <String>[];
    for (final quoted in RegExp(r'''["']([^"']+)["']''').allMatches(inner)) {
      final url = _absolute(quoted.group(1)!, pageUrl);
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }
    return urls;
  }

  void _sendView(String? postId) {
    if (!config.sendViewCount || postId == null || postId.isEmpty) return;
    unawaited(() async {
      try {
        // The theme's jQuery handler posts a plain form body and sets the
        // AJAX header. Dio turns a `Map` into JSON, which the endpoint rejects
        // with a 400, so encode the body by hand.
        await postText(
          '${config.baseUrl}/wp-admin/admin-ajax.php',
          rawBody: 'action=dynamic_view_ajax&post_id=$postId',
          extraHeaders: {'X-Requested-With': 'XMLHttpRequest'},
        );
      } catch (_) {
        // Analytics only; never surface a failure to the reader.
      }
    }());
  }

  String? _postId(dom.Document document) {
    for (final script in document.querySelectorAll('script')) {
      final data = script.text;
      if (data.isEmpty) continue;
      final match =
          _mangaPageIdRegex.firstMatch(data) ?? _chapterPageIdRegex.firstMatch(data);
      final value = match?.group(1);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  // --- Parsing helpers ---

  /// Label -> value pairs from the theme's three markup variants:
  /// `.infotable tr`, `.tsinfo .imptdt`, and `.fmed`. Labels carry each site's
  /// language, so callers match against a list of known translations.
  Map<String, String> _infoTable(dom.Element root) {
    final info = <String, String>{};
    void put(String label, String value) {
      final key = label
          .replaceAll(':', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .toLowerCase();
      final clean = value.trim();
      if (key.isEmpty || clean.isEmpty) return;
      info.putIfAbsent(key, () => clean);
    }

    for (final row in root.querySelectorAll('.infotable tr')) {
      final cells = row.querySelectorAll('td, th');
      if (cells.length < 2) continue;
      put(cells.first.text, cells.last.text);
    }
    for (final item in root.querySelectorAll('.tsinfo .imptdt')) {
      final valueEl = item.querySelector('i, a, span');
      final value = valueEl?.text.trim() ?? '';
      if (value.isEmpty) {
        put(item.text, item.text);
      } else {
        put(item.text.replaceFirst(value, ''), value);
      }
    }
    for (final item in root.querySelectorAll('.fmed')) {
      final label = item.querySelector('b')?.text.trim() ?? '';
      final value = item.querySelector('span, a')?.text.trim() ?? '';
      put(label, value);
    }
    return info;
  }

  /// First info value whose label contains any of [keys] (exact matches win).
  String _infoValue(Map<String, String> info, List<String> keys) {
    for (final key in keys) {
      final exact = info[key.toLowerCase()];
      if (exact != null && exact.isNotEmpty) return exact;
    }
    for (final entry in info.entries) {
      for (final key in keys) {
        if (entry.key.contains(key.toLowerCase()) && entry.value.isNotEmpty) {
          return entry.value;
        }
      }
    }
    return '';
  }

  String _firstText(dom.Element root, List<String> selectors) {
    for (final selector in selectors) {
      final element = root.querySelector(selector);
      if (element == null) continue;
      final text = (element.localName == 'meta'
              ? (element.attributes['content'] ?? '')
              : element.text)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// First element matching one of [selectors], in the caller's priority
  /// order. A single comma-joined selector would return document order, which
  /// picks `.lm4-chapter-name` ("FINAL") over `.lm4-chapter-subtitle`.
  dom.Element? _firstOf(dom.Element root, List<String> selectors) {
    for (final selector in selectors) {
      final element = root.querySelector(selector);
      if (element != null && element.text.trim().isNotEmpty) return element;
    }
    return null;
  }

  /// The card's cover, not its language flag or type badge.
  ///
  /// The default card markup puts a flag `<img>` inside `.limit` before the
  /// real cover; Komik Station also tags its cover with `ts-post-image`.
  dom.Element? _coverImage(dom.Element card) {
    for (final selector in const [
      'img.ts-post-image',
      'img[itemprop="image"]',
      'img.wp-post-image',
      '.thumb img',
      'img',
    ]) {
      final img = card.querySelector(selector);
      if (img != null) return img;
    }
    return null;
  }

  String _imageUrl(dom.Element img, String pageUrl) {
    for (final attr in const [
      'data-lazy-src',
      'data-src',
      'data-cfsrc',
      'data-lm-orig-src',
      'data-original',
      'data-echo',
      'src',
    ]) {
      final value = (img.attributes[attr] ?? '').trim();
      // Lazy-loaders park a 1x1 data: URI in `src`, and some fill `data-src`
      // with the same placeholder; the real file is on another attribute.
      if (value.isEmpty || value.startsWith('data:')) continue;
      return _absolute(value, pageUrl);
    }
    return '';
  }

  String _absolute(String raw, String pageUrl) {
    var src = raw.trim();
    if (src.isEmpty) return '';
    if (src.startsWith('//')) return 'https:$src';
    final uri = Uri.tryParse(src);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) return src;
    try {
      return Uri.parse(pageUrl).resolve(src).toString();
    } catch (_) {
      return src.startsWith('/') ? '${config.origin}$src' : src;
    }
  }

  /// Strip scheme + host (and the WordPress subdirectory) from a URL, leaving
  /// the path without a leading slash, e.g. `manga/slug`.
  String _fromPath(String href) {
    var path = href.trim();
    if (path.isEmpty) return '';
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      path = uri.path;
    } else {
      final base = Uri.tryParse(config.baseUrl);
      if (base != null && base.path.isNotEmpty && path.startsWith(base.path)) {
        path = path.substring(base.path.length);
      }
    }
    final basePath = Uri.tryParse(config.baseUrl)?.path ?? '';
    if (basePath.isNotEmpty &&
        basePath != '/' &&
        (path == basePath || path.startsWith('$basePath/'))) {
      path = path.substring(basePath.length);
    }
    final query = path.indexOf('?');
    if (query != -1) path = path.substring(0, query);
    final fragment = path.indexOf('#');
    if (fragment != -1) path = path.substring(0, fragment);
    return path.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');
  }

  String _chapterNumber(String mangaId, String title) {
    final titleRe = RegExp(
      r'(?:chapter|cap[ií]tulo|cap)\s*(\d+(?:[.\-]\d+)*)',
      caseSensitive: false,
    );
    final titleMatch = titleRe.firstMatch(title);
    if (titleMatch != null) return titleMatch.group(1)!;
    // Thai ("ตอนที่ 214"), Japanese ("第214話") and Korean ("214화") titles
    // carry no Latin marker, and without a number the detail screen cannot sort
    // them numerically (an unstable sort then scrambles the list).
    for (final localized in const [
      r'ตอนที่\s*(\d+(?:[.\-]\d+)*)',
      r'ตอน\s*(\d+(?:[.\-]\d+)*)',
      r'第\s*(\d+(?:[.\-]\d+)*)\s*[話话回]',
      r'(\d+(?:[.\-]\d+)*)\s*[話话화]',
    ]) {
      final match = RegExp(localized).firstMatch(title);
      if (match != null) return match.group(1)!;
    }
    // Plenty of Madara sites title a chapter with nothing but its number.
    final bareNumber = RegExp(r'^\s*(\d+(?:[.\-]\d+)*)\s*$').firstMatch(title);
    if (bareNumber != null) return bareNumber.group(1)!;
    final pathRe = RegExp(
      r'[-_/](?:ch(?:apter)?|cap(?:itulo)?)[-_. ]?(\d+(?:[.\-]\d+)*)',
      caseSensitive: false,
    );
    final pathMatch = pathRe.firstMatch(mangaId);
    if (pathMatch != null) return pathMatch.group(1)!;
    // Custom skins put the number last in the slug (`...-capitulo-141`,
    // `...-214`), possibly with a trailing slash on cross-host URLs.
    final trailing = RegExp(r'[-_/](\d+(?:[.\-]\d+)*)/?$').firstMatch(mangaId);
    if (trailing != null) return trailing.group(1)!;
    return '';
  }

  String _parseStatus(String raw) {
    final value = raw.toLowerCase();
    const ongoing = [
      'مستمرة',
      'en curso',
      'ongoing',
      'on going',
      'new season',
      'mass released',
      'ativo',
      'en cours',
      'đang tiến hành',
      'em lançamento',
      'продолжается',
      'publishing',
      'devam ediyor',
      'em andamento',
      'in corso',
      'güncel',
      'berjalan',
      'updating',
      'lançando',
      'in arrivo',
      'emision',
      'en emision',
      'مستمر',
      'curso',
      'en marcha',
      'publicandose',
      'publicando',
      '连载中',
      'devam etmekte',
      '連載中',
    ];
    const completed = [
      'completed',
      'completo',
      'complété',
      'fini',
      'achevé',
      'terminé',
      'tamamlandı',
      'đã hoàn thành',
      'hoàn thành',
      'مكتملة',
      'завершено',
      'finished',
      'finalizad',
      'completata',
      'one-shot',
      'bitti',
      'tamat',
      'completado',
      'concluído',
      '完結',
      'concluido',
      '已完结',
      'bitmiş',
    ];
    const cancelled = [
      'canceled',
      'cancelled',
      'cancelado',
      'cancellato',
      'cancelados',
      'dropped',
      'discontinued',
      'abandonné',
    ];
    const hiatus = [
      'hiatus',
      'on hold',
      'season end',
      'pausado',
      'en espera',
      'en pause',
      'en attente',
      'hiato',
    ];
    if (ongoing.any(value.contains)) return 'Ongoing';
    if (completed.any(value.contains)) return 'Completed';
    if (cancelled.any(value.contains)) return 'Cancelled';
    if (hiatus.any(value.contains)) return 'Hiatus';
    return 'Unknown';
  }

  String _capitalize(String raw) {
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String? _updatedOn(dom.Document document) {
    final elements = document.querySelectorAll(
      '.listinfo time[itemprop="dateModified"], .listinfo time, .fmed time',
    );
    for (final time in elements) {
      final raw = (time.attributes['datetime'] ?? time.text).trim();
      final parsed = config.parseChapterDate(raw);
      if (parsed != null) return _isoDate(parsed);
    }
    return null;
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _substringAfter(String haystack, String needle) {
    final index = haystack.indexOf(needle);
    if (index == -1) return '';
    return haystack.substring(index + needle.length);
  }
}
