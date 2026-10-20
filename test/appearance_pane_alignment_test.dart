import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/widgets/kotatsu_icon.dart';
import 'package:yomou/features/settings/screens/appearance_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

import 'test_fonts.dart';

/// The appearance pane has one vertical guide: its title, its section labels,
/// the edge of the first scheme card and the leading icon of every row all
/// start on the same line. The parts are inset by different amounts to get
/// there -- the list carries 8, a `ListTile` and a section header add their own
/// 16, and a scheme card adds 12 and then 4 -- so the equality is what is worth
/// pinning down rather than any one of those numbers.
///
/// [pane] renders the screen the way the two-pane layout does, with the pane
/// scope set, because that is the only arrangement where the title is laid out
/// against the pane rather than against the screen.
///
/// Measurement is done in Roboto, the font the app ships and the device draws,
/// not the test framework's square-glyph fallback: that fallback draws every
/// glyph a full em wide, which stretched a card's label past the mockup above
/// it and moved the very edges these tests are about.
void main() {
  setUpAll(TestFonts.ensureLoaded);

  Widget pane() {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The app's own theme turns off the 2023 slider, and the pane's grid
        // row measures a slider: without that here the row would be measured
        // against a slider with a thumb-sized box rather than the 48 Material
        // paints in the app.
        theme: ThemeData(
          fontFamily: TestFonts.family,
          // ignore: deprecated_member_use
          sliderTheme: const SliderThemeData(year2023: false),
        ),
        home: const SettingsPaneScope(child: AppearanceSettingsScreen()),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, {Size size = const Size(1200, 4000)}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(pane());
    await tester.pumpAndSettle();
  }

  /// The x everything in the pane is meant to start on: the pane's content box
  /// plus the 8 the scrolling list contributes.
  double guide(WidgetTester tester) =>
      tester.getTopLeft(find.byType(ListView).first).dx + 24;

  /// The visible surface of the scheme card labelled [name] -- the mockup's own
  /// `Container`, which is the edge the eye reads as the card's, rather than
  /// the tappable box around it.
  Rect card(WidgetTester tester, String name) {
    final gesture = find.ancestor(
      of: find.text(name),
      matching: find.byType(GestureDetector),
    );
    expect(gesture, findsOneWidget, reason: '$name is one card');
    return tester.getRect(
      find.descendant(of: gesture, matching: find.byType(Container)).first,
    );
  }

  /// A section header's own box and the label inside it.
  (Rect, Rect) header(WidgetTester tester, String title) {
    final finder = find.widgetWithText(M3SectionHeader, title);
    return (
      tester.getRect(finder),
      tester.getRect(find.descendant(of: finder, matching: find.byType(Text))),
    );
  }

  testWidgets('the title, the section labels, the first card and the row icons share a guide',
      (tester) async {
    await pump(tester);

    final line = guide(tester);
    expect(tester.getTopLeft(find.text('Appearance')).dx, line,
        reason: 'the pane title');
    expect(tester.getTopLeft(find.text('Color Scheme')).dx, line,
        reason: 'a section label');
    expect(
      tester.getTopLeft(
        find.byWidgetPredicate(
          (w) => w is KotatsuIcon && w.name == 'ic_theme_mode',
        ),
      ).dx,
      line,
      reason: 'a row leading icon',
    );
    expect(card(tester, 'Azure').left, line,
        reason: 'the first scheme card');

    expect(tester.takeException(), isNull);
  });

  testWidgets('the pane title is the screen heading, black and one size up',
      (tester) async {
    await pump(tester);

    final text = tester.widget<Text>(find.text('Appearance'));
    final style = text.style!;
    expect(style.fontSize, 20);
    expect(style.fontWeight, FontWeight.w600);

    final cs = Theme.of(
      tester.element(find.byType(AppearanceSettingsScreen)),
    ).colorScheme;
    expect(style.color, cs.onSurface);
  });

  testWidgets('a row keeps a 16px gap to its label at the pane\'s own height',
      (tester) async {
    await pump(tester);

    // A leading slot is only as wide as its icon here -- 24 -- so the gap the
    // framework adds is the whole of the space between the two.
    final theme = tester.getRect(
      find.byWidgetPredicate((w) => w is KotatsuIcon && w.name == 'ic_theme_mode'),
    );
    expect(theme.right + 16, tester.getRect(find.text('Color mode')).left);

    final grid = tester.getRect(
      find.byWidgetPredicate((w) => w is KotatsuIcon && w.name == 'ic_grid'),
    );
    expect(grid.right + 16, tester.getRect(find.text('Grid size')).left);

    // One height for every row rather than Material's 72 for a row with a
    // subtitle under it and 56 for one without: the tightest that still holds
    // a name and a line of its value, so the pane reads as one list instead of
    // two rhythms.
    expect(
      tester.getRect(find.widgetWithText(ListTile, 'Color mode')).height,
      SettingsRows.rowHeight,
    );
    expect(
      tester
          .getRect(find.widgetWithText(SwitchListTile, 'Collapse long description'))
          .height,
      SettingsRows.rowHeight,
    );

    // The slider row is the one row taller than the rhythm: 48 of slider
    // under the value line is already more than 52.
    expect(
      tester.getRect(find.widgetWithText(ListTile, 'Grid size')).height,
      greaterThan(SettingsRows.rowHeight),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the pane fills the pane it is given instead of a centred cap',
      (tester) async {
    // Wider than the width class's 960 cap: capping inside the pane would
    // centre that cap and leave every trailing switch, and the slider's
    // track, floating in dead space beside the edge they belong on.
    await pump(tester, size: const Size(1400, 4000));

    final list = tester.getRect(find.byType(ListView).first);
    expect(list.left, 0);
    expect(list.right, 1400);

    // The trailing control ends on the pane's own edge rather than 200px in
    // from it: the 8 this list insets itself by, then [SettingsRows]' own 8 at
    // the end (against 16 at the start) so a switch lands near the edge it
    // sits against instead of 24 in from it.
    final toggles = tester.getRect(find.byType(Switch).first);
    expect(toggles.right, 1400 - 8 - SettingsRows.trailingInset);
    expect(tester.getRect(find.text('100%')).right, toggles.right);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the swatch row opens on the guide with 8 between its cards',
      (tester) async {
    await pump(tester);

    final first = card(tester, 'Azure');
    final second = card(tester, 'Violet');
    expect(first.left, guide(tester), reason: 'the first card');
    expect(second.left - first.right, 8, reason: 'the gap between two cards');

    // The cards sit 12 under their heading, which is the heading's own trailing
    // space: the carousel adds none of its own above them.
    final (headerBox, headerText) = header(tester, 'Color Scheme');
    final carousel = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      ),
    );
    expect(headerText.bottom + 16, carousel.top);
    expect(carousel.top, headerBox.bottom);
  });

  testWidgets('every section label keeps one 24/16 rhythm and draws a rule only above a grouped one',
      (tester) async {
    await pump(tester);

    for (final title in const [
      'Color Scheme',
      'Effects',
      'Manga List',
      'Details',
      'Main Screen',
      'Privacy',
    ]) {
      final (box, text) = header(tester, title);
      final headerFinder = find.widgetWithText(M3SectionHeader, title);
      final hasRule = tester
          .widgetList(
            find.descendant(of: headerFinder, matching: find.byType(ColoredBox)),
          )
          .isNotEmpty;
      if (title == 'Color Scheme') {
        expect(hasRule, isFalse, reason: 'opens the pane: no rule above $title');
        expect(text.top - box.top, 24, reason: 'above $title');
      } else {
        expect(hasRule, isTrue, reason: 'groups: rule above $title');
        expect(text.top - box.top, 33, reason: 'above $title, rule + 8 pad + 24');
      }
      expect(box.bottom - text.bottom, 16, reason: 'under $title');
    }

    // "Manga List" divides the pane in half and used to buy itself a wider
    // break on top of the shared one. It no longer does: the row above it --
    // Haptics, last of the Effects group -- ends exactly where the heading's
    // own box starts, so the heading is the whole of the space between the
    // two halves.
    expect(
      tester.getRect(find.widgetWithText(M3SectionHeader, 'Manga List')).top,
      tester
          .getRect(find.widgetWithText(SwitchListTile, 'Haptics'))
          .bottom,
    );
    expect(
      tester.getRect(find.widgetWithText(M3SectionHeader, 'Details')).top,
      tester.getRect(find.widgetWithText(SwitchListTile, 'Badges in lists')).bottom,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the grid size row reads its name and value as two ends of one line',
      (tester) async {
    await pump(tester);

    // The setting keeps its own label instead of one interpolated string.
    expect(find.text('Grid size'), findsOneWidget);
    expect(find.text('Grid size: 100%'), findsNothing);
    expect(find.text('100%'), findsOneWidget);

    // Name and value share a baseline; the slider is the line under them.
    final name = tester.getCenter(find.text('Grid size'));
    final value = tester.getCenter(find.text('100%'));
    expect((name.dy - value.dy).abs(), lessThan(2));
    expect(name.dx, lessThan(value.dx));

    final slider = tester.getRect(find.byType(Slider));
    expect(slider.top, greaterThan(name.dy));

    // The value and the track end on the row's own trailing edge, which is the
    // edge the switches further down the pane sit their thumbs on.
    final toggles = tester.getRect(find.byType(Switch).first);
    expect(tester.getRect(find.text('100%')).right, toggles.right);
    expect(slider.right, toggles.right);

    // And the track itself ends 16 short of the row's edge.
    final sliderBox = tester.renderObject<RenderBox>(find.byType(Slider));
    final sliderTheme = SliderTheme.of(tester.element(find.byType(Slider)));
    expect(sliderTheme.padding, const EdgeInsets.only(right: 16));
    final track = const GappedSliderTrackShape().getPreferredRect(
      parentBox: sliderBox,
      sliderTheme: sliderTheme.copyWith(
        trackHeight: sliderTheme.trackHeight ?? 4,
        thumbShape: const HandleThumbShape(),
        overlayShape: const RoundSliderOverlayShape(),
      ),
      isEnabled: true,
    );
    expect(track.left, 0);
    expect(track.right, sliderBox.size.width);

    expect(tester.takeException(), isNull);
  });
}
