import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/features/settings/screens/appearance_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The colour-scheme carousel draws a miniature of the app in each preset's
/// own colours rather than an abstract badge. These hold it to the shape that
/// makes that readable: every preset is present, one mockup is built per
/// preset, and the taller cards still lay out without overflowing their
/// carousel.
void main() {
  Widget host() {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppearanceSettingsScreen(),
      ),
    );
  }

  /// Room for the settings list underneath. The carousel itself is inside a
  /// width-capped column, so it can never show all twelve at once; the test
  /// scrolls it rather than pretending a wider window would do it.
  void useWideSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  const presets = [
    'Totoro',
    'Dynamic',
    'Expressive',
    'Miku',
    'Monochrome',
    'Asuka',
    'Mion',
    'Rikka',
    'Sakura',
    'Mamimi',
    'Kanade',
    'Itsuka',
  ];

  testWidgets('every preset renders as a mini app mockup', (tester) async {
    SharedPreferences.setMockInitialValues({});
    useWideSurface(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final carousel = find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.horizontal,
    );
    expect(carousel, findsOneWidget);

    // Walk the carousel collecting the preset names it builds, rather than
    // asserting each one is on screen at once.
    final seen = <String>{};
    for (var i = 0; i < 12 && seen.length < presets.length; i++) {
      seen.addAll(
        presets.where((name) => find.text(name).evaluate().isNotEmpty),
      );
      await tester.drag(carousel, const Offset(-320, 0));
      await tester.pumpAndSettle();
    }
    expect(seen, presets.toSet());

    // The mockups are drawn, not stubbed out: the swatches carry the fake
    // app's own title text.
    expect(find.text('Abc'), findsAtLeastNWidgets(3));

    expect(tester.takeException(), isNull);
  });
}
