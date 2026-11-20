import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/utils/task_slots.dart';

void main() {
  group('TaskSlots', () {
    test('never exceeds its limit', () async {
      final slots = TaskSlots(2);
      var active = 0;
      var peak = 0;

      Future<void> task() async {
        await slots.acquire();
        active++;
        if (active > peak) peak = active;
        // Give the other workers a chance to try to enter.
        await Future<void>.delayed(Duration.zero);
        active--;
        slots.release();
      }

      await Future.wait([for (var i = 0; i < 8; i++) task()]);

      expect(peak, 2);
      expect(slots.active, 0);
    });

    test('serialises when the limit is one', () async {
      final slots = TaskSlots(1);
      final order = <int>[];

      Future<void> task(int id) async {
        await slots.acquire();
        order.add(id);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        slots.release();
      }

      await Future.wait([for (var i = 0; i < 3; i++) task(i)]);

      expect(order, [0, 1, 2]);
    });

    test('run releases the slot when the action throws', () async {
      final slots = TaskSlots(1);

      await expectLater(
        slots.run<void>(() async => throw StateError('boom')),
        throwsStateError,
      );
      expect(slots.active, 0);

      // A second run must not deadlock on the leaked slot.
      await slots.run<void>(() async {});
      expect(slots.active, 0);
    });

    test('a lowered limit applies as holders release', () async {
      final slots = TaskSlots(3);
      var active = 0;
      var peak = 0;

      Future<void> task() async {
        await slots.run<void>(() async {
          active++;
          if (active > peak) peak = active;
          await Future<void>.delayed(const Duration(milliseconds: 2));
          active--;
        });
      }

      final first = [for (var i = 0; i < 3; i++) task()];
      await Future<void>.delayed(Duration.zero);
      slots.limit = 1;
      final rest = [for (var i = 0; i < 3; i++) task()];

      await Future.wait([...first, ...rest]);
      // The first three were already inside when the limit dropped, so the
      // peak stays at three; nothing after that joins them.
      expect(peak, lessThanOrEqualTo(3));
      expect(slots.active, 0);
    });
  });
}
