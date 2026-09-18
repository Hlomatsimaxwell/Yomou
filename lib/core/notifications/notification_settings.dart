import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// How often the background job may run.
enum Frequency {
  manual('off'),
  less('every_6_hours'),
  defaultMode('every_hour'),
  more('every_15_minutes');

  const Frequency(this.prefix);
  final String prefix;
}

/// What to auto-download when new chapters arrive.
enum AutoDownload { never, downloaded, recentlyRead }

/// Persisted, background-run friendly switchboard for the new-chapter
/// checking settings (adaptation of Kotatsu's "Check for new chapters"
/// screen). Discrete options live in SharedPreferences so the background
/// isolate can read them without Riverpod.
class NotificationSettings {
  static const String wifiOnlyPrefsKey = 'wifi_only';
  static const String frequencyPrefsKey = 'notify_frequency';
  static const String scopeFavoritesPrefsKey = 'look_for_updates_favorites';
  static const String scopeHistoryPrefsKey = 'look_for_updates_history';
  static const String nsfwPrefsKey = 'notify_nsfw';
  static const String categoriesPrefsKey = 'favorite_categories';
  static const String autoDownloadPrefsKey = 'auto_download';

  /// Genre tags treated as mature/adult. Series matching any of these are
  /// skipped from notifications when "Disable NSFW notifications" is on.
  static const List<String> nsfwMarkers = [
    'Ecchi',
    'Hentai',
    'Adult',
    'Smut',
    'Sexual Violence',
    'Mature',
    'Gore',
    'NSFW',
  ];

  static bool tagsAreNsfw(List<String> tags) {
    final lower = tags.map((t) => t.toLowerCase()).toList();
    return nsfwMarkers.any(
      (marker) => lower.any((tag) => tag.contains(marker.toLowerCase())),
    );
  }

  // --- Wi-Fi only ----------------------------------------------------------

  static Future<bool> isWifiOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(wifiOnlyPrefsKey) ?? false;
  }

  static Future<void> setWifiOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(wifiOnlyPrefsKey, value);
  }

  // --- Frequency -----------------------------------------------------------

  static Future<Frequency> frequency() async {
    final prefs = await SharedPreferences.getInstance();
    final index =
        prefs.getInt(frequencyPrefsKey) ?? Frequency.defaultMode.index;
    return Frequency.values[index.clamp(0, Frequency.values.length - 1)];
  }

  static Future<void> setFrequencyIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(frequencyPrefsKey, index);
  }

  /// The periodic interval for [Frequency], or null for manual.
  static Duration? intervalFor(Frequency frequency) {
    switch (frequency) {
      case Frequency.manual:
        return null;
      case Frequency.less:
        return const Duration(hours: 6);
      case Frequency.defaultMode:
        return const Duration(hours: 1);
      case Frequency.more:
        return const Duration(minutes: 15);
    }
  }

  // --- Scope ---------------------------------------------------------------

  static Future<(bool favorites, bool history)> lookForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getBool(scopeFavoritesPrefsKey) ?? true,
      prefs.getBool(scopeHistoryPrefsKey) ?? true,
    );
  }

  static Future<void> setLookForFavorites(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(scopeFavoritesPrefsKey, value);
  }

  static Future<void> setLookForHistory(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(scopeHistoryPrefsKey, value);
  }

  // --- NSFW ----------------------------------------------------------------

  /// Whether NSFW-tagged series may trigger notifications (defaults to no).
  static Future<bool> nsfwAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(nsfwPrefsKey) ?? false;
  }

  static Future<void> setNsfwAllowed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(nsfwPrefsKey, value);
  }

  // --- Favorite categories -------------------------------------------------

  /// The set of genre categories the user opted in to. An empty set means
  /// "all categories" (no filtering) — the default.
  static Future<Set<String>> favoriteCategories() async {
    final state = await categoryState();
    return state.all ? {} : state.selected;
  }

  /// Raw category filter state: whether "all" is enabled and which exact tags
  /// are selected when it is not.
  static Future<({bool all, Set<String> selected})> categoryState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(categoriesPrefsKey);
    if (raw == null) return (all: true, selected: <String>{});
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = decoded['list'] as List? ?? [];
      return (
        all: decoded['all'] == true,
        selected: list.cast<String>().toSet(),
      );
    } catch (_) {
      return (all: true, selected: <String>{});
    }
  }

  /// Persists the category filter. Pass the full known category set when the
  /// user reset everything to "all" so we can store the opt-out state.
  static Future<void> setFavoriteCategories(
    Set<String> selected, {
    required Set<String> allCategories,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final allSelected = allCategories.length == selected.length;
    await prefs.setString(
      categoriesPrefsKey,
      jsonEncode({'all': allSelected, 'list': selected.toList()}),
    );
  }

  // --- Auto-download -------------------------------------------------------

  static Future<AutoDownload> autoDownload() async {
    final prefs = await SharedPreferences.getInstance();
    final index =
        prefs.getInt(autoDownloadPrefsKey) ?? AutoDownload.never.index;
    return AutoDownload.values[index.clamp(0, AutoDownload.values.length - 1)];
  }

  static Future<void> setAutoDownloadIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(autoDownloadPrefsKey, index);
  }
}
