import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/features/onboarding/content_preferences_provider.dart';
import 'package:yomou/features/onboarding/source_presets_provider.dart';

/// Presets are language bundles with one of them active, and the active preset
/// *is* the live language filter. The two sinks that write it -- switching here,
/// and editing chips through [ContentPreferencesNotifier] -- have to agree, or a
/// reader picks "Spanish" and then watches Explore still show an old selection.
///
/// The tests below pin the create/update/delete paths the preset editor drives,
/// with the "all" built-in as the fixed fallback.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Builds a container over a fresh mock store and waits for both notifiers to
  /// finish their async load.
  Future<ProviderContainer> load(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    // Prime the cached instance so the notifiers' own `getInstance()` resolves
    // on a microtask rather than round-tripping the mock channel.
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(sourcePresetsProvider);
    container.read(contentPreferencesProvider);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  SourcePresetsNotifier notifierOf(ProviderContainer c) =>
      c.read(sourcePresetsProvider.notifier);
  Set<String> filterOf(ProviderContainer c) =>
      c.read(contentPreferencesProvider).languages;

  test('starts with only the built-in "all" preset', () async {
    final c = await load({});
    final state = c.read(sourcePresetsProvider);
    expect(state.presets.map((p) => p.id), [kAllPresetId]);
    expect(state.activeId, kAllPresetId);
    expect(state.active.languages, isEmpty);
  });

  test('carries an existing selection into a seeded preset on first run',
      () async {
    final c = await load({
      'onboarding.languages': ['English', 'Spanish'],
    });
    final state = c.read(sourcePresetsProvider);
    expect(state.presets, hasLength(2));
    expect(state.activeId, isNot(kAllPresetId));
    expect(state.active.languages, {'English', 'Spanish'});
    // The filter already agreed with it; loading must not change it.
    expect(filterOf(c), {'English', 'Spanish'});
  });

  test('create adds a named preset, activates it, and points the filter at it',
      () async {
    final c = await load({});
    notifierOf(c).create(name: 'Spanish', languages: {'Spanish'});

    final state = c.read(sourcePresetsProvider);
    expect(state.presets, hasLength(2));
    expect(state.active.name, 'Spanish');
    expect(state.active.languages, {'Spanish'});
    expect(filterOf(c), {'Spanish'});
  });

  test('updating the active preset moves the filter with it', () async {
    final c = await load({});
    notifierOf(c).create(name: 'A', languages: {'English'});
    notifierOf(c).update(
      c.read(sourcePresetsProvider).activeId,
      name: 'A',
      languages: {'French'},
    );

    final state = c.read(sourcePresetsProvider);
    expect(state.active.languages, {'French'});
    expect(filterOf(c), {'French'});
  });

  test('updating an inactive preset leaves the filter alone', () async {
    final c = await load({});
    notifierOf(c).create(name: 'A', languages: {'English'});
    final a = c.read(sourcePresetsProvider).activeId;
    notifierOf(c).create(name: 'B', languages: {'Spanish'});

    notifierOf(c).update(a, name: 'A renamed', languages: {'French'});

    final state = c.read(sourcePresetsProvider);
    expect(state.active.name, 'B');
    expect(
      state.presets.firstWhere((p) => p.id == a).languages,
      {'French'},
    );
    expect(filterOf(c), {'Spanish'});
  });

  test('deleting the active preset falls back to "all" and clears the filter',
      () async {
    final c = await load({});
    notifierOf(c).create(name: 'A', languages: {'English'});
    final a = c.read(sourcePresetsProvider).activeId;

    notifierOf(c).delete(a);

    final state = c.read(sourcePresetsProvider);
    expect(state.presets.map((p) => p.id), [kAllPresetId]);
    expect(state.activeId, kAllPresetId);
    expect(filterOf(c), isEmpty);
  });

  test('the built-in "all" preset can never be renamed or deleted', () async {
    final c = await load({});
    notifierOf(c).rename(kAllPresetId, 'Nope');
    notifierOf(c).delete(kAllPresetId);
    notifierOf(c).update(kAllPresetId, name: 'Nope', languages: {'English'});

    final state = c.read(sourcePresetsProvider);
    expect(state.presets, hasLength(1));
    expect(state.presets.single.name, isEmpty);
    expect(state.presets.single.languages, isEmpty);
  });
}
