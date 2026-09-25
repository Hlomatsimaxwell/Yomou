import 'dart:isolate';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../models/manga_source.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

/// Pure, isolate-safe chapter-list parser. WeebCentral's full-chapter-list
/// page can be several megabytes with thousands of links; parsing it on the UI
/// isolate freezes the app (ANR), so [getChapters] runs this in the
/// background via [Isolate.run].
List<Chapter> _parseWeebCentralChapters(String html, String baseUrl) {
  final document = parser.parse(html);
  final links = document.querySelectorAll('a[href*="/chapters/"]');
  final chapters = <Chapter>[];
  for (final link in links) {
    final href = link.attributes['href'] ?? '';
    final chapterId = Uri.parse(href).pathSegments.length > 1
        ? Uri.parse(href).pathSegments[1]
        : href;
    if (chapterId.isEmpty) continue;

    final span = link.querySelector('span.flex > span');
    final title = span?.text.trim() ?? '';

    final numberMatch = RegExp(
      r'(?<!S)\b(\d+(\.\d+)?)\b',
    ).firstMatch(title);
    final chapterNumber = numberMatch?.group(1) ?? '';

    final time =
        link.querySelector('time[datetime]')?.attributes['datetime'] ?? '';
    final scanlator =
        link.querySelector('svg[stroke]')?.attributes['stroke'] == '#d8b4fe'
        ? 'Official'
        : '';

    chapters.add(
      Chapter(
        id: chapterId,
        title: title,
        chapterNumber: chapterNumber,
        releaseDate: time,
        url: href.startsWith('http') ? href : '$baseUrl$href',
        scanlator: scanlator,
      ),
    );
  }
  return chapters;
}

/// Short-lived parse cache so the updates scan (which reads both the total and
/// the latest chapter for every library series) never parses the giant page
/// twice back-to-back.
final _chapterListCache = <String, ({DateTime at, List<Chapter> chapters})>{};

