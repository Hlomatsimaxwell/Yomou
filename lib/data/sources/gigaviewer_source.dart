import 'dart:convert';

import 'package:html/parser.dart' as parser;

import '../models/chapter.dart';
import '../models/manga.dart';
import '../models/manga_details.dart';
import '../models/manga_filter.dart';
import '../models/manga_source.dart';
import '../models/gigaviewer_site_config.dart';
import 'source_network.dart';

/// One generic source for every GigaViewer-themed Japanese site.
///
/// GigaViewer (Hatena's comic viewer) serves the same GraphQL API and the
/// same `script#episode-json` reader on every site. The only per-site data is
/// which serial groups make up the catalogue, the filter collections, and two
/// sites whose front page is HTML instead of GraphQL. Those live in
/// [GigaViewerSiteConfig]; this class contains no host checks.
class GigaViewerSource extends DioSource implements MangaSource {
  GigaViewerSource(this.config);

  final GigaViewerSiteConfig config;

  /// Remembered first-episode paths, so "Open in browser" lands on the title
  /// after a listing lookup. Details carry the same value in `publicUrl`.
  final Map<String, String> _paths = <String, String>{};

  static const String _seriesListItemFragment = '''
fragment SeriesListItem on Series {
  databaseId
  title
  thumbnailUri
  firstEpisode { permalink }
  firstVolume { permalink }
  latestEpisode { publishedAt }
  latestVolume { thumbnailUri }
  likeCount
}
''';

  static final String _seriesListFragment = '''
fragment SeriesList on Node {
  ... on SerialGroup { series { edges { node { ...SeriesListItem } } } }
  ... on Genre { series { edges { node { ...SeriesListItem } } } }
}
$_seriesListItemFragment''';

  static final String _searchQuery = '''
query Search(\$keyword: String!) {
  searchSeries(keyword: \$keyword) {
    edges { node { ...SeriesListItem } }
  }
}
$_seriesListItemFragment''';

  static const String _seriesQuery = '''
query Series(\$id: String!) {
  series(databaseId: \$id) {
    databaseId
    title
    author { name }
    description
    thumbnailUri
    firstEpisode { permalink }
    firstVolume { permalink }
    latestVolume { thumbnailUri }
    episodes: readableProducts(types: [EPISODE], first: 0) { totalCount }
    volumes: readableProducts(types: [VOLUME], first: 0) { totalCount }
  }
}
''';

  static final RegExp _chapterNumber = RegExp(r'(\d+(?:\.\d+)?)\s*[話巻]');
  static final RegExp _anyNumber = RegExp(r'(\d+(?:\.\d+)?)');

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  String get baseUrl => config.baseUrl;

  @override
  String get readerBaseUrl => config.baseUrl;

  @override
  String get languageCode => config.langCode;

  @override
  String get iconUrl => config.iconUrl;

  @override
  String get networkSourceId => config.id;

  @override
  Map<String, String>? get headers => const {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/138.0.0.0 Mobile Safari/537.36',
    'Accept-Language': 'ja,en;q=0.8',
  };

  @override
  String websiteMangaUrl(String mangaId) {
    final path = _paths[mangaId];
    if (path != null && path.isNotEmpty) {
      return path.startsWith('http') ? path : config.baseUrl + path;
    }
    return config.baseUrl;
  }

  // --- network -----------------------------------------------------------

