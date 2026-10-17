import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/features/settings/screens/manga_sources_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

import 'test_fonts.dart';

/// The Manga sources pane: the order its groups run in, the two dividers that
/// separate them, and the one rhythm its rows keep.
///
/// The order is Kotatsu's `pref_sources.xml`, which is also where the dividers
/// come from: it marks "Enable all sources" and "Mirror switching" with
/// `allowDividerAbove`, so those two are the only rows that start a group.
///
/// Measurement is in Roboto, the font the app ships: the test framework's
/// fallback draws every glyph a full em wide, which wrapped the long subtitles
/// onto a second line and measured a taller row than the device draws.
void main() {
  setUpAll(TestFonts.ensureLoaded);

  Widget pane() {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(fontFamily: TestFonts.family),
        home: const SettingsPaneScope(child: MangaSourcesSettingsScreen()),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, {Size size = const Size(1400, 4000)}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(pane());
    await tester.pumpAndSettle();
  }

  /// The rows in the order they are laid out.
  List<String> rowTitles(WidgetTester tester) {
    return [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title! as Text).data!,
    ];
  }

  testWidgets('the rows run in the inspo order', (tester) async {
    await pump(tester);

    expect(rowTitles(tester), const [
      'Sorting order',
      'Show in grid view',
      'Manage sources',
      'Enable all manga sources',
      'Sources catalog',
      'Disable NSFW',
      'Incognito mode for NSFW manga',
      'Choose mirror automatically',
      'Handle links',
    ]);

    expect(tester.takeException(), isNull);
  });

  testWidgets('two dividers start the second and third groups', (tester) async {
    await pump(tester);

    final dividers = tester.widgetList<Divider>(find.byType(Divider)).toList();
    expect(dividers, hasLength(2));
    for (final divider in dividers) {
      // 24 for the rule's own box plus the 8 of air a section header keeps
      // above and below its rule, so the line clears the rows on both sides.
      expect(divider.height, 40);
      expect(divider.thickness, 1);
    }

    // Each sits between the row that ends its group and the one that opens the
    // next: after Manage sources, and after Incognito mode. The rule owns the
    // whole break, so the next group starts a full 40 under the last row.
    final rows = {
      for (final title in rowTitles(tester))
        title: tester.getRect(find.widgetWithText(ListTile, title)),
    };
    final rules = [
      for (var i = 0; i < find.byType(Divider).evaluate().length; i++)
        tester.getRect(find.byType(Divider).at(i)),
    ]..sort((a, b) => a.top.compareTo(b.top));

    expect(rules[0].top, rows['Manage sources']!.bottom);
    expect(
      rows['Enable all manga sources']!.top - rows['Manage sources']!.bottom,
      40,
    );
    expect(rules[1].top, rows['Incognito mode for NSFW manga']!.bottom);
    expect(
      rows['Choose mirror automatically']!.top -
          rows['Incognito mode for NSFW manga']!.bottom,
      40,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a row that opens a screen or a sheet carries no chevron',
      (tester) async {
    await pump(tester);

    for (final title in const [
      'Sorting order',
      'Manage sources',
      'Incognito mode for NSFW manga',
    ]) {
      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, title),
      );
      expect(tile.trailing, isNull, reason: title);
    }
    expect(find.byIcon(MdiIcons.chevronRight), findsNothing);
    // The switch rows keep their switch, so the trailing slot is not just
    // universally empty.
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Handle links')).trailing,
      isA<Switch>(),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('every switch row says what the switch does', (tester) async {
    await pump(tester);

    for (final subtitle in const [
      'All available manga sources will be enabled permanently',
      'Disable NSFW sources and hide adult manga from list if possible',
      'Automatically switch domains for manga sources on errors if mirrors are available',
      "Handle manga links from external applications (e.g. web browser). "
          "You may also need to enable it manually in the application's system settings",
    ]) {
      expect(find.text(subtitle), findsOneWidget, reason: subtitle);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('the title and the row icons share a guide, 12 under the bar',
      (tester) async {
    await pump(tester);

    final title = tester.getTopLeft(find.text('Manga sources')).dx;
    final icon = tester.getTopLeft(find.byIcon(MdiIcons.sortAscending)).dx;
    expect(title, icon, reason: 'the pane title against a row icon');

    // The pane's rows are the same height as every other settings pane's, and
    // the first of them starts 12 under the bar.
    for (final title in rowTitles(tester)) {
      expect(
        tester.getRect(find.widgetWithText(ListTile, title)).height,
        SettingsRows.rowHeight,
        reason: title,
      );
    }
    final bar = tester.getRect(find.byType(AppBar));
    final first = tester.getRect(
      find.widgetWithText(ListTile, 'Sorting order'),
    );
    expect(first.top - bar.bottom, 12);

    expect(tester.takeException(), isNull);
  });
}
