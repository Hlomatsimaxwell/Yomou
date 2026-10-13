import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/providers/source_sort.dart';

/// The five orders of Settings > Manga sources > Sorting order. The setting
/// looked inert before this because the list it was meant to sort was never
/// actually sorted; these pin the ordering itself, separately from the screens
/// that now use it.
void main() {
  Map<String, dynamic> row(String name, {bool pinned = false}) =>
      {'name': name, 'isPinned': pinned};

  List<String> namesOf(List<Map<String, dynamic>> rows) =>
      [for (final r in rows) r['name'] as String];

  group('sourceFamily', () {
    test('collapses a language variant onto its family', () {
      expect(sourceFamily('MangaFire Portuguese Brazil'), 'MangaFire');
      expect(sourceFamily('MangaBall Chinese'), 'MangaBall');
      expect(sourceFamily('MangaDex Español'), 'MangaDex');
    });

    test('leaves a family name and an unknown name alone', () {
      expect(sourceFamily('MangaPill'), 'MangaPill');
      // A shared prefix without the space is a different source, not a variant.
      expect(sourceFamily('MangaBat'), 'MangaBat');
      expect(sourceFamily('Some New Site'), 'Some New Site');
    });
  });

  test('manual keeps the stored order untouched', () {
    final rows = [row('B'), row('A'), row('C')];
    expect(namesOf(sortSourceRows(rows, SourceSortOrder.manual)), [
      'B',
      'A',
      'C',
    ]);
  });

  group('name', () {
    test('sorts case-insensitively', () {
      final rows = [row('beta'), row('Alpha'), row('gamma')];
      expect(namesOf(sortSourceRows(rows, SourceSortOrder.name)), [
        'Alpha',
        'beta',
        'gamma',
      ]);
    });

    test('pinned rows stay on top of the name order', () {
      final rows = [row('Zulu', pinned: true), row('Alpha'), row('Mike')];
      expect(namesOf(sortSourceRows(rows, SourceSortOrder.name)), [
        'Zulu',
        'Alpha',
        'Mike',
      ]);
    });
  });

  group('popular', () {
    test('follows the curated ranking, not the input order', () {
      final rows = [row('SeiManga'), row('MangaDex'), row('MangaFire')];
      expect(namesOf(sortSourceRows(rows, SourceSortOrder.popular)), [
        'MangaDex',
        'MangaFire',
        'SeiManga',
      ]);
    });

    test('a variant shares its family slot and is name-ordered within it', () {
      final rows = [
        row('MangaFire Spanish'),
        row('MangaFire English'),
        row('MangaBat'),
      ];
      // The MangaFire family outranks MangaBat; the two variant rows share the
      // family slot and fall back to name.
      expect(namesOf(sortSourceRows(rows, SourceSortOrder.popular)), [
        'MangaFire English',
        'MangaFire Spanish',
        'MangaBat',
      ]);
    });

    test('an unranked source sorts after every ranked one', () {
      final rows = [row('Some New Site'), row('Manganato')];
      expect(namesOf(sortSourceRows(rows, SourceSortOrder.popular)), [
        'Manganato',
        'Some New Site',
      ]);
    });
  });

  test('lastUsed puts the most recently opened first, unopened by name', () {
    final rows = [row('A'), row('B'), row('C')];
    const used = {'C': 300, 'A': 100};
    expect(
      namesOf(sortSourceRows(rows, SourceSortOrder.lastUsed, lastUsed: used)),
      ['C', 'A', 'B'],
    );
  });

  test('popularReliable pushes unreliable families below reliable ones', () {
    final rows = [
      row('MangaFire'),
      row('MangaDex'),
      row('Mangago'),
      row('MangaBat'),
    ];
    // MangaDex and MangaBat are reliable and rank above; MangaFire and Mangago
    // are browser/Cloudflare-gated and drop to the end, still by popularity.
    expect(namesOf(sortSourceRows(rows, SourceSortOrder.popularReliable)), [
      'MangaDex',
      'MangaBat',
      'MangaFire',
      'Mangago',
    ]);
  });
}
