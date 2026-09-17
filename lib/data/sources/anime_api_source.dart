import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/manga_source.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

class AnimeApiSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'anime_api';

  @override
  String get name => 'Anime-API';

  @override
  String get baseUrl => 'https://anime-api.vercel.app/api';
  @override
  String get iconUrl => 'https://anime-api.vercel.app/favicon.ico';

  @override
  String get readerBaseUrl => 'https://anime-api.vercel.app/api';

  @override
  Map<String, String>? get headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Referer': 'https://anime-api.vercel.app/',
  };

  Future<Response> _getJson(String url) async {
    final client = await dio;
    return client.get(
      url,
      options: Options(receiveTimeout: const Duration(seconds: 10)),
    );
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    debugPrint('API: Fetching popular manga...');
    try {
      final response = await _getJson('$baseUrl/manga');

      debugPrint('API: Popular manga response code: ${response.statusCode}');

      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.data.toString());
      debugPrint('API: Successfully parsed ${data.length} manga');

      return data.map((item) {
        return Manga(
          id: item['id']?.toString() ?? '',
          sourceId: id,
          title: item['title'] ?? 'Unknown Title',
          coverUrl: item['image'] ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('API ERROR (Popular): $e');
      return [];
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    debugPrint('API: Fetching chapters for $mangaId...');
    try {
      final response = await _getJson('$baseUrl/manga/$mangaId');

      debugPrint('API: Chapter response code: ${response.statusCode}');

      if (response.statusCode != 200) return [];

      final Map<String, dynamic> data = jsonDecode(response.data.toString());
      final List<dynamic> chaptersData = data['chapters'] ?? [];
      debugPrint('API: Found ${chaptersData.length} chapters');

      return chaptersData.map((chapter) {
        return Chapter(
          id: chapter['id']?.toString() ?? '',
          title: chapter['title'] ?? '',
          chapterNumber: chapter['chapterNumber']?.toString() ?? '',
          releaseDate: '',
          url: chapter['url'] ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('API ERROR (Chapters): $e');
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    final fullUrl = '$baseUrl/chapter/$chapterId';
    debugPrint('API: Requesting pages from: $fullUrl');

    try {
      final response = await _getJson(fullUrl);

      debugPrint('API: Page response code: ${response.statusCode}');

      if (response.statusCode != 200) return [];

      final Map<String, dynamic> data = jsonDecode(response.data.toString());
      final List<dynamic> pages = data['pages'] ?? [];

      debugPrint(
        'API: Found ${pages.length} pages. First page URL: ${pages.isNotEmpty ? pages[0] : 'None'}',
      );

      return pages.map((url) => url.toString()).toList();
    } catch (e) {
      debugPrint('API ERROR (Pages): $e');
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    var details = MangaDetails(
      id: mangaId,
      sourceId: id,
      title: 'Unknown',
      coverUrl: '',
    );
    try {
      final response = await _getJson('$baseUrl/manga/$mangaId');
      if (response.statusCode != 200) return details;

      final Map<String, dynamic> data = jsonDecode(response.data.toString());
      details = MangaDetails(
        id: mangaId,
        sourceId: id,
        title: data['title']?.toString() ?? 'Unknown',
        coverUrl: data['image']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        author: data['author']?.toString() ?? '',
        status: data['status']?.toString() ?? '',
        year: data['year']?.toString() ?? '',
        tags:
            (data['genres'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
      return details;
    } catch (e) {
      debugPrint('API ERROR (Details): $e');
      return details;
    }
  }

  @override
  Future<int> getTotalChapters(String mangaId) async => 0;

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async => [];

  @override
  Future<List<String>> getAvailableTags() async => [];

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async => null;

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async => [];
}
