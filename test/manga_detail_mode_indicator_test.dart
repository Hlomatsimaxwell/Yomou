import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/features/library/widgets/mode_segment_control.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The mode control exists to be *one* control: a single track with a single
/// indicator that slides between Chapters, Pages and Bookmarks.
///
/// Three chips that each light themselves up is a row of buttons however it is
/// dressed, and it was built that way twice before. What makes it a switch is
/// the travel, so the travel is what is pinned here -- an indicator that lands
/// under the wrong label is the kind of bug that looks like a styling choice
/// and survives a visual review.
void main() {
  test('three tabs put the indicator on thirds of the track', () {
    // A one-third-wide indicator inside the track spans the free space from
    // x = -1 to x = 1, so the stops are the two ends and the middle.
    expect(modeSegmentIndicatorAlignment(0, 3), const Alignment(-1, 0));
    expect(modeSegmentIndicatorAlignment(1, 3), const Alignment(0, 0));
    expect(modeSegmentIndicatorAlignment(2, 3), const Alignment(1, 0));
  });

  test('the stops are evenly spaced, not bunched at one end', () {
    // The middle stop has to be exactly between the two ends, or the indicator
    // would visibly lag or overshoot on the way past it.
    final first = modeSegmentIndicatorAlignment(0, 3).x;
    final middle = modeSegmentIndicatorAlignment(1, 3).x;
    final last = modeSegmentIndicatorAlignment(2, 3).x;
    expect(middle - first, closeTo(last - middle, 1e-9));
  });

  test('a fourth or fifth tab still divides the track evenly', () {
    expect(modeSegmentIndicatorAlignment(0, 5).x, -1);
    expect(modeSegmentIndicatorAlignment(1, 5).x, closeTo(-0.5, 1e-9));
    expect(modeSegmentIndicatorAlignment(3, 5).x, closeTo(0.5, 1e-9));
    expect(modeSegmentIndicatorAlignment(4, 5).x, 1);
  });

  test('an out-of-range tab is clamped rather than sliding off the track', () {
    // The selected tab comes from screen state that can briefly outlive the
    // list it indexes into, and an indicator parked outside the track would be
    // a visible glitch rather than a harmless no-op.
    expect(modeSegmentIndicatorAlignment(9, 3), const Alignment(1, 0));
    expect(modeSegmentIndicatorAlignment(-4, 3), const Alignment(-1, 0));
  });

  test('a single-tab control centres its indicator rather than dividing by zero', () {
    expect(modeSegmentIndicatorAlignment(0, 1), Alignment.center);
    expect(modeSegmentIndicatorAlignment(0, 0), Alignment.center);
  });

  // The arithmetic above can be right while the control still renders as three
  // flat labels -- which is exactly what shipped twice: a fill that was the
  // same tone as the track it sat on. So these render it and look at the paint.
  group('rendered', () {
    Future<void> pumpControl(
      WidgetTester tester, {
      required int activeTab,
      Brightness brightness = Brightness.light,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          // The delegates go on the app, not on a wrapping Localizations: an
          // app builds its own Localizations node and would shadow the outer
          // one, leaving AppLocalizations.of() null.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: ModeSegmentControl(
                  activeTab: activeTab,
                  onTabSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      // Settle the slide so the indicator is at its stop, not mid-travel.
      await tester.pumpAndSettle();
    }

    const indicatorKey = ValueKey('modeSegmentIndicator');
    const trackKey = ValueKey('modeSegmentTrack');

    BoxDecoration indicatorOf(WidgetTester tester) {
      return tester.widget<DecoratedBox>(find.byKey(indicatorKey)).decoration
          as BoxDecoration;
    }

    Color trackColorOf(WidgetTester tester) {
      return (tester.widget<Container>(find.byKey(trackKey)).decoration
              as BoxDecoration)
          .color!;
    }

    /// The fill as the eye meets it, which is the fill composited over the
    /// track it sits on -- not the raw colour, whose alpha would otherwise
    /// flatter a translucent fill in dark mode.
    double fillLuminance(WidgetTester tester) {
      final fill = indicatorOf(tester).color!;
      return Color.alphaBlend(fill, trackColorOf(tester)).computeLuminance();
    }

    testWidgets('the active segment has a real fill, not the track colour', (
      tester,
    ) async {
      await pumpControl(tester, activeTab: 0);
      final decoration = indicatorOf(tester);
      // The whole bug in two earlier passes: the fill existed but was the same
      // tone as the track, so there was nothing to see. A fill that equals the
      // track is not a fill.
      expect(decoration.color, isNot(trackColorOf(tester)));
      expect(decoration.borderRadius, isNotNull);
      // And it is raised: without the shadow a white fill on a light track is
      // a patch of slightly different grey, however far apart the two greys are.
      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('the fill is a visible step up from the track', (tester) async {
      await pumpControl(tester, activeTab: 0);
      final track = trackColorOf(tester).computeLuminance();
      // Perceptual distance, not equality: a one-or-two point difference in
      // luminance is the "invisible selection" failure mode again.
      expect(fillLuminance(tester), greaterThan(track + 0.08));
    });

    testWidgets('the fill moves to the selected segment', (tester) async {
      await pumpControl(tester, activeTab: 0);
      final inner = tester.getRect(find.byType(AnimatedAlign));
      final indicatorAtZero = tester.getRect(find.byKey(indicatorKey));
      await pumpControl(tester, activeTab: 2);
      final indicatorAtTwo = tester.getRect(find.byKey(indicatorKey));
      // One segment wide, and parked under the third segment rather than the
      // first. This is the travel that makes it one control.
      expect(indicatorAtZero.width, closeTo(inner.width / 3, 0.5));
      expect(indicatorAtTwo.width, closeTo(inner.width / 3, 0.5));
      expect(indicatorAtTwo.left, greaterThan(indicatorAtZero.left));
      expect(indicatorAtTwo.right, closeTo(inner.right, 1.0));
    });

    testWidgets('dark mode lifts the fill instead of painting it white', (
      tester,
    ) async {
      await pumpControl(tester, activeTab: 1, brightness: Brightness.dark);
      // In dark, a fully opaque white pill would be a glaring hole in the bar:
      // it is a lift off the track, so it stays translucent and still reads
      // lighter than what it sits on.
      expect(indicatorOf(tester).color!.a, lessThan(1.0));
      expect(
        fillLuminance(tester),
        greaterThan(trackColorOf(tester).computeLuminance() + 0.02),
      );
    });
  });
}
