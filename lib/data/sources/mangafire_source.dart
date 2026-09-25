import 'dart:convert';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga_filter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'mangafire_vrf.dart';
import 'source_network.dart';

/// MangaFire (mangafire.to) — one entry per language branch, mirroring
/// Kotatsu's MangaFire English / Spanish / Spanish (Latin) / French / Japanese
/// / Portuguese / Portuguese (Brazil) sources. Each variant shares the domain
/// but only reads its own language's chapter branches.
class MangaFireSource extends DioSource implements MangaSource {
  /// Source id, e.g. `mangafire-en`.
  final String sourceId;

  /// Language branch to read (en / es / fr / ja / pt / pt-br / es-la).
  final String langCode;

  MangaFireSource({required this.sourceId, required this.langCode});

  @override
  String get networkSourceId => id;

  @override
  String get id => sourceId;
  @override
  String get name => _nameFor(sourceId);
  @override
  String get baseUrl => 'https://mangafire.to';
  @override
  String get readerBaseUrl => 'https://mangafire.to';
  @override
  String get iconUrl => 'https://mangafire.to/assets/mangafire/favicon.svg';

  static String _nameFor(String sourceId) {
    const names = {
      'mangafire-en': 'MangaFire English',
      'mangafire-es': 'MangaFire Spanish',
      'mangafire-esla': 'MangaFire Spanish Latin',
      'mangafire-fr': 'MangaFire French',
      'mangafire-ja': 'MangaFire Japanese',
      'mangafire-pt': 'MangaFire Portuguese',
      'mangafire-ptbr': 'MangaFire Portuguese Brazil',
    };
    return names[sourceId] ?? 'MangaFire';
  }

  @override
  Map<String, String>? get headers => {
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
  };

  String _abs(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    return '$baseUrl$url';
  }

  /// Extracts the numeric manga id (".../manga/xxx-slug.38922" -> "38922").
  String _numericId(String mangaId) =>
      mangaId.contains('.') ? mangaId.substring(mangaId.lastIndexOf('.') + 1) : mangaId;

  /// Listings come from the `/filter` page (same layout whether browsed by
  /// genre, status, sort or keyword).
  List<Manga> _parseFilter(String html) {
    final document = parser.parse(html);
    final result = <Manga>[];
    final seen = <String>{};
    for (final unit in document.querySelectorAll('.original.card-lg .unit .inner')) {
      final a = unit.querySelector('.info > a');
      final href = a?.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final path = href.replaceAll(RegExp(r'^/+'), '');
      if (seen.contains(path)) continue;
      final title = a?.text.trim() ?? '';
      if (title.isEmpty) continue;
      final cover = _abs(unit.querySelector('img')?.attributes['src'] ?? '');
      seen.add(path);
      result.add(
        Manga(
          id: path,
          title: title,
          coverUrl: cover,
          sourceId: id,
        ),
      );
    }
    return result;
  }

