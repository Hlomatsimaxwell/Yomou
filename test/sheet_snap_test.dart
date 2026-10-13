import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/widgets/sheet_snap.dart';

/// Yomou's two trays are dragged by their header bars, not by the scrollable
/// [DraggableScrollableSheet] hands out, so they snap themselves.
///
/// These pin the behaviour that was wrong on device: a flick used to be able to
/// stop a stop short, and a tray dragged down from full screen used to do
/// nothing at all. A flick now always travels one stop, and a drag let go
/// without a flick settles on the nearer of the two it sits between.
void main() {
  /// The tray's stops: collapsed bar, half, full screen.
  const tray = [0.12, 0.5, 1.0];

  /// A flick is thrown well past the threshold; 300 logical pixels per second.
  const flick = 1200.0;

  group('a flick travels one stop', () {
    test('upwards from the collapsed bar', () {
      expect(sheetSnapTarget(size: 0.12, velocity: -flick, stops: tray), 0.5);
    });

    test('upwards again from the half state, all the way to full', () {
      expect(sheetSnapTarget(size: 0.5, velocity: -flick, stops: tray), 1.0);
    });

    test('downwards from full screen, back to half', () {
      expect(sheetSnapTarget(size: 1.0, velocity: flick, stops: tray), 0.5);
    });

    test('downwards again from half, back to the bar', () {
      expect(sheetSnapTarget(size: 0.5, velocity: flick, stops: tray), 0.12);
    });

    test('and stops at the ends rather than running past them', () {
      expect(sheetSnapTarget(size: 0.95, velocity: -flick, stops: tray), 1.0);
      expect(sheetSnapTarget(size: 0.2, velocity: flick, stops: tray), 0.12);
    });
  });

  group('a drag without a flick settles on the nearer stop', () {
    test('past the half state goes up', () {
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

  group('a two-stop tray', () {
    // The detail tray: collapsed bar or full screen, nothing between.
    const twoStop = [0.12, 1.0];

    test('goes all the way up on one flick', () {
      expect(sheetSnapTarget(size: 0.12, velocity: -flick, stops: twoStop), 1.0);
    });

    test('and all the way down on the reverse', () {
      expect(sheetSnapTarget(size: 1.0, velocity: flick, stops: twoStop), 0.12);
    });

    test('a slow drag lands on the nearer end', () {
      expect(sheetSnapTarget(size: 0.4, velocity: 0, stops: twoStop), 0.12);
      expect(sheetSnapTarget(size: 0.8, velocity: 0, stops: twoStop), 1.0);
    });
  });

  test('the stops need not be given in order', () {
    expect(sheetSnapTarget(size: 1.0, velocity: flick, stops: [1.0, 0.12, 0.5]), 0.5);
  });
}
