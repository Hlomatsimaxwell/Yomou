import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';

/// Twelve presets: our original five plus seven more in the same picker. The
/// failure these guard against is quiet: a name the picker can store that does
/// not resolve falls through `paletteForScheme`'s Totoro fallback, so the
/// swatch moves, the setting saves, and the app still looks exactly as it did.
///
/// Five of them were also recolored and renamed when the swatches turned out
/// to cluster into look-alike pairs, so the migration from the old names is
/// part of what this holds down too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ported = [
    'Asuka',
    'Sepia',
    'Cyan',
    'Emerald',
    'Amber',
    'Kanade',
    'Rose',
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
    final emerald = schemePalettes[AppColorScheme.emerald]!;
    expect(themeSeedFor('Emerald'), emerald.accent);
    expect(themeSecondaryFor('Emerald'), emerald.secondary);

    // The accent is the seed, not the resulting primary: fromSeed derives a
    // tonal role from it. A preset that echoed its accent straight back would
    // be painting a colour the rest of the scheme does not agree with.
    final scheme = colorSchemeFor('Emerald', Brightness.dark);
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.primary, isNot(emerald.accent));
    expect(scheme.secondary, emerald.secondary);
  });

  test('a name stored before the recolor still resolves', () {
    // The five renamed presets were written to SharedPreferences by earlier
    // builds. Left unmigrated they would match no enum entry and quietly fall
    // back to Totoro, moving the swatch under the reader's feet.
    expect(migrateSchemeName('Mion'), 'Sepia');
    expect(migrateSchemeName('rikka'), 'Cyan');
    expect(migrateSchemeName('SAKURA'), 'Emerald');
    expect(migrateSchemeName('mamimi'), 'Amber');
    expect(migrateSchemeName('Itsuka'), 'Rose');
    // Names that never existed land on the default instead of an empty scheme.
    expect(migrateSchemeName('Nonsense'), 'Totoro');
    expect(migrateSchemeName('totoro'), 'Totoro');
  });

  test('picking a ported preset actually re-themes the app', () async {
    // End to end through the notifier and the theme bundle, since the palette
    // map being right is only half of it: the name has to survive the round
    // trip through SharedPreferences (and the rename migration) and reach
    // ColorScheme.fromSeed.
    SharedPreferences.setMockInitialValues({'appearance.colorScheme': 'Itsuka'});
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appearanceSettingsProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final settings = container.read(appearanceSettingsProvider);
    expect(settings.colorScheme, 'Rose');

    final bundle = container.read(themeNotifierProvider);
    final expected = colorSchemeFor('Rose', Brightness.dark);
    expect(bundle.darkTheme.colorScheme.primary, expected.primary);
    expect(
      bundle.darkTheme.colorScheme.primary,
      isNot(colorSchemeFor('totoro', Brightness.dark).primary),
    );
  });
}
