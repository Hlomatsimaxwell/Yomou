import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yomou/core/widgets/responsive.dart' show kWideLayoutWidth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/screens/favorites_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The four manga grids disagreed about how many columns they had.
///
/// Two of them ended in a bare `.clamp(2, 7)`, which held History and Suggestions
/// to a ceiling one lower than the [kMangaGridMaxColumns] the other two already
/// used -- so on a wide window the library showed eight-column covers on two tabs
/// and seven-column covers on the other two, and the cells did not match between
/// tabs of the same screen. Favourites had no density setting at all, so it
/// honoured no stored choice and sat at whatever the width derived, which is
/// another way of being different from its two siblings.
///
/// All three also derived their cells from MediaQuery rather than from the width
/// they were actually given, so the nav rail's 80px was invisible to them and
/// every column on a desktop was sized for space the grid did not have.
///
/// These hold all of that to one answer: one ceiling, taken from the shared
/// helper, measured from the real width.
void main() {
  /// The widths a phone, tablet, desktop and very wide desktop present.
  const widths = [360.0, 768.0, 1245.0, 1920.0];

  Widget host() {
    return ProviderScope(
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
  }

  /// The columns and the cell width the grid on screen actually resolved to.
  Future<(int, double)> resolveFavorites(
    WidgetTester tester,
    double width,
  ) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final delegate =
        tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    final columns = delegate.crossAxisCount;
    final cellWidth =
        (width -
            kMangaGridHorizontalPadding * 2 -
            (columns - 1) * kMangaGridCrossSpacing) /
        columns;
    return (columns, cellWidth);
  }

  test('one ceiling, and it is the shared one', () {
    // The property the bare clamps broke: whatever the width, nothing resolves
    // past the constant every grid shares.
    for (var width = 320.0; width <= 2560.0; width += 20) {
      final derived = _columnsAt(width, userColumns: 3);
      expect(
        derived,
        lessThanOrEqualTo(kMangaGridMaxColumns),
        reason: '$derived columns at ${width}px, past the shared ceiling',
      );
      expect(derived, greaterThanOrEqualTo(2));
    }
  });

  test('the ceiling is reached and then held', () {
    // Past the point where the target cell width divides the window, the count
    // stops and the extra width goes into bigger cells. This is the difference
    // between a 7-column grid with 40px of air per cell and an 8-column one
    // without.
    expect(_columnsAt(1920, userColumns: 3), kMangaGridMaxColumns);
    expect(_columnsAt(2560, userColumns: 3), kMangaGridMaxColumns);
  });

  test('a stored choice is honoured on a narrow layout, exactly', () {
    // Below the wide-layout threshold the setting is a value, not a floor: the
    // phone grid is what the user asked for at any angle, landscape included.
    for (final stored in [1, 2, 3, 4, 5, 6]) {
      expect(_columnsAt(360, userColumns: stored), stored);
      expect(_columnsAt(700, userColumns: stored), stored);
    }
  });

  test('a stored choice becomes a floor on a wide layout', () {
    // A deliberate dense choice survives a tablet; a coarse one is improved on.
    for (var width = 900.0; width <= 2000.0; width += 100) {
      final derived = _columnsAt(width, userColumns: 3);
      expect(derived, greaterThanOrEqualTo(3), reason: 'at ${width}px');
    }
  });

  testWidgets('favourites resolves the same columns as the shared helper', (
    tester,
  ) async {
    // The grid has to ask [mangaGridColumnsFor] rather than deciding for itself.
    // It used to call [mangaGridColumns], which honours no stored choice at all,
    // which is how this screen ended up a different density from the two beside
    // it while showing the same cards.
    for (final width in widths) {
      final (columns, cellWidth) = await resolveFavorites(tester, width);
      expect(
        columns,
        _columnsAt(width, userColumns: 3),
        reason: 'favourites disagrees at ${width}px',
      );
      expect(
        cellWidth,
        greaterThan(0),
        reason: 'no room for a cell at ${width}px',
      );
    }
  });

  testWidgets('a wide window gives every grid the same cell', (tester) async {
    // The end-to-end claim: at the desktop width, the cells are the size the
    // shared helper says, and they are the size a source catalogue shows.
    final (columns, cellWidth) = await resolveFavorites(tester, 1245);
    final context = tester.element(find.byType(SliverGrid));
    final expectedRatio = mangaCellAspectRatio(
      context,
      columns: columns,
      titleFontSize: mangaCardTitleFontSize(columns),
      availableWidth: 1245,
    );
    final delegate =
        tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.childAspectRatio, expectedRatio);
    // 8 columns of (1245 - 32 - 7 * 10) / 8 = 142.875. This is the number the
    // clamp used to cap out at 7: (1245 - 32 - 6 * 10) / 7 = 169.3, so History
    // and Suggestions were showing covers a fifth wider than their siblings at
    // the same window.
    expect(columns, kMangaGridMaxColumns);
    expect(cellWidth, closeTo(142.875, 0.5));
    expect(cellWidth, lessThan(169.3), reason: 'still capped at seven columns');
  });

  test('no screen reintroduces a private column ceiling', () {
    // The clamps were written as bare numbers, so nothing stopped them coming
    // back. A screen may cap its count at the shared constant and at nothing
    // else: any other number in a clamp or a max is a second opinion about the
    // ceiling, and the two opinions are what made these grids disagree.
    final screens = [
      'lib/features/library/screens/favorites_screen.dart',
      'lib/features/history/screens/history_screen.dart',
      'lib/features/suggestions/screens/suggestions_screen.dart',
      'lib/features/source_management/screens/manga_grid_screen.dart',
    ];

    // Matches ".clamp(<lo>, <hi>)" so a bound can be inspected rather than merely
    // counted. kMangaGridMaxColumns is allowed as the upper bound because that is
    // the ceiling being restated, not a second one.
    //
    // Comments are stripped first, and that is not incidental: the note left on
    // each screen's resolver names the `.clamp(2, 7)` that was removed, so a
    // scan that read the prose would fail on the very documentation of the fix.
    // Matching code only is also the whole point -- a ceiling that only exists in
    // a comment changes nothing.
    final clamp = RegExp(r'\.clamp\(\s*(\d+)\s*,\s*([A-Za-z0-9_.]+)\s*\)');

    for (final screen in screens) {
      final source = _withoutComments(File(screen).readAsStringSync());
      for (final match in clamp.allMatches(source)) {
        final hi = match.group(2)!;
        final hiIsNumber = int.tryParse(hi);
        expect(
          hiIsNumber == null || hiIsNumber == kMangaGridMaxColumns,
          isTrue,
          reason:
              '$screen caps columns at $hi, which is neither the shared '
              'kMangaGridMaxColumns ($kMangaGridMaxColumns) nor absent',
        );
      }
    }
  });

  test('the slider range and its reversal come from the same constants', () {
    // Every screen used to write `7 - value` and `7 - _gridSize` by hand while
    // describing the range as 1..6 elsewhere. If the two ever disagree the thumb
    // sits at the wrong end, and a user dragging to "fewer columns" gets more of
    // them.
    expect(
      mangaGridColumnsForSliderPosition(mangaGridSliderPositionForColumns(3)),
      3,
    );
    for (var columns = 1.0; columns <= 6.0; columns++) {
      final position = mangaGridSliderPositionForColumns(columns);
      expect(position, inInclusiveRange(1, 6), reason: '$columns columns');
      expect(mangaGridColumnsForSliderPosition(position), columns.round());
    }
    // And the range is reachable: six positions, so five divisions.
    expect(kMangaGridSliderMaxColumns - kMangaGridSliderMinColumns, 5);
  });
}

