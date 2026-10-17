import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/screens/favorites_screen.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The manga grids do not have a column count any more; they have a cover size.
///
/// The reader picks a percentage of the design cell: [kMangaGridBaseCellWidth]
/// on a phone or a portrait tablet, [kMangaGridBaseCellWidthLandscape] on a
/// landscape one at least [kWideLayoutWidth] wide -- and the count is
/// whatever fits at that size, rounded, never below [kMangaGridMinColumns] and
/// never capped. It reads as "cover size" because that is what it controls: the
/// columns are a consequence, which is how "fewer, bigger covers" became
/// reachable at all.
///
/// One stored setting reaches every grid, in [appearanceSettingsProvider]. The
/// four that had a slider each used to keep their own column preference and
/// their own idea of the default, so a reader who wanted bigger covers had to
/// say so four times -- and on a wide window the number was only ever a floor,
/// so saying it did nothing. The retired preference and the retired column
/// constants are scanned for below, because a second preference is exactly how
/// the grids came to disagree.
void main() {
  /// A phone, a tablet, a large tablet and a desktop, each 1600 tall.
  const widths = [360.0, 768.0, 1245.0, 1920.0];

  /// Favourites, the plainest grid: full screen, no rail beside it, so [width]
  /// in the helpers below is the width the grid is actually given.
  ///
  /// [gridSize] is keyed into the scope rather than set afterwards, so each
  /// size is a fresh provider reading the preference the test just seeded.
  Widget host({double gridSize = kMangaGridSizeDefault}) => ProviderScope(
    key: ValueKey<double>(gridSize),
    overrides: [
      favoritesProvider.overrideWith(
        (ref) async => [
          for (var i = 0; i < 6; i++)
            Manga(id: 'id$i', title: 'Title $i', coverUrl: '', sourceId: '0'),
        ],
      ),
      downloadedMangasProvider.overrideWith((ref) async => <String>{}),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const FavoritesScreen(),
    ),
  );

  /// Pumps favourites at [width] with [gridSize] already on disk, and returns
  /// the count and cell width the grid resolved.
  ///
  /// Seeded rather than overridden, so the path the app really takes -- load
  /// from preferences, notify, rebuild -- is the one under test.
  Future<(int, double)> resolveFavorites(
    WidgetTester tester,
    double width, {
    double gridSize = kMangaGridSizeDefault,
  }) async {
    SharedPreferences.setMockInitialValues({
      'appearance.gridSize': gridSize,
    });
    await SharedPreferences.getInstance();
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(gridSize: gridSize));
    await tester.pumpAndSettle();

    return _drawnGrid(tester, width);
  }

  test('the grid-size control is one set of numbers', () {
    // Every screen used to write its own range (1..6, 2..4, 2..5) and its own
    // `7 - value` arithmetic, so the same thumb position meant a different
    // number of covers depending on which sheet it was in.
    expect(kMangaGridSizeMin, 50);
    expect(kMangaGridSizeMax, 150);
    expect(kMangaGridSizeStep, 5);
    expect(kMangaGridSizeDivisions, 20);
    expect(
      (kMangaGridSizeMax - kMangaGridSizeMin) % kMangaGridSizeStep,
      0,
      reason: 'the range has to divide evenly, or the last stop is unreachable',
    );
    expect(kMangaGridSizeDefault, 100);
    expect(
      (kMangaGridSizeDefault - kMangaGridSizeMin) % kMangaGridSizeStep,
      0,
      reason: 'the default has to sit on a stop, or the thumb starts off it',
    );
    expect(kMangaGridSizeMin, lessThan(kMangaGridSizeMax));
    expect(kMangaGridMinColumns, 2);
    expect(kMangaGridBaseCellWidth, 120);
    expect(kMangaGridBaseCellWidthLandscape, 140);
    expect(kWideLayoutWidth, 600);
  });

  testWidgets('the base cell changes where the reference changes it', (
    tester,
  ) async {
    // The reference states the landscape cell as a `w600dp-land` resource:
    // 140dp only when the window is landscape *and* at least 600dp across.
    // Orientation is part of it on purpose -- a phone turned sideways is over
    // 800dp wide, and width alone would lay its covers out at a tablet's.
    const cases = <(double, double, double)>[
      (400.0, 800.0, kMangaGridBaseCellWidth),
      (800.0, 400.0, kMangaGridBaseCellWidthLandscape),
      (599.0, 400.0, kMangaGridBaseCellWidth),
      (600.0, 400.0, kMangaGridBaseCellWidthLandscape),
      (800.0, 1280.0, kMangaGridBaseCellWidth),
      (1280.0, 800.0, kMangaGridBaseCellWidthLandscape),
    ];

    for (final (width, height, expected) in cases) {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('context'))),
      );
      await tester.pump();

      final context = tester.element(find.byType(Text));
      expect(
        mangaGridBaseCellWidth(context),
        expected,
        reason: '${width}x$height',
      );
    }
  });

  test('every size on every window keeps the grid a grid', () {
    // 150% on a 320px window resolves 1.6 of them. One cover per row is a list
    // that has stopped being a grid, so the last stop on the slider reads
    // "two enormous covers", never one.
    for (var width = 320.0; width <= 640.0; width += 20) {
      for (var size = kMangaGridSizeMin;
          size <= kMangaGridSizeMax;
          size += kMangaGridSizeStep) {
        final columns = _columnsAt(width, size.toDouble(), height: 800);
        expect(
          columns,
          greaterThanOrEqualTo(kMangaGridMinColumns),
          reason: '${width}px at $size%',
        );
      }
    }
    // The floor has to be the thing answering, rather than a clamp that only
    // fires somewhere further out.
    expect(_columnsAt(320, 150, height: 800), 2);
  });

  test('bigger covers means fewer of them, never the other way round', () {
    // The slider is a size control, so this is the whole contract: as it goes
    // up the covers grow and the count gives way. Rounding the fit could
    // otherwise let a step up in size hand back a column somewhere.
    for (final width in widths) {
      var columns = _columnsAt(width, kMangaGridSizeMin.toDouble());
      var cell = _cellWidthAt(width, columns);
      for (var size = kMangaGridSizeMin + kMangaGridSizeStep;
          size <= kMangaGridSizeMax;
          size += kMangaGridSizeStep) {
        final next = _columnsAt(width, size.toDouble());
        final nextCell = _cellWidthAt(width, next);
        expect(
          next,
          lessThanOrEqualTo(columns),
          reason:
              '${width}px: $size% must not need more columns than '
              '${size - kMangaGridSizeStep}%',
        );
        expect(
          nextCell,
          greaterThanOrEqualTo(cell),
          reason: '${width}px at $size%: the covers must not shrink',
        );
        columns = next;
        cell = nextCell;
      }
    }
  });

  test('100% is the design cell, and both ends match the reference', () {
    // The counts the grids were matched to, at the reference's own numbers: a
    // phone at 120dp, a portrait tablet at 120dp, and a landscape tablet at
    // 140dp once the navigation rail has taken its 80.
    expect(_columnsAt(360, 100, height: 800), 3);
    expect(_columnsAt(800, 100, height: 1280), 6);
    expect(_columnsAt(1280, 100, height: 800, availableWidth: 1168), 8);

    // Both ends of the slider, so the size control moves the count in the
    // direction a reader dragging it expects.
    expect(_columnsAt(360, 50, height: 800), 5);
    expect(_columnsAt(360, 150, height: 800), 2);
    expect(_columnsAt(800, 50, height: 1280), 12);
    expect(_columnsAt(800, 150, height: 1280), 4);
    expect(_columnsAt(1280, 50, height: 800, availableWidth: 1168), 15);
    expect(_columnsAt(1280, 150, height: 800, availableWidth: 1168), 5);
  });

  test('nothing caps the count any more', () {
    // The shared ceiling this used to have was eight, past which the extra
    // width went into air instead of into another column. There is no such
    // point now: a desktop at the design size draws thirteen, and even at 150%
    // -- the setting a reader picks for *bigger* covers -- it draws nine.
    expect(_columnsAt(1920, 100, height: 1080), 13);
    expect(_columnsAt(1920, 50, height: 1080), 25);
    expect(_columnsAt(1920, 150, height: 1080), 9);

    // And the count keeps growing with the window: no width saturates, so a
    // wider screen is always more covers at the same size rather than the same
    // covers at a bigger size.
    var previous = 0;
    for (final width in [768.0, 1024.0, 1280.0, 1600.0, 1920.0]) {
      final columns = _columnsAt(width, 100, height: width + 400);
      expect(columns, greaterThan(previous), reason: '${width}px');
      previous = columns;
    }
  });

  testWidgets('the drawn grid and the helper are the same arithmetic', (
    tester,
  ) async {
    // The helper above is a replication -- it takes the numbers MediaQuery
    // would supply -- so this is what stops the two drifting apart: the real
    // function, in a real build, at every width and both ends of the range.
    for (final width in widths) {
      final (columns, cellWidth) = await resolveFavorites(tester, width);

      final context = tester.element(find.byType(SliverGrid));
      for (final size in [50.0, 100.0, 150.0]) {
        expect(
          mangaGridColumns(context, gridSize: size, availableWidth: width),
          _columnsAt(width, size),
          reason: '${width}px at $size%',
        );
      }

      // The screen drew what the replication says it should, so these tests
      // and the app are arguing from the same arithmetic.
      expect(
        columns,
        _columnsAt(width, kMangaGridSizeDefault),
        reason: '${width}px drawn',
      );

      // And the cover it lands on is the one the setting names: at 100% a cell
      // is the design cell wherever rounding put it, which is the claim the
      // label makes on every sheet that has this slider.
      expect(
        cellWidth,
        inInclusiveRange(100, 144),
        reason: '${width}px: a 100% cover came out $cellWidth wide',
      );
      expect(cellWidth, greaterThan(0), reason: 'no room for a cell at $width');

      final drawn =
          tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;

      // The cell the grid measures with is the cell it is given: the aspect
      // ratio is computed from the same count, the same padding and the same
      // title size, or a two-line title is measured at one width and painted
      // at another.
      expect(
        drawn.childAspectRatio,
        mangaCellAspectRatio(
          context,
          columns: columns,
          titleFontSize: mangaCardTitleFontSize(columns),
          availableWidth: width,
        ),
        reason: '${width}px measured against a different cell than it draws',
      );
    }
  });

  testWidgets('the stored grid size is what the grid draws', (tester) async {
    // Nothing stored, so the design size: a portrait tablet at 800px draws
    // six columns of the cell it was matched to.
    final (defaults, _) = await resolveFavorites(tester, 800);
    expect(defaults, 6);

    // A stored size is read on load and changes the grid, which is the part
    // that used to be inert on a wide window -- where the width decided the
    // count and the setting was only ever a floor.
    final (coarse, coarseCell) = await resolveFavorites(
      tester,
      800,
      gridSize: 150,
    );
    expect(coarse, 4);
    expect(coarseCell, greaterThan(_cellWidthAt(800, defaults)));

    final (fine, fineCell) = await resolveFavorites(tester, 800, gridSize: 50);
    expect(fine, 12);
    expect(fineCell, lessThan(_cellWidthAt(800, defaults)));
  });

  testWidgets('the sheet slider moves the preference the grid reads', (
    tester,
  ) async {
    final (before, _) = await resolveFavorites(tester, 800);
    expect(before, 6);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FavoritesScreen)),
    );
    expect(
      container.read(appearanceSettingsProvider).gridSize,
      kMangaGridSizeDefault,
    );

    await tester.tap(find.byIcon(MdiIcons.dotsVertical));
    await tester.pumpAndSettle();

    final slider = find.byType(Slider);
    expect(slider, findsOneWidget, reason: 'the sheet has one size control');
    await tester.drag(slider, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(appearanceSettingsProvider).gridSize,
      kMangaGridSizeMax.toDouble(),
      reason: 'dragging right runs the track to its top end',
    );
    final after =
        tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    expect(after.crossAxisCount, lessThan(before));
    expect(after.crossAxisCount, 4);
  });

  test('every grid screen gets its count from the shared helper', () {
    // One definition of the arithmetic is the whole point of this file's
    // subject: two tabs of the same library that count for themselves are two
    // tabs that draw different cards.
    //
    // Explore's wall is deliberately not here. It lays out source logos and
    // names rather than covers, so it keeps its own target width, its own floor
    // and its own ceiling, and none of them follow a cover size.
    const screens = [
      'lib/features/history/screens/history_screen.dart',
      'lib/features/library/screens/favorites_screen.dart',
      'lib/features/library/screens/related_manga_screen.dart',
      'lib/features/suggestions/screens/suggestions_screen.dart',
      'lib/features/source_management/screens/manga_grid_screen.dart',
      'lib/features/explore/screens/global_search_screen.dart',
      'lib/features/explore/screens/source_search_results_screen.dart',
    ];

    // A count written into the delegate is a count this screen chose.
    final literalCount = RegExp(r'crossAxisCount:\s*\d');
    // And an upper bound written as a number is a private ceiling: the helper
    // has no ceiling to restate. An identifier is a named constant rather than
    // a number picked in a screen, which is at least greppable -- though for a
    // column count neither is wanted, which is what the check above is for.
    final numberCeiling = RegExp(r'\.clamp\(\s*\d+\s*,\s*(\d+)\s*\)');

    for (final screen in screens) {
      final source = _stripComments(File(screen).readAsStringSync());
      expect(
        source.contains('mangaGridColumns('),
        isTrue,
        reason: '$screen does not ask the shared helper',
      );
      expect(
        literalCount.hasMatch(source),
        isFalse,
        reason: '$screen picks its own column count',
      );
      for (final match in numberCeiling.allMatches(source)) {
        fail('$screen clamps at ${match.group(1)}, a bound of its own');
      }
    }
  });

  test('nothing reads the retired column preference', () {
    // The percent setting replaced it, and one preference for every grid is
    // the whole story of this file: a second one is how four grids came to
    // disagree about what a cover should look like.
    //
    // Comments are stripped first, so a note explaining the retirement is not
    // read as a use of it -- the documentation of a change must not fail the
    // test of the change.
    const retired = [
      'appearance.gridColumns',
      'gridDensityProvider',
      'grid_density_provider',
      'history_grid_size',
      'favorites_grid_size',
      'suggestions_grid_size',
      'manga_grid_grid_size',
      'kMangaGridMaxColumns',
      'kMangaGridTargetCellWidth',
      'kMangaGridSliderMinColumns',
      'kMangaGridSliderMaxColumns',
      'mangaGridSliderPositionForColumns',
      'mangaGridColumnsForSliderPosition',
      'mangaGridColumnsFor',
    ];

    final files =
        (Directory('lib').listSync(recursive: true).whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path)));

    for (final file in files) {
      if (!file.path.endsWith('.dart')) continue;
      final source = _stripComments(file.readAsStringSync());
      for (final token in retired) {
        expect(
          source.contains(token),
          isFalse,
          reason: '${file.path} still reads $token',
        );
      }
    }
  });
}

