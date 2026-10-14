import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';

import 'package:yomou/widgets/m3_components.dart';

/// Every single-select picker in Settings is this one sheet: a row per choice
/// with a plain check on the current one, and nothing else.
///
/// Two things went wrong on device that these pin: picker sheets carried a
/// Cancel button even though tapping a row already applies the choice and
/// closes the sheet, and a few pickers drew a radio or a circled box next to
/// every option instead of the plain tick the appearance sheets use.
void main() {
  /// Opens the sheet and returns a reader for the value it hands back once a
  /// row is tapped (null until then).
  Future<String? Function()> open(
    WidgetTester tester, {
    String selected = 'rtl',
  }) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showM3OptionSheet<String>(
                    context,
                    title: 'Default mode',
                    options: const [
                      ('standard', 'Standard'),
                      ('rtl', 'Right to left'),
                      ('webtoon', 'Webtoon'),
                    ],
                    selected: selected,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  testWidgets('offers one row per option and no Cancel button', (tester) async {
    await open(tester);

    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Right to left'), findsOneWidget);
    expect(find.text('Webtoon'), findsOneWidget);

    // The whole point: there is nothing to cancel. Tapping a row is the action.
    expect(find.text('Cancel'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('ticks the current option and no other', (tester) async {
    await open(tester, selected: 'rtl');

    Finder tickIn(String label) => find.descendant(
          of: find.widgetWithText(ListTile, label),
          matching: find.byIcon(RemixIcons.check_line),
        );

    expect(tickIn('Right to left'), findsOneWidget);
    expect(tickIn('Standard'), findsNothing);
    expect(tickIn('Webtoon'), findsNothing);
    // Exactly one tick overall, so an option cannot be double-marked.
    expect(find.byIcon(RemixIcons.check_line), findsOneWidget);

    // Not the circled box or the radio the old pickers drew.
    expect(find.byIcon(RemixIcons.checkbox_circle_fill), findsNothing);
    expect(find.byIcon(RemixIcons.checkbox_circle_line), findsNothing);
    expect(find.byIcon(RemixIcons.radio_button_line), findsNothing);
  });

  testWidgets('tapping a row returns its value and closes the sheet', (
    tester,
  ) async {
    final result = await open(tester, selected: 'rtl');
    // The future has not resolved yet -- the sheet is still open.
    expect(find.text('Default mode'), findsOneWidget);

    await tester.tap(find.text('Webtoon'));
    await tester.pumpAndSettle();

    expect(result(), 'webtoon');
    expect(find.text('Default mode'), findsNothing);
  });
}
