import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/features/settings/screens/manga_sources_settings_screen.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';
import 'package:yomou/features/source_management/screens/manga_sources_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The sources list is a screen the reader reaches from two places -- the
/// Manga sources pane's own row, and Explore's own manage action -- and it is a
/// detail of that settings section rather than a page of its own. These hold the
/// two halves of that: that a window with a settings pane puts it in the pane
/// instead of over the top of it, and that a window without one still gets a
/// page of its own.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size, Widget home) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'a window with a pane opens the sources list in it, over the category',
      (tester) async {
    await pumpAt(tester, const Size(1200, 1400), const SettingsScreen());

    await tester.tap(find.text('Manga sources'));
    await tester.pumpAndSettle();

    expect(find.byType(ManageSourcesScreen), findsNothing);

    await tester.tap(find.text('Manage sources'));
    await tester.pumpAndSettle();

    // The list is beside the screen it opened, not covered by it: the hub's
    // menu column is still the way out of this section.
    expect(find.byType(ManageSourcesScreen), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Reader settings'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the sources list leaves back to the category it opened over',
      (tester) async {
    await pumpAt(tester, const Size(1200, 1400), const SettingsScreen());

    await tester.tap(find.text('Manga sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage sources'));
    await tester.pumpAndSettle();

    // The arrow on the list's own bar, not the hub's -- which has one of its
    // own for leaving settings altogether, on the other side of the divider.
    await tester.tap(
      find.descendant(
        of: find.byType(ManageSourcesScreen),
        matching: find.byIcon(MdiIcons.arrowLeft),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ManageSourcesScreen), findsNothing);
    // Back on this section's own rows, still inside settings.
    expect(find.text('Sorting order'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the system back leaves the sources list before leaving settings',
      (tester) async {
    await pumpAt(tester, const Size(1200, 1400), const SettingsScreen());

    await tester.tap(find.text('Manga sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage sources'));
    await tester.pumpAndSettle();
    expect(find.byType(ManageSourcesScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ManageSourcesScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Sorting order'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a window without a pane still opens it as a page of its own',
      (tester) async {
    await pumpAt(tester, const Size(500, 4000), const SettingsScreen());

    await tester.tap(find.text('Manga sources'));
    await tester.pumpAndSettle();
    expect(find.byType(MangaSourcesSettingsScreen), findsOneWidget);

    await tester.tap(find.text('Manage sources'));
    await tester.pumpAndSettle();

    expect(find.byType(ManageSourcesScreen), findsOneWidget);
    // A phone has no category list to keep beside it, so the row's section is
    // off screen behind this one.
    expect(find.text('Appearance'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('opening the sources list from elsewhere puts it in a pane too',
      (tester) async {
    late BuildContext opened;
    await pumpAt(
      tester,
      const Size(1200, 1400),
      Builder(
        builder: (context) {
          opened = context;
          return const SizedBox();
        },
      ),
    );

    openManageSources(opened);
    await tester.pumpAndSettle();

    // Settings is on screen with this section selected, and the pane is already
    // on the list that was asked for: there is no step between "open the sources
    // list" and having it.
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(ManageSourcesScreen), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('from elsewhere, a window without a pane opens a page',
      (tester) async {
    late BuildContext opened;
    await pumpAt(
      tester,
      const Size(500, 4000),
      Builder(
        builder: (context) {
          opened = context;
          return const SizedBox();
        },
      ),
    );

    openManageSources(opened);
    await tester.pumpAndSettle();

    expect(find.byType(ManageSourcesScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);

    expect(tester.takeException(), isNull);
  });
}
