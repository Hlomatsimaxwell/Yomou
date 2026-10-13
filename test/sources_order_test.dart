import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/data/providers/sources_provider.dart';

/// Long-press reordering in Manage sources, and the manual order surviving a
/// restart. The manual order used to be saved but never read back, so the list
/// always came up in registry order no matter how it was arranged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const prefsKey = 'pinned_sources_list';

  List<String> namesOf(SourcesNotifier n) =>
      [for (final s in n.state) s['name'] as String];

  int pinnedCount(SourcesNotifier n) =>
      n.state.where((s) => s['isPinned'] == true).length;

  Future<SourcesNotifier> fresh() async {
    SharedPreferences.setMockInitialValues({});
    final n = SourcesNotifier();
    await Future<void>.delayed(Duration.zero);
    return n;
  }

  test('every pinned row sits above every unpinned row from the start', () async {
    final n = await fresh();
    final pinned = pinnedCount(n);
    expect(pinned, greaterThan(0));
    for (final s in n.state.take(pinned)) {
      expect(s['isPinned'], isTrue);
    }
    for (final s in n.state.skip(pinned)) {
      expect(s['isPinned'], isNot(true));
    }
  });

  test('a drag cannot carry a row across the pinned boundary', () async {
    final n = await fresh();
    final pinned = pinnedCount(n);
    final names = namesOf(n);

    // An unpinned row dragged to the very top lands at the top of the unpinned
    // block, not above the pinned rows.
    final dragged = names.last;
    n.reorder(names.length - 1, 0);
    expect(namesOf(n)[pinned], dragged);
    expect(pinnedCount(n), pinned);

    // A pinned row dragged far down stays at the bottom of the pinned block.
    final pinnedNames = names.sublist(0, pinned).toSet();
    n.reorder(0, n.state.length - 1);
    expect(pinnedCount(n), pinned);
    expect(namesOf(n).sublist(0, pinned).toSet(), pinnedNames);
  });

  test('a drag inside a zone reorders that zone', () async {
    final n = await fresh();
    final pinned = pinnedCount(n);
    final first = namesOf(n)[pinned];
    final third = namesOf(n)[pinned + 2];

    n.reorder(pinned, pinned + 2);

    final after = namesOf(n);
    expect(after.indexOf(first), pinned + 2);
    expect(after.indexOf(third), pinned + 1);
  });

  test('To top moves within the row\'s own zone', () async {
    final n = await fresh();
    final pinned = pinnedCount(n);
    final target = namesOf(n)[pinned + 3];

    n.moveToTop(target);

    expect(namesOf(n)[pinned], target);
    expect(pinnedCount(n), pinned);
  });

  test('loading restores a saved manual order', () async {
    // Deliberately neither registry order nor sorted: MangaBat before Mangago
    // among the unpinned rows, with MangaDex pinned on top.
    SharedPreferences.setMockInitialValues({
      prefsKey: jsonEncode([
        {'name': 'MangaBat', 'isPinned': false, 'isEnabled': true},
        {'name': 'MangaDex', 'isPinned': true, 'isEnabled': true},
        {'name': 'Mangago', 'isPinned': false, 'isEnabled': true},
      ]),
    });

    final n = SourcesNotifier();
    await Future<void>.delayed(Duration.zero);
    final names = namesOf(n);

    expect(names.first, 'MangaDex');
    expect(names.indexOf('MangaBat'), lessThan(names.indexOf('Mangago')));
    // A source the saved blob did not mention still arrives, after the saved
    // ones rather than vanished.
    expect(names, contains('MangaFire English'));
  });
}
