import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;

import '../models/chapter.dart';
import '../models/manga.dart';
import '../models/manga_details.dart';
import '../models/manga_filter.dart';
import '../models/manga_source.dart';
import '../models/zeistmanga_site_config.dart';
import 'source_network.dart';

/// One generic source for every ZeistManga-themed site.
///
/// These sites publish their whole catalogue through Blogger's JSON feed:
/// manga are posts under a label (`Series` by default), chapters are posts
/// under a second label discovered on the manga page, and reader images live
/// in the chapter post body. Kotatsu's `ZeistMangaParser` uses exactly this
/// shape, with small per-site overrides that are folded into
/// [ZeistMangaSiteConfig] (see [ZeistMangaSiteConfig.mangaCategory] and
/// [ZeistMangaSiteConfig.pageSelector]).
class ZeistMangaSource extends DioSource implements MangaSource {
  ZeistMangaSource(this.config);

  final ZeistMangaSiteConfig config;

  /// Reader image selectors used by the theme, plus the handful of site
  /// overrides from Kotatsu's subclasses. A config selector replaces this
  /// whole list when a site needs something completely different.
  static const String _defaultPageSelector =
      'div.check-box img, article#reader .separator img, '
      '#reader div.separator img, article.container .separator img, '
      '#readarea img, #reader img, #readerarea img, '
      '#seoneurons-target img, .post-body img, .entry-content img';

  static final RegExp _chapterImageRegex =
      RegExp(r'''(?:config\['chapterImage'\]|chapterImage)\s*=\s*\[([^\]]*)\]''');
  static final RegExp _contentTemplateRegex =
      RegExp(r'const content\s*=\s*`([^`]*)`', dotAll: true);
  static final RegExp _escapedSrcRegex =
      RegExp(r'src\\x3d\\x22([^\x22]+)\\x22');
  static final RegExp _numberRegex = RegExp(r'(\d+(?:\.\d+)?)');

