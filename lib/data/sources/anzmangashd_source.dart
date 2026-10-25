import 'package:html/parser.dart' as html_parser;
import 'package:yomou/core/diagnostics/diag_log.dart';
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_details.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/models/manga_filter.dart';
import 'dart:io';

class _CachedPage {
  _CachedPage(this.html);

  final String html;
  final DateTime at = DateTime.now();
}

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
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Mobile Safari/537.36';

  /// Pages fetched in the last couple of minutes.
  ///
  /// The detail screen asks for the same manga page twice in a row (details,
  /// then the chapter list). The second request used to be a fresh round trip
  /// that could stall with no timeout at all, which left the chapter tray
  /// spinning forever and kept its cache key marked as in-flight, so every
  /// later visit to that manga spun too. Serving both from one fetch removes
  /// that second request and makes the two calls consistent.
  final Map<String, _CachedPage> _pages = {};

  Future<String> fetchHtml(String url) async {
    final cached = _pages[url];
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 2)) {
      return cached.html;
    }
    // One retry: the site occasionally drops a connection mid-body, and a
    // retry is cheaper than showing an empty page for the rest of the visit.
    for (var attempt = 0; attempt < 2; attempt++) {
      final html = await _fetchOnce(url);
      if (html.isNotEmpty) {
        _pages[url] = _CachedPage(html);
        if (_pages.length > 8) _pages.remove(_pages.keys.first);
        return html;
      }
    }
    return '';
  }

  Future<String> _fetchOnce(String url) async {
    final watch = Stopwatch()..start();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final res =
          await req.close().timeout(const Duration(seconds: 15));
      final body = await res
          .transform(const SystemEncoding().decoder)
          .join()
          .timeout(const Duration(seconds: 20));
      diagSoon(
        'anzmangashd: $url -> ${res.statusCode} ${body.length}b '
        '${watch.elapsedMilliseconds}ms',
      );
      return res.statusCode == 200 ? body : '';
    } catch (e) {
      diagSoon(
        'anzmangashd: $url failed ${watch.elapsedMilliseconds}ms: '
        '${e.runtimeType} $e',
      );
      return '';
    } finally {
      client.close(force: true);
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
    final watch = Stopwatch()..start();
    try {
      final html = await fetchHtml('$baseUrl/manga/$mangaId');
      final document = html_parser.parse(html);

      final heading = document.querySelector('h2.widget-title')?.text.trim();
      final title = (heading != null && heading.isNotEmpty)
          ? heading
          : _cleanTitle(document.querySelector('title')?.text, ' - AnzManga');
      final cover = _coverFromImg(document.querySelector('img.img-responsive'));
      final summary = document.querySelector('.well p')?.text.trim() ?? '';

      final genres = <String>[];
      document.querySelectorAll('dd a[href*="/category/"]').forEach((e) {
        final t = e.text.trim();
        if (t.isNotEmpty) genres.add(t);
      });
      diagSoon(
        'anzmangashd: details $mangaId "${title.isEmpty ? '(no title)' : title}" '
        '${genres.length} tags ${watch.elapsedMilliseconds}ms',
      );

      return MangaDetails(
        id: mangaId,
        sourceId: id,
        title: title,
        coverUrl: cover,
        description: summary,
        tags: genres,
      );
    } catch (e) {
      diagSoon(
        'anzmangashd: details $mangaId threw '
        '${watch.elapsedMilliseconds}ms: ${e.runtimeType} $e',
      );
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    final watch = Stopwatch()..start();
    try {
      final html = await fetchHtml('$baseUrl/manga/$mangaId');
      if (html.isEmpty) {
        diagSoon('anzmangashd: chapters $mangaId got no html');
        return [];
      }
      final document = html_parser.parse(html);
      final chapters = <Chapter>[];

      var entries = document.querySelectorAll('ul.chapters li');
      if (entries.isEmpty) entries = document.querySelectorAll('li');
      final entryCount = entries.length;

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

        final chapterId = _relativeChapterId(href);
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

      diagSoon(
        'anzmangashd: chapters $mangaId = ${chapters.length} '
        'of $entryCount entries ${watch.elapsedMilliseconds}ms',
      );
      return chapters;
    } catch (e) {
      diagSoon(
        'anzmangashd: chapters $mangaId threw '
        '${watch.elapsedMilliseconds}ms: ${e.runtimeType} $e',
      );
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    final watch = Stopwatch()..start();
    try {
      // Chapter ids arrive as absolute URLs from the detail page; older cached
      // rows may still hold the path form, so accept both.
      final url = chapterId.startsWith('http')
          ? chapterId
          : '$baseUrl$chapterId';
      final html = await fetchHtml(url);
      final document = html_parser.parse(html);
      final urls = <String>[];

      for (final img in document.querySelectorAll('img.img-responsive')) {
        // Reader pages lazy-load every scan from data-src; `src` is a 1x1 GIF
        // placeholder (and the site logo on the header), so it is never a page.
        final raw = (img.attributes['data-src'] ?? '').trim();
        if (raw.isEmpty || raw.startsWith('data:')) continue;
        if (!raw.startsWith('http')) continue;
        urls.add(raw);
      }
      diagSoon(
        'anzmangashd: pages $chapterId = ${urls.length} ${watch.elapsedMilliseconds}ms',
      );
      return urls;
    } catch (e) {
      diagSoon(
        'anzmangashd: pages $chapterId threw '
        '${watch.elapsedMilliseconds}ms: ${e.runtimeType} $e',
      );
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

  /// Chapter links are absolute URLs on the detail page. Keep only the path so
  /// the reader can rebuild the URL with the base instead of doubling it.
  String _relativeChapterId(String href) {
    final clean = _idFromHref(href, keepTail: true);
    if (clean.startsWith(baseUrl)) {
      return clean.substring(baseUrl.length);
    }
    return clean;
  }

  static String _coverFromImg(dynamic img) {
    if (img == null) return '';
    final raw = (img.attributes['data-src'] ?? img.attributes['src'] ?? '')
        .toString()
        .trim();
    if (!raw.startsWith('http')) return '';
    return raw;
  }

  static String _cleanTitle(String? raw, String suffix) {
    if (raw == null) return '';
    var t = raw.trim();
    if (t.endsWith(suffix)) {
      t = t.substring(0, t.length - suffix.length).trim();
    }
    const online = ' Manga Online';
    if (t.endsWith(online)) {
      t = t.substring(0, t.length - online.length).trim();
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
