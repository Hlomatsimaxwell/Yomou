import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/security/screenshot_policy.dart';

/// Named color schemes matching Kotatsu's preset themes.
enum AppColorScheme { totoro, dynamic, expressive, miku, monochrome }

/// Palettes for each named scheme: (accent, accentLight, accentDark, surface).
class SchemePalette {
  const SchemePalette(
      {required this.accent,
      required this.accentLight,
      required this.accentDark,
      required this.surface,
      this.secondary});

  final Color accent;
  final Color accentLight;
  final Color accentDark;
  final Color surface;

  /// Secondary color used to seed the Material 3 color scheme.
  final Color? secondary;
}

const Map<AppColorScheme, SchemePalette> schemePalettes = {
  AppColorScheme.totoro: SchemePalette(
    accent: Color(0xFF4C8DFF),
    accentLight: Color(0xFFA5C8FF),
    accentDark: Color(0xFF2B5CE6),
    surface: Color(0xFF22304D),
    secondary: Color(0xFFA5C8FF),
  ),
  AppColorScheme.dynamic: SchemePalette(
    accent: Color(0xFF7C5AFF),
    accentLight: Color(0xFFB8A9FF),
    accentDark: Color(0xFF5435CC),
    surface: Color(0xFF2D2542),
    secondary: Color(0xFFB8A9FF),
  ),
  AppColorScheme.expressive: SchemePalette(
    accent: Color(0xFFFF7043),
    accentLight: Color(0xFFFFAB91),
    accentDark: Color(0xFFE64A19),
    surface: Color(0xFF3E2620),
    secondary: Color(0xFFFFAB91),
  ),
  AppColorScheme.miku: SchemePalette(
    accent: Color(0xFF3DDC84),
    accentLight: Color(0xFF8AF4B0),
    accentDark: Color(0xFF1BA25A),
    surface: Color(0xFF1A3326),
    secondary: Color(0xFF8AF4B0),
  ),
  AppColorScheme.monochrome: SchemePalette(
    accent: Color(0xFF000000),
    accentLight: Color(0xFF666666),
    accentDark: Colors.white,
    surface: Color(0xFF000000),
    secondary: Color(0xFF666666),
  ),
};

/// Returns the palette for the current scheme name.
SchemePalette paletteForScheme(String name) {
  final scheme = AppColorScheme.values.firstWhere(
    (s) => s.name.toLowerCase() == name.toLowerCase(),
    orElse: () => AppColorScheme.totoro,
  );
  return schemePalettes[scheme]!;
}

// ---------------------------------------------------------------------------
// Settings model
// ---------------------------------------------------------------------------

class AppearanceSettings {
  const AppearanceSettings({
    required this.colorScheme,
    required this.themeMode,
    required this.listMode,
    required this.gridSize,
    required this.showQuickFilters,
    required this.showReadingProgress,
    required this.showListBadges,
    required this.collapseDescription,
    required this.showPagesThumbnails,
    required this.showFloatingContinueButton,
    required this.showNavLabels,
    required this.useFloatingNavBar,
    required this.pinNavUiOnScroll,
    required this.exitConfirmation,
    required this.showRecentShortcuts,
    required this.hideNsfwFromShortcuts,
    required this.language,
    required this.defaultTab,
    required this.searchSuggestions,
    required this.mainScreenSections,
    required this.protectApp,
    required this.screenshotPolicy,
    required this.useFrostedGlass,
  });

  // All requested defaults from spec
  factory AppearanceSettings.defaults() => const AppearanceSettings(
        colorScheme: 'Totoro',
        themeMode: ThemeMode.system,
        listMode: 'Grid',
        gridSize: 100,
        showQuickFilters: true,
        showReadingProgress: true,
        showListBadges: true,
        collapseDescription: true,
        showPagesThumbnails: true,
        showFloatingContinueButton: true,
        showNavLabels: true,
        useFloatingNavBar: true,
        pinNavUiOnScroll: false,
        exitConfirmation: true,
        showRecentShortcuts: true,
        hideNsfwFromShortcuts: true,
        language: 'system',
        defaultTab: 'Last used',
        searchSuggestions: {
          'history': true,
          'trending': true,
          'new': true,
          'popular': true,
        },
        mainScreenSections: {
          'History': true,
          'Favorites': true,
          'Suggestions': true,
          'Explore': true,
          'Updates': true,
        },
        protectApp: false,
        screenshotPolicy: 'Allow',
        useFrostedGlass: true,
      );

