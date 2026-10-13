import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When each source row was last opened, keyed by its exact name ("MangaDex",
/// "MangaFire Portuguese Brazil") in milliseconds since the epoch.
///
/// This is the only input [SourceSortOrder.lastUsed] needs and it is recorded
/// when a source's grid is opened, which is the moment the reader picked that
/// source over the others. A source that was never opened is absent rather than
/// stored as zero, so "never used" and "used at the epoch" cannot be confused.
class SourceLastUsedNotifier extends StateNotifier<Map<String, int>> {
  SourceLastUsedNotifier() : super(const {}) {
    _load();
  }

  static const _prefsKey = 'sources.lastUsed';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      state = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      // A corrupt blob must not take the source list down with it; starting
      // over just costs one round of recency.
      state = const {};
    }
  }

  /// Records that [name] was opened at [at] (defaults to now).
  Future<void> markUsed(String name, {DateTime? at}) async {
    if (name.isEmpty) return;
    final stamp = (at ?? DateTime.now()).millisecondsSinceEpoch;
    state = {...state, name: stamp};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state));
  }
}

final sourceLastUsedProvider =
    StateNotifierProvider<SourceLastUsedNotifier, Map<String, int>>(
  (ref) => SourceLastUsedNotifier(),
);
