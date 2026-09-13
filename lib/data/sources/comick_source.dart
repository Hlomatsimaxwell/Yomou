import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/manga_source.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

class ComickSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'comick';
  @override
  String get name => 'ComicK';
  @override
  String get baseUrl => 'https://comick.live';
  @override
  String get readerBaseUrl => 'https://comick.live';
  @override
  String get iconUrl => 'https://comick.io/favicon.ico';

  @override
  Map<String, String>? get headers => {
    'Referer': 'https://comick.live/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  };

  static const int _maxChapterPages = 12;

  Future<Map<String, dynamic>?> _getJson(String url) async {
    final body = await grabText(url);
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('$id json error: $e');
      return null;
    }
  }

  List<Manga> _parseList(dynamic data) {
    final result = <Manga>[];
    if (data is! List) return result;
    for (final item in data) {
      if (item is! Map) continue;
      final slug = item['slug']?.toString() ?? '';
      final title = item['title']?.toString() ?? '';
      String cover = item['full_image_path']?.toString() ?? '';
      if (cover.isNotEmpty && !cover.startsWith('http')) {
        cover = '$baseUrl$cover';
      }
      if (slug.isEmpty || title.isEmpty) continue;
      result.add(
        Manga(id: slug, sourceId: id, title: title, coverUrl: cover),
      );
    }
    return result;
  }

  Future<Map<String, dynamic>?> _comicData(String slug) async {
    final html = await grabText('$baseUrl/comic/$slug');
    if (html.isEmpty) return null;
    final match = RegExp(
      r'<script[^>]*id="comic-data"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    try {
      return jsonDecode(match.group(1)!) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('$id comic-data error: $e');
      return null;
    }
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final json = await _getJson('$baseUrl/api/comics/top?type=popular_ongoing&day=7');
      return _parseList(json?['data']);
    } catch (e) {
      debugPrint('ComicK Popular Error: $e');
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final data = await _comicData(mangaId);
      if (data == null) return null;

      final tags = <String>[];
      for (final entry in (data['md_comic_md_genres'] as List?) ?? const []) {
        final g = (entry as Map?)?['md_genres'];
        final n = (g as Map?)?['name']?.toString() ?? '';
        if (n.isNotEmpty && !tags.contains(n)) tags.add(n);
      }

      final authors = <String>[];
      for (final a in (data['authors'] as List?) ?? const []) {
        final n = (a as Map?)?['name']?.toString() ?? '';
        if (n.isNotEmpty && n.toLowerCase() != 'n/a' && !authors.contains(n)) {
          authors.add(n);
        }
      }

      final desc = (data['parsed']?.toString() ?? '').trim();
      final translated = data['translation_completed'] == true;
      final status = data['status']?.toString() ?? '';
      final resolvedStatus = (status.isNotEmpty && status.toLowerCase() != '1')
          ? status
          : (translated ? 'Completed' : 'Ongoing');

      return MangaDetails(
        id: mangaId,
        sourceId: id,
        title: data['title']?.toString() ?? '',
        coverUrl: data['default_thumbnail']?.toString() ?? '',
        description: desc,
        author: authors.join(', '),
        status: resolvedStatus,
        year: (data['year'] ?? '').toString(),
        tags: tags,
        followers: (data['user_follow_count'] as num?)?.toInt() ?? 0,
        totalChapters: (data['chapter_count'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('ComicK Details Error: $e');
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final chapters = <Chapter>[];
      var page = 1;
      while (page <= _maxChapterPages) {
        final json = await _getJson(
          '$baseUrl/api/comics/$mangaId/chapter-list?page=$page',
        );
        final data = json?['data'];
        if (data is! List || data.isEmpty) break;
        for (final item in data) {
          if (item is! Map) continue;
          final lang = item['lang']?.toString() ?? '';
          if (lang.isNotEmpty && lang != 'en') continue;
          final hid = item['hid']?.toString() ?? '';
          final chap = item['chap']?.toString() ?? '';
          if (hid.isEmpty || chap.isEmpty) continue;
          final id = '$mangaId/$hid-chapter-$chap-$lang';
          chapters.add(
            Chapter(
              id: id,
              title: 'Chapter $chap',
              chapterNumber: chap,
              releaseDate:
                  item['publish_at']?.toString() ??
                  item['created_at']?.toString(),
              url: '$baseUrl/api/comics/$id',
            ),
          );
        }
        if (data.length < 60) break;
        page++;
      }
      return chapters.reversed.toList();
    } catch (e) {
      debugPrint('ComicK Chapters Error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final json = await _getJson('$baseUrl/api/comics/$chapterId');
      final images = ((json?['chapter'] as Map?)?['images'] as List?) ?? const [];
      final urls = <String>[];
      for (final img in images) {
        final u = (img as Map?)?['url']?.toString() ?? '';
        if (u.isNotEmpty) urls.add(u);
      }
      return urls;
    } catch (e) {
      debugPrint('ComicK Pages Error: $e');
      return [];
    }
  }

  @override
  Future<int> getTotalChapters(String mangaId) async {
    try {
      final data = await _comicData(mangaId);
      return (data?['chapter_count'] as num?)?.toInt() ??
          (await getChapters(mangaId)).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async {
    try {
      final chapters = await getChapters(mangaId);
      for (final c in chapters.reversed) {
        final date = DateTime.tryParse(c.releaseDate ?? '');
        if (date != null) return (c.title, date.toLocal());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      final json = await _getJson(
        '$baseUrl/api/search?q=${Uri.encodeQueryComponent(query)}&page=$page',
      );
      return _parseList(json?['data'] ?? json?['comics']);
    } catch (e) {
      debugPrint('ComicK Search Error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getAvailableTags() async => [];

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    return [];
  }
}