  final String colorScheme;
  final ThemeMode themeMode;
  final String listMode;
  final double gridSize; // 50-150 (% of normal)
  final bool showQuickFilters;
  final bool showReadingProgress;
  final bool showListBadges;
  final bool collapseDescription;
  final bool showPagesThumbnails;
  final bool showFloatingContinueButton;
  final bool showNavLabels;
  final bool useFloatingNavBar;
  final bool pinNavUiOnScroll;
  final bool exitConfirmation;
  final bool showRecentShortcuts;
  final bool hideNsfwFromShortcuts;
  final String language;
  final String defaultTab;
  final Map<String, bool> searchSuggestions;
  final Map<String, bool> mainScreenSections;
  final bool protectApp;
  final String screenshotPolicy;
  final bool useFrostedGlass;

  AppearanceSettings copyWith({
    String? colorScheme,
    ThemeMode? themeMode,
    String? listMode,
    double? gridSize,
    bool? showQuickFilters,
    bool? showReadingProgress,
    bool? showListBadges,
    bool? collapseDescription,
    bool? showPagesThumbnails,
    bool? showFloatingContinueButton,
    bool? showNavLabels,
    bool? useFloatingNavBar,
    bool? pinNavUiOnScroll,
    bool? exitConfirmation,
    bool? showRecentShortcuts,
    bool? hideNsfwFromShortcuts,
    String? language,
    String? defaultTab,
    Map<String, bool>? searchSuggestions,
    Map<String, bool>? mainScreenSections,
    bool? protectApp,
    String? screenshotPolicy,
    bool? useFrostedGlass,
  }) =>
      AppearanceSettings(
        colorScheme: colorScheme ?? this.colorScheme,
        themeMode: themeMode ?? this.themeMode,
        listMode: listMode ?? this.listMode,
        gridSize: gridSize ?? this.gridSize,
        showQuickFilters: showQuickFilters ?? this.showQuickFilters,
        showReadingProgress: showReadingProgress ?? this.showReadingProgress,
        showListBadges: showListBadges ?? this.showListBadges,
        collapseDescription: collapseDescription ?? this.collapseDescription,
        showPagesThumbnails:
            showPagesThumbnails ?? this.showPagesThumbnails,
        showFloatingContinueButton:
            showFloatingContinueButton ?? this.showFloatingContinueButton,
        showNavLabels: showNavLabels ?? this.showNavLabels,
        useFloatingNavBar: useFloatingNavBar ?? this.useFloatingNavBar,
        pinNavUiOnScroll: pinNavUiOnScroll ?? this.pinNavUiOnScroll,
        exitConfirmation: exitConfirmation ?? this.exitConfirmation,
        showRecentShortcuts:
            showRecentShortcuts ?? this.showRecentShortcuts,
        hideNsfwFromShortcuts:
            hideNsfwFromShortcuts ?? this.hideNsfwFromShortcuts,
        language: language ?? this.language,
        defaultTab: defaultTab ?? this.defaultTab,
        searchSuggestions:
            searchSuggestions ?? this.searchSuggestions,
        mainScreenSections:
            mainScreenSections ?? this.mainScreenSections,
        protectApp: protectApp ?? this.protectApp,
        screenshotPolicy: screenshotPolicy ?? this.screenshotPolicy,
        useFrostedGlass: useFrostedGlass ?? this.useFrostedGlass,
      );
}

// ---------------------------------------------------------------------------
// Persistence helpers
// ---------------------------------------------------------------------------

