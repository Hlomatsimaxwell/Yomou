import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

/// MangaTown (mangatown.com) source.
///
/// Plain HTML site (sister site of MangaHere / MangaFox). No API token is
/// needed; the reader page embeds the first page image URL and a
/// `total_pages` counter, and every following page is the same URL with the
/// trailing number incremented.
class MangatownSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'mangatown';
  @override
  String get name => 'MangaTown';
  @override
  String get baseUrl => 'https://www.mangatown.com';
  @override
  String get readerBaseUrl => 'https://www.mangatown.com';
  @override
  String get iconUrl => 'https://www.mangatown.com/favicon.ico';

  @override
  Map<String, String>? get headers => {
    // Reader images (zjcdn.mangahere.org) are hotlink-protected: they return
    // 403 unless the Referer points to mangatown.com.
    'Referer': 'https://www.mangatown.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  Future<String> _fetchText(String url) async {
    final body = await grabText(url);
    return body.replaceAll('<!DOCTYPE', '<!doctype');
  }

  /// Parses manga cards rendered in a `.manga_pic_list` grid (used by the
  /// Hot / Directory / Search pages).
  List<Manga> _parseCards(String html) {
    final document = parser.parse(html);
    final items = document.querySelectorAll('.manga_pic_list li');
    final result = <Manga>[];
    for (final item in items) {
      final cover = item.querySelector('.manga_cover');
      final href = cover?.attributes['href'] ?? '';
      if (!href.startsWith('/manga/')) continue;
      final img = cover?.querySelector('img');
      final titleEl = item.querySelector('.title a');
      final title =
          cover?.attributes['title']?.trim() ??
          titleEl?.text.trim() ??
          '';
      if (title.isEmpty) continue;
      result.add(
        Manga(
          id: _idFromHref(href),
          sourceId: id,
          title: title,
          coverUrl: img?.attributes['src'] ?? '',
          description: '',
        ),
      );
    }
    return result;
  }

  static String _idFromHref(String href) {
    final parts = href.split('/').where((s) => s.isNotEmpty).toList();
    final mangaIdx = parts.indexOf('manga');
    return (mangaIdx != -1 && mangaIdx + 1 < parts.length)
        ? parts[mangaIdx + 1]
        : href.trim().replaceAll('/', '');
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final url =
          page <= 1
              ? '$baseUrl/hot/'
              : '$baseUrl/hot/$page.htm';
      final html = await _fetchText(url);
      if (html.isEmpty) return [];
      return _parseCards(html);
    } catch (e) {
      debugPrint('MangaTown Popular Error: $e');
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await _fetchText('$baseUrl/manga/$mangaId/');
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final titleEl = document.querySelector('h1.title-top');
      final info = document.querySelector('.detail_info');
      final coverImg = info?.querySelector('img');

      String description = '';
      String author = '';
      String status = '';
      final tags = <String>[];

      final lis = info?.querySelectorAll('li') ?? [];
      for (final li in lis) {
        final text = li.text;
        if (li.querySelector('#hide') != null) {
          description = li.querySelector('#hide')?.text.trim() ?? description;
        } else if (text.contains('Author(s)')) {
          author =
              li.querySelector('a')?.text.trim() ?? '';
        } else if (text.contains('Status(s)')) {
          status = li.text
              .replaceAll('Status(s):', '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          // "Ongoing Countach 283 will coming soon" -> "Ongoing"
          status = status.split(' ').first;
        } else if (text.contains('Genre(s)')) {
          for (final a in li.querySelectorAll('a')) {
            final t = a.text.trim();
            if (t.isNotEmpty) tags.add(t);
          }
        }
      }

      final summarySpan = info?.querySelector('#hide');
      if (summarySpan != null) {
        description = summarySpan.text.trim();
        final moreIdx = description.indexOf('MORE');
        if (moreIdx != -1) description = description.substring(0, moreIdx);
      }

      return MangaDetails(
        id: mangaId,
        sourceId: id,
        title: titleEl?.text.trim() ?? 'Unknown',
        coverUrl: coverImg?.attributes['src'] ?? '',
        description: description,
        author: author,
        status: status,
        year: '',
        tags: tags,
        followers: 0,
        totalChapters: 0,
      );
    } catch (e) {
      debugPrint('MangaTown Details Error: $e');
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final html = await _fetchText('$baseUrl/manga/$mangaId/');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final chapters = <Chapter>[];
      final rows = document.querySelectorAll('.chapter_list li');
      for (final row in rows) {
        final link = row.querySelector('a');
        final href = link?.attributes['href'] ?? '';
        if (!href.startsWith('/manga/')) continue;
        final path = href.replaceFirst(baseUrl, '');
        if (!path.startsWith('/manga/')) continue;
        final id = path
            .replaceFirst(RegExp(r'^/'), '')
            .replaceAll(RegExp(r'/$'), '');
        final title = link?.text.trim() ?? '';
        if (title.isEmpty) continue;

        final numberMatch = RegExp(r'[Cc](\d+(?:\.\d+)?)$').firstMatch(id);
        final chapterNumber = numberMatch?.group(1) ?? '';

        final timeEl = row.querySelector('.time');
        final releaseDate = timeEl?.text.trim() ?? '';

        chapters.add(
          Chapter(
            id: id,
            title: title,
            chapterNumber: chapterNumber,
            releaseDate: releaseDate,
            url: '$baseUrl/$id',
          ),
        );
      }
      // MangaTown lists newest-first; the app expects oldest-first.
      return chapters.reversed.toList();
    } catch (e) {
      debugPrint('MangaTown Chapters Error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final html = await _fetchText('$baseUrl/$chapterId');
      if (html.isEmpty) return [];

      final totalMatch = RegExp(r'total_pages\s*=\s*(\d+)').firstMatch(html);
      final total = int.tryParse(totalMatch?.group(1) ?? '') ?? 0;
      if (total <= 0) return [];

      // First image: embedded as <img id="image" src="..."/> or the first
      // zjcdn.mangahere.org image on the page (may be protocol-relative).
      final imgMatch = RegExp(
        r'(?:https?:)?//zjcdn\.mangahere\.org/store/manga/\S+?\.(?:jpg|jpeg|png|webp)',
      ).firstMatch(html);
      if (imgMatch == null) return [];
      final raw = imgMatch.group(0)!;
      final firstUrl = raw.startsWith('//')
          ? 'https:$raw'
          : raw;

      // Split the numeric suffix (page number) from the URL prefix.
      final suffixMatch =
          RegExp(r'^(.*\D)(\d+)\.(jpg|jpeg|png|webp)$')
              .firstMatch(firstUrl);
      if (suffixMatch == null) return [];

      final prefix = suffixMatch.group(1)!;
      final startNum = int.tryParse(suffixMatch.group(2)!) ?? 0;
      final width = suffixMatch.group(2)!.length;
      final ext = suffixMatch.group(3)!;

      final pages = <String>[];
      for (var i = 0; i < total; i++) {
        final num = startNum + i;
        final numStr = num.toString().padLeft(width, '0');
        pages.add('$prefix$numStr.$ext');
      }
      return pages;
    } catch (e) {
      debugPrint('MangaTown Pages Error: $e');
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
      for (final chapter in chapters.reversed) {
        final date = parseMangatownDate(chapter.releaseDate ?? '');
        if (date != null) {
          final title = chapter.chapterNumber.isEmpty
              ? chapter.title
              : 'Chapter ${chapter.chapterNumber}';
          return (title, date);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      final searchQuery = query.trim().replaceAll(' ', '+');
      final url =
          page <= 1
              ? '$baseUrl/search?name=$searchQuery'
              : '$baseUrl/search?page=$page&name=$searchQuery';
      final html = await _fetchText(url);
      if (html.isEmpty) return [];
      return _parseCards(html);
    } catch (e) {
      debugPrint('MangaTown Search Error: $e');
      return [];
    }
  }

  /// Builds the genre slug -> display name map from the directory page.
  Map<String, String>? _directoryCache;

  Future<Map<String, String>> _genreMap() async {
    final cached = _directoryCache;
    if (cached != null) return cached;
    final html = await _fetchText('$baseUrl/directory/');
    final map = <String, String>{};
    if (html.isNotEmpty) {
      final document = parser.parse(html);
      for (final a in document.querySelectorAll('a[href*="/directory/"]')) {
        final href = a.attributes['href'] ?? '';
        final m = RegExp(r'^/directory/0-([a-z0-9_]+)-0-0-0-0/$')
            .firstMatch(href);
        if (m != null) {
          final slug = m.group(1)!;
          final label = a.text.trim();
          if (slug.isNotEmpty && label.isNotEmpty) map[slug] = label;
        }
      }
    }
    return _directoryCache = map;
  }

  @override
  Future<List<String>> getAvailableTags() async {
    try {
      final map = await _genreMap();
      return map.values.toSet().toList()..sort();
    } catch (_) {
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
      final map = await _genreMap();
      final nameToSlug = <String, String>{};
      for (final entry in map.entries) {
        nameToSlug[entry.value.toLowerCase()] = entry.key;
      }
      final slugs = <String>[];
      for (final tag in tags) {
        final slug = nameToSlug[tag.trim().toLowerCase()];
        if (slug != null) slugs.add(slug);
      }
      if (slugs.isEmpty) return [];

      final genre = slugs.join('-');
      final url =
          page <= 1
              ? '$baseUrl/directory/0-$genre-0-0-0-0/'
              : '$baseUrl/directory/0-$genre-0-0-0-0/$page.htm';
      final html = await _fetchText(url);
      if (html.isEmpty) return [];
      return _parseCards(html);
    } catch (e) {
      debugPrint('MangaTown Tags Error: $e');
      return [];
    }
  }
}

/// Parses "Sep 10,2026", "Today Sep 10,2026" and "Yesterday Sep 09,2026"
/// style dates used in the chapter list.
DateTime? parseMangatownDate(String raw) {
  final m = RegExp(
    r'(?:Today|Yesterday)?\s*([A-Za-z]{3})\s+(\d{1,2}),\s*(\d{4})',
  ).firstMatch(raw.trim());
  if (m == null) return null;
  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[m.group(1)!.toLowerCase()];
  if (month == null) return null;
  final day = int.tryParse(m.group(2)!);
  final year = int.tryParse(m.group(3)!);
  if (day == null || year == null) return null;
  return DateTime(year, month, day);
}