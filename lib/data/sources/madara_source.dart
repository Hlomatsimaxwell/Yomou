import 'dart:convert';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import '../models/madara_site_config.dart';
import 'source_network.dart';
import 'captcha_gate.dart';

/// A Madara/WordPress manga source fully driven by a [MadaraSiteConfig].
///
/// The listing / search / detail / chapter parts are generic enough to be
/// covered by CSS selectors, so they live here once. Only page-image
/// resolution is per-site — that is delegated to a pluggable
/// [MadaraPageUrlExtractor] chosen from the config's [MadaraPageExtractor].
class MadaraSource extends DioSource implements MangaSource {
  MadaraSource(this.config);

  final MadaraSiteConfig config;

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  String get baseUrl => config.baseUrl;

  @override
  String websiteMangaUrl(String mangaId) => '$websiteUrl/$mangaId';

  @override
  String get readerBaseUrl => config.baseUrl;

  @override
  String get iconUrl => config.iconUrl;

  @override
  String get networkSourceId => config.id;

  @override
  Map<String, String>? get headers {
    final result = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
      ...config.extraHeaders,
    };
    if (config.imagesNeedReferer) {
      result['Referer'] = '${config.baseUrl}/';
    }
    return result;
  }

  // --- URL templates ---

  String _pageUrl(String path, int page) {
    if (path.contains('{page}')) return path.replaceAll('{page}', '$page');
    if (page <= 1) return path;
    // WordPress paginates path-style archives with `page` (Madara's reader
    // sends `&page=`) while query-string listings at the site root
    // (`?m_orderby=...`, `?s=...`, `?genre[]=...`) are the main query and
    // must be paged with `paged`. Mixing the two silently re-returns page
    // one, which looks like an artificially short catalog.
    final queryListing = path.trim().startsWith('?') ||
        path.contains('?s=') ||
        path.contains('genre[]=') ||
        path.contains('m_orderby=');
    return '$path${path.contains('?') ? '&' : '?'}'
        '${queryListing ? 'paged' : 'page'}=$page';
  }

  String _fromPath(String href) {
    var path = href.trim();
    // Sites routinely link themselves as an absolute URL on another host --
    // `www.` when the configured base has none, http vs https, or a mirror --
    // so strip any scheme + host rather than only the configured base.
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      path = uri.path;
    } else {
      path = path.replaceFirst(baseUrl, '');
    }
    final query = path.indexOf('?');
    if (query != -1) path = path.substring(0, query);
    return path.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/$'), '');
  }

  // --- Shared listing parser (popular / search / tags) ---

  List<Manga> _parseMangaGrid(String html) {
    if (html.isEmpty) return [];
    final document = parser.parse(html);
    final cards = document.querySelectorAll(config.mangaCardSelector);
    if (cards.isEmpty) {
      for (final fallback in const [
        '.page-item-detail',
        '.c-tabs-item__content',
      ]) {
        final extra = document.querySelectorAll(fallback);
        if (extra.isNotEmpty) {
          return _parseCards(extra);
        }
      }
    }
    return _parseCards(cards);
  }

  List<Manga> _parseCards(List<dynamic> cards) {
    final mangas = <Manga>[];
    for (final card in cards) {
      final candidates = <dom.Element>[];
      candidates.addAll(card.querySelectorAll(config.mangaTitleSelector));
      candidates.addAll(card.querySelectorAll('.post-title a'));
      candidates.addAll(card.querySelectorAll('h3 a, h4 a, h5 a'));
      candidates.addAll(
        card.querySelectorAll(
          'a[href*="/manga/"], a[href*="/comic/"], a[href*="/series/"], a[href*="/manhwa/"]',
        ),
      );
      dom.Element? link;
      for (final a in candidates) {
        final href = a.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        if (href.contains('/tag/') ||
            href.contains('/category/') ||
            href.contains('/genre/') ||
            href.contains('/manga-tag/') ||
            href.contains('/comic-tag/')) {
          continue;
        }
        final text = a.text.trim();
        final attrTitle = (a.attributes['title'] ?? '').trim();
        if (text.isEmpty && attrTitle.isEmpty) continue;
        if (link == null || text.length > link.text.trim().length) {
          link = a;
        }
      }
      final href = link?.attributes['href'] ?? '';
      final id = _fromPath(href);
      if (id.isEmpty || !id.contains('/')) continue;
      final img = card.querySelector(config.mangaCoverSelector);
      final cover =
          img?.attributes[config.coverAttr] ?? img?.attributes['src'] ?? '';
      var title = link?.text.trim() ?? '';
      if (title.isEmpty) title = (link?.attributes['title'] ?? '').trim();
      mangas.add(
        Manga(
          id: id,
          title: title.isEmpty ? 'No name' : title,
          coverUrl: cover,
          sourceId: this.id,
        ),
      );
    }
    return mangas;
  }

  // --- MangaSource interface ---

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final path = _pageUrl(config.popularPath, page);
      final html = await grabText('$baseUrl/$path');
      return _parseMangaGrid(html);
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      if (query.isEmpty) return [];
      final path = config.searchPath.replaceAll(
        '{query}',
        Uri.encodeQueryComponent(query),
      );
      final html = await grabText('$baseUrl/${_pageUrl(path, page)}');
      return _parseMangaGrid(html);
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
      return [];
    }
  }

  @override
  Future<List<Manga>> searchWithFilter(
    MangaFilter filter, {
    int page = 1,
  }) async {
    return searchMangaByTags(filter.genres, page: page);
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    try {
      if (tags.isEmpty) return [];
      final path = config.tagSearchPath.replaceAll(
        '{tag}',
        Uri.encodeQueryComponent(tags.join(',')),
      );
      final html = await grabText('$baseUrl/${_pageUrl(path, page)}');
      return _parseMangaGrid(html);
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
      return [];
    }
  }

  @override
  Future<List<String>> getAvailableTags() async {
    try {
      final html = await grabText('$baseUrl/?post_type=wp-manga');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final links = document.querySelectorAll(
        '.genres ul.genres-ul li a, select.genres option',
      );
      final tags = <String>[];
      for (final a in links) {
        final name = a.text.trim();
        if (name.isNotEmpty && !tags.contains(name)) tags.add(name);
      }
      return tags;
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/$mangaId');
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final titleEl = document.querySelector('h1');
      final titleText = titleEl?.text.trim() ?? '';
      final title = titleText.isNotEmpty ? titleText : 'Unknown';
      // Prefer the summary cover: on many Madara pages the first <img> in the
      // document is the site logo in the header, which the card selector
      // (`img`) would otherwise hand back as the cover.
      final coverEl =
          document.querySelector('.summary_image img') ??
          document.querySelector(config.mangaCoverSelector);
      final cover =
          coverEl?.attributes[config.coverAttr] ??
          coverEl?.attributes['src'] ??
          '';
      final description =
          document
              .querySelector(config.detailDescriptionSelector)
              ?.text
              .trim() ??
          '';
      final author = document
          .querySelectorAll(config.detailAuthorsSelector)
          .map((a) => a.text.trim())
          .where((t) => t.isNotEmpty)
          .join(', ');

      final tags = <String>[];
      for (final a in document.querySelectorAll(config.detailGenresSelector)) {
        final t = a.text.trim();
        if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
      }

      var statusRaw =
          document.querySelector(config.detailStatusSelector)?.text.trim() ??
          '';
      // Some sites list "Release" before "Status" under `.post-status`, so the
      // configured selector lands on the release year. Prefer the row whose
      // heading actually says "Status" when the site labels its rows.
      for (final item in document.querySelectorAll(
        '.post-status .post-content_item',
      )) {
        final heading =
            item.querySelector('.summary-heading')?.text.trim().toLowerCase() ??
            '';
        if (heading.contains('status')) {
          statusRaw =
              item.querySelector('.summary-content')?.text.trim() ?? statusRaw;
          break;
        }
      }
      String status = statusRaw;
      switch (statusRaw.toLowerCase()) {
        case 'ongoing':
          status = 'Ongoing';
          break;
        case 'completed':
          status = 'Completed';
          break;
        case 'hiatus':
          status = 'Hiatus';
          break;
        case 'cancelled':
        case 'canceled':
          status = 'Cancelled';
          break;
      }

      return MangaDetails(
        id: mangaId,
        title: title,
        coverUrl: cover,
        sourceId: id,
        description: description,
        author: author,
        status: status,
        tags: tags,
      );
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/$mangaId');
      if (html.isEmpty) return [];

      final document = parser.parse(html);
      var items = document.querySelectorAll(config.chapterListSelector);
      if (items.isEmpty) {
        // Madara's "load chapters with AJAX" mode ships an empty
        // `#manga-chapters-holder` and fills it from
        // `{mangaUrl}/ajax/chapters/?t=1`. Sites with long chapter lists use it
        // so the series page stays small.
        final ajax = await postText('$baseUrl/$mangaId/ajax/chapters/?t=1');
        if (ajax.isNotEmpty) {
          items = parser
              .parse(ajax)
              .querySelectorAll(config.chapterListSelector);
        }
      }
      final chapters = <Chapter>[];

      for (final item in items) {
        final link = config.chapterLinkSelector.isEmpty
            ? item
            : item.querySelector(config.chapterLinkSelector);
        if (link == null) continue;
        final href = link.attributes['href'] ?? '';
        final id = _fromPath(href);
        if (id.isEmpty) continue;
        final title = link.text.trim();
        if (title.isEmpty) continue;

        chapters.add(
          Chapter(
            id: id,
            title: title,
            chapterNumber: _chapterNumber(id, title),
            releaseDate: '',
            url: '$baseUrl/$id',
          ),
        );
      }
      return chapters;
    } catch (e) {
      if (e is CaptchaRequiredException) rethrow;
      return [];
    }
  }

  String _chapterNumber(String id, String title) {
    final titleRe = RegExp(
      r'(?:chapter|cap[ií]tulo|cap)\s*(\d+(?:[.\-]\d+)*)',
      caseSensitive: false,
    );
    final titleMatch = titleRe.firstMatch(title);
    if (titleMatch != null) return titleMatch.group(1)!;
    // Plenty of Madara sites title a chapter with nothing but its number.
    final bareNumber = RegExp(r'^\s*(\d+(?:[.\-]\d+)*)\s*$').firstMatch(title);
    if (bareNumber != null) return bareNumber.group(1)!;
    final pathRe = RegExp(
      r'[-_/](?:ch(?:apter)?|cap(?:itulo)?)[-_. ]?(\d+(?:[.\-]\d+)*)',
      caseSensitive: false,
    );
    final pathMatch = pathRe.firstMatch(id);
    if (pathMatch != null) return pathMatch.group(1)!;
    return '';
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
    return null;
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final url = '$baseUrl/$chapterId';
      return await _buildExtractor().extract(
        source: this,
        config: config,
        chapterId: chapterId,
        chapterUrl: url,
      );
    } catch (_) {
      return [];
    }
  }

  MadaraPageUrlExtractor _buildExtractor() {
    switch (config.pageExtractor) {
      case MadaraPageExtractor.styleList:
        return InlineDomPageExtractor(appendStyleList: true);
      case MadaraPageExtractor.ajaxRest:
        return MadaraAjaxRestPageExtractor();
      case MadaraPageExtractor.chapterDataJs:
        return ChapterDataJsPageExtractor();
      case MadaraPageExtractor.inline:
        return InlineDomPageExtractor();
    }
  }
}

