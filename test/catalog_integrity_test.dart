import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/data/sources/catalog/madara_catalog.g.dart' as madara;
import 'package:yomou/data/sources/catalog/manga_themesia_catalog.g.dart'
    as themesia;
import 'package:yomou/data/sources/catalog/zeistmanga_catalog.g.dart' as zeist;
import 'package:yomou/data/sources/catalog/gigaviewer_catalog.g.dart' as giga;

/// Guards the hand-off between the generated catalogs and the runtime registry.
///
/// The .data/ JSON files are gitignored, so a future addition is only visible
/// through a regenerated .g.dart. If a regeneration emits a duplicate id/name,
/// drops the enabled flag, or produces a name the registry cannot resolve, the
/// source silently disappears (or, worse, `getSourceByName` falls back to
/// MangaDex). These checks make that failure loud.
void main() {
  final catalogs = <String, List<dynamic>>{
    'madara': madara.catalogMadaraConfigs,
    'mangathemesia': themesia.catalogMangaThemesiaConfigs,
    'zeistmanga': zeist.catalogZeistMangaConfigs,
    'gigaviewer': giga.catalogGigaViewerConfigs,
  };

  test('generated catalogs are non-empty with unique ids and names', () {
    catalogs.forEach((label, configs) {
      expect(configs, isNotEmpty, reason: '$label catalog is empty');
      expect(
        configs.map((c) => c.id as String).toSet().length,
        configs.length,
        reason: '$label catalog has duplicate ids',
      );
      expect(
        configs.map((c) => c.name as String).toSet().length,
        configs.length,
        reason: '$label catalog has duplicate names',
      );
      for (final config in configs) {
        expect((config.id as String).isNotEmpty, isTrue, reason: label);
        expect((config.name as String).isNotEmpty, isTrue, reason: label);
        expect(config.baseUrl as String, startsWith('http'), reason: label);
      }
    });
  });

  test('every generated site resolves by name and by stored source id', () {
    catalogs.forEach((label, configs) {
      for (final config in configs) {
        final id = config.id as String;
        final name = config.name as String;

        final byName = getSourceByName(name);
        expect(byName.id, id, reason: '$label name "$name" resolved elsewhere');
        expect(byName.name, name, reason: label);

        final byId = getSourceBySourceId(id);
        expect(byId, isNotNull, reason: '$label id "$id" does not resolve');
        expect(byId!.id, id, reason: label);
      }
    });
  });

  test('catalog source rows stay enabled and point at the site itself', () {
    for (final row in madara.catalogSourceRows) {
      expect(row['isEnabled'], true, reason: row['name'] as String);
      expect(row['siteUrl'], isNotEmpty, reason: row['name'] as String);
    }
    for (final row in themesia.catalogMangaThemesiaSourceRows) {
      expect(row['isEnabled'], true, reason: row['name'] as String);
      expect(row['siteUrl'], isNotEmpty, reason: row['name'] as String);
    }
    for (final row in zeist.catalogZeistMangaSourceRows) {
      expect(row['isEnabled'], true, reason: row['name'] as String);
      expect(row['siteUrl'], isNotEmpty, reason: row['name'] as String);
    }
    for (final row in giga.catalogGigaViewerSourceRows) {
      expect(row['isEnabled'], true, reason: row['name'] as String);
      expect(row['siteUrl'], isNotEmpty, reason: row['name'] as String);
    }
  });

  test('gigaviewer catalog keeps its 19 sites and their collection ids', () {
    expect(giga.catalogGigaViewerConfigs.length, 19);
    for (final config in giga.catalogGigaViewerConfigs) {
      // Comic Border's front page is HTML, so it needs no GraphQL group ids.
      if (config.catalogMode == 'graphql') {
        expect(
          config.seriesListIds +
              config.filterOptions.expand((o) => o.ids).toList(),
          isNotEmpty,
          reason: config.name,
        );
      }
      for (final option in config.filterOptions) {
        expect(option.label, isNotEmpty, reason: config.name);
      }
    }
    final action = giga.catalogGigaViewerByName['Comic Action']!;
    expect(action.seriesListIds, contains('14079602755641808866'));
    expect(action.filterOptions.first.label, '連載作品');
    expect(giga.catalogGigaViewerByName['Zenon']!.unavailableWhenStatusNull,
        isTrue);
  });
}
