import 'dart:convert';
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

/// Komga — a self-hosted comic server exposing a documented REST API.
///
/// This source talks to the Komga API of *your own* server. Point it at your
/// instance by changing [KomgaSource.komgaServerUrl] (or by using the per-
/// source "Domain" override in the network settings of this source, which is
/// how you'd reach a LAN address such as `http://192.168.1.10:25600`). If your
/// server requires a username/password or an API key, add the right
/// `Authorization` / `X-API-Key` header to [headers].
class KomgaSource extends DioSource implements MangaSource {
  /// Set this to your Komga server (e.g. `http://192.168.1.10:25600`).
  static const String komgaServerUrl = 'https://demo.komga.org';

  @override
  String get networkSourceId => id;

  @override
  String get id => 'komga';
  @override
  String get name => 'Komga';
  @override
  String get baseUrl => komgaServerUrl;
  @override
  String get readerBaseUrl => komgaServerUrl;
  @override
  String get iconUrl => '';

  @override
  Map<String, String>? get headers => const {
    'Accept': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };

  String get _api => '$baseUrl/api/v1';

  /// Parses a JSON body and returns the `content` array of a paged response.
  List<dynamic> _content(String body) {
    if (body.isEmpty) return [];
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['content'] is List) {
        return decoded['content'] as List;
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final body = await grabText('$_api/series?page=${page - 1}&size=50');
      final result = <Manga>[];
      for (final raw in _content(body)) {
        if (raw is! Map) continue;
        final m = raw.cast<String, dynamic>();
        final id = m['id']?.toString() ?? '';
        final title = m['name']?.toString() ?? '';
        if (id.isEmpty || title.isEmpty) continue;
        result.add(Manga(id: id, title: title, coverUrl: '$baseUrl/api/v1/series/$id/thumbnail', sourceId: id));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      if (query.isEmpty) return [];
      final body = await grabText(
        '$_api/series?search=${Uri.encodeQueryComponent(query)}&page=${page - 1}&size=50',
      );
      final result = <Manga>[];
      for (final raw in _content(body)) {
        if (raw is! Map) continue;
        final m = raw.cast<String, dynamic>();
        final id = m['id']?.toString() ?? '';
        final title = m['name']?.toString() ?? '';
        if (id.isEmpty || title.isEmpty) continue;
        result.add(Manga(id: id, title: title, coverUrl: '$baseUrl/api/v1/series/$id/thumbnail', sourceId: id));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final body = await grabText('$_api/series/$mangaId');
      if (body.isEmpty) return null;
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final s = decoded.cast<String, dynamic>();

      final metadata = (s['metadata'] is Map)
          ? (s['metadata'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{};

      final tags = <String>[];
      final genres = metadata['genres'];
      if (genres is List) tags.addAll(genres.map((x) => x.toString()));
      final authors = <String>[];
      final authorList = metadata['authors'];
      if (authorList is List) {
        for (final a in authorList) {
          if (a is Map && a['name'] != null) authors.add(a['name'].toString());
        }
      }

      final statusRaw = (s['status'] is Map)
          ? (s['status'] as Map)['label']?.toString()
          : s['status']?.toString();
      String status = statusRaw ?? '';
      if (status.toLowerCase() == 'ended') status = 'Completed';
      if (status.toLowerCase() == 'ongoing') status = 'Ongoing';

      final year = metadata['releaseDate']?.toString() ?? '';

      return MangaDetails(
        id: mangaId,
        title: s['name']?.toString() ?? '',
        coverUrl: '$baseUrl/api/v1/series/$mangaId/thumbnail',
        sourceId: id,
        description: metadata['summary']?.toString() ?? '',
        author: authors.join(', '),
        status: status,
        year: year.isNotEmpty && year.length >= 4 ? year.substring(0, 4) : '',
        tags: tags,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final body = await grabText('$_api/books?series_id=$mangaId&page=0&size=500');
      final chapters = <Chapter>[];
      for (final raw in _content(body)) {
        if (raw is! Map) continue;
        final b = raw.cast<String, dynamic>();
        final bookId = b['id']?.toString() ?? '';
        if (bookId.isEmpty) continue;
        final number = b['number']?.toString() ?? '';
        final title = b['name']?.toString().trim() ?? '';
        chapters.add(
          Chapter(
            id: 'book/$bookId',
            title: title.isNotEmpty ? title : 'Chapter $number',
            chapterNumber: number,
            releaseDate: b['created']?.toString() ?? '',
            url: '$baseUrl/book/$bookId',
          ),
        );
      }
      chapters.sort((a, b) {
        final na = double.tryParse(a.chapterNumber) ?? 0;
        final nb = double.tryParse(b.chapterNumber) ?? 0;
        return na.compareTo(nb);
      });
      return chapters;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      if (!chapterId.startsWith('book/')) return [];
      final bookId = chapterId.substring('book/'.length);
      final body = await grabText('$_api/books/$bookId/pages');
      if (body.isEmpty) return [];
      final pages = _content(body);
      final urls = <String>[];
      for (final raw in pages) {
        if (raw is! Map) continue;
        final p = raw.cast<String, dynamic>();
        final url = p['url']?.toString() ?? '';
        if (url.isNotEmpty) {
          urls.add(url.startsWith('http') ? url : '$baseUrl$url');
        }
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
  Future<List<Manga>> searchWithFilter(
    MangaFilter filter, {
    int page = 1,
  }) async {
    return searchMangaByTags(filter.genres, page: page);
  }

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async {
    try {
      final chapters = await getChapters(mangaId);
      (String, DateTime)? best;
      for (final c in chapters) {
        final date = DateTime.tryParse(c.releaseDate ?? '')?.toLocal();
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
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    return [];
  }

  @override
  Future<List<String>> getAvailableTags() async {
    try {
      final body = await grabText(
        '$_api/series?page=0&size=200',
      );
      final tags = <String>{};
      for (final raw in _content(body)) {
        if (raw is! Map) continue;
        final s = raw.cast<String, dynamic>();
        final metadata = s['metadata'];
        if (metadata is Map && metadata['genres'] is List) {
          for (final g in metadata['genres'] as List) {
            tags.add(g.toString());
          }
        }
      }
      return tags.toList();
    } catch (_) {
      return [];
    }
  }
}