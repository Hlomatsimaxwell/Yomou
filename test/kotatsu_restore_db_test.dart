import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yomou/core/backup/backup_restore.dart';
import 'package:yomou/core/database/database_helper.dart';

/// Restoring a Kotatsu `.bk.zip` end to end: detect the zip, parse it through
/// the Kotatsu codec and apply the result to a real (ffi) database.
///
/// The codec-level url/source mapping is covered in kotatsu_backup_test.dart;
/// this pins that favorites, history and bookmarks actually land in the exact
/// tables the Library and History tabs read from.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final testMangaIds = [
    'nano-machine-9a7a1ac5',
    '287f20cd-df67-4f09-bca8-112431d87fda',
    'eternally-regressing-knight',
  ];

  Future<void> clearTestRows(DatabaseHelper db) async {
    final raw = await db.database;
    for (final table in ['manga', 'reading_progress', 'bookmarks']) {
      await raw.delete(
        table,
        where: 'mangaId IN (?, ?, ?)',
        whereArgs: testMangaIds,
      );
    }
  }

  Uint8List kotatsuZip() {
    final files = <String, Object>{
      'index': [
        {
          'app_id': 'io.github.kotatsuapp.kotatsu',
          'app_version': 2045,
          'created_at': 1000,
        }
      ],
      'favourites': [
        {
          'manga_id': 1,
          'category_id': 0,
          'sort_key': 0,
          'pinned': false,
          'created_at': 1000,
          'manga': {
            'id': 1,
            'title': 'Nano Machine',
            'url': '/comics/nano-machine-9a7a1ac5',
            'source': 'ASURASCANS',
            'cover_url': 'https://asurascans.com/covers/nano.jpg',
            'tags': <Object>[],
          },
        },
        {
          'manga_id': 2,
          'category_id': 0,
          'sort_key': 1,
          'pinned': false,
          'created_at': 2000,
          'manga': {
            'id': 2,
            'title': 'Bowblade',
            'url': '287f20cd-df67-4f09-bca8-112431d87fda',
            'source': 'MANGADEX',
            'cover_url': '',
            'tags': <Object>[],
          },
        },
        {
          'manga_id': 3,
          'category_id': 0,
          'sort_key': 2,
          'pinned': false,
          'created_at': 3000,
          'manga': {
            'id': 3,
            'title': 'The Ultimate of All Ages',
            'url': '/manga/the-ultimate-of-all-ages/',
            'source': 'S2MANGA',
            'cover_url': '',
            'tags': <Object>[],
          },
        },
      ],
      'history': [
        {
          'manga_id': 2,
          'created_at': 1000,
          'updated_at': 2500,
          'chapter_id': 88,
          'page': 2,
          'scroll': 0.0,
          'percent': 0.5,
          'chapters': 40,
        },
        {
          'manga_id': 4,
          'created_at': 1500,
          'updated_at': 2600,
          'chapter_id': 3,
          'page': 1,
          'scroll': 0.0,
          'percent': 1.0,
          'chapters': 12,
          'manga': {
            'id': 4,
            'title': 'Eternally Regressing Knight',
            'url': '/series/eternally-regressing-knight',
            'source': 'WEEBCENTRAL',
            'cover_url': '',
            'tags': <Object>[],
          },
        },
      ],
      'bookmarks': [
        {
          'manga': {
            'id': 1,
            'title': 'Nano Machine',
            'url': '/comics/nano-machine-9a7a1ac5',
            'source': 'ASURASCANS',
            'tags': <Object>[],
          },
          'tags': <Object>[],
          'bookmarks': [
            {
              'manga_id': 1,
              'page_id': 42,
              'chapter_id': 10,
              'page': 3,
              'scroll': 0.0,
              'image_url': 'https://asurascans.com/pages/nano-003.jpg',
              'created_at': 2000,
              'percent': 0.1,
            }
          ],
        }
      ],
      'sources': <Object>[],
    };

    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(
        ArchiveFile.bytes(entry.key, utf8.encode(jsonEncode(entry.value))),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  test('a Kotatsu zip restores favorites, history and bookmarks', () async {
    final db = DatabaseHelper.instance;
    await clearTestRows(db);

    final result = await BackupRestore.restore(kotatsuZip());

    expect(result.format, BackupFormat.kotatsu);
    final imported = result.tachiyomi!;
    // The two direct favourites plus the history-only WeebCentral title.
    expect(imported.imported, 3);
    // The S2MANGA title is reported for the title scan, which the settings
    // screen wires in (absent here, so it stays out of the database).
    expect(imported.missingMangas, hasLength(1));

    final favorites = await db.getFavorites();
    expect(
      favorites.map((r) => r['mangaId']).toSet(),
      {
        'nano-machine-9a7a1ac5',
        '287f20cd-df67-4f09-bca8-112431d87fda',
      },
    );

    final history = await db.getHistory();
    expect(
      history.map((r) => r['mangaId']).toSet(),
      {
        '287f20cd-df67-4f09-bca8-112431d87fda',
        'eternally-regressing-knight',
      },
    );
    final dex = history.firstWhere(
      (r) => r['mangaId'] == '287f20cd-df67-4f09-bca8-112431d87fda',
    );
    expect(
      DateTime.parse(dex['lastReadAt'] as String),
      DateTime.fromMillisecondsSinceEpoch(2500),
    );
    // Kotatsu has no chapter numbers; a read title is seeded at chapter 0 and
    // placed by its real timestamp.
    expect(dex['lastReadChapter'], 0);

    final bookmarks = await db.getAllBookmarks();
    expect(bookmarks, hasLength(1));
    expect(bookmarks.single['mangaId'], 'nano-machine-9a7a1ac5');
    expect(
      bookmarks.single['pageUrl'],
      'https://asurascans.com/pages/nano-003.jpg',
    );

    await clearTestRows(db);
  });
}