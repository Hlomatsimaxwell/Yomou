import 'package:html/parser.dart' as html_parser;
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_details.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/models/manga_filter.dart';
import 'dart:io';

class AnzMangasHdSource extends MangaSource {
  @override
  String get id => 'anzmangashd';

  @override
  String get name => 'AnzMangasHd';

  @override
  String get baseUrl => 'https://www.anzmanga25.com';

  @override
  String get readerBaseUrl => baseUrl;

  @override
  String get languageCode => 'es';

  @override
  String get iconUrl => '$baseUrl/uploads/favicon.png';

  // Overridable fetch hook kept for tests. Uses a plain HTTP client so the
  // page (which serves straight HTML to any client) always arrives, instead
  // of going through the shared network layer which can return empty.
  Future<String> fetchHtml(String url) async {
    try {
      final client = HttpClient();
      client.userAgent =
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Mobile Safari/537.36';
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      final body = await res.transform(SystemEncoding().decoder).join();
      client.close();
      if (res.statusCode != 200) return '';
      return body;
    } catch (_) {
      return '';
    }
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final html = await fetchHtml('$baseUrl/latest-release');
      final document = html_parser.parse(html);
      final manga = <Manga>[];

      document.querySelectorAll('.manga-item').forEach((element) {
        final link = element.querySelector('h3.manga-heading a') ??
            element.querySelector('a');
        if (link == null) return;
        final href = (link.attributes['href'] ?? '').trim();
        final title = link.text.trim();
        final mangaId = _idFromHref(href);
        if (mangaId.isEmpty || title.isEmpty) return;

        final img = element.querySelector('img');
        final cover = _coverFromImg(img);

        manga.add(Manga(
          id: mangaId,
          title: title,
          sourceId: id,
          coverUrl: cover.isNotEmpty
              ? cover
              : '$baseUrl/uploads/manga/$mangaId/cover/cover_250x350.jpg',
        ));
      });

      return manga;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await fetchHtml('$baseUrl/manga/$mangaId');
      final document = html_parser.parse(html);

      final title = _cleanTitle(
        document.querySelector('title')?.text,
        ' - AnzManga',
      );
      final cover = _coverFromImg(document.querySelector('img.img-responsive'));
      final summary = document.querySelector('.well p')?.text.trim() ?? '';

      final genres = <String>[];
      document.querySelectorAll('dd a[href*="/category/"]').forEach((e) {
        final t = e.text.trim();
        if (t.isNotEmpty) genres.add(t);
      });

      return MangaDetails(
        id: mangaId,
        sourceId: id,
        title: title,
        coverUrl: cover,
        description: summary,
        tags: genres,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final html = await fetchHtml('$baseUrl/manga/$mangaId');
      final document = html_parser.parse(html);
      final chapters = <Chapter>[];

      var entries = document.querySelectorAll('ul.chapters li');
      if (entries.isEmpty) entries = document.querySelectorAll('li');

      for (final li in entries) {
        final link = li.querySelector('h5.chapter-title-rtl a, .chapter-title a, a');
        if (link == null) continue;
        final href = (link.attributes['href'] ?? '').trim();
        if (href.isEmpty) continue;
        final rawTitle = link.text.trim();
        if (rawTitle.isEmpty) continue;

        final dateElement = li.querySelector('.date-chapter-title-rtl');
        final dateStr = dateElement?.text.trim() ?? '';
        var fullTitle = rawTitle;
        if (dateStr.isNotEmpty) {
          fullTitle = fullTitle.replaceFirst(dateStr, '').trim();
        }

        final chapterId = _idFromHref(href, keepTail: true);
        final chapterNum = _chapterNumberFrom(fullTitle, href);
        final cleanTitle = _cleanChapterTitle(fullTitle, chapterNum);

        chapters.add(Chapter(
          id: chapterId,
          title: cleanTitle,
          chapterNumber: chapterNum,
          releaseDate: dateStr.isEmpty ? null : dateStr,
          url: href,
        ));
      }

      return chapters;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final html = await fetchHtml('$baseUrl$chapterId');
      final document = html_parser.parse(html);
      final urls = <String>[];

      document.querySelectorAll('img.img-responsive').forEach((img) {
        final src = _coverFromImg(img);
        if (src.startsWith('http')) urls.add(src);
      });

      return urls;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      final html = await fetchHtml('$baseUrl/search?q=${Uri.encodeQueryComponent(query)}');
      final document = html_parser.parse(html);
      final manga = <Manga>[];

      document.querySelectorAll('.manga-item').forEach((element) {
        final link = element.querySelector('h3.manga-heading a') ??
            element.querySelector('a');
        if (link == null) return;
        final href = (link.attributes['href'] ?? '').trim();
        final title = link.text.trim();
        final mangaId = _idFromHref(href);
        if (mangaId.isEmpty || title.isEmpty) return;

        final img = element.querySelector('img');
        final cover = _coverFromImg(img);

        manga.add(Manga(
          id: mangaId,
          title: title,
          sourceId: id,
          coverUrl: cover,
        ));
      });

      return manga;
    } catch (_) {
      return [];
    }
  }

  static String _idFromHref(String href, {bool keepTail = false}) {
    final clean = href.trim().split('?').first.split('#').first;
    if (!keepTail) {
      final segments = clean.split('/').where((s) => s.isNotEmpty).toList();
      return segments.isEmpty ? '' : segments.last;
    }
    return clean;
  }

  static String _coverFromImg(dynamic img) {
    if (img == null) return '';
    final raw = (img.attributes['data-src'] ?? img.attributes['src'] ?? '')
        .toString()
        .trim();
    final cleaned = raw.replaceAll(RegExp(r'^\s+'), '');
    if (!cleaned.startsWith('http')) return '';
    return cleaned;
  }

  static String _cleanTitle(String? raw, String suffix) {
    if (raw == null) return '';
    var t = raw.trim();
    if (t.endsWith(suffix)) {
      t = t.substring(0, t.length - suffix.length).trim();
    }
    return t;
  }

  static String _chapterNumberFrom(String title, String href) {
    final keywordMatch = RegExp(
      r'(?:chapter|cap[ií]tulo|chap)\s*[#.]?\s*(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(title);
    if (keywordMatch != null) return keywordMatch.group(1)!;
    final trailing = RegExp(r'(\d+(?:\.\d+)?)\s*$').firstMatch(title);
    if (trailing != null) return trailing.group(1)!;
    final last = href.split('/').where((s) => s.isNotEmpty).lastOrNull;
    if (last != null && RegExp(r'^\d+(\.\d+)?$').hasMatch(last)) return last;
    return '';
  }

  static String _cleanChapterTitle(String fullTitle, String num) {
    if (num.isEmpty) return fullTitle;
    return fullTitle.replaceFirst(RegExp('${RegExp.escape(num)}\$'), '').trim();
  }

  @override
  Future<int> getTotalChapters(String mangaId) async => (await getChapters(mangaId)).length;

  @override
  Future<List<Manga>> searchMangaByTags(List<String> tags, {int page = 1}) async =>
      searchByTitle(tags.join(' '), page: page);

  @override
  Future<List<Manga>> searchWithFilter(MangaFilter filter, {int page = 1}) async =>
      searchMangaByTags(filter.genres, page: page);

  @override
  Future<List<String>> getAvailableTags() async => [];

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async => null;
}
