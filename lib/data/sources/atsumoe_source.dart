import 'dart:convert';

import '../models/chapter.dart';
import '../models/manga.dart';
import '../models/manga_details.dart';
import '../models/manga_filter.dart';
import '../models/manga_source.dart';
import 'source_network.dart';

/// Atsumaru — atsu.moe.
///
/// A React SPA over a same-origin JSON API that answers plain HTTP (no
/// Cloudflare interstitial), so every call goes through [DioSource]. Listing,
/// search and filter queries are Typesense requests against
/// `/collections/manga/documents/search`; a title's page comes from
/// `/api/manga/page?id=`, its whole chapter list from `/api/manga/info`, and a
/// chapter's images from `/api/read/chapter`.
///
/// The reader endpoint needs both ids, but [getPageUrls] is handed only the
/// chapter id, so chapter ids pack them together as `<mangaId>/<chapterId>`.
/// Posters and page scans live on the `cdn.atsu.moe` host while the API lives
/// on the bare host, so image URLs are rebuilt against the CDN.
class AtsuMoeSource extends DioSource implements MangaSource {
  @override
  String get networkSourceId => id;

  @override
  String get id => 'atsu';

  @override
  String get name => 'Atsumaru';

  @override
  String get baseUrl => 'https://atsu.moe';

  @override
  String get readerBaseUrl => 'https://atsu.moe';

  @override
  String get iconUrl => 'https://atsu.moe/favicon.ico';