class _AppearancePersistence {
  static const _prefix = 'appearance.';
  static const _colorScheme = '${_prefix}colorScheme';
  static const _themeMode = '${_prefix}themeMode';
  static const _listMode = '${_prefix}listMode';
  static const _gridSize = '${_prefix}gridSize';
  static const _showQuickFilters = '${_prefix}showQuickFilters';
  static const _showReadingProgress = '${_prefix}showReadingProgress';
  static const _showListBadges = '${_prefix}showListBadges';
  static const _collapseDescription = '${_prefix}collapseDescription';
  static const _showPagesThumbnails = '${_prefix}showPagesThumbnails';
  static const _showFab = '${_prefix}showFab';
  static const _showLabels = '${_prefix}showLabels';
  static const _floatingBar = '${_prefix}floatingBar';
  static const _pinScroll = '${_prefix}pinScroll';
  static const _exitConfirm = '${_prefix}exitConfirm';
  static const _recentShortcuts = '${_prefix}recentShortcuts';
  static const _hideNsfwShortcuts = '${_prefix}hideNsfwShortcuts';
  static const _language = '${_prefix}language';
  static const _defaultTab = '${_prefix}defaultTab';
  static const _searchSuggestions = '${_prefix}searchSuggestions';
  static const _mainSections = '${_prefix}mainSections';
  static const _protectApp = '${_prefix}protectApp';
  static const _screenshotPolicy = '${_prefix}screenshotPolicy';
  static const _frostedGlass = '${_prefix}frostedGlass';

  static Future<AppearanceSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final themeModeStr = p.getString(_themeMode) ?? '';
    final themeMode = ThemeMode.values.asNameMap()[themeModeStr] ?? ThemeMode.system;

