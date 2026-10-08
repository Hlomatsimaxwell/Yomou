import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How many columns a manga grid should use, or null for "derive it from the
/// width".
///
/// One choice for the whole app. The four grids that had a density slider each
/// kept their own preference and their own idea of the default, so a reader who
/// wanted bigger covers had to say so four times -- and on a wide window the
/// value was only ever a floor, so saying it once anywhere did nothing.
const String kGridColumnsKey = 'appearance.gridColumns';

/// The preferences the four grids used before density was unified.
///
/// Read once, on first launch after the change, and then never again. They were
/// only ever written when a slider moved, so a key that is absent means the
/// reader never chose anything and the app should stay on auto rather than
/// inheriting the 3-column default that was never a decision.
const List<String> kLegacyGridColumnsKeys = [
  'history_grid_size',
  'favorites_grid_size',
  'suggestions_grid_size',
  'manga_grid_grid_size',
];

/// The reader's grid density. Null means auto: derive the column count from the
/// available width, which is what every grid did before there was a choice.
final gridDensityProvider = StateNotifierProvider<GridDensityNotifier, int?>(
  (ref) => GridDensityNotifier(),
);

class GridDensityNotifier extends StateNotifier<int?> {
  GridDensityNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();

    final stored = p.getInt(kGridColumnsKey);
    if (stored != null) {
      state = stored;
      return;
    }

    // First run after unification: adopt whichever legacy grid the reader had
    // actually moved, if any.
    for (final key in kLegacyGridColumnsKeys) {
      final legacy = p.getDouble(key);
      if (legacy != null) {
        final columns = legacy.round();
        state = columns;
        await p.setInt(kGridColumnsKey, columns);
        return;
      }
    }
  }

  /// Sets the column count, or clears it back to auto when [columns] is null.
  Future<void> setColumns(int? columns) async {
    state = columns;
    final p = await SharedPreferences.getInstance();
    if (columns == null) {
      await p.remove(kGridColumnsKey);
    } else {
      await p.setInt(kGridColumnsKey, columns);
    }
  }
}
