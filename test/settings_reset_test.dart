import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/settings/settings_reset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A representative slice of the real store: one key from each group, the two
  // flags a settings reset must never touch, and a key that belongs to no group
  // (search history is data, not a setting).
  Map<String, Object> seed() => {
    'appearance.themeMode': 'dark',
    'appearance.gridSize': 100.0,
    'manga_grid_list_mode': 'List',
    'onboarding.languages': <String>['en'],
    'onboarding.formats': <String>['Manga'],
    'sourcePresets': '[]',
    'sourcePresets.activeId': 'all',
    'rs.mode': 'webtoon',
    'new_chapter_notifications': false,
    'notify_frequency': 2,
    'cache.staleDays': 5,
    'dl.folder': 'chapters',
    'pinned_sources_list': <String>['mangadex'],
    'source_network_cookies_x': 'y',
    'onboarding.welcomeCompleted': true,
    'changelog.lastSeenVersion': '1.1.0',
    'user_search_history': '["one piece"]',
  };

  Future<Set<String>> remaining() async =>
      (await SharedPreferences.getInstance()).getKeys();

  test('resetting one group leaves every other key alone', () async {
    SharedPreferences.setMockInitialValues(seed());
    await resetSettings({SettingsGroup.appearance});

    final keys = await remaining();
    expect(keys, isNot(contains('appearance.themeMode')));
    expect(keys, isNot(contains('appearance.gridSize')));
    expect(keys, isNot(contains('manga_grid_list_mode')));
    // Untouched groups and protected flags survive.
    expect(keys, contains('rs.mode'));
    expect(keys, contains('onboarding.languages'));
    expect(keys, contains('onboarding.welcomeCompleted'));
  });

  test('content preferences keeps the onboarding-complete flag', () async {
    SharedPreferences.setMockInitialValues(seed());
    await resetSettings({SettingsGroup.contentPreferences});

    final keys = await remaining();
    expect(keys, isNot(contains('onboarding.languages')));
    expect(keys, isNot(contains('onboarding.formats')));
    expect(keys, isNot(contains('sourcePresets')));
    expect(keys, isNot(contains('sourcePresets.activeId')));
    // The welcome sheet must not come back from a settings reset.
    expect(keys, contains('onboarding.welcomeCompleted'));
  });

  test('resetting everything keeps first-run flags and non-setting data',
      () async {
    SharedPreferences.setMockInitialValues(seed());
    await resetSettings(SettingsGroup.values.toSet());

    final keys = await remaining();
    expect(keys, contains('onboarding.welcomeCompleted'));
    expect(keys, contains('changelog.lastSeenVersion'));
    expect(keys, contains('user_search_history'));
    // Every grouped key is gone.
    expect(keys, isNot(contains('appearance.themeMode')));
    expect(keys, isNot(contains('onboarding.formats')));
    expect(keys, isNot(contains('rs.mode')));
    expect(keys, isNot(contains('new_chapter_notifications')));
    expect(keys, isNot(contains('cache.staleDays')));
    expect(keys, isNot(contains('source_network_cookies_x')));
  });

  test('an empty selection is a no-op', () async {
    SharedPreferences.setMockInitialValues(seed());
    final cleared = await resetSettings({});
    expect(cleared, 0);
    expect(await remaining(), contains('appearance.themeMode'));
  });
}
