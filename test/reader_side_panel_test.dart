import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/widgets/reader_side_panel.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The panel is a presentation wrapper, so these tests check placement and the
/// header affordances rather than any reader logic: on a wide window the panel
/// is anchored to the right with a titled header and a close button, and on a
/// narrow window the same content comes up as a bottom sheet with neither.
void main() {
  Widget host() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showReaderSidePanel<void>(
                context,
                title: 'Chapters',
                builder: (context) =>
                    const Center(child: Text('panel-body')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('anchors to the right with a header and close button on wide', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await openPanel(tester);

    expect(find.text('panel-body'), findsOneWidget);
    expect(find.text('Chapters'), findsOneWidget);
    expect(find.byIcon(RemixIcons.close_line), findsOneWidget);

    // The body is inside the panel, so on a 1200-wide window it must sit in the
    // right-hand third.
    final rect = tester.getRect(find.text('panel-body'));
    expect(rect.center.dx, greaterThan(1200 * 2 / 3));

    // It is a side panel, not a bottom sheet: no BottomSheet in the tree, and
    // the titled header sits at the top of the window.
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.getRect(find.text('Chapters')).top, lessThan(80));

    // Closing via the header button dismisses the panel.
    await tester.tap(find.byIcon(RemixIcons.close_line));
    await tester.pumpAndSettle();
    expect(find.text('panel-body'), findsNothing);
  });

  testWidgets('falls back to a bottom sheet on a narrow window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await openPanel(tester);

    expect(find.text('panel-body'), findsOneWidget);
    // The sheet shell has no titled header and no explicit close button.
    expect(find.text('Chapters'), findsNothing);
    expect(find.byIcon(RemixIcons.close_line), findsNothing);

    // It really is the bottom-sheet presentation, not the side panel.
    expect(find.byType(BottomSheet), findsOneWidget);
    final rect = tester.getRect(find.text('panel-body'));
    expect(rect.center.dy, greaterThan(400));
  });
}