  static const List<String> _ongoingLabels = [
    'ongoing',
    'en curso',
    'ativo',
    'activo',
    'lançando',
    'em lançamento',
    'em andamento',
    'مستمر',
    'مستمرة',
    'devam ediyor',
    'güncel',
    'en emisión',
  ];
  static const List<String> _completedLabels = [
    'completed',
    'complete',
    'completo',
    'completado',
    'finalizado',
    'finished',
    'tamamlandı',
    'مكتمل',
    'مكتملة',
    'final',
  ];
  static const List<String> _abandonedLabels = [
    'cancelled',
    'canceled',
    'dropped',
    'dropado',
    'abandonado',
    'cancelado',
    'suspendido',
    'متوقفة',
    'düzenleniyor',
    'hiatus',
  ];

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
  Map<String, String>? get headers => const {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
  };

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) =>
      _getFeedPage(page: page, label: config.mangaCategory);

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) {
    if (query.trim().isEmpty) return getPopularManga(page: page);
    return _getFeedPage(
      page: page,
      label: config.mangaCategory,
      query: query.trim(),
    );
  }

  @override
  Future<List<Manga>> searchMangaByTags(List<String> tags, {int page = 1}) {
    if (tags.isEmpty) return Future.value(<Manga>[]);
    return _getFeedPage(page: page, label: tags.first);
  }

  @override
  Future<List<Manga>> searchWithFilter(MangaFilter filter, {int page = 1}) {
    final status = filter.status.isEmpty ? null : filter.status.first;
    final label = switch (status) {
      'finished' || 'completed' => 'Completed',
      'dropped' || 'cancelled' => 'Cancelled',
      'ongoing' => 'Ongoing',
      _ => filter.genres.isEmpty ? null : filter.genres.first,
    };
    if (label == null) return getPopularManga(page: page);
    return _getFeedPage(page: page, label: label);
  }

  Future<List<Manga>> _getFeedPage({
    required int page,
    required String label,
    String? query,
  }) async {
    try {
      // Kotatsu asks for maxMangaResults + 1 so a partial last page can be
      // detected; 20 per page is the theme default.
      final url = config.feedUrl(
        label,
        maxResults: 21,
        startIndex: 20 * (page - 1) + 1,
        query: query,
      );
      return parseFeed(await grabText(url));
    } catch (_) {
      return <Manga>[];
    }
  }

  /// Parses a Blogger JSON feed into manga rows. Kept public so the parsing
  /// can be unit-tested without a network.
  List<Manga> parseFeed(String body) {
    if (body.trim().isEmpty) return <Manga>[];
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return <Manga>[];
    }
    final feed = (decoded as Map?)?['feed'];
    if (feed is! Map) return <Manga>[];
    final entries = feed['entry'];
    if (entries is! List) return <Manga>[];

    final result = <Manga>[];
    final seen = <String>{};
    for (final entry in entries) {
      if (entry is! Map) continue;
      final title = entry['title']?['\$t']?.toString().trim() ?? '';
      final href = _alternateLink(entry['link']);
      if (title.isEmpty || href.isEmpty || !seen.add(href)) continue;
      result.add(
        Manga(
          id: href,
          title: title,
          coverUrl: _coverFromEntry(entry),
          sourceId: config.id,
        ),
      );
    }
    return result;
  }

  String _alternateLink(Object? links) {
    if (links is! List) return '';
    for (final link in links) {
      if (link is Map && link['rel'] == 'alternate') {
        return link['href']?.toString().trim() ?? '';
      }
    }
    return '';
  }

  String _coverFromEntry(Map entry) {
    final thumb = entry['media\$thumbnail']?['url']?.toString() ?? '';
    if (thumb.isNotEmpty) {
      return thumb
          .replaceAll(RegExp(r'/s.+?-c/'), '/w600/')
          .replaceAll(RegExp(r'=s(?!.*=s).+?-c$'), '=w600')
          .replaceAll(RegExp(r'/s.+?-c-rw/'), '/w600/')
          .replaceAll(RegExp(r'=s(?!.*=s).+?-c-rw$'), '=w600');
    }
    final content = entry['content']?['\$t']?.toString() ?? '';
    if (content.isEmpty) return '';
    return parser.parse(content).querySelector('img')?.attributes['src'] ?? '';
  }

  @override
  Future<List<String>> getAvailableTags() async {
    try {
      final html = await grabText(config.baseUrl);
      if (html.isEmpty) return <String>[];
      final document = parser.parse(html);
      return document
          .querySelectorAll('div.filter ul li')
          .map((li) {
            final label = li.querySelector('label')?.text.trim() ?? '';
            return label;
          })
          .where((label) => label.isNotEmpty)
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText(config.mangaUrl(mangaId));
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final title = document
              .querySelector('h1.post-title, h1.entry-title, [itemprop="name"], h1')
              ?.text
              .trim() ??
          mangaId;
      final cover = document
              .querySelector(
                'img[itemprop="image"], .post-body img, .entry-content img, '
                '.thumb img',
              )
              ?.attributes['src'] ??
          document
              .querySelector('meta[property="og:image"]')
              ?.attributes['content'] ??
          '';
      final description = document
              .querySelector(
                '#synopsis, #Sinopse, #sinopas, .sinopsis, .sinopas',
              )
              ?.text
              .trim() ??
          '';

      return MangaDetails(
        id: mangaId,
        title: title,
        coverUrl: cover,
        sourceId: config.id,
        description: description,
        author: _labeledText(document, const ['author', 'autor', 'الكاتب', 'yazar']) ??
            '',
        status: _parseStatus(
          _labeledText(document, const ['status', 'estado', 'حالة']) ?? '',
        ),
        tags: _detailTags(document),
        language: config.langCode,
        publicUrl: mangaId.startsWith('http') ? mangaId : '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Reads a value next to a label such as `Status:` / `Autor:` from the
  /// several detail layouts the theme uses (`div.y6x11p`, `ul.infonime`,
  /// `dl`, `#append-info`). `package:html` has no `:contains` selector, so
  /// this reproduces the Kotatsu selector in Dart.
  String? _labeledText(dom.Document document, List<String> labels) {
    final candidates = <dom.Element>[
      ...document.querySelectorAll(
        'div.y6x11p, ul.infonime li, #append-info div, dl div, dl li',
      ),
    ];
    for (final element in candidates) {
      final text = element.text.trim();
      if (text.isEmpty || text.length > 140) continue;
      final lower = text.toLowerCase();
      for (final label in labels) {
        if (!lower.startsWith(label.toLowerCase())) continue;
        final value = element.querySelector('.dt, span, dd, a');
        if (value != null && value.text.trim().isNotEmpty) {
          return value.text.trim();
        }
        final colon = text.indexOf(':');
        if (colon >= 0 && colon + 1 < text.length) {
          return text.substring(colon + 1).trim();
        }
      }
    }
    return null;
  }

  List<String> _detailTags(dom.Document document) {
    final tags = <String>[];
    final links = document.querySelectorAll(
      '.info-genre a, article div.mt-15 a, .leading-8 div.my-5.gap-2 a, '
      '.post-body a[href*="/label/"], .entry-content a[href*="/label/"]',
    );
    for (final link in links) {
      final text = link.text.trim();
      if (text.isNotEmpty && !tags.contains(text)) tags.add(text);
    }
    return tags;
  }

  String _parseStatus(String raw) {
    final value = raw.trim().toLowerCase();
    if (_ongoingLabels.any(value.startsWith)) return 'ongoing';
    if (_completedLabels.any(value.startsWith)) return 'completed';
    if (_abandonedLabels.any(value.startsWith)) return 'dropped';
    return '';
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final html = await grabText(config.mangaUrl(mangaId));
      if (html.isEmpty) return <Chapter>[];

      // ToonCubus renders its chapter links directly instead of through a
      // Blogger feed.
      final direct = _directChapters(html);
      if (direct.isNotEmpty) return direct;

      final label = extractChapterLabel(html);
      if (label == null || label.isEmpty) return <Chapter>[];
      final feed = await grabText(
        config.feedUrl(label, maxResults: 9999),
      );
      return parseChapterFeed(feed, mangaId: mangaId);
    } catch (_) {
      return <Chapter>[];
    }
  }

  /// Finds the Blogger label that holds a manga's chapters. Kotatsu checks
  /// the same script/markup patterns, in the same order.
  String? extractChapterLabel(String html) {
    if (html.isEmpty) return null;

    // The `#latest` script's `label = '...'` is the theme's primary form.
    // Scope that search to the widget so an unrelated `label` variable in
    // the page's other scripts cannot win.
    final latest = RegExp(r'''id=["']latest["']''').firstMatch(html);
    if (latest != null) {
      final end = (latest.end + 4000).clamp(0, html.length);
      final scoped = RegExp(r"label\s*=\s*'([^']+)'")
          .firstMatch(html.substring(latest.end, end))
          ?.group(1);
      if (scoped != null && scoped.trim().isNotEmpty) {
        return _decodeLabel(scoped);
      }
    }

    final patterns = <RegExp>[
      RegExp(r"clwd\.run\(\s*'([^']+)'"),
      RegExp(r"label\s*=\s*'([^']+)'"),
      RegExp(r'''data-post-title=["']([^"']+)["']'''),
      RegExp(r'''label_chapter\s*=\s*"([^"]+)"'''),
      RegExp(r'''feeds/posts/default/-/([^?"']+)'''),
    ];
    for (final pattern in patterns) {
      final label = pattern.firstMatch(html)?.group(1)?.trim();
      if (label != null && label.isNotEmpty) return _decodeLabel(label);
    }
    return null;
  }

  String _decodeLabel(String label) {
    try {
      return Uri.decodeComponent(label);
    } catch (_) {
      return label;
    }
  }

  List<Chapter> _directChapters(String html) {
    final document = parser.parse(html);
    final links = document.querySelectorAll('ul.series-chapterlist a[href]');
    final chapters = <Chapter>[];
    for (final link in links) {
      final href = link.attributes['href']?.trim() ?? '';
      final name = link.querySelector('span')?.text.trim() ??
          link.text.trim();
      if (href.isEmpty || name.isEmpty) continue;
      chapters.add(
        Chapter(
          id: href,
          title: name,
          chapterNumber: _numberFrom(name),
          url: href,
        ),
      );
    }
    return chapters;
  }

  /// Parses the chapter feed into chapters, oldest first (Blogger returns
  /// newest first), skipping the manga's own catalogue post.
  List<Chapter> parseChapterFeed(String body, {required String mangaId}) {
    if (body.trim().isEmpty) return <Chapter>[];
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return <Chapter>[];
    }
    final feed = (decoded as Map?)?['feed'];
    if (feed is! Map || feed['entry'] is! List) return <Chapter>[];
    final entries = (feed['entry'] as List).reversed.toList();

    final mangaSlug = Uri.parse(config.mangaUrl(mangaId)).pathSegments.last;
    final chapters = <Chapter>[];
    final seen = <String>{};
    for (final entry in entries) {
      if (entry is! Map) continue;
      final title = entry['title']?['\$t']?.toString().trim() ?? '';
      final href = _alternateLink(entry['link']);
      if (title.isEmpty || href.isEmpty) continue;
      if (Uri.parse(href).pathSegments.last == mangaSlug) continue;
      if (!seen.add(href)) continue;
      final published = entry['published']?['\$t']?.toString() ?? '';
      chapters.add(
        Chapter(
          id: href,
          title: title,
          chapterNumber: _numberFrom(title),
          releaseDate: published.split('T').first,
          url: href,
        ),
      );
    }
    return chapters;
  }

  String _numberFrom(String title) =>
      _numberRegex.firstMatch(title)?.group(1) ?? '';

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
        final date = config.parseDate(chapter.releaseDate);
        if (date != null) return (chapter.title, date);
      }
    } catch (_) {
      // The Updates feed treats a missing date as "unknown".
    }
    return null;
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final html = await grabText(
        chapterId.startsWith('http') ? chapterId : '${config.baseUrl}/$chapterId',
      );
      return parsePageImages(html);
    } catch (_) {
      return <String>[];
    }
  }

  /// Extracts reader images from a chapter post. Handles the theme's
  /// `chapterImage = [...]`, UlasComic's `config['chapterImage']`, the
  /// `const content = \`...\`` template and plain image markup.
  List<String> parsePageImages(String html) {
    if (html.trim().isEmpty) return <String>[];

    final array = _chapterImageRegex.firstMatch(html);
    if (array != null) {
      final urls = array.group(1)!
          .split(',')
          .map((url) => url.trim().replaceAll('"', '').replaceAll("'", ''))
          .where(_isImageUrl)
          .toList();
      if (urls.isNotEmpty) return urls;
    }

    final template = _contentTemplateRegex.firstMatch(html);
    if (template != null) {
      final urls = <String>[];
      for (final src in _escapedSrcRegex.allMatches(template.group(1)!)) {
        urls.add(src.group(1)!);
      }
      if (urls.isEmpty) {
        final document = parser.parse(template.group(1)!);
        for (final img in document.querySelectorAll('img')) {
          final src = img.attributes['src']?.trim() ?? '';
          if (src.isNotEmpty) urls.add(src);
        }
      }
      final cleaned = urls.where(_isImageUrl).toList();
      if (cleaned.isNotEmpty) return cleaned;
    }

    final document = parser.parse(html);
    final urls = <String>[];
    for (final img in document.querySelectorAll(
      config.pageSelector ?? _defaultPageSelector,
    )) {
      final src = (img.attributes['src'] ?? img.attributes['data-src'] ?? '')
          .trim();
      if (_isImageUrl(src) && !urls.contains(src)) urls.add(src);
    }
    return urls;
  }

  bool _isImageUrl(String url) =>
      url.isNotEmpty &&
      !url.startsWith('data:') &&
      !url.toLowerCase().contains('avatar');
}
