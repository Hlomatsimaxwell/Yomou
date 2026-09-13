import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

class MgekoSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'mgeko';
  @override
  String get name => 'Mgeko';
  @override
  String get baseUrl => 'https://www.mgeko.cc';
  @override
  String get readerBaseUrl => 'https://www.mgeko.cc';
  @override
  String get iconUrl => 'https://mgeko.cc/static/img/logo_200x200.png';

  @override
  Map<String, String>? get headers => {
    'Referer': 'https://www.mgeko.cc/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  };

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

  List<Manga> _cardsFromHtml(String html) {
    final document = parser.parse(html);
    final result = <Manga>[];
    for (final card in document.querySelectorAll('article.comic-card')) {
      final link = card.querySelector('.comic-card__cover a') ??
          card.querySelector('.comic-card__title a');
      final href = link?.attributes['href'] ?? '';
      if (!href.contains('/manga/')) continue;
      final slug = Uri.parse(href).path
          .replaceFirst(RegExp(r'^/+'), '')
          .replaceAll(RegExp(r'/$'), '');
      if (slug.isEmpty) continue;
      final title =
          card.querySelector('.comic-card__title a')?.text.trim() ?? '';
      if (title.isEmpty) continue;
      final img = card.querySelector('.comic-card__cover img');
      result.add(
        Manga(
          id: slug,
          sourceId: id,
          title: title,
          coverUrl: img?.attributes['src'] ?? '',
        ),
      );
    }
    return result;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final json = await _getJson('$baseUrl/browse-comics/data/?page=$page');
      return _cardsFromHtml(json?['results_html']?.toString() ?? '');
    } catch (e) {
      debugPrint('Mgeko Popular Error: $e');
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/manga/$mangaId/');
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final title =
          document.querySelector('h1.novel-title')?.text.trim() ?? '';
      final coverEl = document.querySelector('.cover img');
      final cover =
          coverEl?.attributes['data-src'] ??
          coverEl?.attributes['src'] ??
          '';

      final author = document
          .querySelector('.author span[itemprop="author"]')
          ?.text
          .trim() ??
          '';

      final tags = <String>[];
      for (final a in document.querySelectorAll('.categories .property-item')) {
        final t = a.text.trim();
        if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
      }

      return MangaDetails(
        id: mangaId,
        sourceId: id,
        title: title,
        coverUrl: cover,
        description: document
                .querySelector('.description.short')
                ?.text
                .trim() ??
            '',
        author: author,
        tags: tags,
      );
    } catch (e) {
      debugPrint('Mgeko Details Error: $e');
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/manga/$mangaId/');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final chapters = <Chapter>[];
      for (final li in document.querySelectorAll('ul.chapter-list li')) {
        final a = li.querySelector('a[href^="/reader/"]');
        final href = a?.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        final path = href.replaceFirst(RegExp(r'^/+'), '');
        if (path.isEmpty) continue;
        final numText = li.querySelector('.chapter-number')?.text.trim() ?? '';
        final chapterNumber = numText.split('-').first.trim();
        if (chapterNumber.isEmpty) continue;
        chapters.add(
          Chapter(
            id: path,
            title: 'Chapter $chapterNumber',
            chapterNumber: chapterNumber,
            releaseDate: li.querySelector('.chapter-stats')?.text.trim() ?? '',
            url: '$baseUrl/$path',
          ),
        );
      }
      return chapters.reversed.toList();
    } catch (e) {
      debugPrint('Mgeko Chapters Error: $e');
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
      for (final img in document.querySelectorAll('#chapter-reader img')) {
        final src = img.attributes['src'] ?? '';
        if (src.isEmpty || src.contains('transparent')) continue;
        if (!urls.contains(src)) urls.add(src);
      }
      return urls;
    } catch (e) {
      debugPrint('Mgeko Pages Error: $e');
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
        '$baseUrl/browse-comics/data/?page=$page&q=${Uri.encodeQueryComponent(query)}',
      );
      return _cardsFromHtml(json?['results_html']?.toString() ?? '');
    } catch (e) {
      debugPrint('Mgeko Search Error: $e');
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