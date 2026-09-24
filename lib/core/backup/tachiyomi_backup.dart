import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:yomou/core/backup/tachiyomi_protobuf.dart';

/// Compatibility with current Tachiyomi/Mihon `.tachibk` backups.
///
/// Modern Mihon files are a protobuf-encoded `Backup` message that is gzipped
/// onto disk (gzip magic `0x1f8b`). Old Tachiyomi backups are plain JSON and
/// are still accepted on import. Sources are identified by the integer ids
/// Mihon assigns to its extensions (keiyoushi repo); the source ids, field
/// numbers and wire types below were verified against the Mihon source code.
///
/// Entries whose Yomou source has no known Mihon counterpart are skipped on
/// export; on import, entries whose Mihon source id cannot be resolved are
/// skipped. Both paths report the counts so the UI can show a notice.
class TachiyomiBackupCodec {
  TachiyomiBackupCodec._();

  // Current Mihon extension source ids (from the keiyoushi index.json manifest).
  static const Map<String, int> _yomouToMihon = {
    'mangadex': 2499283573021220255,
    'manganato': 1024627298672457456,
    'mangakatana': 3170561626848540385,
    'mangatown': 2703831045012166262,
    'likemanga': 6236979603959140497,
    'asurascans': 6247824327199706550,
    'comick': 4972933717624256217,
    'mgeko': 734865402529567092,
  };

  static const Map<String, String> _sourceDisplayNames = {
    'mangadex': 'MangaDex',
    'manganato': 'Manganato',
    'mangakatana': 'MangaKatana',
    'mangatown': 'Mangatown',
    'likemanga': 'LikeManga',
    'asurascans': 'Asura Scans',
    'comick': 'ComicK',
    'mgeko': 'MangaGeko',
  };

  // Legacy Tachiyomi integer ids accepted on import for older backups.
  static const Map<int, String> _legacyMihonToYomou = {
    1: 'mangadex',
    305: 'manganato',
  };

  static const String _mihonMangadex = 'mangadex';
  static const String _mihonManganato = 'manganato';

  /// Human-readable label for a Yomou source id (used by the import-results
  /// summary screen). Falls back to the raw id when unknown.
  static String sourceDisplayName(String? yomouSource) {
    if (yomouSource == null) return '';
    return _sourceDisplayNames[yomouSource] ?? yomouSource;
  }

  static int? _mihonIdFor(String? yomouSource) {
    if (yomouSource == null) return null;
    return _yomouToMihon[yomouSource];
  }

  static String _mihonUrl(String yomouSource, String mangaId) {
    switch (yomouSource) {
      case 'mangadex':
        return '/title/$mangaId';
      case 'manganato':
        return mangaId.startsWith('manga-') ? '/$mangaId' : '/manga/$mangaId';
      case 'asurascans':
        return mangaId.startsWith('series-') ? '/$mangaId' : '/series/$mangaId';
      default:
        return '/$mangaId';
    }
  }

  /// Maps a Mihon chapter url to the Yomou-internal chapter id for [source].
  ///
  /// Yomou sources almost always key chapters by the last path segment of the
  /// page url (mangadex uses the chapter uuid, asurascans stores an
  /// `api/series/<manga>/chapters/<slug>` id). Returns null when the url
  /// cannot be mapped so callers can fall back gracefully.
  static String? _chapterIdFor(String yomouSource, String mangaId, String url) {
    if (url.isEmpty || url == mangaId) return null;
    var clean = url.split('?').first;
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    final segments =
        clean.split('/').where((s) => s.isNotEmpty).toList(growable: false);
    if (segments.isEmpty) return null;
    if (yomouSource == 'mangadex') {
      final uuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      for (final s in segments.reversed) {
        if (uuid.hasMatch(s)) return s;
      }
    }
    final last = segments.last;
    if (last.isEmpty) return null;
    if (yomouSource == 'asurascans') {
      return 'api/series/$mangaId/chapters/$last';
    }
    return last;
  }