/// Columns and cell width of the grid currently on screen at [width].
(int, double) _drawnGrid(WidgetTester tester, double width) {
  final delegate =
      tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;
  final count = delegate.crossAxisCount;
  return (count, _cellWidthAt(width, count));
}

/// Columns [mangaGridColumns] resolves for a window [width] wide and [height]
/// tall, without needing a widget tree.
///
/// [mangaGridColumns] reads MediaQuery for the base cell, which is unavailable
/// outside a build, so the orientation is passed in instead; [availableWidth]
/// stands in for the width the grid was given, which is the window's unless a
/// nav rail or a side pane takes a share of it. The widget tests above call the
/// real function at these same numbers, so a drift between this and the source
/// shows up there rather than as a silently wrong expectation here.
int _columnsAt(
  double width,
  double gridSize, {
  double? availableWidth,
  double height = 1600,
}) {
  final base = availableWidth ?? width;
  final available = base - kMangaGridHorizontalPadding * 2;
  final cell = _baseCellWidth(width, height) * gridSize / 100;
  final fit =
      ((available + kMangaGridCrossSpacing) / (cell + kMangaGridCrossSpacing))
          .round();
  return fit < kMangaGridMinColumns ? kMangaGridMinColumns : fit;
}

/// [kMangaGridBaseCellWidth] or [kMangaGridBaseCellWidthLandscape] at a window
/// of this size, which is what [mangaGridBaseCellWidth] reads off MediaQuery.
///
/// Restates the reference's `w600dp-land` rule rather than calling
/// [usesWideLayout], so the expectations below are an independent statement of
/// the rule instead of the rule checking itself.
double _baseCellWidth(double width, double height) =>
    width > height && width >= kWideLayoutWidth
        ? kMangaGridBaseCellWidthLandscape
        : kMangaGridBaseCellWidth;

