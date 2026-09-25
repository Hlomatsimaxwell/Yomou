import 'package:dio/dio.dart';
import '../models/manga_source.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import '../models/manga_filter.dart';

class MangaDexSource implements MangaSource {
  @override
  String get id => 'mangadex';

  @override
  String get name => 'MangaDex';

  @override
  String get baseUrl => 'https://api.mangadex.org';
  String get iconUrl => 'https://mangadex.org/favicon.ico';

  @override
  String get readerBaseUrl => 'https://cdn.mangadex.org';

  @override
  Map<String, String>? get headers => {
    'User-Agent': 'MangaReader/1.0',
    'Accept': 'application/json',
  };

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.mangadex.org',
      headers: {'User-Agent': 'MangaReader/1.0'},
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
    ),
  );

  // Cached tag name → id mapping (fetched once per session).
  Map<String, String>? _tagNameToId;

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    try {
      // MangaDex uses 'offset' instead of 'page'
      int offset = (page - 1) * 20;
      final response = await _dio.get(
        '/manga',
        queryParameters: {
          'limit': 20,
          'offset': offset,
          'order': {'followedCount': 'desc'},
          'includes[]': 'cover_art',
        },
      );

      return _parseMangaList(response.data);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final response = await _dio.get(
        '/manga/$mangaId',
        queryParameters: {
          'includes[]': ['author', 'artist', 'cover_art'],
        },
      );

      final item = response.data['data'];
      final attrs = item['attributes'] ?? {};

      // Description (prefer English, fall back to any language).
      String description = '';
      final descMap = attrs['description'];
      if (descMap is Map) {
        description = _extractLocalized(descMap);
      }

      // Author(s)/artist(s) from relationships.
      final authorNames = <String>[];
      final List relationships = item['relationships'] ?? [];
      for (final rel in relationships) {
        final type = rel['type'];
        if (type == 'author' || type == 'artist') {
          final name =
              rel['attributes']?['name']?.toString() ??
              rel['attributes']?['firstName']?.toString() ??
              '';
          if (name.isNotEmpty && !authorNames.contains(name)) {
            authorNames.add(name);
          }
        }
      }

      // Tags (filter comic genre vs format; prefer genre/theme).
      final tags = <String>[];
      final List rawTags = attrs['tags'] ?? [];
      for (final t in rawTags) {
        final tagName = _extractLocalized(t['attributes']?['name']);
        if (tagName.isNotEmpty) tags.add(tagName);
        if (tags.length >= 5) break;
      }

      String status = attrs['status']?.toString() ?? '';
      if (status.toLowerCase() == 'ongoing') {
        status = 'Ongoing';
      } else if (status.toLowerCase() == 'completed') {
        status = 'Completed';
      } else if (status.toLowerCase() == 'hiatus') {
        status = 'Hiatus';
      } else if (status.toLowerCase() == 'cancelled') {
        status = 'Cancelled';
      }

      final year = attrs['year']?.toString() ?? '';

      return MangaDetails(
        id: mangaId,
        sourceId: this.id,
        title: _extractTitle(attrs['title'] ?? {}),
        coverUrl: _coverUrlFor(item),
        description: description,
        author: authorNames.join(', '),
        status: status,
        year: year,
        tags: tags,
        followers: attrs['followedCount'] ?? 0,
        totalChapters: attrs['lastChapter'] is num
            ? (attrs['lastChapter'] as num).round()
            : 0,
      );
    } catch (e) {
      return null;
    }
  }

  String _coverUrlFor(dynamic item) {
    final mangaId = item['id'];
    String fileName = '';
    final List relationships = item['relationships'] ?? [];
    for (final rel in relationships) {
      if (rel['type'] == 'cover_art') {
        fileName = rel['attributes']?['fileName'] ?? '';
        break;
      }
    }
    return fileName.isNotEmpty
        ? 'https://uploads.mangadex.org/covers/$mangaId/$fileName.256.jpg'
        : '';
  }

  // Pick the best localized string (prefer English, fall back to any).
  String _extractLocalized(dynamic map) {
    if (map is! Map) return map?.toString() ?? '';
    if (map['en'] is String && (map['en'] as String).isNotEmpty) {
      return map['en'] as String;
    }
    for (final v in map.values) {
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  // The authoritative chapter count = the highest chapter number across all
  // published chapters (from the aggregate endpoint). This may be larger than
  // the number of English chapter entries actually loaded.
  @override
  Future<int> getTotalChapters(String mangaId) async {
    try {
      final response = await _dio.get('/manga/$mangaId/aggregate');
      final volumes = response.data['volumes'] ?? {};
      double maxChapter = 0;
      volumes.forEach((volKey, vol) {
        final chapters = (vol is Map) ? (vol['chapters'] ?? {}) : {};
        if (chapters is! Map) return;
        for (final c in chapters.values) {
          if (c is Map && c['chapter'] is num) {
            final n = (c['chapter'] as num).toDouble();
            if (n > maxChapter) maxChapter = n;
          }
        }
      });
      return maxChapter.round();
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    final chapters = <Chapter>[];
    try {
      final response = await _dio.get(
        '/manga/$mangaId/feed',
        queryParameters: {
          'order': {'chapter': 'desc'},
          'translatedLanguage[]': 'en',
          'limit': 500,
          'offset': 0,
        },
      );

      final List<dynamic> data = response.data['data'];
      for (final item in data) {
        String groupName = '';
        final List relationships = item['relationships'] ?? [];
        for (final rel in relationships) {
          if (rel['type'] == 'scanlation_group') {
            final name = rel['attributes']?['name'];
            if (name is String && name.isNotEmpty) {
              groupName = name;
              break;
            }
          }
        }
        chapters.add(
          Chapter(
            id: item['id'],
            title: item['attributes']['chapter'] ?? 'Chapter',
            chapterNumber: item['attributes']['chapter'] ?? '0',
            releaseDate: item['attributes']['publishAt'],
            url: '',
            scanlator: groupName,
          ),
        );
      }
    } catch (e) {
      return [];
    }

    return chapters;
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      // 1. Get the "at-home" server URL for the chapter
      final response = await _dio.get('/at-home/server/$chapterId');
      final String baseUrl = response.data['baseUrl'];
      final String hash = response.data['chapter']['hash'];
      final List<dynamic> filenames = response.data['chapter']['data'];

      // 2. Construct the full URLs
      // Format: baseUrl + "/data/" + hash + "/" + filename
      return filenames.map((file) => '$baseUrl/data/$hash/$file').toList();
    } catch (e) {
      return [];
    }
  }

  // Pick the best available title (prefer English, fall back to any language)
  String _extractTitle(dynamic titleMap) {
    if (titleMap is! Map) return 'Unknown Title';
    final t = titleMap;
    if (t['en'] is String && (t['en'] as String).isNotEmpty) {
      return t['en'] as String;
    }
    for (final v in t.values) {
      if (v is String && v.isNotEmpty) return v;
    }
    return 'Unknown Title';
  }

  // Fetch alternative cover artworks (one per volume) via the cover_art
  // endpoint, as (url, label) pairs.
  @override
  Future<List<(String url, String? label)>> getAltCovers(String mangaId) async {
    try {
      final response = await _dio.get(
        '/manga/$mangaId/covers',
        queryParameters: {'limit': 96},
      );
      final data = response.data['data'] as List? ?? [];
      final covers = <(String, String?)>[];
      for (final item in data) {
        final attrs = item['attributes'] ?? {};
        final fileName = attrs['fileName']?.toString() ?? '';
        if (fileName.isEmpty) continue;
        final volume = attrs['volume']?.toString() ?? '';
        final description = _extractLocalized(attrs['description'] ?? {});
        final label = description.isNotEmpty
            ? description
            : (volume.isNotEmpty ? 'Volume $volume' : null);
        covers.add((
          'https://uploads.mangadex.org/covers/$mangaId/$fileName.256.jpg',
          label,
        ));
      }
      return covers;
    } catch (_) {
      return [];
    }
  }

  // Fetch the full tag list from MangaDex and build a name→id map.
  Future<Map<String, String>> _getTagNameToId() async {
    if (_tagNameToId != null) return _tagNameToId!;
    try {
      final response = await _dio.get('/manga/tag');
      final data = response.data['data'] as List? ?? [];
      final map = <String, String>{};
      for (final tag in data) {
        final name = _extractLocalized(tag['attributes']?['name'] ?? {});
        final id = tag['id'] as String? ?? '';
        if (name.isNotEmpty && id.isNotEmpty) {
          map[name.toLowerCase()] = id;
        }
      }
      _tagNameToId = map;
      return map;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    try {
      final nameToId = await _getTagNameToId();
      final tagIds = <String>[];
      for (final tag in tags) {
        final id = nameToId[tag.toLowerCase()];
        if (id != null) tagIds.add(id);
      }
      if (tagIds.isEmpty) return [];

      final offset = (page - 1) * 20;
      final response = await _dio.get(
        '/manga',
        queryParameters: {
          'limit': 20,
          'offset': offset,
          'order': {'followedCount': 'desc'},
          'includes[]': 'cover_art',
          ...{for (final id in tagIds) 'includedTags[]': id},
        },
      );

      return _parseMangaList(response.data);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchWithFilter(
    MangaFilter filter, {
    int page = 1,
  }) async {
    try {
      final nameToId = await _getTagNameToId();
      final includedIds = <String>[];
      for (final tag in filter.genres) {
        final id = nameToId[tag.toLowerCase()];
        if (id != null) includedIds.add(id);
      }
      final excludedIds = <String>[];
      for (final tag in filter.excludeGenres) {
        final id = nameToId[tag.toLowerCase()];
        if (id != null) excludedIds.add(id);
      }

      // MangaDex has no "Upcoming" status; map Finished->completed and
      // Dropped->cancelled, skip anything that doesn't map.
      const statusMap = {
        'finished': 'completed',
        'dropped': 'cancelled',
      };
      final statusParams = <String>[
        for (final s in filter.status)
          if (statusMap[s] != null) statusMap[s]!,
      ];

      // MangaDex only accepts a single exact year, so a proper range is not
      // expressible — send the year only when from == to (best effort).
      int? year;
      final from = filter.yearFrom;
      final to = filter.yearTo;
      if (from != null && to != null && from == to) year = from;

      final orders = {
        'updated': {'latestUploadedChapter': 'desc'},
        'alphabetical': {'title': 'asc'},
        'popularity': {'followedCount': 'desc'},
        'chapterCount': {'chapterCount': 'desc'},
      };

      final offset = (page - 1) * 20;
      final response = await _dio.get(
        '/manga',
        queryParameters: {
          'limit': 20,
          'offset': offset,
          'order': orders[filter.sort] ?? orders['updated'],
          'includes[]': 'cover_art',
          if (filter.language != null) 'originalLanguage[]': filter.language,
          ...{for (final id in includedIds) 'includedTags[]': id},
          ...{for (final id in excludedIds) 'excludedTags[]': id},
          ...{for (final s in statusParams) 'status[]': s},
          if (year != null) 'year': year,
        },
      );

      return _parseMangaList(response.data);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    try {
      final offset = (page - 1) * 20;
      final response = await _dio.get(
        '/manga',
        queryParameters: {
          'limit': 20,
          'offset': offset,
          'title': query.trim(),
          'order': {'relevance': 'desc'},
          'includes[]': 'cover_art',
        },
      );

      return _parseMangaList(response.data);
    } catch (e) {
      return [];
    }
  }

  // Parse a /manga response body into a list of Manga.
  List<Manga> _parseMangaList(dynamic responseBody) {
    final List<dynamic> data = responseBody['data'] ?? [];
    return data.map((item) {
      final mangaId = item['id'];
      String coverFileName = '';
      final List relationships = item['relationships'] ?? [];
      for (var rel in relationships) {
        if (rel['type'] == 'cover_art') {
          coverFileName = rel['attributes']?['fileName'] ?? '';
          break;
        }
      }
      return Manga(
        id: mangaId,
        sourceId: this.id,
        title: _extractTitle(item['attributes']['title'] ?? {}),
        coverUrl: coverFileName.isNotEmpty
            ? 'https://uploads.mangadex.org/covers/$mangaId/$coverFileName.256.jpg'
            : '',
      );
    }).toList();
  }

  @override
  Future<List<String>> getAvailableTags() async {
    try {
      final response = await _dio.get('/manga/tag');
      final data = response.data['data'] as List? ?? [];
      final genres = <String>[];
      for (final tag in data) {
        final group = tag['attributes']?['group'] as String? ?? '';
        if (group == 'genre' || group == 'theme') {
          final name = _extractLocalized(tag['attributes']?['name'] ?? {});
          if (name.isNotEmpty) genres.add(name);
        }
      }
      genres.sort();
      return genres;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async {
    try {
      final response = await _dio.get(
        '/manga/$mangaId/feed',
        queryParameters: {
          'order': {'chapter': 'desc'},
          'translatedLanguage[]': 'en',
          'limit': 1,
          'offset': 0,
        },
      );
      final data = response.data['data'] as List? ?? [];
      if (data.isEmpty) return null;
      final attrs = data[0]['attributes'] ?? {};
      final chapterNum = attrs['chapter']?.toString() ?? '';
      final title = chapterNum.isNotEmpty
          ? 'Chapter $chapterNum'
          : 'New chapter';
      DateTime? publishedAt;
      final pub = attrs['publishAt'];
      if (pub is String) {
        publishedAt = DateTime.tryParse(pub);
      }
      return (title, publishedAt ?? DateTime.now());
    } catch (_) {
      return null;
    }
  }
}
