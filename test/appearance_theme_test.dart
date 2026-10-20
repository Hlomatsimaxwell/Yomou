import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/theme/amoled.dart';
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

  test('disabled rows stay visible in dark mode', () async {
    // The same construction as the icon color above: the base is built light
    // and re-brightened, so ThemeData's default disabledColor (black38) survived
    // into dark mode. A row the active settings cannot honour -- the reader's
    // two-pages row on a strip mode -- then painted black text on the black
    // scaffold and disappeared entirely.
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final bundle = container.read(themeNotifierProvider);

    expect(bundle.darkTheme.disabledColor, Colors.white38);
    expect(bundle.lightTheme.disabledColor, Colors.black38);
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

  test('every slider opts into the expressive spec', () async {
    // Restyling the slider by hand is what let its look drift, so the theme no
    // longer describes one: it only asks for the Material 3 Expressive slider
    // and leaves the drawing to the framework. That request is the switch
    // `year2023: false` -- Flutter 3.41 still defaults to the year-2023 slider
    // (a 4px track under a 10px circle) -- and every field below stays null so
    // the framework supplies the spec: a 16px track, a primary fill over a
    // secondary-container trough, a primary 4x44 handle standing in the gap cut
    // through the track, and a stop dot at each division. Overriding any of
    // them here would shadow that, so they are asserted empty on purpose.
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final bundle = container.read(themeNotifierProvider);

    for (final theme in [bundle.lightTheme, bundle.darkTheme]) {
      final slider = theme.sliderTheme;
      // ignore: deprecated_member_use
      expect(slider.year2023, isFalse);

      expect(slider.trackHeight, isNull);
      expect(slider.activeTrackColor, isNull);
      expect(slider.inactiveTrackColor, isNull);
      expect(slider.thumbColor, isNull);
      expect(slider.thumbSize, isNull);

      expect(slider.trackShape, isNull);
      expect(slider.thumbShape, isNull);
      expect(slider.rangeThumbShape, isNull);
      expect(slider.activeTickMarkColor, isNull);
      expect(slider.inactiveTickMarkColor, isNull);
    }
  });

  testWidgets('both sliders paint the expressive spec, not just ask for it', (
    tester,
  ) async {
    // Opting in with `year2023: false` is only a request. A slider merges its
    // own arguments, the ambient theme and the framework defaults into a fresh
    // SliderThemeData at build time and hands that straight to its render
    // object, so the ambient theme cannot show what the control will draw --
    // reading the values back off the render object is what ties the flag to
    // the 16px track, the bar handle and the secondary-container trough. Only a
    // discrete slider paints the handle, the gapped track and the stop dots, so
    // this also fails loudly if any of them finds the merged theme incomplete.
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final theme = container.read(themeNotifierProvider).darkTheme;
    final scheme = theme.colorScheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Slider(value: 0.4, divisions: 5, onChanged: (_) {}),
              RangeSlider(
                values: const RangeValues(0.2, 0.8),
                divisions: 5,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    // Reading the theme builds the settings notifier, which starts an async load
    // of its own; its channel hops leave zero-duration timers queued, and
    // flutter_test fails a widget test that ends with one still pending. Each
    // pump only drains the timers already due, since a hop can queue the next.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);

    final slider = _paintedTheme(tester, '_SliderRenderObjectWidget');
    expect(slider.trackHeight, 16);
    expect(slider.activeTrackColor, scheme.primary);
    expect(slider.inactiveTrackColor, scheme.secondaryContainer);
    expect(slider.thumbColor, scheme.primary);
    expect(slider.thumbShape, isA<HandleThumbShape>());
    expect(slider.trackShape, isA<GappedSliderTrackShape>());
    expect(slider.thumbSize!.resolve(const <WidgetState>{}), const Size(4, 44));
    expect(slider.tickMarkShape, isA<RoundSliderTickMarkShape>());

    final range = _paintedTheme(tester, '_RangeSliderRenderObjectWidget');
    expect(range.trackHeight, 16);
    expect(range.activeTrackColor, scheme.primary);
    expect(range.inactiveTrackColor, scheme.secondaryContainer);
    expect(range.rangeThumbShape, isA<HandleRangeSliderThumbShape>());
    expect(range.rangeTrackShape, isA<GappedRangeSliderTrackShape>());
    expect(range.thumbSize!.resolve(const <WidgetState>{}), const Size(4, 44));
    expect(range.rangeTickMarkShape, isA<RoundRangeSliderTickMarkShape>());
  });

  test('"Black" flattens the dark surfaces and leaves light mode alone',
      () async {
    // The switch is a background, not an accent, so what it has to move is
    // every surface role the scheme carries -- not just `surface`. A scheme
    // from ColorScheme.fromSeed fills surfaceContainerLowest..Highest in with
    // near-blacks of their own, and the scaffold was already pure black, so a
    // setting that only re-tinted `surface` would look like it did nothing.
    SharedPreferences.setMockInitialValues({'appearance.amoledBlack': true});
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // The notifier loads from SharedPreferences on construction; wait for that
    // hop or the theme is built from the defaults, with Black still off.
    container.read(appearanceSettingsProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final bundle = container.read(themeNotifierProvider);
    final dark = bundle.darkTheme;
    final light = bundle.lightTheme;

    expect(dark.extension<AmoledMode>()!.enabled, isTrue);
    for (final color in [
      dark.colorScheme.surface,
      dark.colorScheme.surfaceDim,
      dark.colorScheme.surfaceBright,
      dark.colorScheme.surfaceContainerLowest,
      dark.colorScheme.surfaceContainerLow,
      dark.colorScheme.surfaceContainer,
      dark.colorScheme.surfaceContainerHigh,
      dark.colorScheme.surfaceContainerHighest,
      dark.canvasColor,
      dark.cardColor,
      dark.scaffoldBackgroundColor,
    ]) {
      expect(color, Colors.black, reason: '$color is not pure black');
    }

    // Light mode has no dark background to flatten, so the switch is inert
    // there: the flag stays false and the surfaces stay white.
    expect(light.extension<AmoledMode>()!.enabled, isFalse);
    expect(light.canvasColor, Colors.white);
    expect(presetSurfaceFor('totoro', Brightness.light, amoled: true),
        Colors.white);

    // Contrast: black surfaces are only worth having if what sits on them is
    // still legible. onSurface and onSurfaceVariant are what a Text or an Icon
    // with no color of its own resolves to.
    expect(_contrast(dark.colorScheme.onSurface, Colors.black),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(dark.colorScheme.onSurfaceVariant, Colors.black),
        greaterThanOrEqualTo(4.5));
  });

  test('with Black off the dark surfaces keep their near-black', () async {
    // The guard on the setting's default. Everything above has to hinge on the
    // switch, not on dark mode: the app has always drawn #121212 cards.
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appearanceSettingsProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final dark = container.read(themeNotifierProvider).darkTheme;
    expect(dark.extension<AmoledMode>()!.enabled, isFalse);
    expect(dark.canvasColor, const Color(0xFF121212));
    expect(dark.cardColor, const Color(0xFF121212));
    expect(dark.colorScheme.surfaceContainerHighest, isNot(Colors.black));
    expect(presetSurfaceFor('totoro', Brightness.dark),
        const Color(0xFF121212));
  });
}

/// WCAG relative-luminance contrast, so the assertion above reads as the 4.5:1
/// ratio a body-text pairing is expected to clear rather than a raw luminance.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The theme a slider actually paints with. Both `Slider` and `RangeSlider`
/// resolve one at build time and pass it to their render object, which is the
/// only place it can be read back; the render object is private, so its public
/// getter is reached by name rather than off a type.
SliderThemeData _paintedTheme(WidgetTester tester, String renderObjectWidget) {
  final finder = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == renderObjectWidget,
  );
  final render = tester.renderObject(finder) as dynamic;
  return render.sliderTheme as SliderThemeData;
}