    return AppearanceSettings(
      colorScheme: p.getString(_colorScheme) ?? 'Totoro',
      themeMode: themeMode,
      listMode: p.getString(_listMode) ?? 'Grid',
      gridSize: p.getDouble(_gridSize) ?? 100,
      showQuickFilters: p.getBool(_showQuickFilters) ?? true,
      showReadingProgress: p.getBool(_showReadingProgress) ?? true,
      showListBadges: p.getBool(_showListBadges) ?? true,
      collapseDescription: p.getBool(_collapseDescription) ?? true,
      showPagesThumbnails: p.getBool(_showPagesThumbnails) ?? true,
      showFloatingContinueButton: p.getBool(_showFab) ?? true,
      showNavLabels: p.getBool(_showLabels) ?? true,
      useFloatingNavBar: p.getBool(_floatingBar) ?? true,
      pinNavUiOnScroll: p.getBool(_pinScroll) ?? false,
      exitConfirmation: p.getBool(_exitConfirm) ?? true,
      showRecentShortcuts: p.getBool(_recentShortcuts) ?? true,
      hideNsfwFromShortcuts: p.getBool(_hideNsfwShortcuts) ?? true,
      language: p.getString(_language) ?? 'system',
      defaultTab: p.getString(_defaultTab) ?? 'Last used',
      searchSuggestions: _decodeMap(p.getString(_searchSuggestions)) ??
          AppearanceSettings.defaults().searchSuggestions,
      mainScreenSections: _decodeMap(p.getString(_mainSections)) ??
          AppearanceSettings.defaults().mainScreenSections,
      protectApp: p.getBool(_protectApp) ?? false,
      screenshotPolicy: p.getString(_screenshotPolicy) ?? 'Allow',
      useFrostedGlass: p.getBool(_frostedGlass) ?? true,
    );
  }

  static Future<void> save(AppearanceSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_colorScheme, s.colorScheme);
    await p.setString(_themeMode, s.themeMode.name);
    await p.setString(_listMode, s.listMode);
    await p.setDouble(_gridSize, s.gridSize);
    await p.setBool(_showQuickFilters, s.showQuickFilters);
    await p.setBool(_showReadingProgress, s.showReadingProgress);
    await p.setBool(_showListBadges, s.showListBadges);
    await p.setBool(_collapseDescription, s.collapseDescription);
    await p.setBool(_showPagesThumbnails, s.showPagesThumbnails);
    await p.setBool(_showFab, s.showFloatingContinueButton);
    await p.setBool(_showLabels, s.showNavLabels);
    await p.setBool(_floatingBar, s.useFloatingNavBar);
    await p.setBool(_pinScroll, s.pinNavUiOnScroll);
    await p.setBool(_exitConfirm, s.exitConfirmation);
    await p.setBool(_recentShortcuts, s.showRecentShortcuts);
    await p.setBool(_hideNsfwShortcuts, s.hideNsfwFromShortcuts);
    await p.setString(_language, s.language);
    await p.setString(_defaultTab, s.defaultTab);
    await p.setString(_searchSuggestions, jsonEncode(s.searchSuggestions));
    await p.setString(_mainSections, jsonEncode(s.mainScreenSections));
    await p.setBool(_protectApp, s.protectApp);
    await p.setString(_screenshotPolicy, s.screenshotPolicy);
    await p.setBool(_frostedGlass, s.useFrostedGlass);
  }

  static Map<String, bool>? _decodeMap(String? json) {
    if (json == null) return null;
    try {
      return (jsonDecode(json) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v == true));
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AppearanceSettingsNotifier extends StateNotifier<AppearanceSettings> {
  AppearanceSettingsNotifier() : super(AppearanceSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    state = await _AppearancePersistence.load();
    // Re-apply per start: the native FLAG_SECURE is process-scoped.
    applyScreenshotPolicy(block: state.screenshotPolicy == 'Block');
  }

  Future<void> _persist() async => _AppearancePersistence.save(state);

  // Generic setter — mutate the settings from the current state, then persist.
  Future<void> set(
      AppearanceSettings Function(AppearanceSettings s) update) async {
    state = update(state);
    await _persist();
  }

  // Convenience setters for common types
  Future<void> setColorScheme(String name) async =>
      set((s) => s.copyWith(colorScheme: name));
  Future<void> setThemeMode(ThemeMode mode) async =>
      set((s) => s.copyWith(themeMode: mode));
  Future<void> toggleBool(String key) async {
    switch (key) {
      case 'showQuickFilters':
        set((s) => s.copyWith(showQuickFilters: !s.showQuickFilters));
      case 'showReadingProgress':
        set((s) => s.copyWith(showReadingProgress: !s.showReadingProgress));
      case 'showListBadges':
        set((s) => s.copyWith(showListBadges: !s.showListBadges));
      case 'collapseDescription':
        set((s) => s.copyWith(collapseDescription: !s.collapseDescription));
      case 'showPagesThumbnails':
        set((s) => s.copyWith(showPagesThumbnails: !s.showPagesThumbnails));
      case 'showFloatingContinueButton':
        set((s) => s.copyWith(
            showFloatingContinueButton: !s.showFloatingContinueButton));
      case 'showNavLabels':
        set((s) => s.copyWith(showNavLabels: !s.showNavLabels));
      case 'useFloatingNavBar':
        set((s) => s.copyWith(useFloatingNavBar: !s.useFloatingNavBar));
      case 'pinNavUiOnScroll':
        set((s) => s.copyWith(pinNavUiOnScroll: !s.pinNavUiOnScroll));
      case 'exitConfirmation':
        set((s) => s.copyWith(exitConfirmation: !s.exitConfirmation));
      case 'showRecentShortcuts':
        set((s) => s.copyWith(showRecentShortcuts: !s.showRecentShortcuts));
      case 'hideNsfwFromShortcuts':
        set(
            (s) => s.copyWith(hideNsfwFromShortcuts: !s.hideNsfwFromShortcuts));
      case 'useFrostedGlass':
        set((s) => s.copyWith(useFrostedGlass: !s.useFrostedGlass));
    }
  }

  Future<void> setListMode(String mode) async =>
      set((s) => s.copyWith(listMode: mode));
  Future<void> setGridSize(double size) async =>
      set((s) => s.copyWith(gridSize: size));
  Future<void> setLanguage(String lang) async =>
      set((s) => s.copyWith(language: lang));
  Future<void> setDefaultTab(String tab) async =>
      set((s) => s.copyWith(defaultTab: tab));
  Future<void> toggleSearchSuggestion(String key) async {
    final map = Map<String, bool>.from(state.searchSuggestions);
    map[key] = !(map[key] ?? true);
    set((s) => s.copyWith(searchSuggestions: map));
  }

  Future<void> toggleMainSection(String key) async {
    final map = Map<String, bool>.from(state.mainScreenSections);
    map[key] = !(map[key] ?? true);
    set((s) => s.copyWith(mainScreenSections: map));
  }

  Future<void> setProtectApp(bool value) async =>
      set((s) => s.copyWith(protectApp: value));

  Future<void> setScreenshotPolicy(String policy) async {
    set((s) => s.copyWith(screenshotPolicy: policy));
    await applyScreenshotPolicy(block: policy == 'Block');
  }
}

final appearanceSettingsProvider =
    StateNotifierProvider<AppearanceSettingsNotifier, AppearanceSettings>(
        (ref) => AppearanceSettingsNotifier());

/// Resolves whether the app is effectively showing dark mode, honoring the
/// chosen [ThemeMode] and falling back to system brightness for "system".
bool _effectiveDark(AppearanceSettings settings) {
  switch (settings.themeMode) {
    case ThemeMode.dark:
      return true;
    case ThemeMode.light:
      return false;
    case ThemeMode.system:
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
  }
}

/// Derived accent color for the app based on the active [appearanceSettingsProvider].
final accentProvider = Provider<Color>((ref) {
  final settings = ref.watch(appearanceSettingsProvider);
  final palette = paletteForScheme(settings.colorScheme);
  if (settings.colorScheme.toLowerCase() == 'monochrome') {
    // Monochrome pills/FAB render crisp white or black, never tinted.
    return _effectiveDark(settings) ? Colors.white : Colors.black;
  }
  return palette.accent;
});

final accentLightProvider = Provider<Color>((ref) {
  final schemeName = ref.watch(appearanceSettingsProvider).colorScheme;
  return paletteForScheme(schemeName).accentLight;
});

final accentDarkProvider = Provider<Color>((ref) {
  final schemeName = ref.watch(appearanceSettingsProvider).colorScheme;
  return paletteForScheme(schemeName).accentDark;
});

final accentSurfaceProvider = Provider<Color>((ref) {
  final schemeName = ref.watch(appearanceSettingsProvider).colorScheme;
  return paletteForScheme(schemeName).surface;
});

// ---------------------------------------------------------------------------
// Theme building
// ---------------------------------------------------------------------------

/// Primary seed color for each appearance preset (matches the spec hexes).
Color themeSeedFor(String schemeName) {
  // Prefer the accent already defined for the scheme; fall back to the spec's
  // requested primaries so each preset has a distinct seed.
  try {
    final scheme = AppColorScheme.values.firstWhere(
      (s) => s.name.toLowerCase() == schemeName.toLowerCase(),
      orElse: () => AppColorScheme.totoro,
    );
    return schemePalettes[scheme]!.accent;
  } catch (_) {
    return const Color(0xFF4C8DFF);
  }
}

/// Secondary color for the active preset, if defined.
Color? themeSecondaryFor(String schemeName) {
  try {
    final scheme = AppColorScheme.values.firstWhere(
      (s) => s.name.toLowerCase() == schemeName.toLowerCase(),
      orElse: () => AppColorScheme.totoro,
    );
    return schemePalettes[scheme]?.secondary;
  } catch (_) {
    return null;
  }
}

/// Complete set of light + dark [ThemeData] plus the mode, so the root
/// MaterialApp can be driven from a single provider.
class ThemeDataBundle {
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode mode;

  const ThemeDataBundle({
    required this.lightTheme,
    required this.darkTheme,
    required this.mode,
  });
}

/// Builds both themes; shared widget themes that don't depend on brightness
/// are constructed once.
ThemeData _baseTheme(bool dark) {
  final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
  return ThemeData(
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    dividerColor: Colors.transparent,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      foregroundColor: fg,
      iconTheme: IconThemeData(color: fg),
      titleTextStyle: TextStyle(
        color: fg,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      toolbarHeight: 44,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2E2E33) : Colors.white,
      contentTextStyle: TextStyle(
        color: dark ? Colors.white : const Color(0xFF1C1B1F),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: dark ? BorderSide.none : const BorderSide(color: Colors.black12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      elevation: 0,
      showCloseIcon: false,
    ),
    listTileTheme: ListTileThemeData(iconColor: fg),
  );
}

/// Pure black/white Material 3 scheme for the Monochrome preset.
ColorScheme monochromeScheme(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return const ColorScheme.dark(
      primary: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF000000),
      primaryContainer: Color(0xFF2A2A2A),
      onPrimaryContainer: Color(0xFFFFFFFF),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFFFFFFF),
      secondary: Color(0xFFCCCCCC),
    );
  }
  return const ColorScheme.light(
    primary: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE0E0E0),
    onPrimaryContainer: Color(0xFF000000),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF000000),
    secondary: Color(0xFF444444),
  );
}

