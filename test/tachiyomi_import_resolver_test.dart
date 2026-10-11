import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/backup/tachiyomi_backup.dart';
import 'package:yomou/core/backup/tachiyomi_import_resolver.dart';
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_details.dart';
import 'package:yomou/data/models/manga_source.dart';

/// Minimal source that returns canned search results and can be told to fail,
/// so the resolver's fan-out and matching can be exercised without a network.
class _FakeSource extends MangaSource {
  _FakeSource(
    this.id, {
    this.results = const [],
    this.error = false,
    this.lang = 'en',
  });

  @override
  final String id;
  final List<Manga> results;
  final bool error;
  final String lang;
  var searches = 0;

  @override
  String get name => id;
  @override
  String get baseUrl => 'https://$id.test';
  @override
  String get readerBaseUrl => baseUrl;
  @override
  String get languageCode => lang;

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    searches++;
    if (error) throw Exception('source down');
    return results;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async => const [];
  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async => null;
  @override
  Future<List<Chapter>> getChapters(String mangaId) async => const [];
  @override
  Future<List<String>> getPageUrls(String chapterId) async => const [];
}

Manga _manga(String sourceId, String id, String title, [String cover = '']) =>
    Manga(id: id, title: title, coverUrl: cover, sourceId: sourceId);

TachiyomiImportResult _result(List<TachiyomiMissingManga> missing) =>
    TachiyomiImportResult(
      mangas: const [],
      skippedMangas: const [],
      missingMangas: missing,
    );

