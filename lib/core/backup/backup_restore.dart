import 'dart:convert';
import 'dart:typed_data';
import 'package:yomou/core/backup/tachiyomi_backup.dart';
import 'package:yomou/core/database/database_helper.dart';

/// Which backup format a picked file turned out to be.
///
/// The reader picks one file and never chooses a format themselves, so this is
/// detected rather than asked for: nobody holding a Mihon backup knows it is
/// "gzipped protobuf", and a `.json` extension belongs to both formats.
enum BackupFormat { yomou, tachiyomi }

/// What a Yomou-format backup restored.
class YomouRestoreResult {
  const YomouRestoreResult({
    this.history = 0,
    this.favorites = 0,
    this.bookmarks = 0,
    this.skippedNewer = 0,
  });

  final int history;
  final int favorites;
  final int bookmarks;

  /// Titles skipped because the copy already on this device is further along.
  final int skippedNewer;

  int get restored => history + favorites + bookmarks;
  bool get isEmpty => restored == 0;
}

/// The outcome of a restore, whichever format it turned out to be.
class BackupRestoreResult {
  const BackupRestoreResult.yomou(this.yomou)
    : format = BackupFormat.yomou,
      tachiyomi = null;

  const BackupRestoreResult.tachiyomi(this.tachiyomi)
    : format = BackupFormat.tachiyomi,
      yomou = null;

  final BackupFormat format;
  final YomouRestoreResult? yomou;
  final TachiyomiImportResult? tachiyomi;
}

/// Reading a backup file and writing it into the database.
///
/// Both formats funnel through here so the welcome sheet, the settings screen
/// and any future entry point cannot drift into three subtly different restore
/// paths. Before this existed, Yomou's own restore validated the picked file
/// and then restored nothing at all.
class BackupRestore {
  const BackupRestore._();

  /// Whether [bytes] is a Yomou backup, a Tachiyomi/Mihon one, or neither.
  ///
  /// Throws [FormatException] for anything that is not a backup file.
  static BackupFormat detect(Uint8List bytes) {
    // Gzip is a Tachiyomi `.tachibk` or a gzipped `.proto.gz`. No Yomou backup
    // has ever been written compressed.
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      return BackupFormat.tachiyomi;
    }

    var start = 0;
    while (start < bytes.length &&
        (bytes[start] == 0x20 ||
            bytes[start] == 0x09 ||
            bytes[start] == 0x0a ||
            bytes[start] == 0x0d)) {
      start++;
    }

    // Neither gzipped nor JSON: a bare protobuf `Backup` message.
    if (start >= bytes.length || bytes[start] != 0x7b /* { */) {
      return BackupFormat.tachiyomi;
    }

    final decoded = jsonDecode(
      utf8.decode(Uint8List.sublistView(bytes, start)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file');
    }
    // Yomou's own shape. Everything else that parses as JSON here is a legacy
    // Tachiyomi/Mihon backup, which keys its library under `manga`/`info`.
    if (decoded.containsKey('history') ||
        decoded.containsKey('favorites') ||
        decoded.containsKey('bookmarks')) {
      return BackupFormat.yomou;
    }
    return BackupFormat.tachiyomi;
  }

  /// Reads [bytes] and writes it into the database.
  ///
  /// Throws [FormatException] when the file is not a backup at all.
  static Future<BackupRestoreResult> restore(Uint8List bytes) async {
    switch (detect(bytes)) {
      case BackupFormat.yomou:
        final decoded = jsonDecode(
          utf8.decode(bytes),
        ) as Map<String, dynamic>;
        return BackupRestoreResult.yomou(await restoreYomou(decoded));
      case BackupFormat.tachiyomi:
        return BackupRestoreResult.tachiyomi(
          await applyTachiyomi(TachiyomiBackupCodec.import(bytes)),
        );
    }
  }

