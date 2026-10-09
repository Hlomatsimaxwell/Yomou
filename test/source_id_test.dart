import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/providers/sources_provider.dart';

/// Eight listing parsers wrote the manga's own slug into `sourceId` instead of
/// the source's id, because a local `id` holding the slug shadowed the source's
/// `id` getter. Every title they listed then reported itself as coming from a
/// source that was not installed, and nothing about that was visible: the
/// resolver simply returned null, exactly as it does for a real unknown id.
///
/// These pin the three things that make that class of mistake impossible to
/// repeat unnoticed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Manga manga({required String id, required String sourceId}) =>
      Manga(id: id, title: 't', coverUrl: '', sourceId: sourceId);

  group('the sourceId guard', () {
    test('rejects a slug, which is how eight parsers got this wrong', () {
      // The two shapes the broken parsers actually produced.
      expect(
        () => manga(id: 'manga/1861/slug', sourceId: 'manga/1861/slug'),
        throwsArgumentError,
      );
      expect(
        () => manga(
          id: 'https://manhwa18.com/manga/secret-class',
          sourceId: 'https://manhwa18.com/manga/secret-class',
        ),
        throwsArgumentError,
      );
    });

    test('accepts every id shape the app actually uses', () {
      // Including the ones that are not plain words: variants, and the
      // mangaball family's generated ids.
      for (final id in [
        'mangadex',
        'mangadex-es',
        'mangadex-ptbr',
        'mangafire-ptbr',
        'mangaball-en',
        'mangaball-ptbr',
        'mock',
      ]) {
        expect(
          () => manga(id: 'x', sourceId: id),
          returnsNormally,
          reason: '$id is a real source id and must be accepted',
        );
      }
    });

    test('an empty sourceId is allowed, and means what it says', () {
      // Not every caller knows the source -- the mock source and rows written
      // before the field existed both land here -- so this is not an error.
      expect(() => manga(id: 'x', sourceId: ''), returnsNormally);
    });

    test('every registered source id passes the guard', () {
      // The guard rejects anything holding a '/'. If a source were ever
      // registered under an id holding one, the guard would refuse the source's
      // own listings, so this is checked rather than assumed.
      for (final name in [
        'MangaDex',
        'MangaDex Español',
        'MangaDex Portuguese BR',
        'WeebCentral',
        'MangaKatana',
        'MangaTown',
        'Manganato',
        'Arenascan',
        'Asura Scans',
        'ComicK',
        'Mgeko',
        'Like Manga',
        'Toonily',
        'Reaper Scans',
        'ManhuaPlus',
        'MangaPill',
        'Manhwa18',
        'Flame Scans',
        'Komga',
        'MangaBat',
        'MangaFire English',
        'Mock Source',
      ]) {
        final source = getSourceByName(name);
        expect(
          () => manga(id: 'x', sourceId: source.id),
          returnsNormally,
          reason: '${source.id} must be usable as a sourceId',
        );
      }
    });
  });

  group('rows written by the broken parsers', () {
    test('a cached slug is dropped rather than passed on', () {
      // Manga.fromJson reads rows the cache wrote, which is where the poisoned
      // values are still sitting. Passing one through would keep reporting a
      // source that cannot exist; dropping it says "no known source" instead.
      final row = Manga.fromJson({
        'id': 'manga/1861/slug',
        'title': 't',
        'coverUrl': '',
        'sourceId': 'manga/1861/slug',
      });
      expect(row.sourceId, isEmpty);
      expect(row.id, 'manga/1861/slug', reason: 'the manga keeps its own id');
    });

    test('a cached real source id is kept', () {
      final row = Manga.fromJson({
        'id': 'x',
        'title': 't',
        'coverUrl': '',
        'sourceId': 'mangapill',
      });
      expect(row.sourceId, 'mangapill');
    });

    test('a row with no sourceId at all still decodes', () {
      final row = Manga.fromJson({'id': 'x', 'title': 't', 'coverUrl': ''});
      expect(row.sourceId, isEmpty);
    });
  });

  group('the repair migration', () {
    // In memory, not the app's own database file: this test seeds deliberately
    // broken rows, and the file holds the real library and its reading
    // positions. The schema is copied from `database_helper.dart` so the
    // statements below run against the columns they will meet in the wild.
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE manga (
          mangaId TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          coverUrl TEXT,
          sourceId TEXT,
          totalChapters INTEGER DEFAULT 0,
          lastReadChapter REAL DEFAULT -1,
          lastReadPage INTEGER DEFAULT 0,
          isFavorite INTEGER DEFAULT 0,
          isReadLater INTEGER DEFAULT 0,
          tags TEXT DEFAULT '[]'
        )
      ''');
      await db.execute('''
        CREATE TABLE source_cache (
          key TEXT PRIMARY KEY,
          json TEXT NOT NULL,
          fetchedAt TEXT NOT NULL
        )
      ''');
    });

    tearDown(() async => db.close());

    Future<void> seedManga(String mangaId, String sourceId) async {
      await db.insert('manga', {
        'mangaId': mangaId,
        'title': 't',
        'coverUrl': '',
        'sourceId': sourceId,
      });
    }

    Future<void> seedCache(String key, String json) async {
      await db.insert('source_cache', {
        'key': key,
        'json': json,
        'fetchedAt': '2026-01-01T00:00:00.000',
      });
    }

    /// The three statements the migration runs, copied from
    /// `DatabaseHelper._repairShuffledSourceIds`. Reaching them through the
    /// database rather than by calling the private method keeps the test
    /// asserting the SQL a user upgrading actually gets.
    Future<void> runRepair() async {
      await db.rawUpdate('''
        UPDATE manga
        SET sourceId = (
          SELECT substr(sc.key, 1, instr(sc.key, '/') - 1)
          FROM source_cache sc
          WHERE instr(sc.json, '"id":"' || manga.mangaId || '"') > 0
          LIMIT 1
        )
        WHERE sourceId = mangaId
          AND sourceId NOT LIKE 'https://manhwa18.com/%'
          AND EXISTS (
            SELECT 1 FROM source_cache sc
            WHERE instr(sc.json, '"id":"' || manga.mangaId || '"') > 0
          )
      ''');
      await db.rawUpdate(
        "UPDATE manga SET sourceId = 'manhwa18' "
        "WHERE sourceId LIKE 'https://manhwa18.com/%'",
      );
      await db.rawUpdate(
        "UPDATE manga SET sourceId = '' "
        "WHERE sourceId = mangaId AND TRIM(sourceId) <> ''",
      );
    }

    Future<String?> sourceIdOf(String mangaId) async {
      final rows = await db.query(
        'manga',
        columns: ['sourceId'],
        where: 'mangaId = ?',
        whereArgs: [mangaId],
      );
      return rows.isEmpty ? null : rows.first['sourceId'] as String?;
    }

    test('a poisoned row is recovered from the cache key', () async {
      // What MangaBat wrote: the slug in both columns, with the list cache
      // holding the same id under the source that produced it.
      await seedManga('berserk', 'berserk');
      await seedCache('mangabat/list/popular//1', '[{"id":"berserk"}]');

      await runRepair();

      expect(await sourceIdOf('berserk'), 'mangabat');
    });

    test('a slug holding LIKE wildcards is matched literally', () async {
      // `_` and `%` are wildcards to LIKE and ordinary characters to `instr`.
      // A repair written with LIKE would match a different title's row here and
      // give this one the wrong source.
      await seedManga('the_100%_strongest', 'the_100%_strongest');
      await seedManga('theX100Zstrongest', 'theX100Zstrongest');
      await seedCache(
        'mangapill/list/popular//1',
        '[{"id":"the_100%_strongest"}]',
      );

      await runRepair();

      expect(await sourceIdOf('the_100%_strongest'), 'mangapill');
      expect(
        await sourceIdOf('theX100Zstrongest'),
        isEmpty,
        reason: 'the other row matched nothing and must not inherit a source',
      );
    });

    test('a manhwa18 row is identified by its host, with no cache', () async {
      await seedManga(
        'https://manhwa18.com/manga/secret-class',
        'https://manhwa18.com/manga/secret-class',
      );

      await runRepair();

      expect(
        await sourceIdOf('https://manhwa18.com/manga/secret-class'),
        'manhwa18',
      );
    });

    test('an unresolvable row is cleared, not left wrong', () async {
      // No cache, no recognisable host. An empty id says "no known source",
      // which is true; the slug said "this source is manga/1861/slug", which
      // was not. The right value is written again when details are fetched.
      await seedManga('manga/9999/unknown', 'manga/9999/unknown');

      await runRepair();

      expect(await sourceIdOf('manga/9999/unknown'), isEmpty);
    });

    test('a healthy row is left alone', () async {
      await seedManga('one-piece', 'mangadex');

      await runRepair();

      expect(await sourceIdOf('one-piece'), 'mangadex');
    });

    test('a row whose id merely contains its source is left alone', () async {
      // Not the same as being poisoned: the columns differ, so this is a real
      // row and the repair must not touch it.
      await seedManga('mangadex-specials', 'mangadex');

      await runRepair();

      expect(await sourceIdOf('mangadex-specials'), 'mangadex');
    });

    test('repairing the id costs nobody their library', () async {
      // The point of the repair rather than a rebuild: these titles are
      // favourited and part-read, and only the source column was wrong. If this
      // ever needed a delete or a re-import, every reader would lose their
      // place.
      await db.insert('manga', {
        'mangaId': 'manga/1861/slug',
        'title': 't',
        'coverUrl': '',
        'sourceId': 'manga/1861/slug',
        'isFavorite': 1,
        'lastReadChapter': 42.0,
        'lastReadPage': 7,
      });
      await seedCache(
        'mangapill/list/popular//1',
        '[{"id":"manga/1861/slug"}]',
      );

      await runRepair();

      final rows = await db.query('manga');
      expect(rows, hasLength(1), reason: 'the row itself must survive');
      expect(rows.first['isFavorite'], 1);
      expect(rows.first['lastReadChapter'], 42.0);
      expect(rows.first['lastReadPage'], 7);
      expect(rows.first['sourceId'], 'mangapill');
    });
  });

  group('the cached payloads', () {
    // The grids and the featured hero read these rows, not the library table,
    // so repairing only `manga` left every card on screen still reporting the
    // slug. This calls the real method rather than a copy of it, because it is
    // logic and not a statement: a copied version would pass while the shipped
    // one stayed broken.
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE source_cache (
          key TEXT PRIMARY KEY,
          json TEXT NOT NULL,
          fetchedAt TEXT NOT NULL
        )
      ''');
    });

    tearDown(() async => db.close());

    Future<void> seedCache(String key, String json) => db.insert(
      'source_cache',
      {'key': key, 'json': json, 'fetchedAt': '2026-01-01T00:00:00.000'},
    );

    Future<List<dynamic>> entriesOf(String key) async {
      final rows = await db.query(
        'source_cache',
        columns: ['json'],
        where: 'key = ?',
        whereArgs: [key],
      );
      return jsonDecode(rows.first['json']! as String) as List<dynamic>;
    }

    test('a cached slug is replaced by the key prefix', () async {
      // What MangaPill wrote, in the payload a grid reads.
      await seedCache(
        'mangapill/list/tags/action,fantasy/1',
        '[{"id":"manga/49/slug","title":"A","coverUrl":"","sourceId":"manga/49/slug","tags":[]}]',
      );

      final repaired = await DatabaseHelper.repairCachedSourceIds(db);

      expect(repaired, 1);
      final entry =
          (await entriesOf('mangapill/list/tags/action,fantasy/1')).first
              as Map<String, dynamic>;
      expect(entry['sourceId'], 'mangapill');
      expect(entry['id'], 'manga/49/slug', reason: 'the manga keeps its id');
      expect(entry['title'], 'A');
    });

    test('every entry in a payload is stamped, not just the first', () async {
      await seedCache(
        'manhwa18/list/title/hi/1',
        '[{"id":"a","sourceId":"https://manhwa18.com/manga/a"},'
            '{"id":"b","sourceId":"https://manhwa18.com/manga/b"}]',
      );

      await DatabaseHelper.repairCachedSourceIds(db);

      final entries = await entriesOf('manhwa18/list/title/hi/1');
      expect(
        entries.cast<Map<String, dynamic>>().map((e) => e['sourceId']),
        everyElement('manhwa18'),
      );
    });

    test('a healthy payload is left byte-for-byte alone', () async {
      final healthy = '[{"id":"x","sourceId":"mangadex"}]';
      await seedCache('mangadex/list/popular//1', healthy);

      final repaired = await DatabaseHelper.repairCachedSourceIds(db);

      expect(repaired, 0);
      final rows = await db.query(
        'source_cache',
        columns: ['json'],
        where: 'key = ?',
        whereArgs: ['mangadex/list/popular//1'],
      );
      expect(rows.first['json'], healthy);
    });

    test('non-list payloads are left alone', () async {
      // `tags` holds strings and has no sourceId to fix; `details` was written
      // by a parser that passed the source correctly.
      await seedCache('mangapill/tags', '["Action","Adventure"]');
      await seedCache(
        'mangapill/details/manga%2F1861%2Fslug',
        '{"id":"manga/1861/slug","sourceId":"manga/1861/slug"}',
      );

      final repaired = await DatabaseHelper.repairCachedSourceIds(db);

      expect(repaired, 0);
      final rows = await db.query('source_cache', columns: ['key', 'json']);
      expect(rows, hasLength(2));
    });

    test('a payload that will not decode is skipped, not thrown on', () async {
      // A cache row can be truncated or half-written. It was unreadable before
      // this ran and is unreadable after; what must not happen is the migration
      // dying on it and leaving every later row unrepaired.
      await seedCache('mangapill/list/broken/1', '[{"id":"a",');
      await seedCache(
        'mangabat/list/good/1',
        '[{"id":"b","sourceId":"manga/b"}]',
      );

      final repaired = await DatabaseHelper.repairCachedSourceIds(db);

      expect(repaired, 1, reason: 'the row after the broken one is repaired');
      final entry =
          (await entriesOf('mangabat/list/good/1')).first
              as Map<String, dynamic>;
      expect(entry['sourceId'], 'mangabat');
    });
  });
}
