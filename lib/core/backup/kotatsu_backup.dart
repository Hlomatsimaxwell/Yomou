import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:yomou/core/backup/tachiyomi_backup.dart';

/// Compatibility with Kotatsu `.bk.zip` backups.
///
/// A Kotatsu backup is a zip of one JSON array per table (`favourites`,
/// `history`, `bookmarks`, `categories`, `sources`, `index`, ...). Manga are
/// identified by a Kotatsu catalog enum ("MANGADEX", "COMICK_FUN", ...) plus a
/// site-relative url. Both the urls and the source set overlap heavily with
/// what the Tachiyomi path already maps, so import and export reuse those
/// conventions instead of inventing a parallel format.
///
/// Import produces the same [TachiyomiImportResult] the Tachiyomi/Mihon path
/// produces, so the title-scan resolver ([resolveTachiyomiMissing]), the
/// database apply step, the results screen and the "remove unreadable entries"
/// cleanup all work unchanged. Titles whose Kotatsu source Yomou ships are
/// bound directly from the canonical url; the rest are searched for by title.
///
/// Export writes the twelve files Kotatsu produces so a Yomou library can be
/// restored into Kotatsu. Two limitations come from Kotatsu's own format:
/// chapter *numbers* are not stored (only a last-read timestamp and a
/// percentage), so exported reading history carries a chapter hash rather than
/// a number, and imported history re-reads as "chapter 0" with its real
/// timestamp.
class KotatsuBackupCodec {
  KotatsuBackupCodec._();

  /// Kotatsu catalog enums whose manga ids Yomou can derive from the same
  /// canonical url Kotatsu stores. Entries on these sources import directly,
  /// with no network scan.
  ///
  /// Kotatsu carries catalogues Yomou does not (COMIX, S2MANGA, AINZSCANS,
  /// MANGAPLUS, BATOTO's bato.to, ...); those are deliberately absent so their
  /// entries fall through to the title scan instead of landing as unreadable.
  static const Map<String, String> _kotatsuToYomou = {
    'MANGADEX': 'mangadex',
    'COMICK_FUN': 'comick',
    'MANGATOWN': 'mangatown',
    'ASURASCANS': 'asurascans',
    'MANGAGO': 'mangago',
    'MANGAGEKO': 'mgeko',
    'MANGAPILL': 'mangapill',
    'WEEBCENTRAL': 'weebcentral',
    'LIKEMANGA': 'likemanga',
    'SEIMANGA': 'seimanga',
    'ARENASCANS': 'arenascan',
    'ATSUMOE': 'atsu',
    'MANHUAPLUS': 'manhuaplus',
    'MANGABAT': 'mangabat',
    'MANGAFIRE_EN': 'mangafire-en',
    'MANGAFIRE_ES': 'mangafire-es',
    'MANGAFIRE_ESLA': 'mangafire-esla',
    'MANGAFIRE_FR': 'mangafire-fr',
    'MANGAFIRE_JA': 'mangafire-ja',
    'MANGAFIRE_PT': 'mangafire-pt',
    'MANGAFIRE_PTBR': 'mangafire-ptbr',
  };

  static const Map<String, String> _yomouToKotatsu = {
    'mangadex': 'MANGADEX',
    'comick': 'COMICK_FUN',
    'mangatown': 'MANGATOWN',
    'asurascans': 'ASURASCANS',
    'mangago': 'MANGAGO',
    'mgeko': 'MANGAGEKO',
    'mangapill': 'MANGAPILL',
    'weebcentral': 'WEEBCENTRAL',
    'likemanga': 'LIKEMANGA',
    'seimanga': 'SEIMANGA',
    'arenascan': 'ARENASCANS',
    'atsu': 'ATSUMOE',
    'manhuaplus': 'MANHUAPLUS',
    'mangabat': 'MANGABAT',
    'mangafire-en': 'MANGAFIRE_EN',
    'mangafire-es': 'MANGAFIRE_ES',
    'mangafire-esla': 'MANGAFIRE_ESLA',
    'mangafire-fr': 'MANGAFIRE_FR',
    'mangafire-ja': 'MANGAFIRE_JA',
    'mangafire-pt': 'MANGAFIRE_PT',
    'mangafire-ptbr': 'MANGAFIRE_PTBR',
  };

