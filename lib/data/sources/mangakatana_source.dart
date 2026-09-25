import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

/// MangaKatana (https://mangakatana.com) source.
///
/// All endpoint serve plain HTML: the manga directory (`/manga/page/N`),
/// genre pages (`/genre/{slug}/page/N`), title search (`/?search=...`) and
/// the book page all share the same `#book_list .item` card markup. Chapter
/// page image URLs are embedded as a JS array (`thzq`/`ytaw`) of tokenized
/// `i1.mangakatana.com/token/...` URLs inside the chapter page, so no extra
/// request is needed to get pages.
class MangakatanaSource extends DioSource implements MangaSource {
  @override
  String get id => 'mangakatana';

  @override
  String get name => 'MangaKatana';

  @override
  String get baseUrl => 'https://mangakatana.com';
  @override
  String get iconUrl => 'https://mangakatana.com/favicon.ico';

  @override
  String get readerBaseUrl => 'https://mangakatana.com';

  @override
  Map<String, String>? get headers => {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept': 'text/html,application/xhtml+xml',
    'Referer': 'https://mangakatana.com/',
  };

  @override
  String get networkSourceId => id;

  // --- Shared card grid parser (search / directory / genre pages) ---

  List<Manga> _parseMangaGrid(String html) {
    if (html.isEmpty) return [];
    final document = parser.parse(html);
    final items = document.querySelectorAll('#book_list .item');
    final mangas = <Manga>[];
    for (final item in items) {
      final link =
          item.querySelector('.title a') ??
          item.querySelector('a[href*="/manga/"]');
      final href = link?.attributes['href'] ?? '';
      final path = href.replaceFirst(baseUrl, '');
      if (!path.startsWith('/manga/')) continue;
      final id = path.replaceFirst(RegExp(r'^/'), '');
      final img = item.querySelector('.media img[src]');
      final title = link?.text.trim() ?? '';
      mangas.add(
        Manga(
          id: id,
          title: title.isEmpty ? 'No name' : title,
          coverUrl: img?.attributes['src'] ?? '',
          sourceId: this.id,
        ),
      );
    }
    return mangas;
  }