/// Strategy used to resolve the page-image list for a chapter.
abstract class MadaraPageUrlExtractor {
  Future<List<String>> extract({
    required MadaraSource source,
    required MadaraSiteConfig config,
    required String chapterId,
    required String chapterUrl,
  });
}

/// Extracts page images found in the chapter HTML (eager or lazy-loaded).
class InlineDomPageExtractor implements MadaraPageUrlExtractor {
  const InlineDomPageExtractor({this.appendStyleList = false});

  final bool appendStyleList;

  @override
  Future<List<String>> extract({
    required MadaraSource source,
    required MadaraSiteConfig config,
    required String chapterId,
    required String chapterUrl,
  }) async {
    final html = await source.grabText(chapterUrl);
    if (html.isEmpty) return [];
    final document = parser.parse(html);
    final images = document.querySelectorAll(config.readerImageSelector);
    final pages = <String>[];
    for (final img in images) {
      final src =
          img.attributes[config.readerImageAttr] ?? img.attributes['src'] ?? '';
      if (src.isEmpty) continue;
      var url = src.trim();
      if (url.startsWith('//')) url = 'https:$url';
      if (appendStyleList)
        url = url.contains('?') ? '$url&style=list' : '$url?style=list';
      if (!pages.contains(url)) pages.add(url);
    }
    return pages;
  }
}