void main() {
  group('keeps unsupported-source entries for the scan', () {
    test('legacy JSON entries become missing, not skipped', () {
      final json = jsonEncode({
        'library': [
          {
            'url': 'https://unknown-site.test/manga/solo-leveling',
            'title': 'Solo Leveling',
            'source': 123456789,
            'thumbnailUrl': 'https://unknown-site.test/cover.jpg',
            'isFavorite': true,
            'history': [
              {'lastReadAt': 1700000000000},
            ],
            'chapters': [
              {
                'url': 'https://unknown-site.test/solo-leveling/50',
                'name': 'Chapter 50',
                'bookmark': true,
              },
            ],
          },
        ],
      });

      final parsed = TachiyomiBackupCodec.import(
        Uint8List.fromList(utf8.encode(json)),
      );

      expect(parsed.mangas, isEmpty);
      expect(parsed.skippedMangas, isEmpty);
      expect(parsed.missingMangas, hasLength(1));
      final missing = parsed.missingMangas.single;
      expect(missing.title, 'Solo Leveling');
      expect(missing.sourceName, 'source 123456789');
      expect(missing.coverUrl, 'https://unknown-site.test/cover.jpg');
      expect(missing.lastReadChapter, 50);
      expect(missing.isFavorite, isTrue);
    });
  });

  group('resolveTachiyomiMissing', () {
    test('re-binds a missing title to a source that has it', () async {
      final source = _FakeSource(
        'mangapill',
        results: [
          _manga('mangapill', '999', 'Something Else'),
          _manga('mangapill', '5163', 'Solo Leveling', 'https://c/1.jpg'),
        ],
      );
      final parsed = _result([
        const TachiyomiMissingManga(
          title: 'Solo Leveling',
          url: 'https://unknown.test/solo-leveling',
          sourceName: 'Comick',
          lastReadChapter: 42,
          isFavorite: true,
        ),
      ]);

      final out = await resolveTachiyomiMissing(parsed, [source]);

      expect(out.recoveredMangas, hasLength(1));
      final recovered = out.recoveredMangas.single;
      expect(recovered.sourceId, 'mangapill');
      expect(recovered.mangaId, '5163');
      expect(recovered.title, 'Solo Leveling');
      expect(recovered.coverUrl, 'https://c/1.jpg');
      expect(recovered.lastReadChapter, 42);
      expect(recovered.isFavorite, isTrue);
      expect(out.skippedMangas, isEmpty);
      expect(out.imported, 1);
    });

    test('reports an entry as failed when no source has the title', () async {
      final source = _FakeSource(
        'mangapill',
        results: [_manga('mangapill', '1', 'Some Unrelated Manga')],
      );
      final parsed = _result([
        const TachiyomiMissingManga(
          title: 'Solo Leveling',
          url: 'https://unknown.test/solo-leveling',
          sourceName: 'Comick',
        ),
      ]);

      final out = await resolveTachiyomiMissing(parsed, [source]);

      expect(out.recoveredMangas, isEmpty);
      expect(out.skippedMangas, hasLength(1));
      expect(out.skippedMangas.single.title, 'Solo Leveling');
      expect(
        out.skippedMangas.single.reason,
        TachiyomiSkippedReason.unsupportedSource,
      );
    });

    test('a failing source does not hide a match from a working one',
        () async {
      final broken = _FakeSource('broken', error: true);
      final working = _FakeSource(
        'mangapill',
        results: [_manga('mangapill', '5163', 'Solo Leveling')],
      );
      final parsed = _result([
        const TachiyomiMissingManga(
          title: 'Solo Leveling',
          url: 'https://unknown.test/solo-leveling',
        ),
      ]);

      final out = await resolveTachiyomiMissing(parsed, [broken, working]);

      expect(out.recoveredMangas, hasLength(1));
      expect(out.recoveredMangas.single.sourceId, 'mangapill');
    });

    test('reports progress for each scanned title', () async {
      final source = _FakeSource('mangapill');
      final parsed = _result([
        const TachiyomiMissingManga(title: 'One', url: ''),
        const TachiyomiMissingManga(title: 'Two', url: ''),
      ]);

      final updates = <String>[];
      await resolveTachiyomiMissing(
        parsed,
        [source],
        onProgress: (done, total) => updates.add('$done/$total'),
      );

      expect(updates.first, '0/2');
      expect(updates.last, '2/2');
    });

    test('nothing to scan returns the result untouched', () async {
      final parsed = _result(const []);
      final out = await resolveTachiyomiMissing(parsed, [
        _FakeSource('mangapill'),
      ]);
      expect(identical(out, parsed), isTrue);
    });

    test('with no sources to search, entries are reported as failed', () async {
      final parsed = _result([
        const TachiyomiMissingManga(title: 'Solo Leveling', url: ''),
      ]);
      final out = await resolveTachiyomiMissing(parsed, const []);
      expect(out.recoveredMangas, isEmpty);
      expect(out.skippedMangas, hasLength(1));
      expect(
        out.skippedMangas.single.reason,
        TachiyomiSkippedReason.unsupportedSource,
      );
    });

    test('prefers a source in the reader content language', () async {
      // The non-preferred source is listed first so an early fan-out stop on it
      // still has to give way to the English source in the extra window.
      final spanish = _FakeSource(
        'es-src',
        lang: 'es',
        results: [_manga('es-src', 'es-1', 'Solo Leveling')],
      );
      final english = _FakeSource(
        'en-src',
        lang: 'en',
        results: [_manga('en-src', 'en-1', 'Solo Leveling')],
      );
      final parsed = _result([
        const TachiyomiMissingManga(title: 'Solo Leveling', url: ''),
      ]);

      final out = await resolveTachiyomiMissing(
        parsed,
        [spanish, english],
        preferredLanguages: const {'English'},
      );

      expect(out.recoveredMangas.single.sourceId, 'en-src');
    });

    test('falls back to another language when none matches', () async {
      final spanish = _FakeSource(
        'es-src',
        lang: 'es',
        results: [_manga('es-src', 'es-1', 'Solo Leveling')],
      );
      final parsed = _result([
        const TachiyomiMissingManga(title: 'Solo Leveling', url: ''),
      ]);

      final out = await resolveTachiyomiMissing(
        parsed,
        [spanish],
        preferredLanguages: const {'English'},
      );

      expect(out.recoveredMangas.single.sourceId, 'es-src');
    });

    test('treats a regional code as its base language', () async {
      final portuguese = _FakeSource(
        'pt-src',
        lang: 'pt-br',
        results: [_manga('pt-src', 'pt-1', 'Solo Leveling')],
      );
      final english = _FakeSource(
        'en-src',
        lang: 'en',
        results: [_manga('en-src', 'en-1', 'Solo Leveling')],
      );
      final parsed = _result([
        const TachiyomiMissingManga(title: 'Solo Leveling', url: ''),
      ]);

      final out = await resolveTachiyomiMissing(
        parsed,
        [english, portuguese],
        preferredLanguages: const {'Portuguese'},
      );

      expect(out.recoveredMangas.single.sourceId, 'pt-src');
    });
  });
}
