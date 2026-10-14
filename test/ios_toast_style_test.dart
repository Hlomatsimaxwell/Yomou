import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yomou/core/widgets/ios/ios_toast.dart';

// The toast is inserted into the root overlay, where nothing has put a
// [Material] above it -- so its text used to be laid out with the fallback
// style Flutter reserves for exactly that case: red, monospace, and underlined
// in double yellow. The underline was the visible one ("two yellow lines under
// the text"), and the pill's own color and size hid the rest of it.
TextStyle _resolvedStyle(WidgetTester tester, String message) {
  return tester.renderObject<RenderParagraph>(find.text(message)).text.style!;
}

Future<void> _showToast(WidgetTester tester, String message) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showIosToast(context, message: message),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('show'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('the toast message is not underlined by the fallback style', (
    tester,
  ) async {
    await _showToast(tester, 'Chapter downloaded');
    expect(find.text('Chapter downloaded'), findsOneWidget);

    final style = _resolvedStyle(tester, 'Chapter downloaded');
    expect(style.decoration, isNot(TextDecoration.underline));
    expect(style.decorationColor, isNot(const Color(0xFFFFFF00)));
    // The fallback is monospace at 48; neither should have reached the pill.
    expect(style.fontFamily, isNot('monospace'));
    expect(style.fontSize, 14);

    // Let the toast's timer run out so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Chapter downloaded'), findsNothing);
  });

  testWidgets('the toast action label is clean too', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showIosToast(
                  context,
                  message: 'Removed from library',
                  actionLabel: 'Undo',
                  onAction: () {},
                ),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_resolvedStyle(tester, 'Undo').decoration, isNot(TextDecoration.underline));

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
