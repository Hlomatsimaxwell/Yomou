import 'package:dio/dio.dart';
import '../models/manga_source.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import '../models/manga_filter.dart';
import '../models/manga_translation.dart';

class MangaDexSource implements MangaSource {
  MangaDexSource({
    this.sourceId = 'mangadex',
    this.displayName = 'MangaDex',
    this.langCode = 'en',
  });

  /// Source id, e.g. `mangadex` / `mangadex-es`.
  final String sourceId;

  /// Display name, e.g. `MangaDex` / `MangaDex Español`.
  final String displayName;

  /// Chapter language branch (`en`, `es`, `pt-br`, ...).
  final String langCode;

  @override
  String get id => sourceId;

  @override
  String get name => displayName;

  @override
  String get baseUrl => 'https://api.mangadex.org';
  @override
  String get iconUrl => 'https://mangadex.org/favicon.ico';

  @override
  String get readerBaseUrl => 'https://cdn.mangadex.org';

  String get networkSourceId => id;

  @override
  String get languageCode => langCode;

  @override
  bool get supportsSignIn => false;

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

  /// The manga id may carry a `.language` suffix addressing one translation of
  /// a work (MangaDex publishes the same title with chapters in many
  /// languages). `abc123.es` = the Spanish translation of title `abc123`.
  String _baseId(String mangaId) => MangaLanguage.baseIdOf(mangaId);

  /// The language this manga id refers to (suffix when present).
  String _langOf(String mangaId) => MangaLanguage.suffixOf(mangaId) ?? langCode;

  /// Every translation of [baseId] that has at least one chapter, from the
  /// aggregate endpoint (volume -> chapter map, each chapter carrying its
  /// `translatedLanguage`).
  Future<List<Map<String, dynamic>>> _aggregateChapters(String baseId) async {
    try {
      final response = await _dio.get('/manga/$baseId/aggregate');
      final volumes = response.data['volumes'] ?? {};
      final chapters = <Map<String, dynamic>>[];
      volumes.forEach((volKey, vol) {
        final list = (vol is Map) ? (vol['chapters'] ?? {}) : {};
        if (list is! Map) return;
        for (final entry in list.values) {
          if (entry is Map) chapters.add(entry.cast<String, dynamic>());
        }
      });
      return chapters;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<MangaTranslation>> getTranslations(String mangaId) async {
    final baseId = _baseId(mangaId);
    final chapters = await _aggregateChapters(baseId);
    final langs = <String>{};
    for (final c in chapters) {
      final l = c['translatedLanguage']?.toString();
      if (l != null && l.isNotEmpty) langs.add(l);
    }
    return [
      for (final l in langs)
        MangaTranslation(
          language: l,
          mangaId: MangaLanguage.withSuffix(baseId, l),
        ),
    ];
  }

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
      final baseId = _baseId(mangaId);
      final language = _langOf(mangaId);
      final response = await _dio.get(
        '/manga/$baseId',
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
        description = _extractLocalized(descMap, preferred: language);
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
      final translations = await getTranslations(mangaId);
      final total = await _chapterCount(baseId, language);

      return MangaDetails(
        id: mangaId,
        sourceId: this.id,
        title: _extractTitle(attrs['title'] ?? {}, preferred: language),
        coverUrl: _coverUrlFor(item),
        description: description,
        author: authorNames.join(', '),
        status: status,
        year: year,
        tags: tags,
        followers: attrs['followedCount'] ?? 0,
        totalChapters: total > 0
            ? total
            : attrs['lastChapter'] is num
                ? (attrs['lastChapter'] as num).round()
                : 0,
        language: language,
        translations: translations,
      );
    } catch (e) {
      return null;
    }
  }

  /// Number of chapters published in [language] (the aggregate endpoint is
  /// per-language; falls back to the whole title when unknown).
  Future<int> _chapterCount(String baseId, String language) async {
    final chapters = await _aggregateChapters(baseId);
    if (chapters.isEmpty) return 0;
    var maxChapter = 0.0;
    for (final c in chapters) {
      if (c['translatedLanguage']?.toString() != language) continue;
      final n = c['chapter'];
      if (n is num && n.toDouble() > maxChapter) maxChapter = n.toDouble();
    }
    return maxChapter.round();
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

  // Pick the best localized string (prefer [preferred] (the translation being
  // viewed), then the source language, then English, then anything).
  String _extractLocalized(dynamic map, {String? preferred}) {
    if (map is! Map) return map?.toString() ?? '';
    for (final key in [preferred, langCode, 'en']) {
      if (key == null) continue;
      if (map[key] is String && (map[key] as String).isNotEmpty) {
        return map[key] as String;
      }
    }
    for (final v in map.values) {
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  // The authoritative chapter count = the highest chapter number across all
  // published chapters (from the aggregate endpoint). This may be larger than
  // the number of chapter entries actually loaded. Scoped to the translation
  // addressed by [mangaId] when it carries a language suffix.
  @override
  Future<int> getTotalChapters(String mangaId) async {
    final count = await _chapterCount(_baseId(mangaId), _langOf(mangaId));
    if (count > 0) return count;
    try {
      final response =
          await _dio.get('/manga/${_baseId(mangaId)}/aggregate');
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
        '/manga/${_baseId(mangaId)}/feed',
        queryParameters: {
          'order': {'chapter': 'desc'},
          'translatedLanguage[]': _langOf(mangaId),
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

  // Pick the best available title (prefer [preferred] (the translation being
  // viewed), then the source language, then English, then anything).
  String _extractTitle(dynamic titleMap, {String? preferred}) {
    if (titleMap is! Map) return 'Unknown Title';
    final t = titleMap;
    for (final key in [preferred, langCode, 'en']) {
      if (key == null) continue;
      if (t[key] is String && (t[key] as String).isNotEmpty) {
        return t[key] as String;
      }
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
        '/manga/${_baseId(mangaId)}/covers',
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
        '/manga/${_baseId(mangaId)}/feed',
        queryParameters: {
          'order': {'chapter': 'desc'},
          'translatedLanguage[]': _langOf(mangaId),
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
