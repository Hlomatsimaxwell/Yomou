import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'date_parse.dart';
import 'source_network.dart';

class LikeMangaSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'likemanga';
  @override
  String get name => 'Like Manga';
  @override
  String get baseUrl => 'https://likemanga.ink';
  @override
  String get readerBaseUrl => 'https://likemanga.ink';
  @override
  String get iconUrl => 'https://likemanga.ink/favicon.ico';

  @override
  Map<String, String>? get headers => {
    'Referer': 'https://likemanga.ink/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  String _abs(String url) {
    if (url.isEmpty || url.startsWith('http')) return url;
    return '$baseUrl/${url.replaceFirst(RegExp(r'^/+'), '')}';
  }

  List<Manga> _parseCards(String html) {
    final document = parser.parse(html);
    final result = <Manga>[];
    for (final card in document.querySelectorAll('div.card')) {
      final link = card.querySelector('.title-manga a');
      final href = link?.attributes['href'] ?? '';
      if (!RegExp(r'^/[^/?#]+-\d+/$').hasMatch(href)) continue;
      final title = link?.text.trim() ?? '';
      if (title.isEmpty) continue;
      final img = card.querySelector('a img');
      result.add(
        Manga(
          id: href.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/$'), ''),
          sourceId: id,
          title: title,
          coverUrl: _abs(img?.attributes['src'] ?? ''),
        ),
      );
    }
    return result;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final html = await grabText(
        page <= 1 ? '$baseUrl/' : '$baseUrl/?page=$page',
      );
      if (html.isEmpty) return [];
      return _parseCards(html);
    } catch (e) {
      debugPrint('LikeManga Popular Error: $e');
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/$mangaId/');
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final title = document.querySelector('h1')?.text.trim() ?? '';
      final coverImg = document.querySelector('.col-image img');
      final tags = <String>[];
      for (final a in document.querySelectorAll('.kind .col-8 a')) {
        final t = a.text.trim();
        if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
      }

      final author = _rowText(document, '.author row');
      final status = _rowText(document, '.status row');

      return MangaDetails(
        id: mangaId,
        sourceId: id,
        title: title,
        coverUrl: _abs(coverImg?.attributes['src'] ?? ''),
        description:
            document.querySelector('#summary_shortened')?.text.trim() ?? '',
        author: author,
        status: status,
        tags: tags,
      );
    } catch (e) {
      debugPrint('LikeManga Details Error: $e');
      return null;
    }
  }

  String _rowText(dynamic document, String rowClass) {
    final selector =
        'li.${rowClass.split(' ').where((s) => s.isNotEmpty).join('.')}';
    for (final row in document.querySelectorAll(selector)) {
      final value = row.querySelector('.col-8')?.text.trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'updating') return value;
    }
    return '';
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/$mangaId/');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final chapters = <Chapter>[];
      for (final li in document.querySelectorAll(
        '#list_chapter_id_detail li',
      )) {
        final a = li.querySelector('a');
        final href = a?.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        final path = href.replaceFirst(RegExp(r'^/+'), '');
        final m = RegExp(r'chapter-([^/]+)').firstMatch(path);
        if (m == null) continue;
        final chapterNumber = m.group(1)!.split('-').first;
        final releaseEl = li.querySelector('.chapter-release-date');
        chapters.add(
          Chapter(
            id: path,
            title: a?.text.trim() ?? 'Chapter $chapterNumber',
            chapterNumber: chapterNumber,
            releaseDate: releaseEl?.text.trim() ?? '',
            url: '$baseUrl/$path',
          ),
        );
      }
      return chapters.reversed.toList();
    } catch (e) {
      debugPrint('LikeManga Chapters Error: $e');
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
      for (final img in document.querySelectorAll('.page-chapter img')) {
        final src = img.attributes['src'] ?? '';
        if (src.isNotEmpty && !urls.contains(src)) urls.add(src);
      }
      return urls;
    } catch (e) {
      debugPrint('LikeManga Pages Error: $e');
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
        final date = parseHumanChapterDate(c.releaseDate ?? '');
        if (date != null) return (c.title, date);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      final keyword = Uri.encodeQueryComponent(query.trim());
      final pageParam = page > 1 ? '&page=$page' : '';
      final html = await grabText(
        '$baseUrl/?act=search&f%5Bstatus%5D=all&f%5Bsortby%5D=lastest-chap'
        '&f%5Bkeyword%5D=$keyword$pageParam',
      );
      if (html.isEmpty) return [];
      return _parseCards(html);
    } catch (e) {
      debugPrint('LikeManga Search Error: $e');
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
