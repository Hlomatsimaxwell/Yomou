import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/features/settings/screens/appearance_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The colour-scheme carousel draws a miniature of the app in each preset's
/// own colours rather than an abstract badge. These hold it to the shape that
/// makes that readable: every preset is present, five mockups are built, and
/// the taller cards still lay out without overflowing their carousel.
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

  /// Wide enough for all five swatches to be built: a horizontal [ListView]
  /// only builds what fits, so a narrow surface would hide later presets.
  void useWideSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('every preset renders as a mini app mockup', (tester) async {
    SharedPreferences.setMockInitialValues({});
    useWideSurface(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    for (final name in [
      'Totoro',
      'Dynamic',
      'Expressive',
      'Miku',
      'Monochrome',
    ]) {
      expect(find.text(name), findsOneWidget);
    }

    // One title placeholder per swatch: the mockup is drawn, not stubbed out.
    expect(find.text('Abc'), findsNWidgets(5));

    expect(tester.takeException(), isNull);
  });
}