  @override
  Map<String, String>? get headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Referer': 'https://atsu.moe/',
  };

  /// Asks the search API rather than the SPA shell, so the connectivity check
  /// fails when the API (not just the static bundle) is unreachable.
  @override
  String get testUrl =>
      '$baseUrl/collections/manga/documents/search?q=*&query_by=title'
      '&per_page=1';

  /// Posters and page scans are served from the CDN; the bare host 301s (and
  /// 410s for page images).
  static const String _cdnBase = 'https://cdn.atsu.moe';

  /// The fields the site's own search asks for. Keeping the list short keeps
  /// the response small.
  static const String _queryBy =
      'title,englishTitle,otherNames,authors,acronyms';

  static const String _includeFields =
      'id,title,englishTitle,authors,poster,posterSmall,posterMedium,type,'
      'medium,isAdult,status,year,mbRating,popularity,dateAdded';

  /// The filter sheet's statuses mapped onto Atsumaru's own values. It has no
  /// "upcoming" state, so that option is dropped rather than guessed at.
  static const Map<String, String> _filterStatus = {
    'finished': 'Completed',
    'dropped': 'Canceled',
  };

  /// Genre name -> id, cached for the session. Null until loaded.
  Map<String, String>? _genreIds;

  /// Builds the Typesense query string by hand: [Uri.replace] writes spaces as
  /// `+`, which Typesense reads literally inside `filter_by`.
  String _queryString(Map<String, String> params) => params.entries
      .map(
        (e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');

  String _imageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final normalized = path.startsWith('/') ? path : '/static/$path';
    return '$_cdnBase$normalized';
  }

  /// A search/listing request. [query] is `*` to match everything.
  Future<List<Manga>> _search({
    required String query,
    int page = 1,
    String sort = 'views:desc',
    List<String> genreIds = const [],
    List<String> excludeGenreIds = const [],
    List<String> statuses = const [],
    int? yearFrom,
    int? yearTo,
  }) async {
    final filters = <String>[
      'hidden:!=true',
      'mbContentRating:!=[`Pornographic`]',
    ];
    if (genreIds.isNotEmpty) {
      filters.add('genreIds:=[${genreIds.join(',')}]');
    }
    if (excludeGenreIds.isNotEmpty) {
      filters.add('genreIds:!=[${excludeGenreIds.join(',')}]');
    }
    if (statuses.isNotEmpty) {
      filters.add('status:=[${statuses.join(',')}]');
    }
    if (yearFrom != null) filters.add('year:>=$yearFrom');
    if (yearTo != null) filters.add('year:<=$yearTo');
    final params = <String, String>{
      'q': query,
      'query_by': _queryBy,
      'query_by_weights': '4,3,2,2,1',
      'num_typos': '4,3,2,1,0',
      'prefix': 'true,true,true,true,false',
      'include_fields': _includeFields,
      'filter_by': filters.join(' && '),
      'page': '$page',
      'per_page': '40',
      if (sort.isNotEmpty) 'sort_by': sort,
    };
    final url = '$baseUrl/collections/manga/documents/search'
        '?${_queryString(params)}';
    final body = await grabText(url, useBaseUrl: false);
    if (body.isEmpty) return const [];
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final hits = decoded['hits'];
    if (hits is! List) return const [];
    final result = <Manga>[];
    for (final hit in hits) {
      if (hit is! Map) continue;
      final doc = hit['document'];
      if (doc is! Map) continue;
      final manga = _mangaFromDocument(doc.cast<String, dynamic>());
      if (manga != null) result.add(manga);
    }
    return result;
  }

  Manga? _mangaFromDocument(Map<String, dynamic> doc) {
    final mangaId = doc['id']?.toString() ?? '';
    if (mangaId.isEmpty) return null;
    final title = doc['title'] ?? doc['englishTitle'] ?? '';
    final poster = doc['poster']?.toString() ?? '';
    return Manga(
      id: mangaId,
      title: title.toString(),
      coverUrl: _imageUrl(poster),
      sourceId: id,
    );
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) {
    return _search(query: '*', page: page, sort: 'views:desc');
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) {
    final term = query.trim();
    if (term.isEmpty) return Future.value(const []);
    return _search(query: term, page: page, sort: '');
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    final body = await grabText(
      '$baseUrl/api/manga/page?id=${Uri.encodeComponent(mangaId)}',
      useBaseUrl: false,
    );
    if (body.isEmpty) return null;
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final page = decoded['mangaPage'];
    if (page is! Map) return null;
    final manga = page.cast<String, dynamic>();
    final poster = manga['poster'];
    final coverPath = poster is Map
        ? (poster['image'] ?? poster['largeImage'] ?? '').toString()
        : (poster ?? '').toString();
    final released = manga['released'];
    final year = released is num && released > 0
        ? DateTime.fromMillisecondsSinceEpoch(released.toInt(), isUtc: true)
              .year
              .toString()
        : '';
    final total = manga['totalChapterCount'];
    return MangaDetails(
      id: mangaId,
      title: (manga['title'] ?? manga['englishTitle'] ?? '').toString(),
      coverUrl: _imageUrl(coverPath),
      sourceId: id,
      description: (manga['synopsis'] ?? '').toString().trim(),
      author: _names(manga['authors']).join(', '),
      status: (manga['status'] ?? '').toString().toLowerCase(),
      year: year,
      tags: _names(manga['genres']),
      totalChapters: total is num ? total.toInt() : 0,
      language: 'en',
    );
  }

  /// Pulls the `name` field out of a list of `{id, name}` records, keeping the
  /// first occurrence of each (Atsumaru lists a person once per role).
  List<String> _names(Object? list) {
    if (list is! List) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final item in list) {
      final name = item is Map ? item['name']?.toString() : null;
      if (name == null || name.isEmpty) continue;
      if (seen.add(name)) out.add(name);
    }
    return out;
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    final body = await grabText(
      '$baseUrl/api/manga/info?mangaId=${Uri.encodeComponent(mangaId)}',
      useBaseUrl: false,
    );
    if (body.isEmpty) return const [];
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final chapters = decoded['chapters'];
    if (chapters is! List) return const [];
    final result = <Chapter>[];
    final seen = <String>{};
    for (final item in chapters) {
      if (item is! Map) continue;
      final chapter = item.cast<String, dynamic>();
      final chapterId = chapter['id']?.toString() ?? '';
      if (chapterId.isEmpty) continue;
      final number = _numberLabel(chapter['number']);
      // The site lists one entry per scanlation team; without the team names
      // (this endpoint omits them) identically numbered rows would read as
      // duplicates, so keep the first of each.
      final key = number.isEmpty ? chapterId : number;
      if (!seen.add(key)) continue;
      result.add(
        Chapter(
          id: '$mangaId/$chapterId',
          title: (chapter['title'] ?? '').toString(),
          chapterNumber: number,
          url: '$readerBaseUrl/read/$mangaId/$chapterId',
        ),
      );
    }
    return result;
  }

  String _numberLabel(Object? number) {
    if (number == null) return '';
    if (number is num && number == number.truncateToDouble()) {
      return number.toInt().toString();
    }
    return number.toString();
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    final slash = chapterId.indexOf('/');
    if (slash <= 0 || slash == chapterId.length - 1) return const [];
    final mangaId = chapterId.substring(0, slash);
    final cid = chapterId.substring(slash + 1);
    final body = await grabText(
      '$baseUrl/api/read/chapter?mangaId=${Uri.encodeComponent(mangaId)}'
      '&chapterId=${Uri.encodeComponent(cid)}',
      useBaseUrl: false,
    );
    if (body.isEmpty) return const [];
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final read = decoded['readChapter'];
    if (read is! Map) return const [];
    final pages = read['pages'];
    if (pages is! List) return const [];
    final result = <String>[];
    for (final page in pages) {
      final image = page is Map ? page['image']?.toString() : null;
      if (image == null || image.isEmpty) continue;
      result.add(_imageUrl(image));
    }
    return result;
  }

  @override
  Future<int> getTotalChapters(String mangaId) async {
    return (await getChapters(mangaId)).length;
  }

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async {
    final body = await grabText(
      '$baseUrl/api/manga/page?id=${Uri.encodeComponent(mangaId)}',
      useBaseUrl: false,
    );
    if (body.isEmpty) return null;
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final page = decoded['mangaPage'];
    if (page is! Map) return null;
    final chapters = page['chapters'];
    if (chapters is! List || chapters.isEmpty) return null;
    final newest = chapters.first;
    if (newest is! Map) return null;
    final title = (newest['title'] ?? '').toString();
    final created = newest['createdAt'];
    if (title.isEmpty || created is! num || created <= 0) return null;
    return (
      title,
      DateTime.fromMillisecondsSinceEpoch(created.toInt(), isUtc: true),
    );
  }

  /// Loads (and caches) the genre list the filter sheet populates from.
  Future<Map<String, String>> _loadGenres() async {
    final cached = _genreIds;
    if (cached != null) return cached;
    final body = await grabText(
      '$baseUrl/api/explore/availableFilters',
      useBaseUrl: false,
    );
    final map = <String, String>{};
    if (body.isNotEmpty) {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final genres = decoded['genres'];
        if (genres is List) {
          for (final genre in genres) {
            if (genre is! Map) continue;
            final name = genre['name']?.toString() ?? '';
            final genreId = genre['id']?.toString() ?? '';
            if (name.isNotEmpty && genreId.isNotEmpty) map[name] = genreId;
          }
        }
      }
    }
    return _genreIds = map;
  }

  @override
  Future<List<String>> getAvailableTags() async {
    return (await _loadGenres()).keys.toList();
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    final map = await _loadGenres();
    final ids = <String>[];
    for (final tag in tags) {
      final genreId = map[tag];
      if (genreId != null) ids.add(genreId);
    }
    if (ids.isEmpty) return const [];
    return _search(query: '*', page: page, genreIds: ids);
  }

  @override
  Future<List<Manga>> searchWithFilter(
    MangaFilter filter, {
    int page = 1,
  }) async {
    final genres = await _loadGenres();
    final genreIds = <String>[];
    for (final genre in filter.genres) {
      final genreId = genres[genre];
      if (genreId != null) genreIds.add(genreId);
    }
    final excludeIds = <String>[];
    for (final genre in filter.excludeGenres) {
      final genreId = genres[genre];
      if (genreId != null) excludeIds.add(genreId);
    }
    final statuses = <String>[];
    for (final status in filter.status) {
      final mapped = _filterStatus[status];
      if (mapped != null) statuses.add(mapped);
    }
    return _search(
      query: '*',
      page: page,
      sort: _sortFor(filter.sort),
      genreIds: genreIds,
      excludeGenreIds: excludeIds,
      statuses: statuses,
      yearFrom: filter.yearFrom,
      yearTo: filter.yearTo,
    );
  }

  String _sortFor(String sort) {
    switch (sort) {
      case 'alphabetical':
        return 'title:asc';
      case 'popularity':
        return 'views:desc';
      case 'chapterCount':
        return 'chapterCount:desc';
      case 'updated':
      default:
        return 'dateAdded:desc';
    }
  }
}