  /// Resolves a Mihon source id (+ url fallbacks) back to a Yomou source id.
  static String? _yomouSourceFor(int? mihonSource, String url) {
    if (mihonSource != null) {
      final legacy = _legacyMihonToYomou[mihonSource];
      if (legacy != null) return legacy;
      final match = _yomouToMihon.entries
          .where((e) => e.value == mihonSource)
          .toList();
      if (match.isNotEmpty) return match.first.key;
    }
    final u = url.toLowerCase();
    if (u.startsWith('/title/')) return _mihonMangadex;
    if (u.contains('/manga-')) return _mihonManganato;
    if (u.startsWith('/series/')) return 'asurascans';
    return null;
  }

  static final RegExp _mangadexUuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Extracts the Yomou-internal manga id from a Mihon source url.
  ///
  /// Each Yomou source stores its id in its own format:
  ///  - mangadex: the `/title/<uuid>` or `/manga/<uuid>` uuid. Anything that
  ///    does not look like a MangaDex uuid is rejected so entries aliased to
  ///    non-uuid urls (seen in real-world backups) do not land in the library
  ///    unreadable.
  ///  - manganato: the slug/token after the `manga-` prefix (Yomou's chapter
  ///    fetcher re-adds it).
  ///  - mangakatana: the full `manga/...` path (no leading slash).
  ///  - asurascans/other: the final path segment.
  static String? _mangaIdFor(String yomouSource, String url) {
    var clean = url.split('?').first;
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.isEmpty) return null;
    if (yomouSource == 'mangadex') {
      for (final prefix in const ['/title/', '/manga/']) {
        if (clean.startsWith(prefix)) {
          final id = clean.substring(prefix.length).split('/').first;
          return id.isNotEmpty && _mangadexUuid.hasMatch(id) ? id : null;
        }
      }
      return null;
    }
    if (yomouSource == 'manganato') {
      final last = clean.split('/').last;
      return last.startsWith('manga-') ? last.substring('manga-'.length) : last;
    }
    if (yomouSource == 'mangakatana') {
      return clean.startsWith('/') ? clean.substring(1) : clean;
    }
    if (yomouSource == 'mgeko') {
      // Yomou's mgeko source keys manga by the full path minus slashes,
      // e.g. `/manga/bowblade-spirit-mg12/` -> `manga/bowblade-spirit-mg12`.
      final stripped = clean.startsWith('/') ? clean.substring(1) : clean;
      return stripped.isEmpty ? null : stripped;
    }
    final last = clean.split('/').last;
    return last.isEmpty ? null : last;
  }

  static double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int? _toMs(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
      final n = int.tryParse(v);
      if (n != null) return n;
    }
    return null;
  }

  // ---- Export ----

  /// Builds the `.tachibk` bytes (gzipped Mihon `Backup` protobuf) from Yomou
  /// database rows. Returns the bytes plus counts for reporting.
  static TachiyomiExportResult export({
    required List<Map<String, dynamic>> favorites,
    required List<Map<String, dynamic>> bookmarks,
    required List<Map<String, dynamic>> readingProgress,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in favorites) {
      byId[row['mangaId'] as String] = row;
    }

    final readingByManga = <String, List<Map<String, dynamic>>>{};
    for (final row in readingProgress) {
      final mangaId = row['mangaId'] as String?;
      if (mangaId == null) continue;
      readingByManga.putIfAbsent(mangaId, () => []).add(row);
    }

    final bookmarksByManga = <String, List<Map<String, dynamic>>>{};
    for (final row in bookmarks) {
      final mangaId = row['mangaId'] as String?;
      if (mangaId == null) continue;
      bookmarksByManga.putIfAbsent(mangaId, () => []).add(row);
    }

    final usedSources = <int, String>{};
    final backupMessage = ProtoWriter();
    var skipped = 0;

    for (final entry in byId.entries) {
      final mangaId = entry.key;
      final row = entry.value;
      final source = row['sourceId'] as String?;
      final mihonId = _mihonIdFor(source);
      if (mihonId == null || source == null) {
        skipped++;
        continue;
      }

      final title = (row['title'] as String?) ?? '';
      final coverUrl = (row['coverUrl'] as String?) ?? '';
      final dateAdded =
          _toMs(row['lastReadAt']) ?? DateTime.now().millisecondsSinceEpoch;
      usedSources.putIfAbsent(mihonId, () => source);

      backupMessage.writeMessageField(1, (manga) {
        manga.writeInt64Field(1, mihonId); // source
        manga.writeStringField(2, _mihonUrl(source, mangaId)); // url
        manga.writeStringField(3, title);
        manga.writeStringField(9, coverUrl); // thumbnailUrl
        manga.writeInt64Field(13, dateAdded); // dateAdded
        manga.writeBoolField(100, true); // favorite

        final seenChapterKeys = <String>{};
        for (final bm in bookmarksByManga[mangaId] ??
            const <Map<String, dynamic>>[]) {
          final pageUrl = (bm['pageUrl'] as String?) ?? '';
          final url = pageUrl.isNotEmpty
              ? pageUrl
              : ((bm['chapterId'] as String?) ?? '');
          if (url.isEmpty) continue;
          final key = url;
          final at = _toMs(bm['createdAt']) ??
              DateTime.now().millisecondsSinceEpoch;
          if (seenChapterKeys.contains(key)) continue;
          seenChapterKeys.add(key);
          manga.writeMessageField(16, (c) {
            c.writeStringField(1, url);
            c.writeStringField(2, (bm['chapterTitle'] as String?) ?? '');
            c.writeBoolField(4, true); // read
            c.writeBoolField(5, true); // bookmark
            c.writeInt64Field(7, at); // dateFetch
            c.writeInt64Field(8, at); // dateUpload
          });
          manga.writeMessageField(104, (h) {
            h.writeStringField(1, url);
            h.writeInt64Field(2, at); // lastRead = read timestamp (ms)
          });
        }

        for (final rp in readingByManga[mangaId] ??
            const <Map<String, dynamic>>[]) {
          final chapterId = (rp['chapterId'] as String?) ?? '';
          final chapterNum = _toDouble(rp['chapterNumber']);
          final at = _toMs(rp['lastReadAt']) ??
              DateTime.now().millisecondsSinceEpoch;
          if (chapterId.isEmpty || seenChapterKeys.contains(chapterId)) {
            continue;
          }
          seenChapterKeys.add(chapterId);
          manga.writeMessageField(16, (c) {
            c.writeStringField(1, chapterId);
            c.writeStringField(2, '');
            c.writeBoolField(4, true); // read
            c.writeFloat32Field(9, chapterNum);
            c.writeInt64Field(7, at); // dateFetch
            c.writeInt64Field(8, at); // dateUpload
          });
          manga.writeMessageField(104, (h) {
            h.writeStringField(1, chapterId);
            h.writeInt64Field(2, at); // lastRead = read timestamp (ms)
          });
        }
      });
    }

    for (final entry in usedSources.entries) {
      backupMessage.writeMessageField(101, (s) {
        s.writeStringField(1,
            _sourceDisplayNames[entry.value] ?? entry.value);
        s.writeInt64Field(2, entry.key); // sourceId
      });
    }

    final payload = backupMessage.takeBytes();
    final bytes = Uint8List.fromList(gzip.encode(payload));

    return TachiyomiExportResult(
      bytes: bytes,
      exported: byId.length - skipped,
      skipped: skipped,
    );
  }

  // ---- Import ----

  /// Parses a `.tachibk` backup (gzipped protobuf) or a legacy JSON backup
  /// into rows ready for the Yomou database.
  /// Throws [FormatException] on malformed input.
  static TachiyomiImportResult import(Uint8List bytes) {
    Uint8List payload;
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      try {
        payload = Uint8List.fromList(gzip.decode(bytes));
      } catch (_) {
        throw const FormatException('Invalid Tachiyomi backup file');
      }
    } else {
      payload = bytes;
    }

    // Legacy JSON backups: parse and import their library.
    var start = 0;
    while (start < payload.length && (payload[start] == 0x20 ||
        payload[start] == 0x09 ||
        payload[start] == 0x0a ||
        payload[start] == 0x0d)) {
      start++;
    }
    if (start < payload.length) {
      final first = payload[start];
      if (first == 0x7b /* { */) {
        return _importJson(utf8.decode(
          Uint8List.sublistView(payload, start),
        ));
      }
    }

    // Protobuf `Backup` message.
    final fields = TachiyomiProtoCodec.decode(payload);
    final rawMangas = fields[1] ?? const <Object?>[];

    // Backup source list (field 101) carries the human-readable extension
    // names, so skipped entries can tell the user which source is missing.
    final mihonSourceNames = <int, String>{};
    for (final rawS in fields[101] ?? const <Object?>[]) {
      final s = TachiyomiProtoCodec.asMessage(rawS);
      if (s == null) continue;
      final sid = TachiyomiProtoCodec.asInt(
        (s[2] ?? const <Object?>[]).firstOrNull,
      );
      if (sid <= 0) continue;
      final name = TachiyomiProtoCodec.asString(
        (s[1] ?? const <Object?>[]).firstOrNull,
      );
      mihonSourceNames[sid] = name.isNotEmpty ? name : 'source $sid';
    }
    String? sourceNameFor(int? sourceInt) {
      if (sourceInt == null) return null;
      return mihonSourceNames[sourceInt] ?? 'source $sourceInt';
    }

    final mangas = <TachiyomiImportedManga>[];
    final skippedMangas = <TachiyomiSkippedManga>[];

    for (final raw in rawMangas) {
      final manga = TachiyomiProtoCodec.asMessage(raw);
      if (manga == null) {
        skippedMangas.add(TachiyomiSkippedManga(
          reason: TachiyomiSkippedReason.invalidEntry,
        ));
        continue;
      }
      final url = TachiyomiProtoCodec.asString(
        (manga[2] ?? const <Object?>[]).firstOrNull,
      );
      final title = TachiyomiProtoCodec.asString(
        (manga[3] ?? const <Object?>[]).firstOrNull,
      );
      final sourceInt = (manga[1] ?? const <Object?>[]).firstOrNull;
      final intSource = sourceInt is int ? sourceInt : null;
      final sourceId = _yomouSourceFor(intSource, url);
      if (sourceId == null) {
        skippedMangas.add(TachiyomiSkippedManga(
          title: title,
          url: url,
          sourceName: sourceNameFor(intSource),
          reason: TachiyomiSkippedReason.unsupportedSource,
        ));
        continue;
      }
      final mangaId = _mangaIdFor(sourceId, url);
      if (mangaId == null || mangaId.isEmpty) {
        skippedMangas.add(TachiyomiSkippedManga(
          title: title,
          url: url,
          sourceName: sourceNameFor(intSource),
          reason: TachiyomiSkippedReason.missingMangaId,
        ));
        continue;
      }
      if (title.isEmpty) {
        // fall through; TachiyomiImportedManga falls back to the manga id.
      }

      final coverUrl = TachiyomiProtoCodec.asString(
        (manga[9] ?? const <Object?>[]).firstOrNull,
      );

      final bookmarks = <Map<String, dynamic>>[];
      final readChapters = <Map<String, dynamic>>[];
      var lastChapter = 0.0;
      String? lastChapterUrl;
      DateTime? lastReadAt;
      int? newestReadAt;

      for (final rawH in manga[104] ?? const <Object?>[]) {
        final h = TachiyomiProtoCodec.asMessage(rawH);
        if (h == null) continue;
        final at = TachiyomiProtoCodec.asInt(
          (h[2] ?? const <Object?>[]).firstOrNull,
        );
        if (at > 0 && (newestReadAt == null || at > newestReadAt)) {
          newestReadAt = at;
        }
      }
      if (newestReadAt != null) {
        lastReadAt = DateTime.fromMillisecondsSinceEpoch(newestReadAt);
      }

      for (final rawC in manga[16] ?? const <Object?>[]) {
        final c = TachiyomiProtoCodec.asMessage(rawC);
        if (c == null) continue;
        final chapterId = TachiyomiProtoCodec.asString(
          (c[1] ?? const <Object?>[]).firstOrNull,
        );
        final chapterName = TachiyomiProtoCodec.asString(
          (c[2] ?? const <Object?>[]).firstOrNull,
        );
        final isBookmark = TachiyomiProtoCodec.asBool(
          (c[5] ?? const <Object?>[]).firstOrNull,
        );
        if (isBookmark) {
          bookmarks.add({
            'chapterId': chapterId,
            'chapterTitle': chapterName,
            'pageUrl': chapterId,
          });
        }
        final num = TachiyomiProtoCodec.asFloat32(
          (c[9] ?? const <Object?>[]).firstOrNull,
        );
        if (num > lastChapter) {
          lastChapter = num;
          lastChapterUrl = chapterId;
        }
        if (lastChapter == 0 && chapterName.isNotEmpty) {
          final parsed = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(chapterName);
          if (parsed != null) {
            final n = double.tryParse(parsed.group(1)!);
            if (n != null && n > lastChapter) {
              lastChapter = n;
              lastChapterUrl = chapterId;
            }
          }
        }
      }

      if (lastChapter > 0) {
        final chapterId = _chapterIdFor(sourceId, mangaId, lastChapterUrl ?? '');
        if (chapterId != null && chapterId.isNotEmpty) {
          readChapters.add({
            'chapterId': chapterId,
            'chapterNumber': lastChapter,
            'lastReadAt': lastReadAt,
          });
        }
      }

      final favFields = manga[100];
      final isFavorite = favFields == null
          ? true // Mihon omits the default-true favorite flag in library backups.
          : TachiyomiProtoCodec.asBool(favFields.firstOrNull);

      mangas.add(TachiyomiImportedManga(
        mangaId: mangaId,
        title: title.isEmpty ? mangaId : title,
        coverUrl: coverUrl,
        sourceId: sourceId,
        lastReadChapter: lastChapter,
        lastReadAt: lastReadAt,
        isFavorite: isFavorite,
        bookmarks: bookmarks,
        readChapters: readChapters,
      ));
    }

    return TachiyomiImportResult(
      mangas: mangas,
      skippedMangas: skippedMangas,
    );
  }

  static TachiyomiImportResult _importJson(String source) {
    final decoded = jsonDecode(source);
    Map<String, dynamic> data;
    if (decoded is Map<String, dynamic>) {
      final backup = decoded['backup'];
      if (backup is Map<String, dynamic>) {
        data = backup;
      } else {
        data = decoded;
      }
    } else {
      throw const FormatException('Invalid Tachiyomi backup file');
    }

    final rawLibrary = data['library'];
    if (rawLibrary is! List) {
      throw const FormatException('Backup contains no library');
    }

    final mangas = <TachiyomiImportedManga>[];
    final skippedMangas = <TachiyomiSkippedManga>[];

    for (final raw in rawLibrary) {
      if (raw is! Map<String, dynamic>) {
        skippedMangas.add(TachiyomiSkippedManga(
          reason: TachiyomiSkippedReason.invalidEntry,
        ));
        continue;
      }
      final url = (raw['url'] as String?) ?? '';
      final title = (raw['title'] as String?) ?? url;
      final sourceInt = raw['source'] is int
          ? (raw['source'] as int)
          : int.tryParse('${raw['source']}');
      final sourceId = _yomouSourceFor(sourceInt, url);
      if (sourceId == null) {
        skippedMangas.add(TachiyomiSkippedManga(
          title: title,
          url: url,
          sourceName: sourceInt == null
              ? null
              : 'source $sourceInt',
          reason: TachiyomiSkippedReason.unsupportedSource,
        ));
        continue;
      }
      final mangaId = _mangaIdFor(sourceId, url);
      if (mangaId == null || mangaId.isEmpty) {
        skippedMangas.add(TachiyomiSkippedManga(
          title: title,
          url: url,
          reason: TachiyomiSkippedReason.missingMangaId,
        ));
        continue;
      }
      final coverUrl = (raw['thumbnailUrl'] as String?) ?? '';
      final isFavorite = raw['isFavorite'] != false;

      final bookmarks = <Map<String, dynamic>>[];
      final readChapters = <Map<String, dynamic>>[];
      var lastChapter = 0.0;
      String? lastChapterUrl;
      DateTime? lastReadAt;

      final rawHistory = raw['history'];
      if (rawHistory is List) {
        for (final h in rawHistory) {
          if (h is! Map<String, dynamic>) continue;
          final ms = _toMs(h['lastReadAt']);
          if (ms != null) {
            final at = DateTime.fromMillisecondsSinceEpoch(ms);
            if (lastReadAt == null || at.isAfter(lastReadAt)) {
              lastReadAt = at;
            }
          }
        }
      }

      final rawChapters = raw['chapters'];
      if (rawChapters is List) {
        for (final c in rawChapters) {
          if (c is! Map<String, dynamic>) continue;
          final chapterId = (c['url'] as String?) ?? '';
          final chapterName = (c['name'] as String?) ?? '';
          final isBookmark = c['bookmark'] == true || c['bookmark'] == 'true';
          if (isBookmark) {
            bookmarks.add({
              'chapterId': chapterId,
              'chapterTitle': chapterName,
              'pageUrl': (c['url'] as String?) ?? '',
            });
          }
          final parsed = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(chapterName);
          if (parsed != null) {
            final n = double.tryParse(parsed.group(1)!);
            if (n != null && n > lastChapter) {
              lastChapter = n;
              lastChapterUrl = chapterId;
            }
          }
        }
      }

      if (lastChapter > 0) {
        final chapterId = _chapterIdFor(sourceId, mangaId, lastChapterUrl ?? '');
        if (chapterId != null && chapterId.isNotEmpty) {
          readChapters.add({
            'chapterId': chapterId,
            'chapterNumber': lastChapter,
            'lastReadAt': lastReadAt,
          });
        }
      }

      mangas.add(TachiyomiImportedManga(
        mangaId: mangaId,
        title: title,
        coverUrl: coverUrl,
        sourceId: sourceId,
        lastReadChapter: lastChapter,
        lastReadAt: lastReadAt,
        isFavorite: isFavorite,
        bookmarks: bookmarks,
        readChapters: readChapters,
      ));
    }

    return TachiyomiImportResult(
      mangas: mangas,
      skippedMangas: skippedMangas,
    );
  }
}

