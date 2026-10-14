import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/widgets/sheet_snap.dart';

/// Yomou's two trays are dragged by their header bars, not by the scrollable
/// [DraggableScrollableSheet] hands out, so they snap themselves.
///
/// These pin the behaviour that was wrong on device: a flick used to be able to
/// stop a stop short, a tray dragged down from full screen used to do nothing at
/// all, and a tray dragged most of the way up used to fall back to the halfway
/// point it had already passed.
void main() {
  /// The detail tray's stops: collapsed bar, halfway, full screen.
  const tray = [0.12, 0.5, 1.0];

  /// A flick is thrown well past the threshold of 300 logical pixels per second.
  const flick = 1200.0;

  group('a flick travels one stop', () {
    test('upwards from the collapsed bar', () {
      expect(sheetSnapTarget(size: 0.12, velocity: -flick, stops: tray), 0.5);
    });

    test('upwards again from halfway, all the way to full', () {
      expect(sheetSnapTarget(size: 0.5, velocity: -flick, stops: tray), 1.0);
    });

    test('downwards from full screen, back to halfway', () {
      expect(sheetSnapTarget(size: 1.0, velocity: flick, stops: tray), 0.5);
    });

    test('downwards again from halfway, back to the bar', () {
      expect(sheetSnapTarget(size: 0.5, velocity: flick, stops: tray), 0.12);
    });

    test('and stops at the ends rather than running past them', () {
      expect(sheetSnapTarget(size: 0.95, velocity: -flick, stops: tray), 1.0);
      expect(sheetSnapTarget(size: 0.2, velocity: flick, stops: tray), 0.12);
    });
  });

  group('a drag without a flick settles on the nearer stop', () {
    test('past halfway goes up', () {
      expect(sheetSnapTarget(size: 0.8, velocity: 0, stops: tray), 1.0);
    });

    test('just short of it drops back to it', () {
      expect(sheetSnapTarget(size: 0.6, velocity: 0, stops: tray), 0.5);
    });

    test('towards the bar goes down', () {
      expect(sheetSnapTarget(size: 0.2, velocity: 0, stops: tray), 0.12);
    });

    test('and a lazy drag is not treated as a flick', () {
      // 200 is under the threshold, so the size decides and the tray stays
      // where it was dragged to; the same release thrown at 400 carries on up.
      expect(sheetSnapTarget(size: 0.55, velocity: -200, stops: tray), 0.5);
      expect(sheetSnapTarget(size: 0.55, velocity: -400, stops: tray), 1.0);
    });

    test('a size that has not moved off a stop stays on it', () {
      expect(sheetSnapTarget(size: 0.5, velocity: 0, stops: tray), 0.5);
    });
  });

  group('a tap walks the stops one at a time', () {
    test('the bar opens to halfway, not past it', () {
      expect(sheetNextStop(size: 0.12, stops: tray), 0.5);
    });

    test('halfway opens the rest of the way', () {
      expect(sheetNextStop(size: 0.5, stops: tray), 1.0);
    });

    test('and full screen wraps round to closed', () {
      expect(sheetNextStop(size: 1.0, stops: tray), 0.12);
    });

    test('a tray already past a stop does not fall back to it', () {
      // The tester's report in one line: this is the tray they dragged most of
      // the way up, and it opens rather than dropping to the halfway point.
      expect(sheetNextStop(size: 0.7, stops: tray), 1.0);
    });
  });

  group('and the same walk downwards', () {
    test('full screen closes to halfway, halfway to the bar', () {
      expect(sheetPreviousStop(size: 1.0, stops: tray), 0.5);
      expect(sheetPreviousStop(size: 0.5, stops: tray), 0.12);
    });

    test('the bar, which is already the bottom, wraps to full screen', () {
      expect(sheetPreviousStop(size: 0.12, stops: tray), 1.0);
    });

    test('a tray above a stop skips the ones it has not reached', () {
      expect(sheetPreviousStop(size: 0.9, stops: tray), 0.5);
    });
  });

  test('the stops need not be given in order', () {
    expect(
      sheetSnapTarget(size: 1.0, velocity: flick, stops: [1.0, 0.12, 0.5]),
      0.5,
    );
    expect(sheetNextStop(size: 0.12, stops: [1.0, 0.5, 0.12]), 0.5);
  });
}
