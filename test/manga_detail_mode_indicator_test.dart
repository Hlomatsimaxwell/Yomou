import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';

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

  test('a single-tab control centres its indicator instead of dividing by zero', () {
    expect(modeSegmentIndicatorAlignment(0, 1), Alignment.center);
    expect(modeSegmentIndicatorAlignment(0, 0), Alignment.center);
  });
}
