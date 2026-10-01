import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/screens/favorites_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// Favourites had its own idea of what a manga card is: a fixed 12pt title, a
/// cell measured for that 12pt, a heart drawn inline that ignored the list
/// badges setting, and covers requested at infinite width, which is the one
/// size the decode cap refuses. Every other grid derives all four from
/// [mangaCardTitleFontSize] and [mangaCellAspectRatio]; these hold this one to
/// the same pair, at both ends of the column range.
void main() {
  const titles = [
    'A Title Long Enough To Need Two Lines In A Narrow Cell',
    'Short One',
    'Another Fairly Long Title Here',
    'Fourth',
  ];

  Widget host() {
    return ProviderScope(
      overrides: [
        favoritesProvider.overrideWith(
          (ref) async => [
            for (var i = 0; i < titles.length; i++)
              Manga(
                id: 'id$i',
                title: titles[i],
                coverUrl: '',
                sourceId: '0',
              ),
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

  /// Pumps at [width] and returns the resolved column count, the font size the
  /// titles are drawn at, and whether the cell was measured at that same size.
  Future<(int, double, bool)> measure(
    WidgetTester tester,
    double width,
  ) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    final columns = delegate.crossAxisCount;

    final titleStyle = tester.widget<Text>(
      find.text(titles.first),
    ).style!;

    // The width the grid actually resolves its cells against: the 16px of
    // horizontal padding the sliver adds, taken off the window.
    final context = tester.element(find.byType(SliverGrid));
    final expected = mangaCellAspectRatio(
      context,
      columns: columns,
      titleFontSize: mangaCardTitleFontSize(columns),
    );

    return (columns, titleStyle.fontSize!, delegate.childAspectRatio == expected);
  }

  testWidgets('narrow window: three columns, titles at 12pt', (tester) async {
    final (columns, fontSize, measuredAtFontSize) = await measure(tester, 360);

    expect(columns, 3);
    expect(fontSize, mangaCardTitleFontSize(3));
    expect(fontSize, 12);
    // A cell measured at one size and drawn at another clips the second line of
    // every title long enough to need one, so both come from the same call.
    expect(
      measuredAtFontSize,
      isTrue,
      reason: 'cell was not measured at the drawn font size',
    );
  });

  testWidgets('wide window: titles shrink and the cell follows', (
    tester,
  ) async {
    final (columns, fontSize, measuredAtFontSize) = await measure(tester, 1280);

    expect(columns, greaterThanOrEqualTo(kMangaCardCompactColumns));
    expect(fontSize, mangaCardTitleFontSize(columns));
    expect(fontSize, 10);
    expect(
      measuredAtFontSize,
      isTrue,
      reason: 'cell was not measured at the drawn font size',
    );
  });

  testWidgets('no cover asks for an infinite width', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // The decode cap rejects infinity and hands back the full source image, so
    // every favourite in the grid was being pulled in at source resolution.
    final covers = tester.widgetList<CachedMangaImage>(
      find.byType(CachedMangaImage),
    );
    expect(covers, isNotEmpty);
    for (final cover in covers) {
      expect(
        cover.width,
        isNot(double.infinity),
        reason: 'cover requested at infinite width',
      );
      expect(cover.height, isNot(double.infinity));
    }
  });
}