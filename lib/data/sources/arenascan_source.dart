import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'date_parse.dart';
import 'source_network.dart';

class ArenascanSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'arenascan';
  @override
  String get name => 'Arenascan';
  @override
  String get baseUrl => 'https://arenascan.com';
  @override
  String get readerBaseUrl => 'https://arenascan.com';
  @override
  String get iconUrl => 'https://arenascan.com/favicon.ico';

  @override
  Map<String, String>? get headers => {
    'Referer': 'https://arenascan.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  List<Manga> _parseCards(String html) {
    final document = parser.parse(html);
    final result = <Manga>[];
    for (final a in document.querySelectorAll('.listupd .bsx a')) {
      final href = a.attributes['href'] ?? '';
      if (!href.contains('/manga/')) continue;
      final title =
          a.attributes['title']?.trim() ??
          a.querySelector('.tt')?.text.trim() ??
          '';
      final slug = _slugFromHref(href);
      if (title.isEmpty || slug.isEmpty) continue;
      result.add(
        Manga(
          id: slug,
          sourceId: id,
          title: title,
          coverUrl: a.querySelector('img')?.attributes['src'] ?? '',
        ),
      );
    }
    return result;
  }

  static String _slugFromHref(String href) {
    final parts = Uri.parse(href).path.split('/').where((s) => s.isNotEmpty);
    final list = parts.toList();
    final idx = list.indexOf('manga');
    return (idx != -1 && idx + 1 < list.length) ? list[idx + 1] : '';
  }

  static String _cleanChapterPath(String href) {
    final path = Uri.parse(href).path
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/$'), '');
    return path;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final url = page <= 1 ? '$baseUrl/manga/' : '$baseUrl/manga/page/$page/';
      final html = await grabText(url);
      if (html.isEmpty) return [];
      return _parseCards(html);
    } catch (e) {
      debugPrint('Arenascan Popular Error: $e');
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/manga/$mangaId/');
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final title = document.querySelector('h1.entry-title')?.text.trim() ?? '';
      final cover =
          document.querySelector('.thumb img')?.attributes['src'] ?? '';
      final descEl = document.querySelector(
        '.entry-content[itemprop="description"]',
      );

      final tags = <String>[];
      for (final a in document.querySelectorAll('.mgen a')) {
        final t = a.text.trim();
        if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
      }

      String status = '';
      for (final row in document.querySelectorAll('.tsinfo .imptdt')) {
        final t = row.text.trim();
        for (final s in ['Ongoing', 'Completed', 'Hiatus', 'Dropped']) {
          if (t.contains(s)) {
            status = s;
            break;
          }
        }
        if (status.isNotEmpty) break;
      }

      return MangaDetails(
        id: mangaId,
        sourceId: id,
        title: title,
        coverUrl: cover,
        description: descEl?.text.trim() ?? '',
        status: status,
        tags: tags,
      );
    } catch (e) {
      debugPrint('Arenascan Details Error: $e');
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
      for (final li in document.querySelectorAll('#chapterlist ul li')) {
        final a = li.querySelector('.eph-num a');
        final href = a?.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        final path = _cleanChapterPath(href);
        if (path.isEmpty) continue;
        final numEl = li.querySelector('.chapternum');
        final numText = numEl?.text.trim() ?? '';
        final chapterNumber = numText
            .replaceAll(RegExp(r'^[Cc]hapter\s*'), '')
            .trim();
        if (chapterNumber.isEmpty) continue;
        chapters.add(
          Chapter(
            id: path,
            title: numText,
            chapterNumber: chapterNumber,
            releaseDate: li.querySelector('.chapterdate')?.text.trim() ?? '',
            url: '$baseUrl/$path',
          ),
        );
      }
      return chapters.reversed.toList();
    } catch (e) {
      debugPrint('Arenascan Chapters Error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final html = await grabText('$baseUrl/$chapterId');
      if (html.isEmpty) return [];

      final urls = <String>[];
      final match = RegExp(
        r'ts_reader\.run\((.*?)\);',
        dotAll: true,
      ).firstMatch(html);
      if (match != null) {
        try {
          final data = jsonDecode(match.group(1)!) as Map<String, dynamic>;
          final sources = data['sources'] as List? ?? const [];
          for (final s in sources) {
            final images = (s as Map?)?['images'] as List? ?? const [];
            for (final u in images) {
              final url = u.toString();
              if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
            }
          }
        } catch (e) {
          debugPrint('Arenascan ts_reader parse error: $e');
        }
      }

      if (urls.isEmpty) {
        for (final m in RegExp(
          r'src="(https://cdn\.arenascan\.com/[^"]+)"',
        ).allMatches(html)) {
          final url = m.group(1)!;
          if (!urls.contains(url)) urls.add(url);
        }
      }
      return urls;
    } catch (e) {
      debugPrint('Arenascan Pages Error: $e');
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
      final url = '$baseUrl/?s=${Uri.encodeQueryComponent(query)}';
      final html = await grabText(url);
      if (html.isEmpty) return [];
      return _parseCards(html);
    } catch (e) {
      debugPrint('Arenascan Search Error: $e');
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