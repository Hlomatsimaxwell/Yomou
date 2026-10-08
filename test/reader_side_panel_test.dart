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

    // It is a side panel, not a bottom sheet: no BottomSheet in the tree.
    expect(find.byType(BottomSheet), findsNothing);

    // The panel hugs its content instead of filling the window. A short body
    // used to stretch the panel to the full height, leaving a column of empty
    // surface under whatever was actually in it.
    final header = tester.getRect(find.text('Chapters'));
    expect(header.top, greaterThan(100));
    // The header is at the top of the panel, above the body it labels.
    expect(header.top, lessThan(rect.top));

    // Closing via the header button dismisses the panel.
    await tester.tap(find.byIcon(RemixIcons.close_line));
    await tester.pumpAndSettle();
    expect(find.text('panel-body'), findsNothing);
  });

  testWidgets('caps at the window and scrolls when the content is taller', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showReaderSidePanel<void>(
                  context,
                  title: 'Chapters',
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 60; i++) Text('chapter-$i'),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await openPanel(tester);

    // Hugging the content must not mean growing past the window: the panel
    // stops at the window's height and scrolls the rest, and the header stays
    // reachable at the top of it.
    final header = tester.getRect(find.text('Chapters'));
    expect(header.top, lessThan(80));
    expect(tester.takeException(), isNull);
    // The last row is 60 chapters down, so it cannot all be laid out on
    // screen -- it is there, but scrolled out of view.
    expect(find.text('chapter-59'), findsOneWidget);
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
