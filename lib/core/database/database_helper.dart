import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // Singleton pattern to ensure only one database connection exists
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    // Get the default path for databases on Android/iOS
    String path = join(await getDatabasesPath(), 'manga_reader.db');

    return await openDatabase(
      path,
      version: 9,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS manga (
          mangaId TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          coverUrl TEXT,
          sourceId TEXT,
          totalChapters INTEGER DEFAULT 0,
          lastReadChapter REAL DEFAULT -1,
          lastReadPage INTEGER DEFAULT 0,
          lastTrayTotalChapters INTEGER DEFAULT 0,
          lastReadAt TEXT,
          isFavorite INTEGER DEFAULT 0,
          isReadLater INTEGER DEFAULT 0,
          tags TEXT DEFAULT '[]'
        )
      ''');
    }
    if (oldVersion < 3) {
      await _createBookmarksTable(db);
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE manga ADD COLUMN lastReadPage INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE manga ADD COLUMN lastTrayTotalChapters INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE manga ADD COLUMN tags TEXT DEFAULT '[]'");
    }
    if (oldVersion < 7) {
      await _createDownloadsTable(db);
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE downloads ADD COLUMN pageUrls TEXT');
      await _createSourceCacheTable(db);
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE manga ADD COLUMN originalTitle TEXT');
      await db.execute('ALTER TABLE manga ADD COLUMN originalCoverUrl TEXT');
    }
  }

  Future _createDB(Database db, int version) async {
    // Store per-chapter reading records
    await db.execute('''
      CREATE TABLE reading_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mangaId TEXT NOT NULL,
        chapterId TEXT NOT NULL,
        chapterNumber REAL NOT NULL,
        lastReadAt TEXT NOT NULL
      )
    ''');

    // Store manga metadata used to build the History screen
    await db.execute('''
      CREATE TABLE manga (
        mangaId TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        coverUrl TEXT,
        sourceId TEXT,
        totalChapters INTEGER DEFAULT 0,
        lastReadChapter REAL DEFAULT -1,
        lastReadPage INTEGER DEFAULT 0,
        lastTrayTotalChapters INTEGER DEFAULT 0,
        lastReadAt TEXT,
        isFavorite INTEGER DEFAULT 0,
        isReadLater INTEGER DEFAULT 0,
        tags TEXT DEFAULT '[]',
        originalTitle TEXT,
        originalCoverUrl TEXT
      )
    ''');

    await _createBookmarksTable(db);
    await _createDownloadsTable(db);
    await _createSourceCacheTable(db);
  }

  Future _createSourceCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS source_cache (
        key TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        fetchedAt TEXT NOT NULL
      )
    ''');
  }

  Future _createBookmarksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mangaId TEXT NOT NULL,
        chapterId TEXT NOT NULL,
        chapterTitle TEXT NOT NULL,
        pageIndex INTEGER NOT NULL,
        pageUrl TEXT NOT NULL,
        note TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future _createDownloadsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS downloads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mangaId TEXT NOT NULL,
        chapterId TEXT NOT NULL,
        chapterNumber REAL DEFAULT 0,
        chapterTitle TEXT,
        pageCount INTEGER DEFAULT 0,
        localDir TEXT,
        pageUrls TEXT,
        downloadedAt TEXT NOT NULL,
        UNIQUE(mangaId, chapterId)
      )
    ''');
  }

  // Method to mark a chapter as read
  Future<void> markChapterAsRead(
    String mangaId,
    String chapterId,
    double chapterNum,
  ) async {
    final db = await instance.database;

    // We use 'conflictAlgorithm: ConflictAlgorithm.replace'
    // so that if the chapter is already there, it just updates the number.
    await db.insert('reading_progress', {
      'mangaId': mangaId,
      'chapterId': chapterId,
      'chapterNumber': chapterNum,
      'lastReadAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // You can add a method here later to get the last read chapter
  Future<Map<String, dynamic>?> getLastReadChapter(String mangaId) async {
    final db = await instance.database;
    final result = await db.query(
      'reading_progress',
      where: 'mangaId = ?',
      whereArgs: [mangaId],
      orderBy: 'chapterNumber DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // Returns the set of chapter numbers already read for a given manga.
  Future<Set<double>> getReadChapterNumbers(String mangaId) async {
    final db = await instance.database;
    final rows = await db.query(
      'reading_progress',
      where: 'mangaId = ?',
      whereArgs: [mangaId],
    );
    return rows
        .map((r) => ((r['chapterNumber'] ?? 0) as num).toDouble())
        .toSet();
  }

  // Record a manga's metadata + latest read chapter (used to build History).
  // Upserts: preserves favorite/readLater state if already present.
  Future<void> saveMangaProgress({
    required String mangaId,
    required String title,
    String? coverUrl,
    String? sourceId,
    int totalChapters = 0,
    required double lastReadChapter,
    int lastReadPage = 0,
    int lastTrayTotalChapters = 0,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query(
      'manga',
      where: 'mangaId = ?',
      whereArgs: [mangaId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final row = existing.first;
      final newChapter = lastReadChapter;
      // A user-customized title/cover (set via Edit metadata) must survive
      // progress updates coming in from the source.
      final keepCustomTitle =
          (row['originalTitle'] as String?)?.isNotEmpty == true;
      final keepCustomCover =
          (row['originalCoverUrl'] as String?)?.isNotEmpty == true;

      await db.update(
        'manga',
        {
          'title': keepCustomTitle ? (row['title'] ?? title) : title,
          'coverUrl': keepCustomCover
              ? (row['coverUrl'])
              : (coverUrl ?? row['coverUrl']),
          'sourceId': sourceId ?? row['sourceId'],
          'totalChapters': totalChapters > 0
              ? totalChapters
              : (row['totalChapters'] as int? ?? 0),
          'lastReadChapter': newChapter,
          'lastReadPage': lastReadPage,
          'lastTrayTotalChapters': lastTrayTotalChapters > 0
              ? lastTrayTotalChapters
              : (row['lastTrayTotalChapters'] as int? ?? 0),
          'lastReadAt': now,
        },
        where: 'mangaId = ?',
        whereArgs: [mangaId],
      );
    } else {
      await db.insert('manga', {
        'mangaId': mangaId,
        'title': title,
        'coverUrl': coverUrl,
        'sourceId': sourceId,
        'totalChapters': totalChapters,
        'lastReadChapter': lastReadChapter,
        'lastReadPage': lastReadPage,
        'lastTrayTotalChapters': lastTrayTotalChapters,
        'lastReadAt': now,
        'isFavorite': 0,
        'isReadLater': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // Returns all manga that have reading history, most recently read first.
  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await instance.database;
    final result = await db.query(
      'manga',
      where: 'lastReadChapter >= 0',
      orderBy: 'lastReadAt DESC',
    );
    return result;
  }

  Future<Map<String, dynamic>?> getManga(String mangaId) async {
    final db = await instance.database;
    final result = await db.query(
      'manga',
      where: 'mangaId = ?',
      whereArgs: [mangaId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Applies a user's "Edit metadata" changes (custom title/cover or resets).
  // The first customization snapshots the source values (originalTitle/
  // originalCoverUrl) so "use default" can restore them later. Writing a value
  // that equals the original clears the override automatically.
  Future<void> saveMangaMetadata({
    required String mangaId,
    String? newTitle,
    String? newCoverUrl,
    bool resetTitle = false,
    bool resetCover = false,
  }) async {
    final db = await instance.database;
    final existing = await db.query(
      'manga',
      where: 'mangaId = ?',
      whereArgs: [mangaId],
      limit: 1,
    );
    if (existing.isEmpty) return;

    final row = existing.first;
    final updates = <String, dynamic>{};

    if (resetTitle) {
      updates['title'] = (row['originalTitle'] as String?) ?? row['title'];
      updates['originalTitle'] = null;
    } else if (newTitle != null && newTitle != row['title']) {
      if ((row['originalTitle'] as String?) == null) {
        updates['originalTitle'] = row['title'];
      }
      updates['title'] = newTitle;
    }

    if (resetCover) {
      updates['coverUrl'] =
          (row['originalCoverUrl'] as String?) ?? row['coverUrl'];
      updates['originalCoverUrl'] = null;
    } else if (newCoverUrl != null && newCoverUrl != row['coverUrl']) {
      if ((row['originalCoverUrl'] as String?) == null) {
        updates['originalCoverUrl'] = row['coverUrl'];
      }
      updates['coverUrl'] = newCoverUrl;
    }

    // If the edited value matches the original, drop the override entirely.
    if (row['originalTitle'] is String &&
        updates['title'] == row['originalTitle']) {
      updates['originalTitle'] = null;
    }
    if (row['originalCoverUrl'] is String &&
        updates['coverUrl'] == row['originalCoverUrl']) {
      updates['originalCoverUrl'] = null;
    }

    if (updates.isEmpty) return;
    await db.update(
      'manga',
      updates,
      where: 'mangaId = ?',
      whereArgs: [mangaId],
    );
  }

  // ---- Favorites ----

  // Whether the given manga is currently favorited.
  Future<bool> getIsFavorite(String mangaId) async {
    final db = await instance.database;
    final result = await db.query(
      'manga',
      where: 'mangaId = ? AND isFavorite = 1',
      whereArgs: [mangaId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Adds or removes a manga from favorites.
  Future<void> setFavorite({
    required String mangaId,
    required String title,
    String? coverUrl,
    String? sourceId,
    required bool isFavorite,
  }) async {
    final db = await instance.database;
    final existing = await db.query(
      'manga',
      where: 'mangaId = ?',
      whereArgs: [mangaId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update(
        'manga',
        {'isFavorite': isFavorite ? 1 : 0},
        where: 'mangaId = ?',
        whereArgs: [mangaId],
      );
    } else {
      await db.insert('manga', {
        'mangaId': mangaId,
        'title': title,
        'coverUrl': coverUrl,
        'sourceId': sourceId,
        'totalChapters': 0,
        'lastReadChapter': -1,
        'lastReadAt': DateTime.now().toIso8601String(),
        'isFavorite': isFavorite ? 1 : 0,
        'isReadLater': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // Re-binds a stored manga entry to a different source extension.
  Future<void> updateMangaSource({
    required String mangaId,
    required String sourceId,
  }) async {
    final db = await instance.database;
    await db.update(
      'manga',
      {'sourceId': sourceId},
      where: 'mangaId = ?',
      whereArgs: [mangaId],
    );
  }

  // Returns all favorited manga.
  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await instance.database;
    return db.query(
      'manga',
      where: 'isFavorite = 1',
      orderBy: 'title COLLATE NOCASE ASC',
    );
  }

  // Remove all reading history (leaves favorites intact).
  Future<void> clearHistory() async {
    final db = await instance.database;
    await db.delete('manga', where: 'lastReadChapter >= 0');
    await db.delete('reading_progress');
  }

  // Removes the given manga from history (manga row + per-chapter progress),
  // snapshotting the deleted rows so they can be restored via undo.
  Future<
    ({List<Map<String, dynamic>> manga, List<Map<String, dynamic>> progress})
  >
  deleteFromHistory(List<String> mangaIds) async {
    final db = await instance.database;
    final placeholders = List.filled(mangaIds.length, '?').join(',');
    final mangaRows = List<Map<String, dynamic>>.from(
      await db.query(
        'manga',
        where: 'mangaId IN ($placeholders)',
        whereArgs: mangaIds,
      ),
    );
    final progressRows = List<Map<String, dynamic>>.from(
      await db.query(
        'reading_progress',
        where: 'mangaId IN ($placeholders)',
        whereArgs: mangaIds,
      ),
    );
    await db.delete(
      'manga',
      where: 'mangaId IN ($placeholders)',
      whereArgs: mangaIds,
    );
    await db.delete(
      'reading_progress',
      where: 'mangaId IN ($placeholders)',
      whereArgs: mangaIds,
    );
    return (manga: mangaRows, progress: progressRows);
  }

  // Re-inserts rows captured by [deleteFromHistory] (used by the undo action).
  Future<void> restoreHistoryRows(
    List<Map<String, dynamic>> mangaRows,
    List<Map<String, dynamic>> progressRows,
  ) async {
    final db = await instance.database;
    for (final row in mangaRows) {
      await db.insert(
        'manga',
        Map<String, dynamic>.of(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final row in progressRows) {
      await db.insert(
        'reading_progress',
        Map<String, dynamic>.of(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  // Save tags for a manga (JSON array string).
  Future<void> saveMangaTags(String mangaId, List<String> tags) async {
    final db = await instance.database;
    final existing = await db.query(
      'manga',
      where: 'mangaId = ?',
      whereArgs: [mangaId],
      limit: 1,
    );
    final tagsJson = jsonEncode(tags);
    if (existing.isNotEmpty) {
      await db.update(
        'manga',
        {'tags': tagsJson},
        where: 'mangaId = ?',
        whereArgs: [mangaId],
      );
    } else {
      await db.insert('manga', {
        'mangaId': mangaId,
        'title': '',
        'tags': tagsJson,
        'lastReadAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // Get the top N most frequent tags across all history + favorites manga.
  Future<List<String>> getUserTopTags({int limit = 5}) async {
    final db = await instance.database;
    final rows = await db.query(
      'manga',
      columns: ['tags'],
      where: "tags IS NOT NULL AND tags != '[]'",
    );

    final freq = <String, int>{};
    for (final row in rows) {
      final raw = row['tags'] as String? ?? '[]';
      try {
        final List<dynamic> list = jsonDecode(raw);
        for (final tag in list) {
          final t = tag.toString();
          freq[t] = (freq[t] ?? 0) + 1;
        }
      } catch (_) {}
    }

    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  // Get all manga rows with non-empty tags (for suggestions).
  Future<List<Map<String, dynamic>>> getMangaWithTags() async {
    final db = await instance.database;
    return db.query('manga', where: "tags IS NOT NULL AND tags != '[]'");
  }

  // ---- Bookmarks ----

  Future<int> addBookmark({
    required String mangaId,
    required String chapterId,
    required String chapterTitle,
    required int pageIndex,
    required String pageUrl,
    String? note,
  }) async {
    final db = await instance.database;
    return db.insert('bookmarks', {
      'mangaId': mangaId,
      'chapterId': chapterId,
      'chapterTitle': chapterTitle,
      'pageIndex': pageIndex,
      'pageUrl': pageUrl,
      'note': note,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getBookmarks(String mangaId) async {
    final db = await instance.database;
    return db.query(
      'bookmarks',
      where: 'mangaId = ?',
      whereArgs: [mangaId],
      orderBy: 'createdAt DESC',
    );
  }

  Future<int?> findBookmarkId({
    required String mangaId,
    required String chapterId,
    required int pageIndex,
  }) async {
    final db = await instance.database;
    final rows = await db.query(
      'bookmarks',
      where: 'mangaId = ? AND chapterId = ? AND pageIndex = ?',
      whereArgs: [mangaId, chapterId, pageIndex],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<void> deleteBookmark(int id) async {
    final db = await instance.database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Downloads ----

  Future<void> addDownload({
    required String mangaId,
    required String chapterId,
    double chapterNumber = 0,
    String? chapterTitle,
    int pageCount = 0,
    String? localDir,
    String? pageUrls,
  }) async {
    final db = await instance.database;
    await db.insert('downloads', {
      'mangaId': mangaId,
      'chapterId': chapterId,
      'chapterNumber': chapterNumber,
      'chapterTitle': chapterTitle,
      'pageCount': pageCount,
      'localDir': localDir,
      'pageUrls': pageUrls,
      'downloadedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Lightweight upsert of manga identity metadata (title/cover/source) used by
  // the download cache and offline catalog so joins have data to display.
  // Preserves unrelated columns (favorites, progress, tags, ...).
  Future<void> upsertManga({
    required String mangaId,
    String title = 'Unknown',
    String? coverUrl,
    String? sourceId,
    int totalChapters = 0,
  }) async {
    final db = await instance.database;
    final existing = await db.query(
      'manga',
      columns: ['coverUrl', 'sourceId', 'totalChapters'],
      where: 'mangaId = ?',
      whereArgs: [mangaId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final row = existing.first;
      final keepCustomTitle =
          (row['originalTitle'] as String?)?.isNotEmpty == true;
      final keepCustomCover =
          (row['originalCoverUrl'] as String?)?.isNotEmpty == true;
      await db.update(
        'manga',
        {
          'title': keepCustomTitle ? (row['title'] ?? title) : title,
          'coverUrl': keepCustomCover
              ? (row['coverUrl'])
              : (coverUrl ?? row['coverUrl']),
          'sourceId': sourceId ?? row['sourceId'],
          'totalChapters': totalChapters > 0
              ? totalChapters
              : (row['totalChapters'] as int? ?? 0),
        },
        where: 'mangaId = ?',
        whereArgs: [mangaId],
      );
    } else {
      await db.insert('manga', {
        'mangaId': mangaId,
        'title': title,
        'coverUrl': coverUrl,
        'sourceId': sourceId,
        'totalChapters': totalChapters,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Map<String, dynamic>>> getDownloads(String mangaId) async {
    final db = await instance.database;
    return db.query(
      'downloads',
      where: 'mangaId = ?',
      whereArgs: [mangaId],
      orderBy: 'downloadedAt DESC',
    );
  }

  Future<Map<String, dynamic>?> getDownload(
    String mangaId,
    String chapterId,
  ) async {
    final db = await instance.database;
    final rows = await db.query(
      'downloads',
      where: 'mangaId = ? AND chapterId = ?',
      whereArgs: [mangaId, chapterId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<bool> isChapterDownloaded(String mangaId, String chapterId) async {
    return (await getDownload(mangaId, chapterId)) != null;
  }

  Future<void> removeDownload(String mangaId, String chapterId) async {
    final db = await instance.database;
    await db.delete(
      'downloads',
      where: 'mangaId = ? AND chapterId = ?',
      whereArgs: [mangaId, chapterId],
    );
  }

  /// All downloaded chapters across every manga, most recently downloaded
  /// first, with the owning manga's title/cover/source joined in.
  Future<List<Map<String, dynamic>>> getAllDownloads() async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT d.*, m.title AS mangaTitle, m.coverUrl AS mangaCover,
             m.sourceId AS mangaSource
      FROM downloads d
      LEFT JOIN manga m ON m.mangaId = d.mangaId
      ORDER BY d.downloadedAt DESC
    ''');
  }

  /// All bookmarks across every manga, most recently bookmarked first, with
  /// the owning manga's title/cover/source joined in.
  Future<List<Map<String, dynamic>>> getAllBookmarks() async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT b.*, m.title AS mangaTitle, m.coverUrl AS mangaCover,
             m.sourceId AS mangaSource
      FROM bookmarks b
      LEFT JOIN manga m ON m.mangaId = b.mangaId
      ORDER BY b.createdAt DESC
    ''');
  }

  // Manga ids that have at least one chapter downloaded.
  Future<Set<String>> getMangaIdsWithDownloads() async {
    final db = await instance.database;
    final rows = await db.rawQuery('SELECT DISTINCT mangaId FROM downloads');
    return rows
        .map((r) => (r['mangaId'] as String? ?? ''))
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  // Chapter ids currently downloaded for a given manga.
  Future<Set<String>> getDownloadedChapterIds(String mangaId) async {
    final db = await instance.database;
    final rows = await db.query(
      'downloads',
      columns: ['chapterId'],
      where: 'mangaId = ?',
      whereArgs: [mangaId],
    );
    return rows
        .map((r) => (r['chapterId'] as String? ?? ''))
        .where((s) => s.isNotEmpty)
        .toSet();
  }
}