class TachiyomiExportResult {
  const TachiyomiExportResult({
    required this.bytes,
    required this.exported,
    required this.skipped,
  });

  final Uint8List bytes;
  final int exported;
  final int skipped;
}

class TachiyomiImportedManga {
  const TachiyomiImportedManga({
    required this.mangaId,
    required this.title,
    required this.coverUrl,
    required this.sourceId,
    required this.lastReadChapter,
    required this.lastReadAt,
    this.isFavorite = true,
    required this.bookmarks,
    this.readChapters = const <Map<String, dynamic>>[],
  });

  final String mangaId;
  final String title;
  final String coverUrl;
  final String sourceId;
  final double lastReadChapter;
  final DateTime? lastReadAt;
  final bool isFavorite;
  final List<Map<String, dynamic>> bookmarks;

  /// Per-chapter read records (`chapterId`/`chapterNumber`/`lastReadAt`)
  /// derived from the backup so the reader can seed its progress table.
  final List<Map<String, dynamic>> readChapters;
}

class TachiyomiImportResult {
  const TachiyomiImportResult({
    required this.mangas,
    required this.skippedMangas,
  });

  final List<TachiyomiImportedManga> mangas;
  final List<TachiyomiSkippedManga> skippedMangas;

  int get skipped => skippedMangas.length;
}

/// Why an entry from the backup was not imported. Rendered as l10n keys is
/// left to the UI; these are stable codes for grouping.
enum TachiyomiSkippedReason { unsupportedSource, missingMangaId, invalidEntry }

/// A manga entry that could not be imported, with enough detail to tell the
/// user what happened (e.g. title + the unsupported source's display name).
class TachiyomiSkippedManga {
  const TachiyomiSkippedManga({
    this.title,
    this.url,
    this.sourceName,
    required this.reason,
  });

  final String? title;
  final String? url;

  /// Human-readable source name from the backup (e.g. "Comick (Unoriginal)").
  final String? sourceName;
  final TachiyomiSkippedReason reason;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}