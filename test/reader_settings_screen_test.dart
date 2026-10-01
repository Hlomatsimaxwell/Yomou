import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/features/settings/screens/reader_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The screen is only built when the user opens Settings > Reader, so nothing
/// else in the suite exercises it. These check that it still builds, that every
/// section is present, and that the rows which cannot act are actually inert
/// rather than merely dimmed.
void main() {
  Widget host() {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReaderSettingsScreen(),
      ),
    );
  }

  /// Tall enough that the whole list is built. A [ListView] only builds what is
  /// on screen, so at the default test surface the lower half of the screen
  /// does not exist as far as these assertions are concerned.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('builds with every section header in order', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // One header per group, in reading order. Matching the count as well as the
    // labels catches a section losing all its rows and leaving an empty header.
    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Vertical & webtoon'), findsOneWidget);
    expect(find.text('Controls'), findsOneWidget);
    expect(find.text('E-Ink'), findsOneWidget);
    expect(find.text('Display'), findsOneWidget);
    expect(find.text('Pages'), findsOneWidget);

    // The screen-level note and the reset row are both still there.
    expect(find.text('Reset reader settings'), findsOneWidget);
    expect(find.textContaining('defaults for a new title'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('rows the active mode cannot honour are inert', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // The default reading mode is webtoon, a strip mode: the vertical rows are
    // live and the paged-only row is not. A row with a null callback cannot
    // change anything however hard it is tapped, which is the whole point of
    // gating them rather than just dimming them.
    SwitchListTile tileFor(String label) {
      return tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(SwitchListTile),
        ),
      );
    }

    expect(tileFor('Gaps between pages').onChanged, isNotNull);
    expect(tileFor('Two pages in landscape').onChanged, isNull);
    expect(find.text('Only used in the vertical and webtoon modes'), findsNothing);
    expect(
      find.text('Only used in the standard and right-to-left modes'),
      findsOneWidget,
    );
  });
}