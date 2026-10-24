import 'package:html/parser.dart' as html_parser;
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_details.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/models/manga_filter.dart';
import 'package:yomou/data/sources/source_network.dart';

class AsiaLotussSource extends DioSource implements MangaSource {
  @override
  String get id => 'asialotuss';

  @override
  String get name => 'Asia Lotuss';

  @override
  String get baseUrl => 'https://asialotuss.com';

  @override
  String get readerBaseUrl => baseUrl;

  @override
  String get networkSourceId => id;

  @override
  String get languageCode => 'es';

  @override
  String get iconUrl => '$baseUrl/favicon.ico';

  @override
  Map<String, String>? get headers => const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Mobile Safari/537.36',
      };

  Future<String> fetchHtml(String url) async => grabText(url);

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final html = await fetchHtml(baseUrl);
      final document = html_parser.parse(html);
      final manga = <Manga>[];

      document.querySelectorAll('div.bs').forEach((bs) {
        final link = bs.querySelector('a');
        if (link == null) return;
        final href = (link.attributes['href'] ?? '').trim();
        final title = (link.attributes['title'] ?? '').trim();
        if (href.isEmpty) return;
        final mangaId = _fromPath(href);
        if (mangaId.isEmpty) return;

        final img = bs.querySelector('img');
        final cover = _coverFromImg(img);

        manga.add(Manga(
          id: mangaId,
          title: title.isNotEmpty ? title : 'No title',
          sourceId: id,
          coverUrl: cover,
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
      final path = mangaId.startsWith('http') ? mangaId : '$baseUrl/$mangaId';
      final html = await fetchHtml(path);
      final document = html_parser.parse(html);

      final title = document.querySelector('h1.entry-title')?.text.trim() ?? '';
      final cover = _coverFromImg(document.querySelector('img.ts-post-image'));
      final summary = document
              .querySelector('.entry-content.entry-content-single')
              ?.text
              .trim() ??
          '';

      return MangaDetails(
        id: mangaId,
        sourceId: id,
        title: title,
        coverUrl: cover,
        description: summary,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final path = mangaId.startsWith('http') ? mangaId : '$baseUrl/$mangaId';
      final html = await fetchHtml(path);
      final document = html_parser.parse(html);
      final chapters = <Chapter>[];

      document.querySelectorAll('#chapterlist li').forEach((li) {
        final link = li.querySelector('.eph-num a');
        if (link == null) return;
        final href = (link.attributes['href'] ?? '').trim();
        if (href.isEmpty) return;
        final title = li.querySelector('.chapternum')?.text.trim() ?? link.text.trim();
        if (title.isEmpty) return;
        final dateStr = li.querySelector('.chapterdate')?.text.trim() ?? '';

        final chapterId = _fromPath(href);
        chapters.add(Chapter(
          id: chapterId,
          title: title,
          chapterNumber: _chapterNumber(title, href),
          releaseDate: dateStr.isEmpty ? null : dateStr,
          url: href,
        ));
      });

      return chapters;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final url = chapterId.startsWith('http')
          ? chapterId
          : '$baseUrl/$chapterId';
      final html = await fetchHtml(url);
      final pages = <String>[];
      final re = RegExp(r'"images"\s*:\s*\[([^\]]+)\]');
      for (final m in re.allMatches(html)) {
        for (final q in RegExp(r'"([^"]+)"').allMatches(m.group(1)!)) {
          final pageUrl = q.group(1)!.trim();
          if (pageUrl.isNotEmpty && !pages.contains(pageUrl)) {
            pages.add(pageUrl.replaceAll('\\', ''));
          }
        }
      }
      return pages;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      final html = await fetchHtml('$baseUrl/?s=${Uri.encodeQueryComponent(query)}');
      final document = html_parser.parse(html);
      final manga = <Manga>[];

      document.querySelectorAll('div.bs').forEach((bs) {
        final link = bs.querySelector('a');
        if (link == null) return;
        final href = (link.attributes['href'] ?? '').trim();
        final title = (link.attributes['title'] ?? '').trim();
        if (href.isEmpty) return;
        final mangaId = _fromPath(href);
        if (mangaId.isEmpty) return;

        final img = bs.querySelector('img');
        final cover = _coverFromImg(img);

        manga.add(Manga(
          id: mangaId,
          title: title.isNotEmpty ? title : 'No title',
          sourceId: id,
          coverUrl: cover,
        ));
      });

      return manga;
    } catch (_) {
      return [];
    }
  }

  static String _fromPath(String href) {
    return href
        .replaceFirst(RegExp(r'^https?://[^/]+'), '')
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/$'), '');
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

  static String _chapterNumber(String title, String href) {
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(title);
    if (m != null) return m.group(1)!;
    return '';
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
