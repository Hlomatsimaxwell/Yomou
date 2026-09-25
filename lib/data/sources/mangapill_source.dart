import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

/// MangaPill — server-rendered Tailwind HTML (no JS parsing needed).
/// Covers and page images are lazy (`data-src`) and hotlink-protected: every
/// image request must carry a `Referer: https://mangapill.com/` header, which
/// this source advertises via [headers] (the reader forwards them).
class MangaPillSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'mangapill';
  @override
  String get name => 'MangaPill';
  @override
  String get baseUrl => 'https://mangapill.com';
  @override
  String get readerBaseUrl => 'https://mangapill.com';
  @override
  String get iconUrl => 'https://mangapill.com/favicon.ico';

  @override
  Map<String, String>? get headers => {
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
  };

  String _idFromHref(String href) =>
      href.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/$'), '');

  /// Cards are plain `<div>` grid cells holding one cover anchor
  /// (`a.relative.block`) and one title anchor (`a.mb-2`).
  List<Manga> _parseGrid(String html) {
    final document = parser.parse(html);
    final result = <Manga>[];
    final seen = <String>{};
    for (final anchor in document.querySelectorAll('a.relative.block')) {
      final href = anchor.attributes['href'] ?? '';
      if (!RegExp(r'^/manga/\d+/').hasMatch(href)) continue;
      final id = _idFromHref(href);
      if (seen.contains(id)) continue;

      final img = anchor.querySelector('img');
      final cover = img?.attributes['data-src'] ??
          img?.attributes['src'] ??
          '';
      var title = anchor.text.trim();
      if (title.isEmpty) {
        final parent = anchor.parent;
        if (parent != null) {
          for (final a in parent.querySelectorAll('a[href^="/manga/"]')) {
            if (identical(a, anchor)) continue;
            final t = a.text.trim();
            if (t.isNotEmpty) {
              title = t;
              break;
            }
          }
        }
      }
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

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final html = await grabText('$baseUrl/');
      if (html.isEmpty) return [];
      return _parseGrid(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      if (query.isEmpty || page > 1) return [];
      final html = await grabText(
        '$baseUrl/search?q=${Uri.encodeQueryComponent(query)}&page=1',
      );
      if (html.isEmpty) return [];
      return _parseGrid(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    try {
      if (tags.isEmpty || page > 1) return [];
      final params = tags
          .map((t) => 'genre=${Uri.encodeQueryComponent(t)}')
          .join('&');
      final html = await grabText('$baseUrl/search?$params&page=1');
      if (html.isEmpty) return [];
      return _parseGrid(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getAvailableTags() async {
    try {
      final html = await grabText('$baseUrl/search?q=a&page=1');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final tags = <String>[];
      for (final a in document.querySelectorAll('a[href^="/search?genre="]')) {
        final t = a.text.trim();
        if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
      }
      return tags;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/$mangaId');
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final title = document.querySelector('h1')?.text.trim() ?? '';
      final coverImg = document.querySelector('div.w-60.h-80.relative.rounded img');
      final description =
          document.querySelector('p.text-sm.text--secondary')?.text.trim() ??
              '';

      final tags = <String>[];
      for (final a in document.querySelectorAll('a[href^="/search?genre="]')) {
        final t = a.text.trim();
        if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
      }

      String status = '';
      for (final label in document.querySelectorAll('label.text-secondary')) {
        final name = label.text.trim();
        if (name.toLowerCase() == 'status') {
          final parent = label.parent;
          if (parent != null) {
            final divs = parent.querySelectorAll('div');
            if (divs.isNotEmpty) status = divs.first.text.trim();
          }
          break;
        }
      }

      return MangaDetails(
        id: mangaId,
        title: title,
        coverUrl: coverImg?.attributes['data-src'] ??
            coverImg?.attributes['src'] ??
            '',
        sourceId: id,
        description: description,
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
      final html = await grabText('$baseUrl/$mangaId');
      if (html.isEmpty) return [];
      final document = parser.parse(html);

      final items = document.querySelectorAll(
        'div#chapters > div[data-filter-list] > a',
      );
      final chapters = <Chapter>[];
      final seen = <String>{};
      for (final a in items) {
        final href = a.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        final id = _idFromHref(href);
        if (seen.contains(id)) continue;
        final title = a.attributes['title']?.trim() ?? a.text.trim();
        if (title.isEmpty) continue;
        final numMatch = RegExp(
          r'chapter[\s-]*(\d+(?:[.\-]\d+)*)',
          caseSensitive: false,
        ).firstMatch(title);
        seen.add(id);
        chapters.add(
          Chapter(
            id: id,
            title: title,
            chapterNumber: numMatch?.group(1) ?? '',
            url: '$baseUrl/$id',
          ),
        );
      }
      // The page lists newest-first; the app expects oldest-first.
      return chapters.reversed.toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final html = await grabText('$baseUrl/$chapterId');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final urls = <String>[];
      for (final img in document.querySelectorAll('img.js-page')) {
        final src = img.attributes['data-src'] ??
            img.attributes['src'] ??
            '';
        if (src.isNotEmpty && !urls.contains(src)) urls.add(src);
      }
      return urls;
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
    return null;
  }

  @override
  Future<List<Manga>> searchWithFilter(
    MangaFilter filter, {
    int page = 1,
  }) async {
    return searchMangaByTags(filter.genres, page: page);
  }
}