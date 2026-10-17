import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The hub is a column of categories with a search over it. These hold the two
/// halves that are easy to get wrong: that a search narrows the list, and that
/// both layouts still lay out once the list is a column with a field on top of
/// it rather than a bare `ListView`.
void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String term) async {
    await tester.tap(find.byIcon(MdiIcons.magnify));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), term);
    await tester.pumpAndSettle();
  }

  testWidgets('the hub no longer offers Content preferences or Reset',
      (tester) async {
    await pump(tester, const Size(500, 4000));

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Reader settings'), findsOneWidget);
    expect(find.text('Content preferences'), findsNothing);
    expect(find.text('Reset'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a search narrows the hub to the rows that match', (tester) async {
    await pump(tester, const Size(500, 4000));

    await search(tester, 'reader');

    expect(find.text('Reader settings'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Downloads'), findsNothing);
    // About is a row like any other, so it falls out of a search it does not
    // answer rather than sitting under every result.
    expect(find.text('About'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty field is not a filter', (tester) async {
    await pump(tester, const Size(500, 4000));

    await search(tester, '');

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Reader settings'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('a search that matches nothing says so', (tester) async {
    await pump(tester, const Size(500, 4000));

    await search(tester, 'zzzz');

    expect(find.text('No settings match'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
  });

  testWidgets('the two-pane hub lays out with the search field in the list pane',
      (tester) async {
    await pump(tester, const Size(1200, 1400));

    // The detail pane opens on the first category, so the Appearance screen is
    // beside the category list.
    expect(find.text('Color Scheme'), findsOneWidget);

    await search(tester, 'reader');

    // The list narrows; the pane keeps the selection it had, because a search
    // is a way to reach a row, not a selection of its own.
    expect(find.text('Reader settings'), findsOneWidget);
    expect(find.text('Color Scheme'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the two-pane hub caps its bar to the menu column and the line '
      'runs to the top', (tester) async {
    await pump(tester, const Size(1200, 1400));

    // The hub's own bar sits inside the menu column: its title and its search
    // action end on the line between the panes rather than out at the window's
    // right edge, so the search belongs to the list it acts on and the detail
    // pane keeps the whole of its own bar.
    final title = tester.getRect(find.text('Settings'));
    final search = tester.getRect(find.byIcon(MdiIcons.magnify));
    expect(title.right, lessThanOrEqualTo(kSettingsCategoryPaneWidth));
    expect(search.right, lessThanOrEqualTo(kSettingsCategoryPaneWidth));

    // The line separating the two sides runs the full height of the screen:
    // it starts at the very top, level with the bar, instead of only under it.
    final divider = tester.getRect(find.byType(VerticalDivider).first);
    expect(divider.top, 0);
    expect(divider.height, 1400);
    expect(divider.left, kSettingsCategoryPaneWidth);

    expect(tester.takeException(), isNull);
  });
}
