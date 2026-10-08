import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yomou/features/onboarding/content_preferences_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The id of the built-in "show everything" preset.
///
/// It is seeded on first load, cannot be renamed or deleted, and carries no
/// languages: an empty selection filters nothing, which is exactly what "all
/// sources" means.
const String kAllPresetId = 'all';

const String _presetsKey = 'sourcePresets';
const String _activePresetKey = 'sourcePresets.activeId';

/// One named language bundle.
///
/// The name is free text and may be empty, in which case the UI shows a
/// localized fallback ("My sources"): the first preset a reader ends up with
/// is created by the welcome sheet before any locale has been handed to the
/// preference layer, so the display name has to be decided where the string
/// can be translated.
class SourcePreset {
  const SourcePreset({
    required this.id,
    this.name = '',
    this.languages = const {},
  });

  final String id;
  final String name;
  final Set<String> languages;

  bool get isAll => id == kAllPresetId;

  SourcePreset copyWith({String? name, Set<String>? languages}) {
    return SourcePreset(
      id: id,
      name: name ?? this.name,
      languages: languages ?? this.languages,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'languages': languages.toList(),
      };

  factory SourcePreset.fromJson(Map<String, dynamic> json) {
    return SourcePreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      languages: ((json['languages'] as List?) ?? const [])
          .whereType<String>()
          .toSet(),
    );
  }
}

/// The list of presets plus whichever one is active.
class SourcePresetsState {
  const SourcePresetsState({required this.presets, required this.activeId});

  final List<SourcePreset> presets;
  final String activeId;

  SourcePreset get active => presets.firstWhere(
        (p) => p.id == activeId,
        orElse: () => const SourcePreset(id: kAllPresetId),
      );
}

/// Owns the preset list and the active id, and keeps the effective language
/// filter (`contentPreferencesProvider`) pointed at the active preset.
///
/// Two sinks write into the same filter:
/// - switching presets here writes the active preset's languages back into
///   [contentPreferencesProvider], which is what the source lists actually
///   watch;
/// - editing the language chips (welcome sheet or settings) writes the new
///   selection back through [syncLanguages] so the active preset never drifts
///   from what the reader sees filtered.
class SourcePresetsNotifier extends StateNotifier<SourcePresetsState> {
  SourcePresetsNotifier(this._ref)
      : super(const SourcePresetsState(
          presets: [SourcePreset(id: kAllPresetId)],
          activeId: kAllPresetId,
        )) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();

    final stored = p.getString(_presetsKey);
    if (stored == null) {
      // First run of the presets feature. Seed "all" plus, when a selection
      // already exists from the welcome sheet or the content preferences
      // screen, a preset that carries it so the reader's choices are not
      // silently dropped by the new feature.
      var activeId = kAllPresetId;
      final seeded = <SourcePreset>[const SourcePreset(id: kAllPresetId)];
      final carried = (p.getStringList('onboarding.languages') ?? const [])
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (carried.isNotEmpty) {
        final id = _newId();
        seeded.add(SourcePreset(id: id, languages: carried.toSet()));
        activeId = id;
      }
      state = SourcePresetsState(presets: seeded, activeId: activeId);
      await _persist();
      return;
    }

    final decoded = jsonDecode(stored) as List;
    final presets = decoded
        .map((e) => SourcePreset.fromJson(e as Map<String, dynamic>))
        .toList();
    final activeId = p.getString(_activePresetKey) ?? kAllPresetId;
    state = SourcePresetsState(presets: presets, activeId: activeId);
  }

  /// Makes [id] the active preset and points the language filter at it.
  ///
  /// Called from the Explore switcher and the manager sheet. Because switching
  /// presets *is* changing the languages the reader wants, it also persists
  /// them under the original `onboarding.languages` key so the filter agrees
  /// with the active preset even before this notifier has loaded.
  void activate(String id) {
    if (!state.presets.any((p) => p.id == id)) return;
    state = SourcePresetsState(presets: state.presets, activeId: id);
    final languages = state.active.languages;
    _ref.read(contentPreferencesProvider.notifier).setLanguages(languages);
    _persistActive();
  }

  /// Fold a freshly edited language selection back into the active preset.
  ///
  /// The editor writes the selection to [contentPreferencesProvider] first and
  /// reports it here so the preset bundle stays the source of truth for that
  /// selection. When "all" is active and the reader picks a language, there is
  /// nowhere to put it -- so a preset is created on the spot (the welcome
  /// sheet's first language tap is what most installs will see).
  void syncLanguages(Set<String> languages) {
    if (state.active.isAll) {
      if (languages.isEmpty) return;
      final preset = SourcePreset(id: _newId(), languages: {...languages});
      state = SourcePresetsState(
        presets: [...state.presets, preset],
        activeId: preset.id,
      );
      _persist();
      return;
    }
    if (state.active.languages.length == languages.length &&
        state.active.languages.containsAll(languages)) {
      return;
    }
    final updated = state.presets
        .map((p) => p.id == state.activeId ? p.copyWith(languages: {...languages}) : p)
        .toList();
    state = SourcePresetsState(presets: updated, activeId: state.activeId);
    _persist();
  }

  /// Clones the current selection into a new preset and activates it.
  void createFromCurrent({String? name}) {
    final languages = _ref.read(contentPreferencesProvider).languages;
    final preset = SourcePreset(
      id: _newId(),
      name: name ?? '',
      languages: {...languages},
    );
    state = SourcePresetsState(
      presets: [...state.presets, preset],
      activeId: preset.id,
    );
    _persist();
  }

  /// Renames a custom preset. An empty name falls back to the localized
  /// "My sources" label at display time.
  void rename(String id, String name) {
    if (id == kAllPresetId) return;
    final updated = state.presets
        .map((p) => p.id == id ? p.copyWith(name: name.trim()) : p)
        .toList();
    state = SourcePresetsState(presets: updated, activeId: state.activeId);
    _persist();
  }

  /// Deletes a custom preset. Deleting the active one falls back to "all",
  /// which clears the language filter with it.
  void delete(String id) {
    if (id == kAllPresetId) return;
    if (!state.presets.any((p) => p.id == id)) return;
    final remaining = state.presets.where((p) => p.id != id).toList();
    var activeId = state.activeId;
    if (activeId == id) {
      activeId = kAllPresetId;
      _ref.read(contentPreferencesProvider.notifier).setLanguages(const {});
    }
    state = SourcePresetsState(presets: remaining, activeId: activeId);
    _persist();
  }

  String _newId() => 'p${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _presetsKey,
      jsonEncode(state.presets.map((preset) => preset.toJson()).toList()),
    );
    await _persistActive();
  }

  Future<void> _persistActive() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_activePresetKey, state.activeId);
  }
}

final sourcePresetsProvider =
    StateNotifierProvider<SourcePresetsNotifier, SourcePresetsState>(
      (ref) => SourcePresetsNotifier(ref),
    );

/// The currently active preset, for widgets that only need that one.
final activePresetProvider = Provider<SourcePreset>((ref) {
  return ref.watch(sourcePresetsProvider).active;
});

/// Display name for a preset: localized for the built-in "all" and for
/// presets the user has not named yet.
String sourcePresetLabel(AppLocalizations l, SourcePreset preset) {
  if (preset.isAll) return l.presetsAllSources;
  if (preset.name.trim().isEmpty) return l.presetsMySources;
  return preset.name;
}