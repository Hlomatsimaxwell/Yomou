import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'date_parse.dart';
import 'source_network.dart';

/// Manhwa18 — a bespoke (non-WordPress) Bootstrap/Laravel site. Lazy covers
/// live in `data-bg` attributes and chapter pages use `data-src`; no
/// hotlink protection and no anti-bot challenges observed.
class Manhwa18Source extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'manhwa18';
  @override
  String get name => 'Manhwa18';
  @override
  String get baseUrl => 'https://manhwa18.com';
  @override
  String get readerBaseUrl => 'https://manhwa18.com';
  @override
  String get iconUrl => 'https://manhwa18.com/favicon.ico';

  @override
  Map<String, String>? get headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  };

  String _idFromHref(String href) =>
      href.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/$'), '');

  List<Manga> _parseCards(String html) {
    final document = parser.parse(html);
    final result = <Manga>[];
    for (final card in document.querySelectorAll('div.thumb-item-flow')) {
      final link = card.querySelector('div.thumb_attr.series-title a');
      final href = link?.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final id = _idFromHref(href);
      if (id.isEmpty) continue;
      final coverEl = card.querySelector('div.content.img-in-ratio.lazy-bg');
      final cover = coverEl?.attributes['data-bg'] ?? '';
      final title = link?.text.trim() ?? '';
      if (title.isEmpty) continue;
      result.add(
        Manga(id: id, title: title, coverUrl: cover, sourceId: id),
      );
    }
    return result;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final pagePart = page > 1 ? '&page=$page' : '';
      final html = await grabText('$baseUrl/manga-list?sort=update$pagePart');
      if (html.isEmpty) return [];
      return _parseCards(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      if (query.isEmpty) return [];
      final pagePart = page > 1 ? '&page=$page' : '';
      final html = await grabText(
        '$baseUrl/tim-kiem?q=${Uri.encodeQueryComponent(query)}$pagePart',
      );
      if (html.isEmpty) return [];
      return _parseCards(html);
    } catch (_) {
      return [];
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
  Future<List<String>> getAvailableTags() async => [];

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/$mangaId');
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final title = document.querySelector('span.series-name')?.text.trim() ??
          document.querySelector('h1')?.text.trim() ??
          '';
      final coverEl = document.querySelector('div.series-cover div.content.img-in-ratio');
      final style = coverEl?.attributes['style'] ?? '';
      final coverMatch = RegExp(
        r'background-image:\s*url\(([^)]+)\)',
        caseSensitive: false,
      ).firstMatch(style);
      final cover = _stripQuotes(coverMatch?.group(1) ?? '');

      final description =
          document.querySelector('div.summary-wrapper div.summary-content')
              ?.text
              .trim() ??
              '';

      final author = _infoValue(document, 'Author');
      final status = _infoValue(document, 'Status');
      final tags = <String>[];
      for (final item in document.querySelectorAll('div.info-item')) {
        final name = item.querySelector('span.info-name')?.text.trim() ?? '';
        if (!name.contains('Genre')) continue;
        for (final a in item.querySelectorAll('span.info-value a')) {
          final t = a.text.trim();
          if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
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

  String _stripQuotes(String value) {
    var v = value.trim();
    if (v.length >= 2 &&
        ((v.startsWith("'") && v.endsWith("'")) ||
            (v.startsWith('"') && v.endsWith('"')))) {
      v = v.substring(1, v.length - 1);
    }
    return v;
  }

  String _infoValue(dynamic document, String name) {
    for (final item in document.querySelectorAll('div.info-item')) {
      final label = item.querySelector('span.info-name')?.text.trim() ?? '';
      if (!label.contains(name)) continue;
      final value = item.querySelector('span.info-value')?.text.trim() ?? '';
      return value.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return '';
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/$mangaId');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final chapters = <Chapter>[];
      for (final a in document.querySelectorAll('ul.list-chapters.at-series a')) {
        final href = a.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        final id = _idFromHref(href);
        if (id.isEmpty) continue;
        final titleEl = a.querySelector('div.chapter-name');
        final title = titleEl?.text.trim() ?? a.text.trim();
        if (title.isEmpty) continue;
        final numMatch = RegExp(
          r'chapter\s*(\d+(?:[.\-]\d+)*)',
          caseSensitive: false,
        ).firstMatch(title);
        final timeEl = a.querySelector('div.chapter-time');
        chapters.add(
          Chapter(
            id: id,
            title: title,
            chapterNumber: numMatch?.group(1) ?? '',
            releaseDate: timeEl?.text.trim() ?? '',
            url: '$baseUrl/$id',
          ),
        );
      }
      // The site lists newest-first; the app expects oldest-first.
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
      for (final img in document.querySelectorAll('#chapter-content img')) {
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
    try {
      final chapters = await getChapters(mangaId);
      (String, DateTime)? best;
      for (final c in chapters) {
        final m = RegExp(
          r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})',
        ).firstMatch(c.releaseDate ?? '');
        final date = m != null
            ? DateTime(
                int.parse(m.group(3)!),
                int.parse(m.group(2)!),
                int.parse(m.group(1)!),
              )
            : parseHumanChapterDate(c.releaseDate ?? '');
        if (date != null && (best == null || date.isAfter(best.$2))) {
          best = (c.title, date);
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Manga>> searchWithFilter(
    MangaFilter filter, {
    int page = 1,
  }) async {
    return searchMangaByTags(filter.genres, page: page);
  }
}