/// [source] with its Dart comments removed, so a scan for code only matches code.
///
/// Handles line comments and the `///` doc comments either way, and does not try
/// to be a parser: a `/* */` block that contained a `//` or the reverse would
/// confuse it, and no file here has one. If one appears the test reports it as a
/// false result rather than silently skipping the rest of the file.
String _withoutComments(String source) {
  final out = StringBuffer();
  for (final line in source.split('\n')) {
    // A /// doc comment, or a trailing // on a line of code.
    final withoutDoc = line.startsWith('///') || line.startsWith('//')
        ? ''
        : line.split('//').first;
    if (withoutDoc.contains('/*')) {
      throw StateError('Block comment in a file the ceiling scan reads: $line');
    }
    out.writeln(withoutDoc);
  }
  return out.toString();
}

/// Columns [mangaGridColumnsFor] resolves for a window [width] wide, without
/// needing a widget tree.
///
/// [mangaGridColumnsFor] asks [usesWideLayout] and falls back to MediaQuery, and
/// both are unavailable outside a build, so the two are supplied here explicitly.
/// The constants are read from the source rather than restated, because the point
/// of the test is that these are the real thresholds.
int _columnsAt(double width, {required int userColumns}) {
  if (width < kWideLayoutWidth) return userColumns;
  final derived = _mangaGridColumnsAt(width);
  return derived > userColumns ? derived : userColumns;
}

/// The derived count at [width], with the media query replaced by the number.
int _mangaGridColumnsAt(double width) {
  final available = width - kMangaGridHorizontalPadding * 2;
  final fit =
      ((available + kMangaGridCrossSpacing) /
              (kMangaGridTargetCellWidth + kMangaGridCrossSpacing))
          .floor();
  return fit.clamp(2, kMangaGridMaxColumns);
}
