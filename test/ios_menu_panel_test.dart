import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';

/// The overflow menu is an options list, so on a wide window it presents the way
/// the List options panel does: anchored to the right edge, over the page rather
/// than across the middle of it. A phone keeps the bottom sheet.
void main() {
  Future<void> openMenu(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showIosMenuPanel<void>(
                  context,
                  children: [
                    IosMenuRow(
                      icon: MdiIcons.refresh,
                      label: 'Refresh',
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a wide window anchors the menu to the right edge', (
    tester,
  ) async {
    await openMenu(tester, const Size(1280, 800));

    // A centred 520 panel would put this row near the middle of the window
    // (x ~ 432); the right-edge panel starts past the halfway point.
    expect(tester.getRect(find.text('Refresh')).left, greaterThan(640));
  });

  testWidgets('a phone keeps the bottom sheet', (tester) async {
    await openMenu(tester, const Size(400, 800));

    // Same row, same window height: still a full-width sheet at the bottom.
    expect(tester.getRect(find.text('Refresh')).left, lessThan(200));
  });
}