/// Creates the final ThemeData for a given brightness. Dark mode always uses
/// pure black (#000000) scaffold and surfaces.
ThemeData _applyBrightness(
  ThemeData base,
  Color seed,
  Color? secondary,
  Brightness brightness, {
  ColorScheme? customScheme,
}) {
  final scheme = customScheme ??
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      );
  final colorScheme = customScheme != null
      ? scheme
      : (secondary != null
          ? scheme.copyWith(secondary: secondary)
          : scheme);

  final dark = brightness == Brightness.dark;

  // Monochrome surfaces are pure black (AMOLED) in dark mode; other schemes
  // lift off the black scaffold with a near-black card color.
  final isMonochrome = customScheme != null;
  final scaffoldBg = dark
      ? Colors.black
      : const Color(0xFFF8F9FA);

  // Dark surfaces are all near-black for OLED displays; light cards are pure
  // white so they lift off the soft off-white scaffold.
  final surfaceColor = dark
      ? (isMonochrome ? Colors.black : const Color(0xFF121212))
      : Colors.white;

  // High-contrast text roles: the dark branch must build its own text theme
  // from a dark scheme (ThemeData() defaults to light, so reusing the light
  // textTheme left every color-less Text near-black on the black scaffold).
  final textTheme = ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
  ).textTheme.apply(
    bodyColor: dark ? Colors.white : const Color(0xFF1C1B1F),
    displayColor: dark ? Colors.white : const Color(0xFF1C1B1F),
  );

  return base.copyWith(
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBg,
    canvasColor: surfaceColor,
    cardColor: surfaceColor,
    textTheme: textTheme,
  );
}

/// Derived theme bundle — watch this at the root to drive MaterialApp.
final themeNotifierProvider = Provider<ThemeDataBundle>((ref) {
  final settings = ref.watch(appearanceSettingsProvider);
  final seed = themeSeedFor(settings.colorScheme);
  final secondary = themeSecondaryFor(settings.colorScheme);
  final base = _baseTheme(false);
  final isMonochrome = settings.colorScheme.toLowerCase() == 'monochrome';
  final light = _applyBrightness(
    base,
    seed,
    secondary,
    Brightness.light,
    customScheme: isMonochrome ? monochromeScheme(Brightness.light) : null,
  );
  final dark = _applyBrightness(
    _baseTheme(true),
    seed,
    secondary,
    Brightness.dark,
    customScheme: isMonochrome ? monochromeScheme(Brightness.dark) : null,
  );
  return ThemeDataBundle(
    lightTheme: light,
    darkTheme: dark,
    mode: settings.themeMode,
  );
});