import 'dart:convert';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'date_parse.dart';
import 'source_network.dart';

/// MangaBat — mangabats.com (the live successor to the hijacked mangabat.com).
///
/// Grid/detail are plain HTML; the chapter list comes from a JSON API
/// (`/api/manga/{slug}/chapters`), and the reader page embeds its page-image
/// list in inline `var cdns = [...]` / `var chapterImages = [...]` JavaScript
/// arrays instead of `<img>` tags. Every image on `*.2xstorage.com` requires a
/// `Referer: https://www.mangabats.com/` header, advertised via [headers].
class MangaBatSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'mangabat';
  @override
  String get name => 'MangaBat';
  @override
  String get baseUrl => 'https://www.mangabats.com';
  @override
  String get readerBaseUrl => 'https://www.mangabats.com';
  @override
  String get iconUrl => 'https://www.mangabats.com/favicon.ico';

  @override
  Map<String, String>? get headers => {
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8,image/webp,*/*',
  };

  bool _isChallenge(String html) =>
      html.contains('Just a moment') || html.contains('challenge-platform');

  /// "Solo Leveling" -> "solo_leveling" (same transform the site's own
  /// `change_alias()` helper applies to the search box).
  String _searchAlias(String query) {
    var s = query.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return s.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  List<Manga> _parseGrid(String html, String source) {
    final document = parser.parse(html);
    final result = <Manga>[];
    final seen = <String>{};
    for (final wrap in document.querySelectorAll('div.list-comic-item-wrap')) {
      final titleA = wrap.querySelector('h3 a');
      final href = titleA?.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final id = _idFromHref(href);
      if (seen.contains(id)) continue;
      final img = wrap.querySelector('a img');
      final cover = img?.attributes['data-src'] ??
          img?.attributes['src'] ??
          '';
      final title = titleA?.text.trim() ?? '';
      if (title.isEmpty) continue;
      seen.add(id);
      result.add(
        Manga(
          id: id,
          title: title,
          coverUrl: cover,
          sourceId: id,
        ),
      );
    }
    return result;
  }

  List<Manga> _parseSearchGrid(String html) {
    final document = parser.parse(html);
    final result = <Manga>[];
    final seen = <String>{};
    for (final item in document.querySelectorAll('div.story_item')) {
      final href = item.querySelector('h3.story_name a')?.attributes['href'] ??
          '';
      if (href.isEmpty) continue;
      final id = _idFromHref(href);
      if (seen.contains(id)) continue;
      final img = item.querySelector('a img');
      final cover = img?.attributes['src'] ??
          img?.attributes['data-src'] ??
          '';
      final title =
          item.querySelector('h3.story_name')?.text.trim() ?? '';
      if (title.isEmpty) continue;
      seen.add(id);
      result.add(
        Manga(
          id: id,
          title: title,
          coverUrl: cover,
          sourceId: id,
        ),
      );
    }
    return result;
  }

  String _idFromHref(String href) {
    var h = href.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/$'), '');
    if (h.startsWith('$baseUrl/')) h = h.substring(baseUrl.length + 1);
    return h.replaceAll('/manga/', '');
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final html = await grabText('$baseUrl/manga-list/hot-manga?page=$page');
      if (html.isEmpty || _isChallenge(html)) return [];
      return _parseGrid(html, 'Hot');
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      final alias = _searchAlias(query);
      if (alias.isEmpty) return [];
      final html = await grabText(
        '$baseUrl/search/story/$alias?page=$page',
      );
      if (html.isEmpty || _isChallenge(html)) return [];
      return _parseSearchGrid(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/manga/$mangaId');
      if (html.isEmpty || _isChallenge(html)) return null;
      final document = parser.parse(html);

      final title = document
              .querySelector('ul.manga-info-text li h1')
              ?.text
              .trim() ??
          '';
      var cover = '';
      final thumb =
          document.querySelector('.thumbnail-wrap img') ??
          document.querySelector('.manga-info-pic img');
      cover = thumb?.attributes['src'] ??
          thumb?.attributes['data-src'] ??
          '';

      final infos = document.querySelectorAll('ul.manga-info-text li');
      String author = '';
      String status = '';
      final tags = <String>[];
      for (final li in infos) {
        final text = li.text.trim();
        if (text.startsWith('Author')) {
          author = text.replaceFirst(RegExp(r'^Author\(s\)\s*:\s*',
              caseSensitive: false),'').trim();
        } else if (text.startsWith('Status')) {
          status = text
              .replaceFirst(RegExp(r'^Status\s*:', caseSensitive: false),'')
              .trim()
              .toLowerCase();
        } else {
          for (final a in li.querySelectorAll('a[href^="/genre/"]')) {
            final t = a.text.trim();
            if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
          }
        }
      }

      var description = '';
      final box = document.querySelector('div#contentBox');
      if (box != null) {
        final prefix =
            document.querySelector('div#contentBox h2 p')?.text.trim() ?? '';
        description = box.text.trim();
        if (prefix.isNotEmpty && description.startsWith(prefix)) {
          description = description.substring(prefix.length).trim();
        }
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
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final chapters = <Chapter>[];
      var offset = 0;
      for (var i = 0; i < 20; i++) {
        final body = await grabText(
          '$baseUrl/api/manga/$mangaId/chapters?limit=100&offset=$offset',
        );
        if (body.isEmpty) break;
        final page = json.decode(body);
        if (page is! Map) break;
        final data = page['data'];
        if (data is! Map) break;
        final items = data['chapters'];
        final pagination = data['pagination'];
        if (items is! List) break;
        for (final raw in items) {
          if (raw is! Map) continue;
          final chapterSlug = raw['chapter_slug']?.toString() ?? '';
          final chapterName = raw['chapter_name']?.toString() ?? '';
          if (chapterSlug.isEmpty) continue;
          final numMatch = RegExp(
            r'chapter[\s-]*(\d+(?:[.\-]\d+)*)',
            caseSensitive: false,
          ).firstMatch(chapterSlug);
          chapters.add(
            Chapter(
              id: '$mangaId/$chapterSlug',
              title: chapterName,
              chapterNumber: numMatch?.group(1) ?? '',
              url: '$baseUrl/manga/$mangaId/$chapterSlug',
              releaseDate: raw['updated_at']?.toString(),
            ),
          );
        }
        final hasMore = pagination is Map && pagination['has_more'] == true;
        if (hasMore != true) break;
        final next = pagination['offset'];
        final total = pagination['total'];
        final totalInt = total is int ? total : int.tryParse('$total') ?? 0;
        final nextInt = next is int ? next : int.tryParse('$next') ?? 0;
        if (nextInt <= offset && totalInt > 0) break;
        offset = nextInt;
        if (totalInt > 0 && offset >= totalInt) break;
      }
      // The API lists newest-first; the app expects oldest-first.
      return chapters.reversed.toList();
    } catch (_) {
      return [];
    }
  }

  /// The chapter page stores its image list in inline JS arrays:
  /// `var cdns = ["https://img-r1.2xstorage.com/"]` and
  /// `var chapterImages = ["slug/11/0.webp", ...]` (escaped slashes).
  List<String> _pageUrlsFromScript(String html) {
    List<dynamic>? decodeVar(String name) {
      final match = RegExp(
        'var $name = (\\[.*?\\])',
        dotAll: true,
      ).firstMatch(html);
      if (match == null) return null;
      try {
        final decoded = json.decode(match.group(1)!.replaceAll(r'\/', '/'));
        return decoded is List ? decoded : null;
      } catch (_) {
        return null;
      }
    }

    final cdns = decodeVar('cdns') ?? [];
    final images = decodeVar('chapterImages') ?? [];
    final urls = <String>[];
    final cdn = cdns.isNotEmpty ? '${cdns.first}' : '';
    for (final image in images) {
      if (image is! String || image.isEmpty) continue;
      final url = '$cdn$image';
      if (!urls.contains(url)) urls.add(url);
    }
    return urls;
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final html = await grabText('$baseUrl/manga/$chapterId');
      if (html.isEmpty || _isChallenge(html)) return [];
      return _pageUrlsFromScript(html);
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