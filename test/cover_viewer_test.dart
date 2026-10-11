import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cover_viewer.dart';

/// The detail screen's cover opens a full-screen viewer. These pin the ways out
/// of it -- the close button, a tap on the art, and the back gesture a plain
/// route push already gives -- plus the hero tag that lets the art fly and the
/// save affordance the viewer offers.
void main() {
  Widget host({String? heroTag}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showCoverViewer(
                context,
                // Empty: the image short-circuits to a fallback, so the test
                // never touches the network.
                imageUrl: '',
                title: 'The Title',
                heroTag: heroTag,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester, {String? heroTag}) async {
    await tester.pumpWidget(host(heroTag: heroTag));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the close button dismisses the viewer', (tester) async {
    await open(tester, heroTag: 'cover-tag');

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('The Title'), findsOneWidget);
    // A tag means the art flies out of the cover it was tapped on.
    expect(find.byType(Hero), findsOneWidget);
    // The viewer offers a save action alongside the close button.
    expect(find.byTooltip('Save image'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('a tap on the art dismisses the viewer', (tester) async {
    await open(tester);

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('no tag means no hero flight', (tester) async {
    await open(tester);
    expect(find.byType(Hero), findsNothing);
  });
}
