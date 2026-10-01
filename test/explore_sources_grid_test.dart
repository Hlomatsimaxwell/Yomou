import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/explore/screens/explore_screen.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/suggestions/providers/suggestions_provider.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/source_icon.dart';

/// The sources wall used to be four columns at every width, with a fixed 64px
/// plate and a fixed 0.92 aspect ratio. On a 1200px-wide desktop that is a 285px
/// cell holding a 64px plate and one line of text -- four per row, and roughly
/// four fifths of each cell empty. These hold it to the three properties that
/// were broken: the column count follows the width, every plate in a row is the
/// same size and fits its cell, and the cell is no taller than the content in
/// it.
void main() {
  const names = [
    'MangaFire',
    'Manganato',
    'MangaDex',
    'MangaHere',
    'MangaSee',
    'Comick',
    'Asura Scans',
    'Raw Manga',
    'MangaPark',
    'Kiriluto',
    'MangaToon',
    'Webtoon',
  ];

  Widget host() {
    return ProviderScope(
      overrides: [
        visibleSourceRowsProvider.overrideWith(
          (ref) => [
            for (var i = 0; i < names.length; i++)
              {'name': names[i], 'iconUrl': '', 'isPinned': i == 0},
          ],
        ),
        // The wall and the list are two presentations of the same setting, and
        // the list is the default; these are about the wall.
        showSourcesInGridProvider.overrideWith((ref) => true),
        // The carousel above the wall reads the database for the user's tags,
        // which has no factory in a test. Empty renders it out of the way.
        suggestionsProvider.overrideWith((ref, _) async => const <Manga>[]),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ExploreScreen(),
      ),
    );
  }

  Future<void> pumpAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  /// The sources grid, told apart from the quick-actions grid above it, which is
  /// always two columns.
  GridView sourcesGrid(WidgetTester tester) {
    final grids = tester.widgetList<GridView>(find.byType(GridView));
    return grids.firstWhere((g) {
      final d = g.gridDelegate;
      return d is SliverGridDelegateWithFixedCrossAxisCount &&
          d.crossAxisCount >= 4;
    });
  }

  Future<(int, double)> resolve(WidgetTester tester, double width) async {
    await pumpAt(tester, width);
    final delegate =
        sourcesGrid(tester).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    return (delegate.crossAxisCount, delegate.childAspectRatio);
  }

  testWidgets('column count grows with the window, and stops at ten', (
    tester,
  ) async {
    final phone = await resolve(tester, 360);
    final tablet = await resolve(tester, 768);
    final desktop = await resolve(tester, 1280);
    final wide = await resolve(tester, 1920);

    // A phone keeps the four columns it has always had.
    expect(phone.$1, 4);
    // A tablet in portrait is where the old layout first started to fall apart.
    expect(tablet.$1, greaterThan(phone.$1));
    expect(desktop.$1, greaterThan(tablet.$1));
    // Past the ceiling the extra width goes into bigger cells, not more of them.
    expect(wide.$1, 10);
    expect(desktop.$1, lessThanOrEqualTo(10));
  });

  testWidgets('the cell holds its plate and its name, and nothing spare', (
    tester,
  ) async {
    for (final width in [360.0, 768.0, 1280.0, 1920.0]) {
      await pumpAt(tester, width);
      final delegate =
          sourcesGrid(tester).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;

      // Constraints.maxWidth inside the grid's own padding, so this is the
      // width the columns were resolved against.
      final gridWidth = width - 32;
      final cellWidth =
          (gridWidth - (delegate.crossAxisCount - 1) * 10) /
          delegate.crossAxisCount;
      final cellHeight = cellWidth / delegate.childAspectRatio;

      final plates = tester.widgetList<SourceIcon>(find.byType(SourceIcon));
      expect(plates, isNotEmpty, reason: 'no plate at ${width}px');
      // Uniform: every plate in the wall is one size, so the wall reads as a
      // grid rather than a ragged collection.
      for (final plate in plates) {
        expect(plate.size, plates.first.size);
        expect(
          plate.size,
          lessThanOrEqualTo(cellWidth),
          reason: 'plate ${plate.size} does not fit a ${cellWidth}px cell',
        );
        expect(plate.size, greaterThanOrEqualTo(56.0));
      }

      final label = tester.widget<Text>(find.text(names.first));
      final labelSize = label.style!.fontSize!;
      // Two name lines are reserved, so this is the height the cell owes, plus
      // the same slack the manga cells add.
      final contentHeight =
          plates.first.size + 4 + labelSize * 1.2 * 2 + kMangaCardTitleSlack;

      // The whole complaint in one assertion: the old grid had a 309px cell
      // holding 82px of content on a desktop. The other direction matters just
      // as much -- a cell shorter than its content is an overflow stripe down
      // the wall, which is what this caught first.
      expect(
        cellHeight - contentHeight,
        lessThan(4.0),
        reason:
            'at ${width}px the cell is ${cellHeight.toStringAsFixed(1)} tall '
            'for ${contentHeight.toStringAsFixed(1)} of content',
      );
      expect(
        contentHeight - cellHeight,
        lessThan(4.0),
        reason: 'content overflows the cell at ${width}px',
      );
    }
  });

  testWidgets('the name is allowed two lines at every width', (tester) async {
    for (final width in [360.0, 1280.0]) {
      await pumpAt(tester, width);
      final label = tester.widget<Text>(find.text(names.first));
      expect(label.maxLines, 2);
      expect(label.overflow, TextOverflow.ellipsis);
    }
  });
}