  /// Applies a decoded Yomou backup.
  ///
  /// Existing rows are never rewound: if this device is already further along a
  /// title than the backup is, that title is counted in
  /// [YomouRestoreResult.skippedNewer] and left alone. Restoring a backup from
  /// a week ago must not throw away a week of reading.
  static Future<YomouRestoreResult> restoreYomou(
    Map<String, dynamic> backup, {
    DatabaseHelper? dbOverride,
  }) async {
    final db = dbOverride ?? DatabaseHelper.instance;

    final history = _rows(backup['history']);
    final favorites = _rows(backup['favorites']);
    final bookmarks = _rows(backup['bookmarks']);

    var restoredHistory = 0;
    var restoredFavorites = 0;
    var restoredBookmarks = 0;
    var skippedNewer = 0;

    for (final row in history) {
      final mangaId = _text(row['mangaId']);
      if (mangaId.isEmpty) continue;
      if (await _isNewerOnDevice(db, mangaId, row)) {
        skippedNewer++;
        continue;
      }
      await db.saveMangaProgress(
        mangaId: mangaId,
        title: _text(row['title']),
        coverUrl: _text(row['coverUrl']),
        sourceId: _text(row['sourceId']),
        totalChapters: _int(row['totalChapters']),
        lastReadChapter: _double(row['lastReadChapter']),
        lastReadPage: _int(row['lastReadPage']),
        lastTrayTotalChapters: _int(row['lastTrayTotalChapters']),
        lastReadAt: _date(row['lastReadAt']),
      );
      restoredHistory++;
    }

    for (final row in favorites) {
      final mangaId = _text(row['mangaId']);
      if (mangaId.isEmpty) continue;
      // A favourite is only skipped when the device is both further along and
      // already marks it favourite. Comparing progress alone would drop a
      // favourite that the backup is the first to record.
      if (await _isNewerOnDevice(db, mangaId, row, requireFavorite: true)) {
        skippedNewer++;
        continue;
      }
      // Progress is written first so a favourite that also carries reading
      // history does not have it wiped by this insert.
      if (_int(row['lastReadChapter']) >= 0) {
        await db.saveMangaProgress(
          mangaId: mangaId,
          title: _text(row['title']),
          coverUrl: _text(row['coverUrl']),
          sourceId: _text(row['sourceId']),
          totalChapters: _int(row['totalChapters']),
          lastReadChapter: _double(row['lastReadChapter']),
          lastReadPage: _int(row['lastReadPage']),
          lastTrayTotalChapters: _int(row['lastTrayTotalChapters']),
          lastReadAt: _date(row['lastReadAt']),
        );
      }
      await db.setFavorite(
        mangaId: mangaId,
        title: _text(row['title']),
        coverUrl: _text(row['coverUrl']),
        sourceId: _text(row['sourceId']),
        isFavorite: true,
      );
      restoredFavorites++;
    }

    for (final row in bookmarks) {
      final mangaId = _text(row['mangaId']);
      if (mangaId.isEmpty) continue;
      await db.addBookmark(
        mangaId: mangaId,
        chapterId: _text(row['chapterId'], fallback: mangaId),
        chapterTitle: _text(row['chapterTitle']),
        pageIndex: _int(row['pageIndex']),
        pageUrl: _text(row['pageUrl']),
        note: _text(row['note']),
      );
      restoredBookmarks++;
    }

    return YomouRestoreResult(
      history: restoredHistory,
      favorites: restoredFavorites,
      bookmarks: restoredBookmarks,
      skippedNewer: skippedNewer,
    );
  }

  /// Writes a parsed Tachiyomi/Mihon backup into the database.
  ///
  /// Moved out of the settings screen so the welcome sheet can restore one
  /// without duplicating the row-by-row application.
  static Future<TachiyomiImportResult> applyTachiyomi(
    TachiyomiImportResult parsed, {
    DatabaseHelper? dbOverride,
  }) async {
    final db = dbOverride ?? DatabaseHelper.instance;

    for (final m in parsed.mangas) {
      await db.saveMangaProgress(
        mangaId: m.mangaId,
        title: m.title,
        coverUrl: m.coverUrl,
        sourceId: m.sourceId,
        lastReadChapter: m.lastReadChapter,
        lastReadAt: m.lastReadAt,
      );
      await db.setFavorite(
        mangaId: m.mangaId,
        title: m.title,
        coverUrl: m.coverUrl,
        sourceId: m.sourceId,
        isFavorite: m.isFavorite,
      );
      for (final b in m.bookmarks) {
        await db.addBookmark(
          mangaId: m.mangaId,
          chapterId: (b['chapterId'] as String?) ?? m.mangaId,
          chapterTitle: (b['chapterTitle'] as String?) ?? m.title,
          pageIndex: 0,
          pageUrl: (b['pageUrl'] as String?) ?? '',
        );
      }
      for (final r in m.readChapters) {
        final chapterId = (r['chapterId'] as String?) ?? '';
        if (chapterId.isEmpty) continue;
        await db.recordReadingProgress(
          mangaId: m.mangaId,
          chapterId: chapterId,
          chapterNumber: (r['chapterNumber'] as num?)?.toDouble() ?? 0,
          at: r['lastReadAt'] as DateTime?,
        );
      }
    }
    return parsed;
  }

  /// Whether the device already holds a copy of [mangaId] that is further
  /// along than the one in the backup.
  ///
  /// Rows with no readable date on either side are not considered newer: a
  /// backup without timestamps should still restore.
  static Future<bool> _isNewerOnDevice(
    DatabaseHelper db,
    String mangaId,
    Map<String, dynamic> row, {
    bool requireFavorite = false,
  }) async {
    final incoming = _date(row['lastReadAt']);
    if (incoming == null) return false;
    final existing = await db.getManga(mangaId);
    if (existing == null) return false;
    final current = _date(existing['lastReadAt']);
    if (current == null) return false;
    if (!current.isAfter(incoming)) return false;
    if (requireFavorite) return existing['isFavorite'] == 1;
    return true;
  }

  static List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((r) => r.cast<String, dynamic>()).toList();
  }

  static String _text(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? -1;
  }

  static DateTime? _date(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
