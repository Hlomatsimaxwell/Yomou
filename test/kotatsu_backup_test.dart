import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/backup/backup_restore.dart';
import 'package:yomou/core/backup/kotatsu_backup.dart';

/// Kotatsu `.bk.zip` support: a zip of one JSON array per table, the same
/// canonical urls Tachiyomi files carry, and the same import result shape so
/// the whole Tachiyomi pipeline (scan, apply, results screen) is reused.
void main() {
  Uint8List bytes(String source) => Uint8List.fromList(utf8.encode(source));

  Uint8List kotatsuZip(Map<String, Object> files) {
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(
        ArchiveFile.bytes(entry.key, utf8.encode(jsonEncode(entry.value))),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// A small but shape-accurate backup spanning sources Yomou carries and
  /// ones it does not.
  Uint8List sampleBackup() {
    return kotatsuZip({
      'index': [
        {'app_id': 'io.github.kotatsuapp.kotatsu', 'app_version': 2045, 'created_at': 1000}
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
            'public_url': 'https://asurascans.com/comics/nano-machine-9a7a1ac5',
            'cover_url': 'https://asurascans.com/covers/nano.jpg',
            'source': 'ASURASCANS',
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
            'title': 'Bowblade: The Descendants of Bowblade',
            'url': '287f20cd-df67-4f09-bca8-112431d87fda',
            'public_url':
                'https://mangadex.org/title/287f20cd-df67-4f09-bca8-112431d87fda',
            'cover_url': 'https://mangadex.org/covers/287f20cd.jpg',
            'source': 'MANGADEX',
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
            'title': 'Chronicles Of The Demon Faction',
            'url': '02-chronicles-of-the-demon-faction',
            'public_url': 'https://comick.io/comic/02-chronicles-of-the-demon-faction',
            'cover_url': '',
            'source': 'COMICK_FUN',
            'tags': <Object>[],
          },
        },
        {
          'manga_id': 4,
          'category_id': 0,
          'sort_key': 3,
          'pinned': false,
          'created_at': 4000,
          'manga': {
            'id': 4,
            'title': 'The Masters Are Subscribing To Me',
            'url': '/read-manga/the_masters_are_subscribing_to_me/',
            'public_url':
                'https://www.mangago.me/read-manga/the_masters_are_subscribing_to_me/',
            'cover_url': '',
            'source': 'MANGAGO',
            'tags': <Object>[],
          },
        },
        {
          'manga_id': 5,
          'category_id': 0,
          'sort_key': 4,
          'pinned': false,
          'created_at': 5000,
          'manga': {
            'id': 5,
            'title': 'Absolute Sword Sense',
            'url': '/manga/absolute-sword-sense-okxdz/',
            'public_url': 'https://www.mgeko.cc/manga/absolute-sword-sense-okxdz/',
            'cover_url': '',
            'source': 'MANGAGEKO',
            'tags': <Object>[],
          },
        },
        {
          'manga_id': 6,
          'category_id': 0,
          'sort_key': 5,
          'pinned': false,
          'created_at': 6000,
          'manga': {
            'id': 6,
            'title': 'The Ultimate of All Ages',
            'url': '/manga/the-ultimate-of-all-ages/',
            'public_url': 'https://s2read.com/manga/the-ultimate-of-all-ages/',
            'cover_url': '',
            'source': 'S2MANGA',
            'tags': <Object>[],
          },
        },
        {
          'manga_id': 8,
          'category_id': 0,
          'sort_key': 6,
          'pinned': false,
          'created_at': 7000,
          'manga': {
            'id': 8,
            'title': 'Real',
            'url': '/manga/reall.ro4y',
            'public_url': 'https://mangafire.to/manga/reall.ro4y',
            'cover_url': '',
            'source': 'MANGAFIRE_EN',
            'tags': <Object>[],
          },
        },
      ],
      'history': [
        {
          'manga_id': 1,
          'created_at': 1000,
          'updated_at': 2000,
          'chapter_id': 99,
          'page': 3,
          'scroll': 0.5,
          'percent': 0.9,
          'chapters': 120,
        },
        {
          'manga_id': 7,
          'created_at': 1500,
          'updated_at': 2500,
          'chapter_id': 42,
          'page': 1,
          'scroll': 0.0,
          'percent': 1.0,
          'chapters': 30,
          'manga': {
            'id': 7,
            'title': 'Heavenly Demon Reborn!',
            'url': '/series/eternally-regressing-knight',
            'public_url': 'https://weebcentral.com/series/eternally-regressing-knight',
            'cover_url': '',
            'source': 'WEEBCENTRAL',
            'tags': <Object>[],
          },
        },
      ],
      'bookmarks': [
        {
          'manga': {
            'id': 1,
            'title': 'Nano Machine',
            'url': '/comics/nano-machine-963c76c5',
            'source': 'ASURASCANS',
            'tags': <Object>[],
          },
          'tags': <Object>[],
          'bookmarks': [
            {
              'manga_id': 1,
              'page_id': 500,
              'chapter_id': 99,
              'page': 7,
              'scroll': 0.0,
              'image_url': 'https://asurascans.com/pages/nano-007.jpg',
              'created_at': 2000,
              'percent': 0.2,
            }
          ],
        }
      ],
      'sources': <Object>[],
    });
  }

  group('detect', () {
    test('a zip is detected as Kotatsu', () {
      expect(
        BackupRestore.detect(kotatsuZip({'index': <Object>[]})),
        BackupFormat.kotatsu,
      );
    });

    test('zip magic without the local-header byte is not Kotatsu', () {
      expect(BackupRestore.detect(bytes('PK-not-a-real-zip')), BackupFormat.tachiyomi);
    });

    test('gzip is still Tachiyomi, not Kotatsu', () {
      expect(BackupRestore.detect(bytes('not gzip at all------------')), BackupFormat.tachiyomi);
    });
  });

  group('import', () {
    test('maps favourites from carried sources straight to Yomou ids', () {
      final result = KotatsuBackupCodec.import(sampleBackup());

      final byId = {for (final m in result.mangas) m.mangaId: m};
      // The five carried favourites plus the history-only WeebCentral title.
      expect(byId, hasLength(6));
      expect(byId['nano-machine-9a7a1ac5']?.sourceId, 'asurascans');
      expect(byId['287f20cd-df67-4f09-bca8-112431d87fda']?.sourceId,
          'mangadex');
      expect(byId['the_masters_are_subscribing_to_me']?.sourceId, 'mangago');
      expect(byId['manga/absolute-sword-sense-okxdz']?.sourceId, 'mgeko');
      // Mangafire ids carry the site's dotted catalog slug.
      expect(byId['reall.ro4y']?.sourceId, 'mangafire-en');
      // The history-only title is a non-favourite; everything else came out
      // of the favourites file.
      final weeb = byId['eternally-regressing-knight']!;
      expect(weeb.isFavorite, isFalse);
      for (final m
          in result.mangas.where((m) => m.mangaId != weeb.mangaId)) {
        expect(m.isFavorite, isTrue, reason: '${m.title} should be a favourite');
      }
      // Sources Yomou doesn't carry are held back for the title scan. ComicK
      // used to be carried; now that the source is gone, its entry lands here
      // instead of importing as an unreadable title.
      expect(result.missingMangas, hasLength(2));
      final missing = {
        for (final m in result.missingMangas) m.sourceName: m.title,
      };
      expect(missing['S2MANGA'], 'The Ultimate of All Ages');
      expect(missing['COMICK_FUN'], 'Chronicles Of The Demon Faction');
    });

    test('history carries the last-read timestamp onto favourites', () {
      final result = KotatsuBackupCodec.import(sampleBackup());
      final nano = result.mangas.firstWhere(
        (m) => m.mangaId == 'nano-machine-9a7a1ac5',
      );
      expect(nano.lastReadAt, DateTime.fromMillisecondsSinceEpoch(2000));
      // Kotatsu backups carry no chapter numbers, so progress is seeded at
      // zero; the timestamp keeps the title placed in History.
      expect(nano.lastReadChapter, 0);
    });

    test('history-only titles import as non-favourites', () {
      final result = KotatsuBackupCodec.import(sampleBackup());
      final weeb = result.mangas.firstWhere(
        (m) => m.mangaId == 'eternally-regressing-knight',
      );
      expect(weeb.isFavorite, isFalse);
      expect(weeb.lastReadAt, DateTime.fromMillisecondsSinceEpoch(2500));
    });

    test('bookmarks follow their manga', () {
      final result = KotatsuBackupCodec.import(sampleBackup());
      final nano = result.mangas.firstWhere(
        (m) => m.bookmarks.isNotEmpty,
      );
      expect(nano.mangaId, 'nano-machine-9a7a1ac5');
      expect(nano.bookmarks, hasLength(1));
      expect(nano.bookmarks.single['pageUrl'],
          'https://asurascans.com/pages/nano-007.jpg');
    });

    test('a broken zip throws FormatException', () {
      expect(
        () => KotatsuBackupCodec.import(bytes('this is not a zip at all')),
        throwsFormatException,
      );
    });

    test('a zip without Kotatsu payloads imports nothing', () {
      final result = KotatsuBackupCodec.import(kotatsuZip({'hello': [1]}));
      expect(result.isEmpty, isTrue);
    });
  });

  group('export', () {
    Map<String, dynamic> row({
      required String mangaId,
      required String sourceId,
      required String title,
      Object? lastReadAt,
      double lastReadChapter = -1,
      int totalChapters = 0,
      bool favorite = true,
    }) {
      return {
        'mangaId': mangaId,
        'title': title,
        'coverUrl': 'https://cover/$mangaId.jpg',
        'sourceId': sourceId,
        'totalChapters': totalChapters,
        'lastReadChapter': lastReadChapter,
        'lastReadPage': 0,
        'lastTrayTotalChapters': 0,
        'lastReadAt': lastReadAt,
        'isFavorite': favorite ? 1 : 0,
        'isReadLater': 0,
        'tags': '[]',
      };
    }

    test('writes the twelve Kotatsu files', () {
      final result = KotatsuBackupCodec.export(
        favorites: [
          row(
            mangaId: 'nano-machine-9a7a1ac5',
            sourceId: 'asurascans',
            title: 'Nano Machine',
            lastReadAt: '2026-10-08T17:44:42.000',
          ),
        ],
        bookmarks: const [],
        readingProgress: const [],
      );
      expect(result.exported, 1);
      expect(result.skipped, 0);

      final archive = ZipDecoder().decodeBytes(result.bytes);
      final names =
          archive.files.map((f) => f.name).toSet();
      expect(
        names,
        containsAll([
          'index',
          'identity',
          'categories',
          'favourites',
          'history',
          'bookmarks',
          'settings',
          'sources',
          'statistics',
          'reader_grid',
          'saved_filters',
          'scrobbling',
        ]),
      );
      // kotatsu-redo's SourceBackup requires added_in; an export without it is
      // rejected mid-restore with "Field 'added_in' is required ...".
      final sources = jsonDecode(
        utf8.decode(archive.files
                .firstWhere((f) => f.name == 'sources')
                .readBytes() ??
            Uint8List(0)),
      ) as List;
      expect(sources, hasLength(1));
      expect(sources.single['source'], 'ASURASCANS');
      expect(sources.single['added_in'], 1010);
      // redo reads reader_grid as JSONArray(...).getJSONObject(0); an empty
      // array fails restore with "Index 0 out of range [0..0)".
      final readerGrid = jsonDecode(
        utf8.decode(archive.files
                .firstWhere((f) => f.name == 'reader_grid')
                .readBytes() ??
            Uint8List(0)),
      ) as List;
      expect(readerGrid, hasLength(1));
      expect(readerGrid.single, isA<Map<String, dynamic>>());
    });

    test('a source Kotatsu does not carry is skipped', () {
      final result = KotatsuBackupCodec.export(
        favorites: [
          row(mangaId: '1234', sourceId: 'manhwa18', title: 'Only Here'),
        ],
        bookmarks: const [],
        readingProgress: const [],
      );
      expect(result.exported, 0);
      expect(result.skipped, 1);
    });

    test('exported favourites carry Kotatsu urls and enum sources', () {
      final result = KotatsuBackupCodec.export(
        favorites: [
          row(
            mangaId: 'nano-machine-9a7a1ac5',
            sourceId: 'asurascans',
            title: 'Nano Machine',
            lastReadAt: '2026-10-08T17:44:42.000',
          ),
          row(
            mangaId: '287f20cd-df67-4f09-bca8-112431d87fda',
            sourceId: 'mangadex',
            title: 'Bowblade',
          ),
        ],
        bookmarks: const [],
        readingProgress: const [],
      );

      final archive = ZipDecoder().decodeBytes(result.bytes);
      final favouriteFile = archive.files.firstWhere((f) => f.name == 'favourites');
      final favourites = jsonDecode(
        utf8.decode(favouriteFile.readBytes() ?? Uint8List(0)),
      ) as List;

      expect(favourites, hasLength(2));
      final asura = (favourites[0] as Map)['manga'] as Map;
      expect(asura['source'], 'ASURASCANS');
      expect(asura['url'], '/comics/nano-machine-9a7a1ac5');
      expect(asura['public_url'],
          'https://asurascans.com/comics/nano-machine-9a7a1ac5');
      final dex = (favourites[1] as Map)['manga'] as Map;
      expect(dex['source'], 'MANGADEX');
      expect(dex['url'], '/title/287f20cd-df67-4f09-bca8-112431d87fda');
    });

    test('bookmarks write an integer scroll and export urls mirror Kotatsu', () {
      final result = KotatsuBackupCodec.export(
        favorites: [
          row(
            mangaId: 'nano-machine-9a7a1ac5',
            sourceId: 'asurascans',
            title: 'Nano Machine',
          ),
          row(
            mangaId: '01JGBZ1ETAKPZ8A73ZT5MY70SW',
            sourceId: 'weebcentral',
            title: 'Enrolling in the Transcendent Academy',
          ),
          row(
            mangaId: 'dkw-one-piece',
            sourceId: 'mangafire-es',
            title: 'One Piece',
          ),
        ],
        bookmarks: [
          {
            'mangaId': 'nano-machine-9a7a1ac5',
            'chapterId': 'api/series/nano-machine-9a7a1ac5/chapters/121',
            'pageIndex': 3,
            'pageUrl': 'https://asurascans.com/pages/nano-003.jpg',
            'createdAt': '2026-10-08T17:44:42.000',
          }
        ],
        readingProgress: const [],
      );

      final archive = ZipDecoder().decodeBytes(result.bytes);

      final bookmarks = jsonDecode(
        utf8.decode(archive.files
                .firstWhere((f) => f.name == 'bookmarks')
                .readBytes() ??
            Uint8List(0)),
      ) as List;
      final entry = (bookmarks.single as Map)['bookmarks'];
      expect((entry as List).single['scroll'], 0);
      // Kotatsu's parser rejects the float form, so this must stay an int.
      expect(jsonEncode(entry.single).contains('"scroll":0.0'), isFalse);

      final favourites = jsonDecode(
        utf8.decode(archive.files
                .firstWhere((f) => f.name == 'favourites')
                .readBytes() ??
            Uint8List(0)),
      ) as List;
      final byTitle = {
        for (final f in favourites) (f as Map)['manga']['title'] as String: f['manga'],
      };
      // WeebCentral is stored bare -- the parser builds /series/ itself.
      expect(byTitle['Enrolling in the Transcendent Academy']!['url'],
          '01JGBZ1ETAKPZ8A73ZT5MY70SW');
      // The Spanish mangafire mirror uses the /title/ form.
      expect(byTitle['One Piece']!['url'], '/title/dkw-one-piece');
    });

    test('reading progress becomes a history entry', () {
      final result = KotatsuBackupCodec.export(
        favorites: [
          row(
            mangaId: 'nano-machine-9a7a1ac5',
            sourceId: 'asurascans',
            title: 'Nano Machine',
            lastReadAt: '2026-10-08T17:44:42.000',
            lastReadChapter: 12,
            totalChapters: 120,
          ),
        ],
        bookmarks: const [],
        readingProgress: [
          {
            'mangaId': 'nano-machine-9a7a1ac5',
            'chapterId': 'api/series/nano-machine-9a7a1ac5/chapters/121',
            'chapterNumber': 12.0,
            'lastReadAt': '2026-10-08T17:44:42.000',
          }
        ],
      );

      final archive = ZipDecoder().decodeBytes(result.bytes);
      final historyFile = archive.files.firstWhere((f) => f.name == 'history');
      final history = jsonDecode(
        utf8.decode(historyFile.readBytes() ?? Uint8List(0)),
      ) as List;
      expect(history, hasLength(1));
      final entry = history.single as Map;
      expect(entry['percent'], 1.0);
      expect(entry['chapters'], 120);
      expect(entry['manga_id'], (jsonDecode(
                utf8.decode(
                  archive.files
                      .firstWhere((f) => f.name == 'favourites')
                      .readBytes() ??
                      Uint8List(0),
                ),
              ) as List)
          .first['manga_id']);
    });

    test('an export round-trips back through import', () {
      final result = KotatsuBackupCodec.export(
        favorites: [
          row(
            mangaId: 'nano-machine-9a7a1ac5',
            sourceId: 'asurascans',
            title: 'Nano Machine',
            lastReadAt: '2026-10-08T17:44:42.000',
            lastReadChapter: 12,
          ),
          row(
            mangaId: 'the_masters_are_subscribing_to_me',
            sourceId: 'mangago',
            title: 'The Masters Are Subscribing To Me',
          ),
        ],
        bookmarks: const [],
        readingProgress: const [],
      );

      final back = KotatsuBackupCodec.import(result.bytes);
      expect(back.mangas, hasLength(2));
      expect(back.isEmpty, isFalse);
      final nano = back.mangas.firstWhere(
        (m) => m.mangaId == 'nano-machine-9a7a1ac5',
      );
      expect(nano.sourceId, 'asurascans');
      expect(nano.isFavorite, isTrue);
      expect(nano.lastReadAt, isNotNull);
      expect(nano.lastReadChapter, 0);
      // A favourite without reading history stays out of History.
      final masters = back.mangas.firstWhere(
        (m) => m.mangaId == 'the_masters_are_subscribing_to_me',
      );
      expect(masters.lastReadAt, isNull);
      expect(masters.lastReadChapter, -1);
    });
  });
}