  static final RegExp _mangadexUuid = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}',
  );

  // ---- Import ----

  /// Parses a Kotatsu `.bk.zip` into entries ready for the Yomou database.
  ///
  /// Favourites restore as the library; history restores each title's last-read
  /// timestamp (the backup has no chapter numbers, so progress is seeded at
  /// chapter 0 and the History tab sorts by the real timestamp); bookmarks
  /// follow their manga. Throws [FormatException] when [bytes] is not a zip.
  static TachiyomiImportResult import(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (_) {
      throw const FormatException('Invalid Kotatsu backup file');
    }
    if (archive.files.isEmpty) {
      throw const FormatException('Invalid Kotatsu backup file');
    }

    final favourites = _listOf(archive, 'favourites') ?? const [];
    final history = _listOf(archive, 'history') ?? const [];
    final bookmarkGroups = _listOf(archive, 'bookmarks') ?? const [];
    if (favourites.isEmpty && history.isEmpty && bookmarkGroups.isEmpty) {
      return const TachiyomiImportResult(mangas: [], skippedMangas: []);
    }

    // Index every manga object by Kotatsu id so favourites, history and
    // bookmarks can enrich each other without re-reading the payloads.
    final mangaById = <int, Map<String, dynamic>>{};
    for (final group in [...favourites, ...history, ...bookmarkGroups]) {
      final manga = _mangaOf(group);
      final id = _kotatsuId(manga?['id']);
      if (id == null || manga == null) continue;
      mangaById[id] = manga;
    }

    // History rows carry their manga id at the top level.
    final historyByManga = <int, Map<String, dynamic>>{};
    for (final h in history) {
      final id = _kotatsuId(h['manga_id']);
      if (id == null) continue;
      historyByManga[id] = h;
    }

    // Bookmarks are grouped per manga under `bookmarks.bookmarks[]`.
    final bookmarksByManga = <int, List<Map<String, dynamic>>>{};
    for (final group in bookmarkGroups) {
      final raw = group['bookmarks'];
      if (raw is! List) continue;
      for (final b in raw.whereType<Map<String, dynamic>>()) {
        final id = _kotatsuId(b['manga_id']);
        if (id == null) continue;
        bookmarksByManga.putIfAbsent(id, () => []).add(b);
      }
    }

    final mangas = <TachiyomiImportedManga>[];
    final missingMangas = <TachiyomiMissingManga>[];
    final skippedMangas = <TachiyomiSkippedManga>[];
    final seenKeys = <String>{};

    // A title the current device has no match for (source Yomou doesn't carry,
    // or an url that does not fit the mapped source) goes through the title
    // scan, exactly like an unsupported Tachiyomi extension would.
    void addMissing(
      Map<String, dynamic> manga,
      bool isFavorite,
      DateTime? readAt,
    ) {
      final title = _text(manga['title']).trim();
      missingMangas.add(TachiyomiMissingManga(
        title: title,
        url: _text(manga['url']),
        sourceName: _text(manga['source']),
        coverUrl: _text(manga['cover_url']),
        // Chapter numbers are not in the format; 0 keeps the entry in History
        // when it really was read, -1 keeps a mere favourite out of it.
        lastReadChapter: readAt != null ? 0 : -1,
        lastReadAt: readAt,
        isFavorite: isFavorite,
      ));
    }

    TachiyomiImportedManga? bind(
      Map<String, dynamic> manga,
      int? kotatsuMangaId,
      Map<String, dynamic>? historyRow,
      bool isFavorite,
    ) {
      final yomouSource = _kotatsuToYomou[_text(manga['source'])];
      if (yomouSource == null) {
        addMissing(manga, isFavorite, _readAt(historyRow));
        return null;
      }
      final mangaId = _mangaIdFor(
        yomouSource,
        _text(manga['url']),
        _text(manga['public_url']),
      );
      if (mangaId == null) {
        addMissing(manga, isFavorite, _readAt(historyRow));
        return null;
      }
      final key = '$yomouSource::$mangaId';
      if (!seenKeys.add(key)) return null;
      final title = _text(manga['title']).trim();
      return TachiyomiImportedManga(
        mangaId: mangaId,
        title: title.isEmpty ? mangaId : title,
        coverUrl: _text(manga['cover_url']),
        sourceId: yomouSource,
        lastReadChapter: historyRow != null ? 0 : -1,
        lastReadAt: _readAt(historyRow),
        isFavorite: isFavorite,
        bookmarks: _bookmarksFor(
          kotatsuMangaId,
          bookmarksByManga,
          title.isEmpty ? mangaId : title,
        ),
      );
    }

    // Favourites first: they are the library.
    for (final fav in favourites) {
      final manga = _mangaOf(fav);
      if (manga == null) continue;
      final id = _kotatsuId(manga['id']);
      final bound = bind(manga, id, historyByManga[id], true);
      if (bound != null) mangas.add(bound);
    }

    // Then history-only titles (read but not favourite) so the History tab
    // survives the move too.
    for (final h in history) {
      final id = _kotatsuId(h['manga_id']);
      if (id == null) continue;
      if (favourites.any((f) =>
          _kotatsuId(_mangaOf(f)?['id']) == id ||
          _kotatsuId(f['manga_id']) == id)) {
        continue; // already imported above with its history attached
      }
      final manga = mangaById[id] ?? _mangaOf(h);
      if (manga == null) continue;
      final bound = bind(manga, id, h, false);
      if (bound != null) mangas.add(bound);
    }

    return TachiyomiImportResult(
      mangas: mangas,
      skippedMangas: skippedMangas,
      missingMangas: missingMangas,
    );
  }

  static List<Map<String, dynamic>> _bookmarksFor(
    int? kotatsuMangaId,
    Map<int, List<Map<String, dynamic>>> byManga,
    String mangaTitle,
  ) {
    final raw = kotatsuMangaId == null ? null : byManga[kotatsuMangaId];
    if (raw == null || raw.isEmpty) return const [];
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final b in raw) {
      final chapterId = _kotatsuId(b['chapter_id']);
      final page = b['page'];
      final key = '${chapterId ?? 0}/$page';
      if (!seen.add(key)) continue;
      out.add({
        // Kotatsu's numeric chapter ids cannot address Yomou pages; keep the
        // bookmark (its image and page index) under a namespaced id rather
        // than dropping the reader's notes.
        'chapterId': 'kotatsu-${chapterId ?? 0}',
        'chapterTitle': mangaTitle,
        'pageUrl': _text(b['image_url']),
      });
    }
    return out;
  }

  // ---- Export ----

  /// Builds a Kotatsu `.bk.zip` from Yomou database rows.
  ///
  /// Only sources Kotatsu carries are written; anything else is counted in
  /// [KotatsuExportResult.skipped].
  static KotatsuExportResult export({
    required List<Map<String, dynamic>> favorites,
    required List<Map<String, dynamic>> readingProgress,
    required List<Map<String, dynamic>> bookmarks,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final progressByManga = <String, List<Map<String, dynamic>>>{};
    for (final r in readingProgress) {
      final mangaId = r['mangaId']?.toString();
      if (mangaId == null || mangaId.isEmpty) continue;
      progressByManga.putIfAbsent(mangaId, () => []).add(r);
    }
    final bookmarksByManga = <String, List<Map<String, dynamic>>>{};
    for (final b in bookmarks) {
      final mangaId = b['mangaId']?.toString();
      if (mangaId == null || mangaId.isEmpty) continue;
      bookmarksByManga.putIfAbsent(mangaId, () => []).add(b);
    }

    final favouritesJson = <Map<String, dynamic>>[];
    final historyJson = <Map<String, dynamic>>[];
    final bookmarkGroups = <Map<String, dynamic>>[];
    final sourcesSeen = <String>[];
    final seenManga = <String>{};
    var skipped = 0;

    for (final row in favorites) {
      final mangaId = row['mangaId']?.toString() ?? '';
      final sourceId = row['sourceId']?.toString() ?? '';
      if (mangaId.isEmpty || !seenManga.add(mangaId)) {
        skipped++;
        continue;
      }
      final kotatsuSource = _yomouToKotatsu[sourceId];
      if (kotatsuSource == null) {
        skipped++;
        continue;
      }
      if (!sourcesSeen.contains(kotatsuSource)) sourcesSeen.add(kotatsuSource);

      final kotatsuId = _stableId('$sourceId:$mangaId');
      final title = row['title']?.toString() ?? '';
      final mangaJson = _mangaJson(
        kotatsuId,
        kotatsuSource,
        sourceId,
        mangaId,
        title,
        row['coverUrl']?.toString() ?? '',
      );

      favouritesJson.add({
        'manga_id': kotatsuId,
        'category_id': 0,
        'sort_key': favouritesJson.length,
        'pinned': false,
        'created_at': _msOf(row['lastReadAt']) ?? nowMs,
        'manga': mangaJson,
      });

      final lastReadAt = _msOf(row['lastReadAt']);
      final reads = progressByManga[mangaId] ?? const <Map<String, dynamic>>[];
      final hasProgress = lastReadAt != null || reads.isNotEmpty;
      if (hasProgress) {
        final latest = reads.isEmpty
            ? null
            : reads.reduce((a, b) =>
                _doubleOf(a['chapterNumber']) >= _doubleOf(b['chapterNumber'])
                    ? a
                    : b);
        final chapterKey = latest == null
            ? 'c${_doubleOf(row['lastReadChapter'])}'
            : 'c${_doubleOf(latest['chapterNumber'])}';
        historyJson.add({
          'manga_id': kotatsuId,
          'created_at': lastReadAt ?? nowMs,
          'updated_at': lastReadAt ?? nowMs,
          'chapter_id': _stableId('$mangaId:$chapterKey'),
          'page': _intOf(row['lastReadPage']),
          'scroll': 0.0,
          'percent': reads.isNotEmpty ? 1.0 : 0.0,
          'chapters': _intOf(row['totalChapters']),
          'manga': mangaJson,
        });
      }

      final bms = bookmarksByManga[mangaId];
      if (bms != null && bms.isNotEmpty) {
        final group = <Map<String, dynamic>>[];
        final seen = <String>{};
        for (final b in bms) {
          final chapterId = b['chapterId']?.toString() ?? '';
          final pageIndex = _intOf(b['pageIndex']);
          final key = '$chapterId/$pageIndex';
          if (!seen.add(key)) continue;
          group.add({
            'manga_id': kotatsuId,
            'page_id': _stableId('$mangaId:p:$chapterId:$pageIndex'),
            'chapter_id': _stableId('$mangaId:c:$chapterId'),
            'page': pageIndex,
            'scroll': 0.0,
            'image_url': b['pageUrl']?.toString() ?? '',
            'created_at': _msOf(b['createdAt']) ?? nowMs,
            'percent': 1.0,
          });
        }
        if (group.isNotEmpty) {
          bookmarkGroups.add({
            'manga': mangaJson,
            'tags': <Object>[],
            'bookmarks': group,
          });
        }
      }
    }

    final files = <String, Object>{
      'index': [
        {
          'app_id': 'io.github.kotatsuapp.kotatsu',
          'app_version': 1,
          'created_at': nowMs,
        }
      ],
      'identity': [
        {'secret': _randomSecret(), 'nickname': 'Yomou'}
      ],
      'categories': <Object>[],
      'favourites': favouritesJson,
      'history': historyJson,
      'bookmarks': bookmarkGroups,
      'settings': [<String, dynamic>{}],
      'sources': [
        for (var i = 0; i < sourcesSeen.length; i++)
          {
            'source': sourcesSeen[i],
            'sort_key': i,
            'used_at': nowMs,
            'pinned': false,
            'enabled': true,
          }
      ],
      'statistics': <Object>[],
      'reader_grid': <Object>[],
      'saved_filters': <Object>[],
      'scrobbling': <Object>[],
    };

    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile.bytes(
        entry.key,
        utf8.encode(jsonEncode(entry.value)),
      ));
    }
    final bytes = ZipEncoder().encode(archive);

    return KotatsuExportResult(
      bytes: Uint8List.fromList(bytes),
      exported: favouritesJson.length,
      skipped: skipped,
    );
  }

  static Map<String, dynamic> _mangaJson(
    int kotatsuId,
    String kotatsuSource,
    String sourceId,
    String mangaId,
    String title,
    String coverUrl,
  ) {
    return {
      'id': kotatsuId,
      'title': title,
      'alt_title': '',
      'url': _kotatsuUrl(sourceId, mangaId),
      'public_url': _publicUrl(sourceId, mangaId),
      'rating': 0.0,
      'nsfw': false,
      'content_rating': 'UNKNOWN',
      'cover_url': coverUrl,
      'large_cover_url': '',
      'state': '',
      'author': '',
      'source': kotatsuSource,
      'tags': <Object>[],
    };
  }

  /// The site-relative url Kotatsu stores for a manga on [sourceId]. These
  /// mirror the shapes Kotatsu writes for the same sites so an exported backup
  /// resolves back on their side.
  static String _kotatsuUrl(String sourceId, String mangaId) {
    switch (sourceId) {
      case 'mangadex':
        return '/title/$mangaId';
      case 'comick':
        return '/comic/$mangaId';
      case 'mangatown':
        return '/manga/$mangaId/';
      case 'asurascans':
        return '/comics/$mangaId';
      case 'mangago':
        return '/read-manga/$mangaId/';
      case 'mgeko':
      case 'likemanga':
        return '/$mangaId/';
      case 'mangapill':
      case 'manhuaplus':
      case 'mangabat':
      case 'seimanga':
        return '/$mangaId';
      case 'weebcentral':
        return '/series/$mangaId';
      case 'atsu':
        return mangaId.startsWith('/') ? mangaId : '/$mangaId';
      case 'arenascan':
        return '/manga/$mangaId/';
      case 'mangafire-en':
      case 'mangafire-es':
      case 'mangafire-esla':
      case 'mangafire-fr':
      case 'mangafire-ja':
      case 'mangafire-pt':
      case 'mangafire-ptbr':
        return '/manga/$mangaId';
      default:
        return '/$mangaId';
    }
  }

  /// A browser-openable page for the manga where the site's public domain is
  /// stable enough to guess; empty elsewhere rather than wrong.
  static String _publicUrl(String sourceId, String mangaId) {
    switch (sourceId) {
      case 'mangadex':
        return 'https://mangadex.org/title/$mangaId';
      case 'comick':
        return 'https://comick.io/comic/$mangaId';
      case 'asurascans':
        return 'https://asurascans.com/comics/$mangaId';
      case 'mangatown':
        return 'https://www.mangatown.com/manga/$mangaId/';
      case 'mangago':
        return 'https://www.mangago.me/read-manga/$mangaId/';
      case 'mgeko':
        return 'https://www.mgeko.cc/$mangaId/';
      case 'weebcentral':
        return 'https://weebcentral.com/series/$mangaId';
      case 'mangafire-en':
      case 'mangafire-es':
      case 'mangafire-esla':
      case 'mangafire-fr':
      case 'mangafire-ja':
      case 'mangafire-pt':
      case 'mangafire-ptbr':
        return 'https://mangafire.to/manga/$mangaId';
      default:
        return '';
    }
  }

  // ---- Url → Yomou manga id ----

  /// Derives the Yomou-internal manga id from a Kotatsu entry's [url] (and
  /// [publicUrl] when the url itself is a bare slug), or null when the entry
  /// cannot be trusted to a readable id.
  ///
  /// The shapes follow the same conventions Yomou's own sources key by: a
  /// MangaDex uuid, a ComicK slug, the mangago slug after `read-manga`, and
  /// the whole path minus slashes for mgeko/mangapill/likemanga.
  static String? _mangaIdFor(String yomouSource, String url, String publicUrl) {
    final candidates = <String>[
      _cleanPath(url),
      _cleanPath(_pathOf(publicUrl)),
    ];
    final seen = <String>{};
    for (final c in candidates) {
      if (c.isEmpty || !seen.add(c)) continue;
      final id = _idFromPath(yomouSource, c);
      if (id != null && _plausible(yomouSource, id)) return id;
    }
    return null;
  }

  static String? _idFromPath(String yomouSource, String clean) {
    if (yomouSource == 'mangadex') {
      return _mangadexUuid.firstMatch(clean)?.group(0);
    }
    if (yomouSource == 'mgeko' ||
        yomouSource == 'mangapill' ||
        yomouSource == 'likemanga' ||
        yomouSource == 'mangabat' ||
        yomouSource == 'manhuaplus') {
      // These Yomou sources key the manga by the whole url path (minus
      // slashes): `/manga/absolute-sword-sense-okxdz/` -> `manga/...`,
      // `/manga/57/berserk` -> `manga/57/berserk`.
      return clean.isEmpty ? null : clean;
    }
    final segments = clean.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? null : segments.last;
  }

  static bool _plausible(String yomouSource, String id) {
    if (id.isEmpty) return false;
    if (yomouSource == 'mangadex') return _mangadexUuid.hasMatch(id);
    return !id.contains(' ') &&
        !id.contains('#') &&
        !id.contains('%') &&
        !id.contains('://') &&
        !id.startsWith('http');
  }

  /// Strips a leading/trailing slash and any query string.
  static String _cleanPath(String value) {
    var v = value.split('?').first.trim();
    while (v.startsWith('/')) {
      v = v.substring(1);
    }
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  /// The site-relative path of a full url (`https://x/y/z` -> `/y/z`).
  static String _pathOf(String value) {
    var v = value.trim();
    final scheme = v.indexOf('://');
    if (scheme > 0) {
      v = v.substring(scheme + 3);
      final slash = v.indexOf('/');
      v = slash >= 0 ? v.substring(slash) : '';
    }
    return v;
  }

  // ---- Payload helpers ----

  static List<Map<String, dynamic>>? _listOf(Archive archive, String name) {
    ArchiveFile? file;
    for (final f in archive.files) {
      if (f.name == name) {
        file = f;
        break;
      }
    }
    if (file == null) return null;
    final data = file.readBytes() ?? Uint8List(0);
    final decoded = jsonDecode(utf8.decode(data));
    if (decoded is! List) return null;
    return decoded.whereType<Map>().map((r) => r.cast<String, dynamic>()).toList();
  }

  static Map<String, dynamic>? _mangaOf(Map<String, dynamic> entry) {
    final manga = entry['manga'];
    if (manga is! Map) return null;
    return manga.cast<String, dynamic>();
  }

  static DateTime? _readAt(Map<String, dynamic>? historyRow) {
    if (historyRow == null) return null;
    final ms = _kotatsuId(historyRow['updated_at']) ??
        _kotatsuId(historyRow['created_at']);
    return _msToDate(ms);
  }

  static DateTime? _msToDate(int? ms) {
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// A Kotatsu id (int64). JSON numbers may exceed 2^53 but Dart ints are
  /// arbitrary precision, so `int` survives the round trip.
  static int? _kotatsuId(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _text(Object? value) => value?.toString() ?? '';

  static int _intOf(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleOf(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _msOf(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
      return int.tryParse(value);
    }
    return null;
  }

  /// Deterministic 63-bit FNV-1a so the same manga always gets the same
  /// Kotatsu id inside a backup (and across exports of the same library).
  static int _stableId(String seed) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(seed)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash;
  }

  static String _randomSecret() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

/// The outcome of exporting to a Kotatsu `.bk.zip`.
class KotatsuExportResult {
  const KotatsuExportResult({
    required this.bytes,
    required this.exported,
    required this.skipped,
  });

  final Uint8List bytes;
  final int exported;
  final int skipped;
}