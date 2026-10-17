import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/widgets/tab_header.dart';

import 'test_fonts.dart';

/// The header all five tabs share. The app draws edge-to-edge, so nothing
/// above it clears the status bar: the settings' app bar does it by being
/// primary and the side rail with its own SafeArea, and this is the header
/// that has to do it for the screens those do not cover.
void main() {
  setUpAll(TestFonts.ensureLoaded);

  const searchKey = ValueKey('search');

  Future<void> pump(
    WidgetTester tester, {
    required TabHeaderMode mode,
    required double topInset,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(fontFamily: TestFonts.family),
          home: MediaQuery(
            // What the window reports on a 28px status bar.
            data: MediaQueryData(padding: EdgeInsets.only(top: topInset)),
            child: TabHeader(
              mode: mode,
              title: 'Updates',
              searchBar: const Placeholder(key: searchKey),
              body: const SizedBox(key: ValueKey('body')),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'a fixed header sits below the status bar, and only below it',
    (tester) async {
      Future<double> titleTop(double inset) async {
        await pump(tester, mode: TabHeaderMode.fixed, topInset: inset);
        return tester.getTopLeft(find.text('Updates')).dy;
      }

      final clear = await titleTop(0);
      final covered = await titleTop(28);

      // The whole header moves down by exactly the inset -- no more, and no
      // margin on top of it. The app bar it stands in for clears the bar and
      // adds nothing else of its own.
      expect(covered - clear, 28);
      expect(covered, greaterThanOrEqualTo(28));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the collapsing strip clears the bar the same way', (tester) async {
    Future<double> searchTop(double inset) async {
      await pump(tester, mode: TabHeaderMode.collapsing, topInset: inset);
      return tester.getTopLeft(find.byKey(searchKey)).dy;
    }

    expect(await searchTop(28) - await searchTop(0), 28);

    expect(tester.takeException(), isNull);
  });
}
