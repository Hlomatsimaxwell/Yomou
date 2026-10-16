import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';

/// ThemeData only picks an icon color from the brightness handed to its own
/// constructor. The base theme in this app is always built light and then
/// re-brightened via copyWith, which does not revisit iconTheme -- so without
/// an explicit override every bare Icon(...) stayed black in dark mode and
/// vanished against the black scaffold.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default icon color follows the theme brightness', () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final bundle = container.read(themeNotifierProvider);

    expect(bundle.darkTheme.iconTheme.color, Colors.white);
    expect(bundle.lightTheme.iconTheme.color, const Color(0xFF1C1B1F));
  });

  test('haptics are on by default and persist when switched off', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(appearanceSettingsProvider.notifier);
    // Let the notifier's async load settle before mutating, so it cannot
    // clobber the value with the on-disk default.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(appearanceSettingsProvider).hapticsEnabled, isTrue);

    await notifier.toggleBool('hapticsEnabled');
    // toggleBool does not await its write; force one so the assertion is honest.
    await notifier.set((s) => s.copyWith(hapticsEnabled: s.hapticsEnabled));

    expect(container.read(appearanceSettingsProvider).hapticsEnabled, isFalse);
    expect(prefs.getBool('appearance.hapticsEnabled'), isFalse);
  });

  test('the monochrome preset gives both cover indicators a disc', () {
    // The reading-progress ring and the favourite heart are drawn on tonal
    // discs, one in each top corner of a cover. Neither role has a usable
    // default here: this Flutter's ColorScheme.light answers tertiaryContainer
    // with whatever `secondary` was handed to it, so the heart's disc came out
    // #444444 in light mode - a black glyph on a dark grey disc, and nothing
    // like the #E0E0E0 the ring wears. The roles are spelled out, and this
    // holds them to it.
    final light = monochromeScheme(Brightness.light);
    expect(light.secondaryContainer, const Color(0xFFE0E0E0));
    expect(light.tertiaryContainer, const Color(0xFFE0E0E0));
    expect(light.onSecondaryContainer, const Color(0xFF000000));
    expect(light.onTertiaryContainer, const Color(0xFF000000));

    final dark = monochromeScheme(Brightness.dark);
    expect(dark.secondaryContainer, const Color(0xFF2A2A2A));
    expect(dark.tertiaryContainer, const Color(0xFF2A2A2A));
    expect(dark.onSecondaryContainer, const Color(0xFFFFFFFF));
    expect(dark.onTertiaryContainer, const Color(0xFFFFFFFF));

    // And no hue in any of them, since the whole point of the preset is that
    // it has none: a role left to a default shows up as a tinted badge.
    for (final scheme in [light, dark]) {
      for (final color in [
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        scheme.outlineVariant,
      ]) {
        expect(color.r, color.g, reason: '$color carries a hue');
        expect(color.g, color.b, reason: '$color carries a hue');
      }
    }
  });

  test('every slider inherits one thick, thumbless track', () async {
    // The slider look lives in the theme now rather than in the two screens
    // that used to restyle their own. That only holds if the theme actually
    // carries it, so this pins the pieces the screens relied on: a thick
    // track, the scheme primary filling it, and no floating circle on either
    // a Slider or a RangeSlider.
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final bundle = container.read(themeNotifierProvider);

    for (final theme in [bundle.lightTheme, bundle.darkTheme]) {
      final slider = theme.sliderTheme;
      final primary = theme.colorScheme.primary;

      // Not the 4px stock track.
      expect(slider.trackHeight, 16);
      expect(slider.activeTrackColor, primary);
      // The remainder is a pale wash of that primary, not a grey.
      expect(slider.inactiveTrackColor, primary.withValues(alpha: 0.16));

      // A radius of zero is what removes the circle from the Slider...
      expect(
        (slider.thumbShape! as RoundSliderThumbShape).enabledThumbRadius,
        0,
      );
      // ...and from both ends of a RangeSlider.
      expect(
        (slider.rangeThumbShape! as RoundRangeSliderThumbShape)
            .enabledThumbRadius,
        0,
      );

      // The halo is absent at rest and only shows up on interaction.
      final overlay = slider.overlayColor! as WidgetStateColor;
      expect(overlay.resolve(const <WidgetState>{}), Colors.transparent);
      expect(overlay.resolve({WidgetState.dragged}).a, 0.12);

      // Tick marks are invisible; every slider is labelled already.
      expect(slider.activeTickMarkColor, Colors.transparent);
      expect(slider.inactiveTickMarkColor, Colors.transparent);
    }
  });
}
