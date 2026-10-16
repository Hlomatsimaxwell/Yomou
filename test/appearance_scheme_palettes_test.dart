import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';

/// Seven presets ported from Kotatsu now sit alongside our original five. The
/// failure these guard against is quiet: a name the picker can store that does
/// not resolve falls through `paletteForScheme`'s Totoro fallback, so the
/// swatch moves, the setting saves, and the app still looks exactly as it did.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ported = [
    'Asuka',
    'Mion',
    'Rikka',
    'Sakura',
    'Mamimi',
    'Kanade',
    'Itsuka',
  ];

  test('every preset has a palette', () {
    expect(AppColorScheme.values.length, 12);
    for (final scheme in AppColorScheme.values) {
      expect(
        schemePalettes[scheme],
        isNotNull,
        reason: '${scheme.name} has no palette entry',
      );
    }
  });

  test('each ported preset resolves by its stored name', () {
    final totoro = schemePalettes[AppColorScheme.totoro]!;
    for (final name in ported) {
      final palette = paletteForScheme(name);
      expect(
        palette.accent,
        isNot(totoro.accent),
        reason: '$name fell through to the Totoro fallback',
      );
      // The picker stores capitalised names but matching is case-insensitive.
      expect(paletteForScheme(name.toLowerCase()).accent, palette.accent);
      expect(paletteForScheme(name.toUpperCase()).accent, palette.accent);
      expect(
        palette.accent,
        schemePalettes[AppColorScheme.values.byName(name.toLowerCase())]!.accent,
      );
    }
  });

  test('no two presets share an accent', () {
    final accents = AppColorScheme.values
        .map((scheme) => schemePalettes[scheme]!.accent)
        .toSet();
    expect(accents.length, AppColorScheme.values.length);
  });

  test('no two presets render the same primary', () {
    // The accent is only the seed. What a reader actually picks between is the
    // derived primary, so two seeds that landed on the same tone would be two
    // swatches that look like one setting.
    final primaries = AppColorScheme.values
        .map((scheme) => colorSchemeFor(scheme.name, Brightness.dark).primary)
        .toSet();
    expect(primaries.length, AppColorScheme.values.length);
  });

  test('a ported preset seeds the Material scheme with its own accent', () {
    final sakura = schemePalettes[AppColorScheme.sakura]!;
    expect(themeSeedFor('Sakura'), sakura.accent);
    expect(themeSecondaryFor('Sakura'), sakura.secondary);

    // The accent is the seed, not the resulting primary: fromSeed derives a
    // tonal role from it. A preset that echoed its accent straight back would
    // be painting a colour the rest of the scheme does not agree with.
    final scheme = colorSchemeFor('Sakura', Brightness.dark);
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.primary, isNot(sakura.accent));
    expect(scheme.secondary, sakura.secondary);
  });

  test('picking a ported preset actually re-themes the app', () async {
    // End to end through the notifier and the theme bundle, since the palette
    // map being right is only half of it: the name has to survive the round
    // trip through SharedPreferences and reach ColorScheme.fromSeed.
    SharedPreferences.setMockInitialValues({'appearance.colorScheme': 'Itsuka'});
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appearanceSettingsProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final settings = container.read(appearanceSettingsProvider);
    expect(settings.colorScheme, 'Itsuka');

    final bundle = container.read(themeNotifierProvider);
    final expected = colorSchemeFor('Itsuka', Brightness.dark);
    expect(bundle.darkTheme.colorScheme.primary, expected.primary);
    expect(
      bundle.darkTheme.colorScheme.primary,
      isNot(colorSchemeFor('totoro', Brightness.dark).primary),
    );
  });
}