/// Uses Madara's built-in REST endpoint (`rest-api/?action=szv_Chapter`).
class MadaraAjaxRestPageExtractor implements MadaraPageUrlExtractor {
  const MadaraAjaxRestPageExtractor();

  @override
  Future<List<String>> extract({
    required MadaraSource source,
    required MadaraSiteConfig config,
    required String chapterId,
    required String chapterUrl,
  }) async {
    final parts = chapterId.split('/');
    if (parts.length < 3) return [];
    final manga = parts[parts.length - 2];
    final chapter = parts.last;
    final endpoint =
        '${config.baseUrl}/rest-api/?action=szv_Chapter&manga=$manga&slug=$chapter';
    final body = await source.grabText(
      endpoint,
      extraHeaders: {'accept': 'application/json'},
    );
    if (body.isEmpty) return [];

    final Map<String, dynamic> data;
    try {
      data = (jsonDecode(body) as Map).cast<String, dynamic>();
    } catch (_) {
      return [];
    }
    final images = data['images'];
    if (images is List) {
      return images
          .map((i) => i.toString())
          .where((i) => i.isNotEmpty)
          .toList();
    }
    if (images is Map) {
      final values = <String>[];
      images.forEach((_, v) {
        if (v is List) {
          values.addAll(v.map((i) => i.toString()).where((i) => i.isNotEmpty));
        } else if (v is String && v.isNotEmpty) {
          values.add(v);
        }
      });
      return values;
    }
    return [];
  }
}

/// Extracts the image list from an embedded `chapterData` / `localized` JS
/// object on the chapter page (some themes do not put images in HTML nodes).
class ChapterDataJsPageExtractor implements MadaraPageUrlExtractor {
  const ChapterDataJsPageExtractor();

  @override
  Future<List<String>> extract({
    required MadaraSource source,
    required MadaraSiteConfig config,
    required String chapterId,
    required String chapterUrl,
  }) async {
    final html = await source.grabText(chapterUrl);
    if (html.isEmpty) return [];

    final pages = <String>[];
    for (final key in ['images', 'urls']) {
      final re = RegExp('"$key"\\s*:\\s*\\[([^\\]]+)\\]');
      for (final m in re.allMatches(html)) {
        for (final q in RegExp(r'"([^"]+)"').allMatches(m.group(1)!)) {
          final url = q.group(1)!.trim();
          if (url.isNotEmpty && !pages.contains(url)) {
            pages.add(url.startsWith('//') ? 'https:$url' : url);
          }
        }
      }
      if (pages.isNotEmpty) break;
    }
    return pages;
  }
}
