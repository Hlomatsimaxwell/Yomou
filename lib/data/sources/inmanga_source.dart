import 'dart:convert';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

class InMangaSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'inmanga';
  @override
  String get name => 'InManga';
  @override
  String get baseUrl => 'https://inmanga.com';
  @override
  String get readerBaseUrl => 'https://inmanga.com';
  @override
  String get iconUrl => 'https://assets.intomanga.com/inmangafavicon.png';

  @override
  Map<String, String>? get headers => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Referer': '$baseUrl/',
  };

  String _guidFromId(String mangaId) {
    // mangaId is "Name/GUID"
    final parts = mangaId.split('/');
    return parts.length > 1 ? parts.last : mangaId;
  }

  String _nameFromId(String mangaId) {
    final parts = mangaId.split('/');
    return parts.length > 1 ? parts.first : mangaId;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final skip = (page - 1) * 20;
      final html = await postText('$baseUrl/manga/getMangasConsultResult', rawBody: 'filter[generes]=&filter[queryString]=&filter[skip]=$skip&filter[take]=20&filter[sortby]=1&filter[broadcastStatus]=0&filter[onlyFavorites]=false&d=');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final mangas = <Manga>[];
      final seen = <String>{};
      for (final a in document.querySelectorAll('a.manga-result')) {
        final href = a.attributes['href'] ?? '';
        if (href.isEmpty || !href.contains('/ver/manga/')) continue;
        final parts = href.split('/ver/manga/');
        if (parts.length < 2) continue;
        final id = parts[1]; // Name/GUID
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        final img = a.querySelector('img');
        final cover = img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
        final titleEl = a.querySelector('h4');
        var title = titleEl?.text.trim() ?? '';
        if (title.isEmpty) title = img?.attributes['alt'] ?? '';
        if (title.isEmpty) continue;
        mangas.add(Manga(id: id, title: title, coverUrl: cover, sourceId: this.id));
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
      final skip = (page - 1) * 20;
      final html = await postText('$baseUrl/manga/getMangasConsultResult', rawBody: 'filter[generes]=&filter[queryString]=${Uri.encodeQueryComponent(query)}&filter[skip]=$skip&filter[take]=20&filter[sortby]=1&filter[broadcastStatus]=0&filter[onlyFavorites]=false&d=');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final mangas = <Manga>[];
      final seen = <String>{};
      for (final a in document.querySelectorAll('a.manga-result')) {
        final href = a.attributes['href'] ?? '';
        if (href.isEmpty || !href.contains('/ver/manga/')) continue;
        final parts = href.split('/ver/manga/');
        if (parts.length < 2) continue;
        final id = parts[1];
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        final img = a.querySelector('img');
        final cover = img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
        final titleEl = a.querySelector('h4');
        var title = titleEl?.text.trim() ?? '';
        if (title.isEmpty) title = img?.attributes['alt'] ?? '';
        if (title.isEmpty) continue;
        mangas.add(Manga(id: id, title: title, coverUrl: cover, sourceId: this.id));
      }
      return mangas;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchWithFilter(MangaFilter filter, {int page = 1}) => getPopularManga(page: page);

  @override
  Future<List<Manga>> searchMangaByTags(List<String> tags, {int page = 1}) => getPopularManga(page: page);

  @override
  Future<List<String>> getAvailableTags() async => [];

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/ver/manga/$mangaId');
      if (html.isEmpty) return null;
      final document = parser.parse(html);
      final title = document.querySelector('h1, .manga-titles h3')?.text.trim() ?? _nameFromId(mangaId);
      final img = document.querySelector('img[src*="cover/manga"], img[src*="thumbnail"]');
      String cover = img?.attributes['src'] ?? '';
      if (cover.isNotEmpty && !cover.startsWith('http')) {
        cover = '$baseUrl$cover';
      }
      final desc = document.querySelector('.manga-synopsis, .sinopsis, p')?.text.trim() ?? '';
      return MangaDetails(id: mangaId, title: title, coverUrl: cover, sourceId: this.id, description: desc);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final guid = _guidFromId(mangaId);
      final jsonStr = await grabText('$baseUrl/chapter/getall?mangaIdentification=$guid');
      if (jsonStr.isEmpty) return [];
      final data = jsonDecode(jsonStr);
      final inner = jsonDecode(data['data']);
      final result = inner['result'] as List?;
      if (result == null) return [];
      final chapters = <Chapter>[];
      for (final c in result) {
        final chId = c['Identification']?.toString() ?? '';
        final num = c['FriendlyChapterNumber']?.toString() ?? c['Number']?.toString() ?? '';
        final date = c['RegistrationDate']?.toString() ?? '';
        if (chId.isEmpty) continue;
        chapters.add(Chapter(
          id: chId,
          title: 'Capítulo $num',
          chapterNumber: num,
          releaseDate: date,
          url: '$baseUrl/ver/manga/${_nameFromId(mangaId)}/$num/$chId',
        ));
      }
      return chapters;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    // chapterId is the chapter GUID
    // Need manga GUID - but we only have chapter GUID here
    // The image URL pattern: https://cdn1.intomanga.com/i/m/{mangaGUID}/c/{chapterGUID}/o/{pageGUID}.jpg
    // We need to get page GUIDs from /chapter/chapterIndexControls
    try {
      final html = await grabText('$baseUrl/chapter/chapterIndexControls?identification=$chapterId');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final pageGuids = <String>[];
      for (final opt in document.querySelectorAll('#PageList option')) {
        final val = opt.attributes['value'] ?? '';
        if (val.isNotEmpty && val.contains('-')) {
          pageGuids.add(val);
        }
      }
      // We need mangaGUID and chapterGUID to construct URLs
      // Extract from the page - the chapterIndexControls doesn't include mangaGUID directly
      // But the image URL template uses chapterGUID (which is chapterId) and pageGUID
      // We need mangaGUID - let's extract from the pu variable in the chapter page
      // For now, construct with just chapterGUID and pageGUID, using a placeholder mangaGUID
      // Actually, we need to fetch the chapter page to get mangaGUID
      // Let's try to get it from the chapter page HTML
      final chapterPageHtml = await grabText('$baseUrl/ver/manga/x/1/$chapterId');
      // Extract mangaGUID from pu variable
      String mangaGuid = '';
      final puMatch = RegExp(r"var pu = 'https://cdn1\.intomanga\.com/i/m/([a-f0-9-]+)/c/").firstMatch(chapterPageHtml);
      if (puMatch != null) {
        mangaGuid = puMatch.group(1) ?? '';
      }
      final urls = <String>[];
      for (final pg in pageGuids) {
        if (mangaGuid.isNotEmpty) {
          urls.add('https://cdn1.intomanga.com/i/m/$mangaGuid/c/${chapterId.toLowerCase()}/o/$pg.jpg');
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