import 'dart:convert';
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

/// Flame Scans (flamecomics.xyz) — a Next.js app. The full series catalog is
/// served as JSON from `/api/series`; details, chapters and page lists are
/// embedded in the `__NEXT_DATA__` JSON of the server-rendered pages. Images
/// are on a plain CDN (no hotlink protection, but the CDN 403s on an absent
/// User-Agent, so a browser UA is always sent).
class FlameScansSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'flamescans';
  @override
  String get name => 'Flame Scans';
  @override
  String get baseUrl => 'https://flamecomics.xyz';
  @override
  String get readerBaseUrl => 'https://flamecomics.xyz';
  @override
  String get iconUrl => 'https://flamecomics.xyz/favicon.ico';

  static const String _cdn = 'https://cdn.flamecomics.xyz';

  @override
  Map<String, String>? get headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  };

  String _coverUrl(Object? seriesId, Object? cover) {
    final id = seriesId?.toString() ?? '';
    final c = cover?.toString() ?? '';
    if (c.isEmpty || id.isEmpty) return '';
    if (c.startsWith('http')) return c;
    if (c.startsWith('/')) return '$_cdn$c';
    return '$_cdn/uploads/images/series/$id/$c';
  }

  List<Manga> _fromSeriesJson(List<dynamic> rows, {String? query}) {
    final result = <Manga>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final map = raw.cast<String, dynamic>();
      final id = map['id']?.toString();
      final title = map['label']?.toString() ?? map['title']?.toString() ?? '';
      if (id == null || title.isEmpty) continue;
      if (query != null &&
          !title.toLowerCase().contains(query.toLowerCase())) {
        continue;
      }
      final image = map['image']?.toString() ?? map['cover']?.toString() ?? '';
      result.add(
        Manga(
          id: id,
          title: title,
          coverUrl: _coverUrl(id, image),
          sourceId: id,
        ),
      );
    }
    return result;
  }

  /// Extracts the `pageProps` object from a Next page's `__NEXT_DATA__`.
  Map<String, dynamic>? _pageProps(String html) {
    final match = RegExp(
      r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    try {
      final decoded = jsonDecode(match.group(1)!) as Map;
      return (decoded['props'] as Map?)?['pageProps'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      if (page > 1) return [];
      final body = await grabText('$baseUrl/api/series');
      if (body.isEmpty) return [];
      final rows = jsonDecode(body);
      if (rows is! List) return [];
      final list = _fromSeriesJson(rows);
      // Use chapter count as a cheap popularity proxy.
      list.sort((a, b) {
        final aId = int.tryParse(a.id) ?? 0;
        final bId = int.tryParse(b.id) ?? 0;
        return bId.compareTo(aId);
      });
      return list.take(60).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      if (page > 1) return [];
      final body = await grabText('$baseUrl/api/series');
      if (body.isEmpty || query.isEmpty) return [];
      final rows = jsonDecode(body);
      if (rows is! List) return [];
      return _fromSeriesJson(rows, query: query);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/series/$mangaId');
      if (html.isEmpty) return null;
      final props = _pageProps(html);
      if (props == null) return null;
      final series = props['series'];
      if (series is! Map) return null;
      final s = series.cast<String, dynamic>();

      String author = '';
      final a = s['author'];
      if (a is List) author = a.map((x) => _str(x)).where((x) => x.isNotEmpty).join(', ');
      String status = '';
      final st = s['status'];
      if (st is String) status = st;
      if (st is Map && st['label'] != null) status = st['label'].toString();

      final tags = <String>[];
      final t = s['tags'];
      if (t is List) tags.addAll(t.map((x) => _str(x)).where((x) => x.isNotEmpty));

      return MangaDetails(
        id: mangaId,
        title: s['title']?.toString() ?? '',
        coverUrl: _coverUrl(mangaId, s['cover'] ?? s['image']),
        sourceId: id,
        description: s['description']?.toString() ?? '',
        author: author,
        status: status,
        year: s['year']?.toString() ?? '',
        tags: tags,
      );
    } catch (_) {
      return null;
    }
  }

  String _str(dynamic value) => value?.toString().trim() ?? '';

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/series/$mangaId');
      if (html.isEmpty) return [];
      final props = _pageProps(html);
      if (props == null) return [];
      final chapters = props['chapters'];
      if (chapters is! List) return [];

      final result = <Chapter>[];
      for (final raw in chapters) {
        if (raw is! Map) continue;
        final c = raw.cast<String, dynamic>();
        final seriesId = c['series_id']?.toString() ?? mangaId;
        final token = c['token']?.toString() ?? '';
        final number = c['chapter']?.toString() ?? '';
        final title = c['title']?.toString().trim() ?? '';
        final chapterTitle = title.isNotEmpty && title != number
            ? 'Chapter $number $title'
            : 'Chapter $number';
        final id = '$seriesId/$token';
        result.add(
          Chapter(
            id: id,
            title: chapterTitle.trim(),
            chapterNumber: number,
            releaseDate: c['release_date']?.toString() ?? '',
            url: '$baseUrl/series/$id',
          ),
        );
      }
      result.sort((a, b) {
        final na = double.tryParse(a.chapterNumber) ?? 0;
        final nb = double.tryParse(b.chapterNumber) ?? 0;
        return na.compareTo(nb);
      });
      return result;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final parts = chapterId.split('/');
      if (parts.length < 2) return [];
      final seriesId = parts[0];
      final token = parts[1];
      final html = await grabText('$baseUrl/series/$seriesId/$token');
      if (html.isEmpty) return [];
      final props = _pageProps(html);
      if (props == null) return [];
      final chapter = props['chapter'];
      if (chapter is! Map) return [];
      final images = chapter['images'];
      if (images is! Map) return [];

      final keys = images.keys.map((k) => int.tryParse(k.toString()) ?? 0).toList()
        ..sort();
      final urls = <String>[];
      for (final key in keys) {
        final meta = images[key.toString()];
        if (meta is! Map) continue;
        final name = meta['name']?.toString();
        if (name == null || name.isEmpty) continue;
        final modified = meta['modified']?.toString() ?? '';
        final q = modified.isNotEmpty ? '?$modified' : '';
        urls.add('$_cdn/uploads/images/series/$seriesId/$token/$name$q');
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
      if (tags.isEmpty || page > 1) return [];
      final body = await grabText('$baseUrl/api/series');
      if (body.isEmpty) return [];
      final rows = jsonDecode(body);
      if (rows is! List) return [];
      final all = _fromSeriesJson(rows);
      return all.where((m) {
        // Cheap in-memory tag check: most series carry tags only in detail;
        // fall back to title match so the browse filter still returns hits.
        return tags.every((t) => m.title.toLowerCase().contains(t.toLowerCase()));
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getAvailableTags() async => [];
}