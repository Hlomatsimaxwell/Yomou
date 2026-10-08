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
                // Column(min), like every sheet in the app. (A Center would
                // fill the loose constraints the panel hands down and stand in
                // for nothing that ships.)
                builder: (context) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('panel-body')],
                  ),
                ),
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

  testWidgets('content that can outgrow the window scrolls itself', (
    tester,
  ) async {
    // The panel never wraps content in a scroll view: that hands the child an
    // unbounded height and crashes any content with an Expanded in it. So tall
    // content must bring its own scroll view, and the panel must cap it at the
    // window's height with the header kept in reach, instead of letting the
    // column run off the bottom of the screen or overflow.
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
                  builder: (context) => SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 60; i++) Text('chapter-$i'),
                      ],
                    ),
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

    // Capped at the window, header on top, nothing overflowing.
    final header = tester.getRect(find.text('Chapters'));
    expect(header.top, lessThan(80));
    expect(tester.takeException(), isNull);
    // The last row is 60 chapters down, so it is laid out but scrolled out of
    // view rather than perching the panel above the window.
    expect(find.text('chapter-59'), findsOneWidget);
  });

  testWidgets('content that flexes gets a bounded height, not a scroll view', (
    tester,
  ) async {
    // The panel used to wrap its content in a SingleChildScrollView so short
    // content could hug the window. That hands the child unbounded height,
    // which is a hard crash for the reader's chapter tray -- its body is a
    // Column with an Expanded in it (the list needs the rest of the height).
    // The panel must instead bound the height and leave scrolling to content
    // that asks for it.
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
                    children: [
                      Expanded(
                        child: Center(child: Text('list-content')),
                      ),
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

    expect(tester.takeException(), isNull);
    // The flexing child filled the bounded height the panel gave it: the
    // header sits at the top of the window again, and the centred text ends
    // up in the middle of the window -- not a few pixels below the header the
    // way a hugging fragment would. The Expanded got real height instead of
    // the infinite height of a scroll view.
    expect(tester.getRect(find.text('Chapters')).top, lessThan(80));
    expect(tester.getRect(find.text('list-content')).center.dy, closeTo(400, 120));
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