  // --- MangaSource interface ---

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      final html = await grabText(
        '$baseUrl/?search=${Uri.encodeQueryComponent(query)}',
      );
      return _parseMangaGrid(html);
    } catch (_) {
      return [];
    }
  }

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
    try {
      if (tags.isEmpty) return [];
      final slug = _genreSlug(tags.first);
      if (slug.isEmpty) return [];
      final html = await grabText('$baseUrl/genre/$slug/page/$page');
      return _parseMangaGrid(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final html = await grabText('$baseUrl/manga/page/$page');
      return _parseMangaGrid(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getAvailableTags() async {
    try {
      final html = await grabText('$baseUrl/genres');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final anchors = document.querySelectorAll('ul.sub-menu.genres li a');
      final tags = <String>[];
      for (final a in anchors) {
        final name = a.querySelector('h3')?.text.trim() ?? '';
        if (name.isNotEmpty && !tags.contains(name)) {
          tags.add(name);
        }
      }
      return tags;
    } catch (_) {
      return [];
    }
  }

  String _genreSlug(String name) {
    return name.trim().toLowerCase().replaceAll(' ', '-');
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/$mangaId');
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final heading = document.querySelector('h1.heading');
      final cover = document.querySelector('.cover img[src]');
      final summary = document.querySelector('.summary p');

      String statusRaw = '';
      String author = '';
      final tags = <String>[];

      final meta = document.querySelector('ul.meta');
      if (meta != null) {
        for (final li in meta.querySelectorAll('li.d-row-small')) {
          final label = li.querySelector('.label')?.text.trim() ?? '';
          if (label.startsWith('Status')) {
            statusRaw = li.querySelector('.value')?.text.trim() ?? '';
          } else if (label.startsWith('Author')) {
            author = li
                .querySelectorAll('.authors a.author')
                .map((a) => a.text.trim())
                .where((t) => t.isNotEmpty)
                .join(', ');
          } else if (label.startsWith('Genre')) {
            for (final a in li.querySelectorAll('.genres a')) {
              final t = a.text.trim();
              if (t.isNotEmpty && !tags.contains(t)) {
                tags.add(t);
              }
            }
          }
        }
      }

      String status = '';
      switch (statusRaw.toLowerCase()) {
        case 'ongoing':
          status = 'Ongoing';
          break;
        case 'completed':
          status = 'Completed';
          break;
        case 'dropped':
          status = 'Cancelled';
          break;
        case 'on hiatus':
        case 'hiatus':
          status = 'Hiatus';
          break;
        default:
          status = statusRaw;
      }

      return MangaDetails(
        id: mangaId,
        title: heading?.text.trim() ?? 'Unknown',
        coverUrl: cover?.attributes['src'] ?? '',
        sourceId: id,
        description: summary?.text.trim() ?? '',
        author: author,
        status: status,
        year: '',
        tags: tags,
        totalChapters: 0,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/$mangaId');
      if (html.isEmpty || !html.contains('class="chapters"')) return [];

      final document = parser.parse(html);
      final rows = document.querySelectorAll('.chapters table tbody tr');
      final chapters = <Chapter>[];

      final numberRe = RegExp(r'(?:v\d+c|c)(\d+(?:\.\d+)?)$');

      for (final row in rows) {
        final link =
            row.querySelector('div.chapter a[href*="/c"]') ??
            row.querySelector('div.chapter a[href*="/v"]');
        if (link == null) continue;
        final href = link.attributes['href'] ?? '';
        final path = href.replaceFirst(baseUrl, '');
        if (!path.startsWith('/manga/')) continue;
        final id = path.replaceFirst(RegExp(r'^/'), '');
        final title = link.text.trim();
        if (title.isEmpty) continue;

        final chapterNumberMatch =
            numberRe.firstMatch(path) ?? numberRe.firstMatch(id);
        final chapterNumber = chapterNumberMatch?.group(1) ?? '';

        final timeEl = row.querySelector('.update_time');
        final releaseDate = timeEl?.text.trim() ?? '';

        chapters.add(
          Chapter(
            id: id,
            title: title,
            chapterNumber: chapterNumber,
            releaseDate: releaseDate,
            url: '$baseUrl/$id',
          ),
        );
      }
      return chapters;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final html = await grabText('$baseUrl/$chapterId');
      if (html.isEmpty) return [];

      final arrays = <List<String>>[];
      final varRe = RegExp(r'var [_a-zA-Z][_a-zA-Z0-9]*=\[');
      for (final m in varRe.allMatches(html)) {
        final start = m.end;
        final end = html.indexOf('];', start);
        if (end == -1) continue;
        final body = html.substring(start, end);
        final urls = _extractTokenUrls(body);
        if (urls.isNotEmpty) arrays.add(urls);
      }
      if (arrays.isEmpty) return [];

      arrays.sort((a, b) => b.length.compareTo(a.length));
      return arrays.first;
    } catch (_) {
      return [];
    }
  }

  List<String> _extractTokenUrls(String body) {
    final urls = <String>[];
    for (final m in RegExp(
      r"'https://i1\.mangakatana\.com/token/[^']*'",
    ).allMatches(body)) {
      final url = m.group(0)!.substring(1, m.group(0)!.length - 1);
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }
    return urls;
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
      for (final chapter in chapters) {
        final date = parseMangakatanaDate(chapter.releaseDate ?? '');
        if (date != null) {
          final title = chapter.chapterNumber.isEmpty
              ? chapter.title
              : 'Chapter ${chapter.chapterNumber}';
          return (title, date);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Parses the "Sep-05-2026" style dates used by MangaKatana.
DateTime? parseMangakatanaDate(String raw) {
  final m = RegExp(r'^([A-Za-z]{3})-(\d{1,2})-(\d{4})$').firstMatch(raw.trim());
  if (m == null) return null;
  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[m.group(1)!.toLowerCase()];
  if (month == null) return null;
  final day = int.tryParse(m.group(2)!);
  final year = int.tryParse(m.group(3)!);
  if (day == null || year == null) return null;
  return DateTime(year, month, day);
}