  /// Builds the `/filter` URL for a browse page (order + tags + keyword).
  String _filterUrl({
    int page = 1,
    String sort = 'most_viewed',
    String? keyword,
    List<String>? genres,
    List<String>? excludeGenres,
  }) {
    final params = <String>[
      'page=$page',
      'language[]=$langCode',
      'sort=$sort',
    ];
    if (keyword != null && keyword.isNotEmpty) {
      final parts = keyword
          .trim()
          .split(RegExp(r'\s+'))
          .map((p) => Uri.encodeQueryComponent(p))
          .join('+');
      params.add('keyword=$parts');
      params.add('vrf=${MfVrf.generate(keyword.trim())}');
    }
    for (final g in genres ?? const <String>[]) {
      params.add('genre[]=${Uri.encodeQueryComponent(g)}');
    }
    for (final g in excludeGenres ?? const <String>[]) {
      params.add('genre[]=-${Uri.encodeQueryComponent(g)}');
    }
    return '$baseUrl/filter?${params.join('&')}';
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      final html = await grabText(_filterUrl(page: page));
      if (html.isEmpty) return [];
      return _parseFilter(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      if (query.trim().isEmpty) return [];
      final html = await grabText(_filterUrl(page: page, keyword: query));
      if (html.isEmpty) return [];
      return _parseFilter(html);
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
  Future<List<String>> getAvailableTags() async {
    try {
      final html = await grabText('$baseUrl/filter');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final tags = <String>[];
      for (final li in document.querySelectorAll('.genres > li')) {
        final label = li.querySelector('label')?.text.trim() ?? '';
        if (label.isNotEmpty && !tags.contains(label)) tags.add(label);
      }
      return tags;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await grabText('$baseUrl/$mangaId');
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final title = document.querySelector('.info > h1')?.text.trim() ?? '';

      final poster = document.querySelector('div.manga-detail div.poster img');
      final cover = _abs(poster?.attributes['src'] ?? '');

      var description = '';
      final synopsis = document.querySelector('#synopsis div.modal-content');
      if (synopsis != null) {
        if (synopsis.querySelector('div') != null) {
          description = synopsis.querySelectorAll('div').map((d) => d.text.trim()).where((t) => t.isNotEmpty).join('\n');
        } else {
          description = synopsis.text.trim();
        }
      }

      final tags = <String>[];
      for (final a in document.querySelectorAll('div.meta a[href*="/genre/"]')) {
        final t = a.text.trim();
        if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
      }

      final authors = <String>[];
      for (final a
          in document.querySelectorAll('div.meta a[href*="/author/"]')) {
        final t = a.text.trim();
        if (t.isNotEmpty && !authors.contains(t)) authors.add(t);
      }

      var status = '';
      final statusEl = document.querySelector('.info > p');
      if (statusEl != null) {
        status = switch (statusEl.text.trim().toLowerCase()) {
          'releasing' => 'ongoing',
          'completed' => 'completed',
          'discontinued' => 'discontinued',
          'on_hiatus' => 'on hiatus',
          'info' => 'upcoming',
          final other => other,
        };
      }

      return MangaDetails(
        id: mangaId,
        title: title,
        coverUrl: cover,
        sourceId: id,
        description: description,
        author: authors.join(', '),
        status: status,
        tags: tags,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final mangaUrl = '$baseUrl/$mangaId';
      final html = await grabText(mangaUrl);
      if (html.isEmpty) return [];
      final document = parser.parse(html);

      // Available chapter/volume types and their language branches.
      final types = <String>[];
      for (final a in document.querySelectorAll('.chapvol-tab > a')) {
        final t = a.attributes['data-name'] ?? '';
        if (t.isNotEmpty && !types.contains(t)) types.add(t);
      }

      final codeToTitle = <String, String>{};
      for (final el in document.querySelectorAll('.m-list div.tab-content')) {
        final type = el.attributes['data-name'] ?? '';
        if (!types.contains(type)) continue;
        for (final item in el.querySelectorAll('.list-menu .dropdown-item')) {
          final code = (item.attributes['data-code'] ?? '').toLowerCase();
          if (code == langCode && !codeToTitle.containsKey(code)) {
            codeToTitle[code] = item.attributes['data-title'] ?? code;
          }
        }
      }

      if (types.isEmpty || codeToTitle.isEmpty) return [];

      final numericId = _numericId(mangaId);
      final chapters = <Chapter>[];
      for (final type in types) {
        final body = await grabText(
          '$baseUrl/ajax/read/$numericId/$type/$langCode?vrf='
          '${MfVrf.generate('$numericId@$type@$langCode')}',
          extraHeaders: {'Accept': 'application/json'},
        );
        if (body.isEmpty) continue;
        final decoded = _decodeJsonBody(body);
        if (decoded == null) continue;
        final result = decoded['result'];
        if (result is! Map) continue;
        final fragment = _htmlFragment(result['html']?.toString() ?? '');
        if (fragment == null) continue;

        for (final a in fragment.querySelectorAll('ul li a')) {
          final chapterId = a.attributes['data-id'] ?? '';
          if (chapterId.isEmpty) continue;
          final dataNumber = a.attributes['data-number'] ?? '';
          final title = a.attributes['title']?.trim().isNotEmpty == true
              ? a.attributes['title']!.trim()
              : '${_titleCase(type)} $dataNumber';
          chapters.add(
            Chapter(
              id: '$mangaId/$type/$langCode/$chapterId',
              title: title,
              chapterNumber: dataNumber,
              url: '$baseUrl/read/$numericId/$type/$langCode/$chapterId',
            ),
          );
        }
      }
      // The AJAX list is newest-first; the app expects oldest-first.
      return chapters.reversed.toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final realId = chapterId.contains('/')
          ? chapterId.substring(chapterId.lastIndexOf('/') + 1)
          : chapterId;
      if (realId.isEmpty) return [];
      final body = await grabText(
        '$baseUrl/ajax/read/chapter/$realId?vrf='
        '${MfVrf.generate('chapter@$realId')}',
        extraHeaders: {'Accept': 'application/json'},
      );
      if (body.isEmpty) return [];
      final decoded = _decodeJsonBody(body);
      if (decoded == null) return [];
      final result = decoded['result'];
      if (result is! Map) return [];
      final images = result['images'];
      if (images is! List) return [];

      final urls = <String>[];
      for (final raw in images) {
        if (raw is! List || raw.isEmpty) continue;
        final url = raw[0]?.toString() ?? '';
        if (url.isEmpty) continue;
        final offset = raw.length > 2 ? raw[2] : 0;
        final o = offset is int ? offset : int.tryParse('$offset') ?? 0;
        urls.add(o < 1 ? url : '$url#scrambled_$o');
      }
      return urls;
    } catch (_) {
      return [];
    }
  }

  dynamic _decodeJsonBody(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  dynamic _htmlFragment(String html) {
    try {
      return parser.parseFragment(html);
    } catch (_) {
      return null;
    }
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
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
      if (chapters.isEmpty) return null;
      return (chapters.last.title, DateTime.now());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    try {
      if (tags.isEmpty) return [];
      final html = await grabText(_filterUrl(page: page, genres: tags));
      if (html.isEmpty) return [];
      return _parseFilter(html);
    } catch (_) {
      return [];
    }
  }
}