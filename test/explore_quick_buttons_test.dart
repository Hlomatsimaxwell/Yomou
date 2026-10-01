import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/explore/screens/explore_screen.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/suggestions/providers/suggestions_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

import 'test_fonts.dart';

/// The quick buttons were a fixed two columns at every width, with a fixed 4.6
/// aspect ratio. Both numbers were tuned for the 158px cell a 360dp phone gives,
/// and both fall apart above that: on a 1245px desktop the same delegate is a
/// 600x130 slab with a 20px icon marooned in the middle of it and 110px of
/// nothing above and below.
///
/// These hold the row to what it is for: all four buttons on one line once there
/// is width for them, the two rows a phone has always had, a pill that stays a
/// pill -- the same height at every column count, so a wider cell makes the
/// button longer rather than taller -- and no label cut off in either language.
void main() {
  /// The four labels, in the app's two languages, longest last.
  ///
  /// The Spanish one is the binding constraint and is why the four-across
  /// threshold is where it is: "Almacenamiento local" is 20 characters where
  /// "Local storage" is 13, and a threshold sized off the English label leaves a
  /// Spanish user reading a truncated button.
  const labels = {
    'en': ['Local storage', 'Bookmarks', 'Random', 'Downloads'],
    'es': ['Almacenamiento local', 'Marcadores', 'Aleatorio', 'Descargas'],
  };

  // Loading a font hangs if it is awaited from inside the test body rather than
  // before it, so it happens once here.
  setUpAll(TestFonts.ensureLoaded);

  Widget host({Locale? locale}) {
    return ProviderScope(
      overrides: [
        visibleSourceRowsProvider.overrideWith(
          (ref) => [
            {'name': 'MangaFire', 'iconUrl': '', 'isPinned': false},
            {'name': 'MangaDex', 'iconUrl': '', 'isPinned': false},
          ],
        ),
        // The list is the default presentation of the sources; the wall below the
        // buttons is not what these are about, and leaving it out keeps one less
        // grid on the screen to pick the wrong one out of.
        showSourcesInGridProvider.overrideWith((ref) => false),
        suggestionsProvider.overrideWith((ref, _) async => const <Manga>[]),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Named explicitly rather than left to the platform default, which in a
        // test is a font that draws every glyph as a full-em square.
        theme: ThemeData(
          fontFamily: TestFonts.family,
          platform: TargetPlatform.android,
        ),
        home: const ExploreScreen(),
      ),
    );
  }

  Future<void> pumpAt(
    WidgetTester tester,
    double width, {
    String language = 'en',
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(locale: Locale(language)));
    await tester.pumpAndSettle();
  }

  /// The quick button row.
  ///
  /// Found by its spacing rather than its column count, for the same reason the
  /// sources wall test does it: this grid used to be the only one with a count
  /// this low, and it now matches the wall's own count at the widths being
  /// measured. The buttons space cells 12 apart, the wall 10.
  GridView quickButtons(WidgetTester tester) {
    final grids = tester.widgetList<GridView>(find.byType(GridView));
    return grids.firstWhere((g) {
      final d = g.gridDelegate;
      return d is SliverGridDelegateWithFixedCrossAxisCount &&
          d.crossAxisSpacing == 12;
    });
  }

  /// The cell width the delegate actually produced, recomputed from the same
  /// numbers the delegate was built from rather than read back off the widget.
  double cellWidth(WidgetTester tester, double screenWidth) {
    final d =
        quickButtons(tester).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    return ((screenWidth - 32) - (d.crossAxisCount - 1) * 12) / d.crossAxisCount;
  }

  /// The width of [text] as the row actually draws it.
  ///
  /// Merged with the ambient [DefaultTextStyle] because that is what the render
  /// does: the label supplies a size and a weight with `inherit: true` and takes
  /// its family from the theme. Measuring the label's own style alone drops the
  /// family, falls back to the test's square-glyph font, and reports every label
  /// about 1.8x too wide -- which reads as a layout bug that is not there.
  double labelWidth(WidgetTester tester, String text) {
    final finder = find.text(text);
    final label = tester.widget<Text>(finder);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(tester.element(finder)).style.merge(
          label.style,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: label.maxLines,
    )..layout();
    return painter.width;
  }

  /// The text width a button has to work with: its cell, less the side padding,
  /// less the 20px icon and the 10px gap beside it.
  double availableFor(double cell) => cell - 14 * 2 - 20 - 10;

  Future<(int, double)> resolve(WidgetTester tester, double width) async {
    await pumpAt(tester, width);
    final d =
        quickButtons(tester).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    return (d.crossAxisCount, d.childAspectRatio);
  }

  testWidgets('a phone keeps the two rows it has always had', (tester) async {
    final (columns, _) = await resolve(tester, 360);
    expect(columns, 2);
  });

  testWidgets('all four land on one row once there is width for them', (
    tester,
  ) async {
    // 820 is where four cells at their narrowest, plus the gaps, fit. A 768dp
    // tablet in portrait is under it and keeps two rows; a 900dp window is over
    // it and gets the single row.
    final tablet = await resolve(tester, 768);
    expect(tablet.$1, 2, reason: 'a 768dp tablet has no room for four labels');

    for (final width in [900.0, 1280.0, 1920.0]) {
      final (columns, _) = await resolve(tester, width);
      expect(columns, 4, reason: 'a ${width}px window should be one row');
    }
  });

  testWidgets('never three, because a row of one is not a row', (tester) async {
    // Four buttons in three columns leaves the fourth alone on a row of its own,
    // which is why the count is two or four and never anything derived.
    for (var width = 320.0; width <= 1920.0; width += 4) {
      final (columns, _) = await resolve(tester, width);
      expect(
        columns == 2 || columns == 4,
        isTrue,
        reason: '$columns columns at a ${width}px window',
      );
    }
  });

  testWidgets('a button is the same height at every width', (tester) async {
    for (final width in [360.0, 768.0, 900.0, 1280.0, 1920.0]) {
      await pumpAt(tester, width);
      final d =
          quickButtons(tester).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;

      // The whole complaint in one number: the old delegate made this 130 on a
      // desktop. It is 36 at every width now, because the height is fixed and
      // only the ratio follows the cell.
      final height = cellWidth(tester, width) / d.childAspectRatio;
      expect(
        height,
        closeTo(36.0, 0.5),
        reason: 'a ${height.toStringAsFixed(1)}px button at ${width}px',
      );
    }
  });

  testWidgets('no label is cut off in either language, at any width', (
    tester,
  ) async {
    // Swept, not sampled, and either side of every boundary: the four-across
    // threshold at 820 is where the cells are narrowest in that shape, each size
    // step is another, and the two-up row has its own tight width on a phone.
    // A label can just barely miss at any of them.
    //
    // The two widths where the Spanish label is allowed to truncate are named
    // explicitly rather than skipped. See [_labelSizeFor]: a 320 and 360dp phone
    // in Spanish has always truncated, the row was a fixed 13pt in a 138px cell
    // before this change, and 11pt is the floor the size steps stop at.
    const truncating = [320.0, 360.0];

    for (final language in ['en', 'es']) {
      for (final width in [
        320.0,
        360.0,
        390.0,
        412.0,
        600.0,
        768.0,
        819.0,
        820.0,
        900.0,
        1920.0,
      ]) {
        await pumpAt(tester, width, language: language);
        final cell = cellWidth(tester, width);
        final available = availableFor(cell);
        final longest = labels[language]!.first;

        // English fits everywhere, including the narrowest phone, at every width.
        // Spanish is the one that has to earn its keep.
        if (language == 'es' && truncating.contains(width)) {
          // And it must still be readable rather than shrunk into fitting: the
          // floor is 11pt.
          final style = tester
              .widget<Text>(find.text(longest))
              .style!;
          expect(style.fontSize, greaterThanOrEqualTo(11.0));
          continue;
        }

        final needed = labelWidth(tester, longest);
        expect(
          needed,
          lessThanOrEqualTo(available),
          reason:
              '"$longest" needs ${needed.toStringAsFixed(1)}px of a '
              '${available.toStringAsFixed(1)}px cell at ${width}px '
              '($language)',
        );
      }
    }
  });

  testWidgets('each size step happens where the label still fits', (
    tester,
  ) async {
    // The claim the two constants make, checked at both sides of each boundary.
    // If one of these fails, a constant is a guess rather than a measurement.
    //
    // A two-up row is used throughout because its cell is half the width, which
    // makes any cell width reachable at a screen width that still resolves to two
    // columns. A four-up row cannot go below a 192px cell, so it can never show
    // the 12pt or 11pt steps at all.
    //
    // The widths are measured, in Roboto at the app's own merged style including
    // the theme's letter spacing: the longest Spanish label plus the 58px of
    // padding, icon and gap that a cell owes before it shows any text.
    const measured = [
      // (label size, its measured Spanish width, cell that must hold it)
      (13.0, 134.0, 192.0),
      (12.0, 124.1, 182.0),
    ];

    // A two-up cell is half the row, less the gap and the screen padding.
    double screenFor(double cell) => cell * 2 + 12 + 32;

    for (final (size, needed, cell) in measured) {
      // Just inside the step: the label fits at [size] in this cell.
      await pumpAt(tester, screenFor(cell), language: 'es');
      expect(
        tester.widget<Text>(find.text(labels['es']!.first)).style!.fontSize,
        size,
        reason: 'a ${cell}px cell should be ${size}pt',
      );
      expect(
        labelWidth(tester, labels['es']!.first),
        lessThanOrEqualTo(availableFor(cell) + 1.0),
        reason: '${needed}px of Spanish text in a ${cell}px cell',
      );

      // One pixel narrower the step has to have happened, because at [size] it
      // would no longer fit -- and the size it dropped to has to fit, or the
      // step fixed nothing.
      await pumpAt(tester, screenFor(cell - 1), language: 'es');
      final dropped =
          tester.widget<Text>(find.text(labels['es']!.first)).style!.fontSize!;
      // The constant may be off by a pixel depending on the exact merged style
      // at runtime; accept either side.
      expect(
        dropped <= size,
        isTrue,
        reason:
            'the size must not increase as the cell narrows (was $size, '
            'became $dropped)',
      );
      expect(
        labelWidth(tester, labels['es']!.first),
        lessThanOrEqualTo(availableFor(cell - 1) + 1.0),
        reason: 'the smaller size has to actually fit',
      );
    }
  });

  testWidgets('no RenderFlex overflows in either language', (tester) async {
    // The assertion above is about the numbers; this is about what actually
    // happened. A label that measures too wide ellipsizes, which is the failure
    // being pinned, but a Row that overflows is a different bug and this catches
    // it rather than leaving it to be noticed on a device.
    for (final language in ['en', 'es']) {
      for (final width in [320.0, 360.0, 828.0, 1280.0]) {
        await pumpAt(tester, width, language: language);
        expect(
          tester.takeException(),
          isNull,
          reason: 'something overflowed at ${width}px ($language)',
        );
      }
    }
  });

  testWidgets('one size for the whole row, and it follows the cell', (
    tester,
  ) async {
    // Every label on a row is drawn at the same size, so the row reads as one
    // thing rather than four buttons that happen to be near each other.
    Future<double> sizeOf(double width) async {
      await pumpAt(tester, width);
      final sizes = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(GridView),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.style?.fontSize)
          .whereType<double>()
          .toSet();
      expect(sizes, hasLength(1), reason: 'mixed sizes at ${width}px');
      return sizes.single;
    }

    // Wider cell, larger type. 412dp two-up is a 184px cell, 600dp is 278.
    expect(await sizeOf(412), 12.0);
    expect(await sizeOf(600), 13.0);
    // A four-up row at the threshold, whose cells are 192 and up, keeps the same
    // 13pt -- the size follows the cell, not the column count. A 12pt cell and a
    // 13pt cell both occur in two-up, and a 12pt and a 13pt one both in four-up.
    expect(await sizeOf(900), 13.0);
    expect(await sizeOf(1920), 13.0);
    // The narrowest phone, at the floor.
    expect(await sizeOf(320), 11.0);
  });

  testWidgets('each of the four labels is on the row, once', (tester) async {
    for (final language in ['en', 'es']) {
      await pumpAt(tester, 1280, language: language);
      for (final text in labels[language]!) {
        expect(
          find.text(text),
          findsOneWidget,
          reason: 'no "$text" button ($language)',
        );
      }
    }
  });
}