  /// Posts a GraphQL query and returns its `data` object, or null on failure.
  Future<Map<String, dynamic>?> _graphql(
    String query,
    Map<String, dynamic> variables,
  ) async {
    try {
      final origin = await effectiveBaseUrl;
      final body = jsonEncode(<String, dynamic>{
        'query': query,
        'variables': variables,
      });
      final text = await postText(
        origin + config.apiPath,
        rawBody: body,
        extraHeaders: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (text.isEmpty) return null;
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final data = decoded['data'];
      return data is Map ? data.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  Future<String> _get(String path, {bool absolute = false}) async {
    final origin = await effectiveBaseUrl;
    final url = absolute || path.startsWith('http') ? path : origin + path;
    return grabText(url, useBaseUrl: false);
  }

  // --- listings ----------------------------------------------------------

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    if (page > 1) return <Manga>[];
    if (config.catalogMode == 'comicborder') {
      return _htmlSeries(
        '',
        'section.top-series',
        'h3',
        linkSelector: 'li.first-episode a, li.this-episode a',
        coverSelector: '.top-key-image',
      );
    }
    if (config.catalogMode == 'shonenjumpplus') {
      return _htmlSeries('/series', 'ul.series-list li a', 'h2.series-list-title');
    }
    final rows = _parseSeriesRows(
      await _fetchCollection(config.seriesListIds),
    );
    rows.sort((a, b) => b.likes.compareTo(a.likes));
    return rows.map((row) => row.manga).toList();
  }

  /// Called by the source self-test and the browse screen's "latest" tab.
  Future<List<Manga>> getLatestUpdates({int page = 1}) async {
    if (page > 1) return <Manga>[];
    if (config.latestMode == 'shonenjumpplus') {
      final weekday = <int, String>{
        DateTime.monday: 'monday',
        DateTime.tuesday: 'tuesday',
        DateTime.wednesday: 'wednesday',
        DateTime.thursday: 'thursday',
        DateTime.friday: 'friday',
        DateTime.saturday: 'saturday',
        DateTime.sunday: 'sunday',
      }[DateTime.now().weekday]!;
      return _htmlSeries(
        '/series',
        'h2.series-list-date-week.$weekday + ul.series-list li a',
        'h2.series-list-title',
      );
    }
    final rows = _parseSeriesRows(
      await _fetchCollection(config.seriesListIds),
    );
    rows.sort((a, b) => _dateOf(b.publishedAt).compareTo(_dateOf(a.publishedAt)));
    return rows.map((row) => row.manga).toList();
  }

  DateTime _dateOf(Object? value) =>
      config.parseDate(value?.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Parses the two sites whose catalogue is server-rendered HTML instead of
  /// GraphQL (Comic Border's top series, Shonen Jump+'s weekly schedule).
  Future<List<Manga>> _htmlSeries(
    String path,
    String itemSelector,
    String titleSelector, {
    String? linkSelector,
    String? coverSelector,
  }) async {
    return parseHtmlSeries(
      await _get(path),
      itemSelector,
      titleSelector,
      linkSelector: linkSelector,
      coverSelector: coverSelector,
    );
  }

  /// Public for unit tests: parses a server-rendered collection page.
  List<Manga> parseHtmlSeries(
    String html,
    String itemSelector,
    String titleSelector, {
    String? linkSelector,
    String? coverSelector,
  }) {
    final document = parser.parse(html);
    final result = <Manga>[];
    final seen = <String>{};
    for (final item in document.querySelectorAll(itemSelector)) {
      final href = item.attributes['href']?.trim() ??
          (linkSelector == null
              ? ''
              : item.querySelector(linkSelector)?.attributes['href']?.trim() ??
                  '');
      final title = item.querySelector(titleSelector)?.text.trim() ?? '';
      if (href.isEmpty || title.isEmpty) continue;
      final id = href.startsWith('http') ? Uri.parse(href).path : href;
      if (!seen.add(id)) continue;
      final image = item.querySelector(coverSelector ?? 'img');
      final cover = image?.attributes['data-src'] ?? image?.attributes['src'] ?? '';
      _paths[id] = href;
      result.add(
        Manga(
          id: id,
          title: title,
          coverUrl: _absoluteCover(cover),
          sourceId: config.id,
        ),
      );
    }
    return result;
  }

  String _absoluteCover(String cover) {
    if (cover.isEmpty) return '';
    if (cover.startsWith('http')) return cover;
    if (cover.startsWith('//')) return 'https:$cover';
    return config.baseUrl + (cover.startsWith('/') ? '' : '/') + cover;
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    if (query.trim().isEmpty || page > 1) return <Manga>[];
    final data = await _graphql(
      _searchQuery,
      <String, dynamic>{'keyword': query.trim()},
    );
    if (data == null) return <Manga>[];
    return parseSeriesListResponse(data);
  }

  @override
  Future<List<Manga>> searchMangaByTags(List<String> tags, {int page = 1}) {
    if (tags.isEmpty) return Future.value(<Manga>[]);
    return _fetchOption(tags.first);
  }

  @override
  Future<List<Manga>> searchWithFilter(MangaFilter filter, {int page = 1}) {
    final wanted = filter.genres.isNotEmpty ? filter.genres.first : '';
    if (wanted.isEmpty) return getPopularManga(page: page);
    return _fetchOption(wanted);
  }

  Future<List<Manga>> _fetchOption(String label) async {
    for (final option in config.filterOptions) {
      if (option.label != label) continue;
      if (option.ids.isEmpty) {
        // Sunday Web Every's 夜サンデー is a website-only collection.
        if (config.nightCollectionPath.isEmpty) return <Manga>[];
        final document = parser.parse(await _get(config.nightCollectionPath));
        final result = <Manga>[];
        for (final link in document.querySelectorAll(
          'ul.webry-series-list li a.webry-series-item-link',
        )) {
          final href = link.attributes['href']?.trim() ?? '';
          final title = link.querySelector('h4.series-title')?.text.trim() ?? '';
          if (href.isEmpty || title.isEmpty) continue;
          final image = link.querySelector('img');
          final cover = image?.attributes['data-src'] ?? image?.attributes['src'] ?? '';
          final id = href.startsWith('http') ? Uri.parse(href).path : href;
          _paths[id] = href;
          result.add(
            Manga(
              id: id,
              title: title,
              coverUrl: _absoluteCover(cover),
              sourceId: config.id,
            ),
          );
        }
        return result;
      }
      if (config.catalogMode == 'shonenjumpplus') {
        return _htmlSeries(
          option.ids.first,
          'ul.series-list li a',
          'h2.series-list-title',
        );
      }
      return parseSeriesListResponse(await _fetchCollection(option.ids));
    }
    return <Manga>[];
  }

  @override
  Future<List<String>> getAvailableTags() async =>
      config.filterOptions.map((option) => option.label).toList();

  /// Fetches one or more serial groups / genres by their raw node ids.
  Future<Map<String, dynamic>?> _fetchCollection(List<String> ids) async {
    if (ids.isEmpty) return null;
    final definitions = <String>[];
    final nodes = <String>[];
    final variables = <String, dynamic>{};
    for (var i = 0; i < ids.length; i++) {
      final key = 'id$i';
      definitions.add('\$$key: ID!');
      nodes.add('$key: node(id: \$$key) { ...SeriesList }');
      variables[key] = GigaViewerSiteConfig.nodeId(ids[i]);
    }
    final query = 'query(${definitions.join(',')}) { ${nodes.join(' ')} }\n'
        '$_seriesListFragment';
    return _graphql(query, variables);
  }

  // --- details -----------------------------------------------------------

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final seriesId = await _resolveSeriesId(mangaId);
      if (seriesId.isEmpty) return null;
      final data = await _graphql(
        _seriesQuery,
        <String, dynamic>{'id': seriesId},
      );
      if (data == null) return null;
      return parseSeriesDetails(data, fallbackId: mangaId);
    } catch (_) {
      return null;
    }
  }

  /// GraphQL addresses series by numeric database id. HTML-based listings
  /// store an episode path instead; the viewer page carries the real id in
  /// `script.js-valve[data-giga_series]`.
  Future<String> _resolveSeriesId(String mangaId) async {
    if (RegExp(r'^\d+$').hasMatch(mangaId)) return mangaId;
    final origin = await effectiveBaseUrl;
    final url = mangaId.startsWith('http') ? mangaId : origin + mangaId;
    final document = parser.parse(await _get(url, absolute: true));
    return document
            .querySelector('script.js-valve')
            ?.attributes['data-giga_series']
            ?.trim() ??
        '';
  }

  /// Public for unit tests: parses a `query Series` response.
  MangaDetails? parseSeriesDetails(
    Map<String, dynamic> data, {
    String fallbackId = '',
  }) {
    final series = data['series'];
    if (series is! Map) return null;
    final id = series['databaseId']?.toString() ?? fallbackId;
    final title = series['title']?.toString() ?? '';
    if (title.isEmpty) return null;
    final cover = series['thumbnailUri']?.toString() ??
        (series['latestVolume'] as Map?)?['thumbnailUri']?.toString() ??
        '';
    final permalink = (series['firstEpisode'] as Map?)?['permalink']?.toString() ??
        (series['firstVolume'] as Map?)?['permalink']?.toString() ??
        '';
    if (permalink.isNotEmpty) _paths[id] = permalink;
    final episodes = (series['episodes'] as Map?)?['totalCount'];
    final volumes = (series['volumes'] as Map?)?['totalCount'];
    return MangaDetails(
      id: id,
      title: title,
      coverUrl: _absoluteCover(cover),
      sourceId: config.id,
      description: series['description']?.toString() ?? '',
      author: (series['author'] as Map?)?['name']?.toString() ?? '',
      tags: const <String>[],
      language: config.langCode,
      totalChapters: (episodes is num ? episodes.toInt() : 0) +
          (volumes is num ? volumes.toInt() : 0),
      publicUrl: permalink,
    );
  }

  // --- chapters ----------------------------------------------------------

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final seriesId = await _resolveSeriesId(mangaId);
      if (seriesId.isEmpty) return <Chapter>[];
      final data = await _graphql(
        _seriesQuery,
        <String, dynamic>{'id': seriesId},
      );
      if (data == null) return <Chapter>[];
      final series = data['series'];
      if (series is! Map) return <Chapter>[];
      final chapters = <Chapter>[];
      for (final type in ['episode', 'volume']) {
        final key = type == 'episode' ? 'episodes' : 'volumes';
        final count = (series[key] as Map?)?['totalCount'];
        final total = count is num ? count.toInt() : 0;
        if (total <= 0) continue;
        final offsetMax = total.clamp(0, 2000);
        for (var offset = 0; offset < offsetMax;) {
          final origin = await effectiveBaseUrl;
          final uri = Uri.parse(
            '$origin/api/viewer/pagination_readable_products',
          ).replace(
            queryParameters: <String, String>{
              'type': type,
              'aggregate_id': seriesId,
              'sort_order': 'desc',
              'offset': '$offset',
            },
          );
          final body = await _get(uri.toString(), absolute: true);
          final batch = parseProducts(
            body,
            statusNullUnavailable: config.unavailableWhenStatusNull,
          );
          if (batch.isEmpty) break;
          chapters.addAll(batch);
          offset += batch.length;
        }
      }
      return chapters;
    } catch (_) {
      return <Chapter>[];
    }
  }

  /// Public for unit tests: parses the REST pagination response.
  List<Chapter> parseProducts(
    String body, {
    bool statusNullUnavailable = false,
  }) {
    if (body.trim().isEmpty) return <Chapter>[];
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return <Chapter>[];
    }
    if (decoded is! List) return <Chapter>[];
    final chapters = <Chapter>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final productId = item['readable_product_id']?.toString() ?? '';
      if (productId.isEmpty) continue;
      final viewerUri = item['viewer_uri']?.toString() ?? '';
      final type = Uri.tryParse(viewerUri)?.pathSegments.isNotEmpty == true
          ? Uri.parse(viewerUri).pathSegments.first
          : 'episode';
      final purchase = item['purchase_info'] as Map?;
      final canRead = purchase?['can_read'] == true;
      final unavailable = purchase?['unavailable'] == true ||
          (statusNullUnavailable && item['status'] == null);
      final title = item['title']?.toString() ?? '';
      final prefix = unavailable
          ? '🔒 '
          : (!canRead ? '💴 ' : '');
      final volumePrefix = type == 'volume' ? '(Volume) ' : '';
      final name = '$prefix$volumePrefix$title';
      final date = item['display_open_at']?.toString() ?? '';
      final number = _numberFrom(title);
      chapters.add(
        Chapter(
          // Type is part of the id: page lookup needs /episode/ vs /volume/.
          id: '$type:$productId',
          title: name,
          chapterNumber: number,
          releaseDate: date.split('T').first,
          url: viewerUri,
        ),
      );
    }
    return chapters;
  }

  String _numberFrom(String title) {
    final explicit = _chapterNumber.firstMatch(title)?.group(1);
    if (explicit != null) return explicit;
    return _anyNumber.firstMatch(title)?.group(1) ?? '';
  }

  @override
  Future<int> getTotalChapters(String mangaId) async {
    final details = await getMangaDetails(mangaId);
    return details?.totalChapters ?? 0;
  }

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async {
    final chapters = await getChapters(mangaId);
    for (final chapter in chapters) {
      final date = config.parseDate(chapter.releaseDate);
      if (date != null) return (chapter.title, date);
    }
    return null;
  }

  // --- reader ------------------------------------------------------------

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final path = _chapterPath(chapterId);
      if (path.isEmpty) return <String>[];
      final html = await _get(path, absolute: true);
      return parsePages(html);
    } catch (_) {
      return <String>[];
    }
  }

  String _chapterPath(String chapterId) {
    if (chapterId.startsWith('http')) return chapterId;
    if (chapterId.startsWith('/')) return chapterId;
    final separator = chapterId.indexOf(':');
    if (separator > 0 && separator < chapterId.length - 1) {
      final type = chapterId.substring(0, separator);
      final productId = chapterId.substring(separator + 1);
      return '/$type/$productId';
    }
    return '/episode/$chapterId';
  }

  /// Public for unit tests: reads `script#episode-json` from a viewer page.
  List<String> parsePages(String html) {
    if (html.trim().isEmpty) return <String>[];
    final document = parser.parse(html);
    final raw = document
        .querySelector('script#episode-json')
        ?.attributes['data-value'];
    if (raw == null || raw.isEmpty) return <String>[];
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return <String>[];
    }
    final product = (decoded as Map?)?['readableProduct'];
    final structure = (product as Map?)?['pageStructure'];
    if (structure is! Map) return <String>[];
    final pages = structure['pages'];
    if (pages is! List) return <String>[];
    final scrambled = structure['choJuGiga']?.toString() == 'baku';
    final result = <String>[];
    for (final page in pages) {
      if (page is! Map || page['type']?.toString() != 'main') continue;
      final src = page['src']?.toString() ?? '';
      if (src.isEmpty) continue;
      result.add(scrambled ? '$src#scramble' : src);
    }
    return result;
  }

  // --- parsing helpers ---------------------------------------------------

  /// Public for unit tests: parses a `query(...)` series-list response into
  /// manga rows, in the order the API returned them.
  List<Manga> parseSeriesListResponse(Object? decoded) => _parseSeriesRows(decoded)
      .map((row) => row.manga)
      .toList();

  List<_SeriesRow> _parseSeriesRows(Object? decoded) {
    if (decoded is! Map) return <_SeriesRow>[];
    final rows = <_SeriesRow>[];
    final seen = <String>{};
    for (final value in decoded.values) {
      if (value is! Map) continue;
      final series = value['series'];
      if (series is! Map) continue;
      final edges = series['edges'];
      if (edges is! List) continue;
      for (final edge in edges) {
        final node = (edge as Map?)?['node'];
        if (node is! Map) continue;
        final row = _seriesNode(node);
        if (row == null || !seen.add(row.manga.id)) continue;
        rows.add(row);
      }
    }
    return rows;
  }

  _SeriesRow? _seriesNode(Map node) {
    final id = node['databaseId']?.toString() ?? '';
    final title = node['title']?.toString() ?? '';
    if (id.isEmpty || title.isEmpty) return null;
    final cover = node['thumbnailUri']?.toString() ??
        (node['latestVolume'] as Map?)?['thumbnailUri']?.toString() ??
        '';
    final permalink = (node['firstEpisode'] as Map?)?['permalink']?.toString() ??
        (node['firstVolume'] as Map?)?['permalink']?.toString() ??
        '';
    if (permalink.isNotEmpty) _paths[id] = permalink;
    final publishedAt =
        (node['latestEpisode'] as Map?)?['publishedAt']?.toString();
    final likes = node['likeCount'];
    return _SeriesRow(
      Manga(
        id: id,
        title: title,
        coverUrl: _absoluteCover(cover),
        sourceId: config.id,
      ),
      likes is num ? likes.toInt() : 0,
      publishedAt,
    );
  }
}

class _SeriesRow {
  const _SeriesRow(this.manga, this.likes, this.publishedAt);

  final Manga manga;
  final int likes;
  final String? publishedAt;
}