/// WeebCentral (https://weebcentral.com) source.
///
/// WeebCentral serves normal HTML for every endpoint (search, series,
/// chapters, chapter images) so no JS execution or Cloudflare bypass is
/// required — a simple GET with a browser User-Agent is enough.
class WeebCentralSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'weebcentral';

  @override
  String get name => 'WeebCentral';

  @override
  String get baseUrl => 'https://weebcentral.com';
  @override
  String get iconUrl => 'https://weebcentral.com/favicon.ico';

  @override
  String get readerBaseUrl => 'https://weebcentral.com';

  @override
  Map<String, String>? get headers => {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept': 'text/html,application/xhtml+xml',
    'Referer': 'https://weebcentral.com/',
  };

  static const int _pageSize = 32;

  String _searchUrl({
    int page = 1,
    String? text,
    String sort = 'Best Match',
    String order = 'Ascending',
    List<String> tags = const [],
    List<String> excludeTags = const [],
  }) {
    final parts = <String>[
      'limit=$_pageSize',
      'offset=${(page - 1) * _pageSize}',
      'sort=${Uri.encodeQueryComponent(sort)}',
      'order=${Uri.encodeQueryComponent(order)}',
      'official=Any',
      'anime=Any',
      'adult=Any',
      'display_mode=${Uri.encodeQueryComponent('Full Display')}',
    ];
    if (text != null && text.isNotEmpty) {
      final clean = text
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (clean.isNotEmpty) {
        parts.add('text=${Uri.encodeQueryComponent(clean)}');
      }
    }
    for (final tag in tags) {
      parts.add('included_tag=${Uri.encodeQueryComponent(tag)}');
    }
    for (final tag in excludeTags) {
      parts.add('excluded_tag=${Uri.encodeQueryComponent(tag)}');
    }
    return '$baseUrl/search/data?${parts.join('&')}';
  }

  List<Manga> _parseSearchResults(String html) {
    if (html.isEmpty) return [];
    final document = parser.parse(html);
    final articles = document.querySelectorAll('article.bg-base-300');
    return articles.map((element) {
      final a = element.querySelector('a[href*="/series/"]');
      final href = a?.attributes['href'] ?? '';
      final id = href.isEmpty
          ? ''
          : Uri.parse(href).pathSegments.length > 1
          ? Uri.parse(href).pathSegments[1]
          : href;
      final img = element.querySelector('img[src]');
      final titleEl = element.querySelector('.text-lg');
      final title = titleEl?.text.trim() ?? 'No name';
      return Manga(
        id: id,
        title: title,
        coverUrl: img?.attributes['src'] ?? '',
        sourceId: this.id,
      );
    }).toList();
  }

  // --- MangaSource interface ---

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      final html = await grabText(
        _searchUrl(page: page, text: query, sort: 'Best Match'),
      );
      return _parseSearchResults(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    try {
      final html = await grabText(
        _searchUrl(
          page: page,
          tags: tags,
          sort: 'Popularity',
          order: 'Descending',
        ),
      );
      return _parseSearchResults(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final html = await grabText(
        _searchUrl(page: page, sort: 'Popularity', order: 'Descending'),
      );
      return _parseSearchResults(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getAvailableTags() async {
    try {
      final html = await grabText('$baseUrl/search');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final inputs = document.querySelectorAll('input[id*="-value"]');
      final tags = <String>[];
      for (final input in inputs) {
        final value = input.attributes['value']?.trim() ?? '';
        if (value.isNotEmpty && !tags.contains(value)) {
          tags.add(value);
        }
      }
      return tags;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/series/$mangaId');
      if (html.isEmpty) return null;
      final document = parser.parse(html);
      final sections = document.querySelectorAll('section[x-data] > section');
      if (sections.length < 2) return null;
      final left = sections[0];
      final right = sections[1];

      final h1 = right.querySelector('h1')?.text.trim() ?? 'Unknown';
      final cover = left.querySelector('img[src]')?.attributes['src'] ?? '';
      final title = h1.isEmpty ? 'Unknown' : h1;

      String description = '';
      String author = '';
      String stateRaw = '';
      String year = '';
      final tags = <String>[];

      bool hasStrong(Element li, String prefix) {
        return li
            .querySelectorAll('strong')
            .any(
              (s) =>
                  s.text.trim().toLowerCase().startsWith(prefix.toLowerCase()),
            );
      }

      for (final li in left.querySelectorAll('li')) {
        if (hasStrong(li, 'Tag')) {
          for (final a in li.querySelectorAll('a')) {
            final t = a.text.trim();
            if (t.isNotEmpty && !tags.contains(t)) {
              tags.add(t);
            }
          }
        } else if (hasStrong(li, 'Status')) {
          stateRaw = li.querySelector('a')?.text.trim() ?? '';
        } else if (hasStrong(li, 'Author')) {
          author = li
              .querySelectorAll('span > a')
              .map((a) => a.text.trim())
              .where((t) => t.isNotEmpty)
              .join(', ');
        } else if (hasStrong(li, 'Released')) {
          year = li.querySelector('span')?.text.trim() ?? '';
        }
      }

      for (final li in right.querySelectorAll('li')) {
        if (hasStrong(li, 'Description')) {
          description = li.querySelector('p')?.text.trim() ?? '';
        }
      }

      String status = '';
      switch (stateRaw) {
        case 'Ongoing':
          status = 'Ongoing';
          break;
        case 'Complete':
          status = 'Completed';
          break;
        case 'Canceled':
          status = 'Cancelled';
          break;
        case 'Hiatus':
          status = 'Hiatus';
          break;
      }

      return MangaDetails(
        id: mangaId,
        title: title,
        coverUrl: cover,
        sourceId: id,
        description: description,
        author: author,
        status: status,
        year: year,
        tags: tags,
        totalChapters: 0,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    final cached = _chapterListCache[mangaId];
    if (cached != null &&
        DateTime.now().difference(cached.at).inMinutes < 5) {
      return cached.chapters;
    }
    try {
      var html = await grabText('$baseUrl/series/$mangaId/full-chapter-list');
      if (!html.contains('/chapters/')) {
        // Fall back to the series page's inline chapter list.
        html = await grabText('$baseUrl/series/$mangaId');
      }
      if (html.isEmpty) return [];

      final chapters = await Isolate.run(
        () => _parseWeebCentralChapters(html, baseUrl),
      );
      _chapterListCache[mangaId] = (at: DateTime.now(), chapters: chapters);
      return chapters;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final html = await grabText(
        '$baseUrl/chapters/$chapterId/images?is_prev=False&reading_style=long_strip',
      );
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final images = document.querySelectorAll(
        'section[id="chapter-images"] img[src]',
      );
      return images.map((img) => img.attributes['src'] ?? '').toList();
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
      for (final chapter in chapters) {
        final date = DateTime.tryParse(chapter.releaseDate ?? '');
        if (date != null) return (chapter.title, date);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
