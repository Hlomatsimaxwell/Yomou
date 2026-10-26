import 'dart:convert';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

class DatgarScanlationSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'datgarscanlation';
  @override
  String get name => 'Datgar Scanlation';
  @override
  String get baseUrl => 'https://datgarscanlation.blogspot.com';
  @override
  String get readerBaseUrl => 'https://datgarscanlation.blogspot.com';
  @override
  String get iconUrl => 'https://datgarscanlation.blogspot.com/favicon.ico';

  @override
  Map<String, String>? get headers => null;

  String _idFromHref(String href) {
    // Use the full href as ID (it's a stable URL)
    return href;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final startIndex = 20 * (page - 1) + 1;
      final url = '$baseUrl/feeds/posts/default/-/Series?alt=json&orderby=published&max-results=21&start-index=$startIndex';
      final jsonStr = await grabText(url);
      if (jsonStr.isEmpty) return [];
      final data = jsonDecode(jsonStr);
      final feed = data['feed'];
      if (feed == null) return [];
      final entries = feed['entry'] as List?;
      if (entries == null || entries.isEmpty) return [];
      final mangas = <Manga>[];
      final seen = <String>{};
      for (final entry in entries) {
        try {
          final title = entry['title']?['\$t']?.toString() ?? '';
          final links = entry['link'] as List?;
          String href = '';
          if (links != null) {
            for (final l in links) {
              if (l['rel'] == 'alternate') {
                href = l['href']?.toString() ?? '';
                break;
              }
            }
          }
          if (href.isEmpty || title.isEmpty) continue;
          if (seen.contains(href)) continue;
          seen.add(href);
          String cover = '';
          final thumb = entry['media\$thumbnail']?['url']?.toString() ?? '';
          if (thumb.isNotEmpty) {
            cover = thumb.replaceAll(RegExp(r'/s\d+-c/'), '/w600/').replaceAll(RegExp(r'=s\d+-c$'), '=w600');
          } else {
            final content = entry['content']?['\$t']?.toString() ?? '';
            if (content.isNotEmpty) {
              final doc = parser.parse(content);
              final img = doc.querySelector('img');
              cover = img?.attributes['src'] ?? '';
            }
          }
          mangas.add(Manga(id: href, title: title, coverUrl: cover, sourceId: this.id));
        } catch (_) {
          continue;
        }
      }
      return mangas;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      if (query.isEmpty) return getPopularManga(page: page);
      final startIndex = 20 * (page - 1) + 1;
      final searchUrl = '$baseUrl/feeds/posts/default/-/Series?alt=json&orderby=published&max-results=21&start-index=$startIndex&q=${Uri.encodeQueryComponent(query)}';
      final jsonStr = await grabText(searchUrl);
      if (jsonStr.isEmpty) return getPopularManga(page: page);
      final data = jsonDecode(jsonStr);
      final feed = data['feed'];
      if (feed == null) return [];
      final entries = feed['entry'] as List?;
      if (entries == null || entries.isEmpty) return [];
      final mangas = <Manga>[];
      final seen = <String>{};
      for (final entry in entries) {
        try {
          final title = entry['title']?['\$t']?.toString() ?? '';
          final links = entry['link'] as List?;
          String href = '';
          if (links != null) {
            for (final l in links) {
              if (l['rel'] == 'alternate') {
                href = l['href']?.toString() ?? '';
                break;
              }
            }
          }
          if (href.isEmpty || title.isEmpty) continue;
          if (seen.contains(href)) continue;
          seen.add(href);
          String cover = '';
          final thumb = entry['media\$thumbnail']?['url']?.toString() ?? '';
          if (thumb.isNotEmpty) {
            cover = thumb.replaceAll(RegExp(r'/s\d+-c/'), '/w600/').replaceAll(RegExp(r'=s\d+-c$'), '=w600');
          }
          mangas.add(Manga(id: href, title: title, coverUrl: cover, sourceId: this.id));
        } catch (_) {
          continue;
        }
      }
      return mangas.isNotEmpty ? mangas : getPopularManga(page: page);
    } catch (_) {
      return getPopularManga(page: page);
    }
  }

  @override
  Future<List<Manga>> searchWithFilter(MangaFilter filter, {int page = 1}) => getPopularManga(page: page);

  @override
  Future<List<Manga>> searchMangaByTags(List<String> tags, {int page = 1}) => getPopularManga(page: page);

  @override
  Future<List<String>> getAvailableTags() async => [];

  String _extractChapterLabel(String html) {
    // Find the #latest div first, then extract label from its script
    final latestIdx = html.indexOf('id=\"latest\"');
    if (latestIdx >= 0) {
      final snippet = html.substring(latestIdx, (latestIdx + 300).clamp(0, html.length));
      final latestMatch = RegExp(r"label\s*=\s*'([^']+)'").firstMatch(snippet);
      if (latestMatch != null) return latestMatch.group(1)!;
    }
    // Fallback: try #myUL script src with /-/label
    final myUlMatch = RegExp(r'feeds/posts/default/-/([^?"]+)').firstMatch(html);
    if (myUlMatch != null) return Uri.decodeComponent(myUlMatch.group(1)!);
    // Try #clwd
    final clwdMatch = RegExp(r"clwd\.run\('([^']+)'").firstMatch(html);
    if (clwdMatch != null) return clwdMatch.group(1)!;
    // Try #chapterlist data-post-title
    // Try var label_chapter
    final labelMatch = RegExp(r'label_chapter\s*=\s*"([^"]+)"').firstMatch(html);
    if (labelMatch != null) return labelMatch.group(1)!;
    return '';
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final url = mangaId.startsWith('http') ? mangaId : '$baseUrl/$mangaId';
      final html = await grabText(url);
      if (html.isEmpty) return null;
      final document = parser.parse(html);
      final title = document.querySelector('h1.post-title, .post-title, h1.entry-title')?.text.trim() ?? mangaId;
      String cover = '';
      final img = document.querySelector('.post-body img, .entry-content img, .separator img');
      if (img != null) {
        cover = img.attributes['src'] ?? '';
      }
      final descEl = document.querySelector('#synopsis, #Sinopse, .sinopsis, .sinopas');
      final desc = descEl?.text.trim() ?? '';
      return MangaDetails(id: mangaId, title: title, coverUrl: cover, sourceId: this.id, description: desc);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final url = mangaId.startsWith('http') ? mangaId : '$baseUrl/$mangaId';
      final html = await grabText(url);
      if (html.isEmpty) return [];
      final label = _extractChapterLabel(html);
      if (label.isEmpty) return [];
      final feedUrl = '$baseUrl/feeds/posts/default/-/${Uri.encodeComponent(label)}?alt=json&orderby=published&max-results=9999';
      final jsonStr = await grabText(feedUrl);
      if (jsonStr.isEmpty) return [];
      final data = jsonDecode(jsonStr);
      final feed = data['feed'];
      if (feed == null) return [];
      final entries = feed['entry'] as List?;
      if (entries == null || entries.isEmpty) return [];
      final chapters = <Chapter>[];
      final mangaSlug = mangaId.split('/').last;
      for (final entry in entries.reversed) {
        try {
          final name = entry['title']?['\$t']?.toString() ?? '';
          final links = entry['link'] as List?;
          String href = '';
          if (links != null) {
            for (final l in links) {
              if (l['rel'] == 'alternate') {
                href = l['href']?.toString() ?? '';
                break;
              }
            }
          }
          if (href.isEmpty) continue;
          final slugChapter = href.split('/').last;
          if (slugChapter == mangaSlug) continue; // skip the manga series post itself
          final dateText = entry['published']?['\$t']?.toString() ?? '';
          chapters.add(Chapter(
            id: href,
            title: name,
            chapterNumber: '',
            releaseDate: dateText.split('T').first,
            url: href,
          ));
        } catch (_) {
          continue;
        }
      }
      return chapters;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final url = chapterId.startsWith('http') ? chapterId : '$baseUrl/$chapterId';
      final html = await grabText(url);
      if (html.isEmpty) return [];
      // Check for chapterImage = [...]
      final chapterImageMatch = RegExp(r'chapterImage\s*=\s*\[([^\]]*)\]').firstMatch(html);
      if (chapterImageMatch != null) {
        final urls = chapterImageMatch.group(1)!
            .replaceAll(' ', '')
            .replaceAll('"', '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList();
        if (urls.isNotEmpty) return urls;
      }
      // Check for const content = `...`
      final contentMatch = RegExp(r'const content\s*=\s*`([^`]*)`').firstMatch(html);
      if (contentMatch != null) {
        final content = contentMatch.group(1)!;
        final doc = parser.parse(content);
        final imgs = doc.querySelectorAll('img');
        final urls = <String>[];
        for (final img in imgs) {
          final src = img.attributes['src'] ?? '';
          if (src.isNotEmpty) urls.add(src);
        }
        if (urls.isNotEmpty) return urls;
      }
      // Fallback: selectPage images
      final document = parser.parse(html);
      final urls = <String>[];
      for (final img in document.querySelectorAll('div.check-box img, article#reader .separator img, article.container .separator img, #readarea img, #reader img, #readerarea img, .post-body img, .entry-content img')) {
        final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
        if (src.isNotEmpty && !src.contains('avatar')) {
          urls.add(src);
        }
      }
      return urls;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async => null;

  @override
  Future<int> getTotalChapters(String mangaId) async => 0;
}