/// Cell width a grid [columns] columns wide gets out of a [width] window,
/// which is the cover width a reader sees when they move the slider.
double _cellWidthAt(double width, int columns) =>
    (width -
        kMangaGridHorizontalPadding * 2 -
        (columns - 1) * kMangaGridCrossSpacing) /
    columns;

/// [source] with its comments removed, so a scan for code only matches code.
///
/// Handles `//` lines, trailing `//`, `///` docs and non-nesting `/* */` pairs
/// on one line -- the file of a source module is full of `/* */` inside Accept
/// headers, and a scan that threw on those would have to be scoped down to the
/// handful of files it cared about, which is a scan that stops noticing the new
/// file. It is not a parser: a block comment opened on one line and closed on
/// the next would leave its first half behind, and a `//` inside a string eats
/// the rest of the line. Both can only make a scan stricter than intended, and
/// none of the identifiers looked for here appear in a string.
String _stripComments(String source) {
  final out = StringBuffer();
  for (final line in source.split('\n')) {
    final withoutBlock = line.replaceAll(RegExp(r'/\*.*?\*/'), '');
    if (withoutBlock.trimLeft().startsWith('//')) {
      out.writeln();
      continue;
    }
    out.writeln(withoutBlock.split('//').first);
  }
  return out.toString();
}
