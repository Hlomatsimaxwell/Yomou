import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

class AsuraScansSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'asurascans';
  @override
  String get name => 'Asura Scans';
  @override
  String get baseUrl => 'https://api.asurascans.com';
  @override
  String get readerBaseUrl => 'https://api.asurascans.com';
  @override
  String get iconUrl => 'https://asurascans.com/favicon.ico';

  @override
  Map<String, String>? get headers => {
    'Referer': 'https://asurascans.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  static const int _chaptersPerPage = 100;
  static const int _maxChapters = 1000;

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
      if (slug.isEmpty || title.isEmpty) continue;
      result.add(
        Manga(
          id: slug,
          sourceId: id,
          title: title,
          coverUrl: item['cover']?.toString() ?? '',
        ),
      );
    }
    return result;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final json = await _getJson(
        '$baseUrl/api/series?limit=20&offset=${(page - 1) * 20}',
      );
      return _parseList(json?['data']);
    } catch (e) {
      debugPrint('AsuraScans Popular Error: $e');
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final json = await _getJson('$baseUrl/api/series/$mangaId');
      final series = json?['series'] ?? json?['data'];
      if (series is! Map) return null;
      final tags = <String>[];
      for (final g in (series['genres'] as List?) ?? const <dynamic>[]) {
        final n = (g as Map?)?['name']?.toString() ?? '';
        if (n.isNotEmpty && !tags.contains(n)) tags.add(n);
      }
      final description = (series['description']?.toString() ?? '')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return MangaDetails(
        id: mangaId,
        sourceId: id,
        title: series['title']?.toString() ?? '',
        coverUrl: series['cover']?.toString() ?? '',
        description: description,
        status: series['status']?.toString() ?? '',
        year: (series['release_year'] ?? '').toString(),
        tags: tags,
        followers: (series['bookmark_count'] as num?)?.toInt() ?? 0,
        totalChapters: (series['chapter_count'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('AsuraScans Details Error: $e');
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final chapters = <Chapter>[];
      var offset = 0;
      while (offset < _maxChapters) {
        final json = await _getJson(
          '$baseUrl/api/series/$mangaId/chapters'
          '?limit=$_chaptersPerPage&offset=$offset',
        );
        final data = json?['data'];
        if (data is! List || data.isEmpty) break;
        for (final item in data) {
          final chSlug = item['slug']?.toString() ?? '';
          final num = item['number']?.toString() ?? '';
          if (chSlug.isEmpty || num.isEmpty) continue;
          chapters.add(
            Chapter(
              id: 'api/series/$mangaId/chapters/$chSlug',
              title: 'Chapter $num',
              chapterNumber: num,
              releaseDate: item['published_at']?.toString(),
              url: '$baseUrl/api/series/$mangaId/chapters/$chSlug',
            ),
          );
        }
        final meta = json?['meta'];
        if (data.length < _chaptersPerPage) break;
        final hasMore = meta is Map ? meta['has_more'] == true : true;
        if (!hasMore) break;
        offset += _chaptersPerPage;
      }
      return chapters.reversed.toList();
    } catch (e) {
      debugPrint('AsuraScans Chapters Error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final json = await _getJson('$baseUrl/$chapterId');
      final pages = ((json?['data'] as Map?)?['chapter'] as Map?)?['pages'];
      if (pages is! List) return [];
      final urls = <String>[];
      for (final p in pages) {
        final u = (p as Map?)?['url']?.toString() ?? '';
        if (u.isNotEmpty) urls.add(u);
      }
      return urls;
    } catch (e) {
      debugPrint('AsuraScans Pages Error: $e');
      return [];
    }
  }

  @override
  Future<int> getTotalChapters(String mangaId) async {
    try {
      final detail = await getMangaDetails(mangaId);
      return detail?.totalChapters ?? (await getChapters(mangaId)).length;
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
        '$baseUrl/api/search?q=${Uri.encodeQueryComponent(query)}',
      );
      return _parseList(json?['data']);
    } catch (e) {
      debugPrint('AsuraScans Search Error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getAvailableTags() async => [];

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
    return [];
  }
}