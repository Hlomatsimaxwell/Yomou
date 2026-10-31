import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/security/screenshot_policy.dart';
import 'package:yomou/core/theme/amoled.dart';

/// Named colour schemes, one per swatch in the appearance picker. Named for
/// the colour each paints rather than a character, so the label says what the
/// card looks like before it is tapped.
enum AppColorScheme {
  azure,
  violet,
  tangerine,
  teal,
  monochrome,
  crimson,
  sepia,
  cyan,
  emerald,
  amber,
  lavender,
  rose,
}

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
  AppColorScheme.azure: SchemePalette(
    accent: Color(0xFF4C8DFF),
    accentLight: Color(0xFFA5C8FF),
    accentDark: Color(0xFF2B5CE6),
    surface: Color(0xFF1F2F4D),
    secondary: Color(0xFFA5C8FF),
  ),
  AppColorScheme.violet: SchemePalette(
    accent: Color(0xFF8E5BFF),
    accentLight: Color(0xFFC9B6FF),
    accentDark: Color(0xFF6937E6),
    surface: Color(0xFF251F3D),
    secondary: Color(0xFFC9B6FF),
  ),
  AppColorScheme.tangerine: SchemePalette(
    accent: Color(0xFFFF6B35),
    accentLight: Color(0xFFFFB69B),
    accentDark: Color(0xFFE64512),
    surface: Color(0xFF3A2118),
    secondary: Color(0xFFFFB69B),
  ),
  AppColorScheme.teal: SchemePalette(
    accent: Color(0xFF3FC5B5),
    accentLight: Color(0xFF9DEDE2),
    accentDark: Color(0xFF249C90),
    surface: Color(0xFF182C29),
    secondary: Color(0xFF9DEDE2),
  ),
  AppColorScheme.monochrome: SchemePalette(
    accent: Color(0xFF000000),
    accentLight: Color(0xFF666666),
    accentDark: Colors.white,
    surface: Color(0xFF000000),
    secondary: Color(0xFF666666),
  ),
  AppColorScheme.crimson: SchemePalette(
    accent: Color(0xFFE63946),
    accentLight: Color(0xFFFFC9C6),
    accentDark: Color(0xFFC62828),
    surface: Color(0xFF3C1F1D),
    secondary: Color(0xFFFFC9C6),
  ),
  AppColorScheme.sepia: SchemePalette(
    accent: Color(0xFF9C6B4F),
    accentLight: Color(0xFFD3B8A5),
    accentDark: Color(0xFF7A5240),
    surface: Color(0xFF2E241E),
    secondary: Color(0xFFD3B8A5),
  ),
  AppColorScheme.cyan: SchemePalette(
    accent: Color(0xFF00BCD4),
    accentLight: Color(0xFFB2EBF2),
    accentDark: Color(0xFF0097A7),
    surface: Color(0xFF16303A),
    secondary: Color(0xFFB2EBF2),
  ),
  AppColorScheme.emerald: SchemePalette(
    accent: Color(0xFF2BB673),
    accentLight: Color(0xFFA5E8C3),
    accentDark: Color(0xFF1B8F57),
    surface: Color(0xFF173227),
    secondary: Color(0xFFA5E8C3),
  ),
  AppColorScheme.amber: SchemePalette(
    accent: Color(0xFFFFD600),
    accentLight: Color(0xFFFFF3B0),
    accentDark: Color(0xFFE6B800),
    surface: Color(0xFF33301A),
    secondary: Color(0xFFFFF3B0),
  ),
  AppColorScheme.lavender: SchemePalette(
    accent: Color(0xFFA9A9C7),
    accentLight: Color(0xFFDFDFEC),
    accentDark: Color(0xFF8686B0),
    surface: Color(0xFF242435),
    secondary: Color(0xFFDFDFEC),
  ),
  AppColorScheme.rose: SchemePalette(
    accent: Color(0xFFFF5C8A),
    accentLight: Color(0xFFFFC2D6),
    accentDark: Color(0xFFE63C72),
    surface: Color(0xFF3A1E29),
    secondary: Color(0xFFFFC2D6),
  ),
};

/// Returns the palette for the current scheme name.
SchemePalette paletteForScheme(String name) {
  final scheme = AppColorScheme.values.firstWhere(
    (s) => s.name.toLowerCase() == name.toLowerCase(),
    orElse: () => AppColorScheme.azure,
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
    required this.reduceMotion,
    required this.hapticsEnabled,
    required this.amoledBlack,
    required this.textScale,
    required this.readerWarmNight,
    required this.showSourcePreviewPane,
  });

  // All requested defaults from spec
  factory AppearanceSettings.defaults() => const AppearanceSettings(
        colorScheme: 'Azure',
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
        pinNavUiOnScroll: true,
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
        useFrostedGlass: false,
        reduceMotion: false,
        hapticsEnabled: true,
        amoledBlack: false,
        textScale: 1.0,
        readerWarmNight: false,
        showSourcePreviewPane: true,
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

  /// When true, decorative and looping animations (the Explore hero sheen and
  /// the loading shimmer) are skipped. Also follows the platform's "remove
  /// animations" accessibility setting at the point of use.
  final bool reduceMotion;

  /// When true (the default), deliberate actions tap back: switching tabs,
  /// favouriting a title, and finishing a chapter.
  final bool hapticsEnabled;

  /// When true, dark mode drops its near-black surfaces for pure black, which
  /// an OLED panel draws with the pixels off. Off by default: on an LCD the
  /// setting buys nothing and flattens the cards against the background.
  final bool amoledBlack;
  final bool readerWarmNight;
  final double textScale;

  /// Show the preview pane in the source grid on wide layouts.
  final bool showSourcePreviewPane;

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
    bool? reduceMotion,
    bool? hapticsEnabled,
    bool? amoledBlack,
    double? textScale,
    bool? readerWarmNight,
    bool? showSourcePreviewPane,
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
        reduceMotion: reduceMotion ?? this.reduceMotion,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        amoledBlack: amoledBlack ?? this.amoledBlack,
        textScale: textScale ?? this.textScale,
        readerWarmNight: readerWarmNight ?? this.readerWarmNight,
        showSourcePreviewPane: showSourcePreviewPane ?? this.showSourcePreviewPane,
      );
}

// ---------------------------------------------------------------------------
// Persistence helpers
// ---------------------------------------------------------------------------

/// Old preset names the picker used before the schemes were recolored,
/// mapped onto their replacements so a stored choice survives the rename.
/// Unknown names fall back to the default rather than silently rendering
/// with the wrong palette, and known names come back capitalised the way the
/// picker stores them.
String migrateSchemeName(String name) {
  const legacy = {
    // The five recolored presets...
    'mion': 'Sepia',
    'rikka': 'Cyan',
    'sakura': 'Emerald',
    'mamimi': 'Amber',
    'itsuka': 'Rose',
    // ...and the six renamed without a recolor, so a name written by any
    // earlier build still lands on the scheme it used to mean.
    'totoro': 'Azure',
    'dynamic': 'Violet',
    'expressive': 'Tangerine',
    'miku': 'Teal',
    'asuka': 'Crimson',
    'kanade': 'Lavender',
  };
  final lower = name.toLowerCase();
  if (AppColorScheme.values.any((s) => s.name == lower)) {
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
  return legacy[lower] ?? 'Azure';
}

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
  static const _reduceMotion = '${_prefix}reduceMotion';
  static const _haptics = '${_prefix}hapticsEnabled';
  static const _amoledBlack = '${_prefix}amoledBlack';
  static const _readerWarmNight = '${_prefix}readerWarmNight';
  static const _textScale = '${_prefix}textScale';
  static const _showSourcePreviewPane = '${_prefix}showSourcePreviewPane';

  static Future<AppearanceSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final themeModeStr = p.getString(_themeMode) ?? '';
    final themeMode = ThemeMode.values.asNameMap()[themeModeStr] ?? ThemeMode.system;

    return AppearanceSettings(
      colorScheme: migrateSchemeName(p.getString(_colorScheme) ?? 'Azure'),
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
      pinNavUiOnScroll: p.getBool(_pinScroll) ?? true,
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
      useFrostedGlass: p.getBool(_frostedGlass) ?? false,
      reduceMotion: p.getBool(_reduceMotion) ?? false,
      hapticsEnabled: p.getBool(_haptics) ?? true,
      amoledBlack: p.getBool(_amoledBlack) ?? false,
      readerWarmNight: p.getBool(_readerWarmNight) ?? false,
      textScale: p.getDouble(_textScale) ?? 1.0,
      showSourcePreviewPane: p.getBool(_showSourcePreviewPane) ?? true,
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
    await p.setBool(_reduceMotion, s.reduceMotion);
    await p.setBool(_haptics, s.hapticsEnabled);
    await p.setBool(_amoledBlack, s.amoledBlack);
    await p.setBool(_readerWarmNight, s.readerWarmNight);
    await p.setDouble(_textScale, s.textScale);
    await p.setBool(_showSourcePreviewPane, s.showSourcePreviewPane);
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
      case 'reduceMotion':
        set((s) => s.copyWith(reduceMotion: !s.reduceMotion));
      case 'hapticsEnabled':
        set((s) => s.copyWith(hapticsEnabled: !s.hapticsEnabled));
      case 'amoledBlack':
        set((s) => s.copyWith(amoledBlack: !s.amoledBlack));
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

  Future<void> setReaderWarmNight(bool value) async =>
      set((s) => s.copyWith(readerWarmNight: value));

  Future<void> setTextScale(double value) async =>
      set((s) => s.copyWith(textScale: value));

  Future<void> setShowSourcePreviewPane(bool value) async =>
      set((s) => s.copyWith(showSourcePreviewPane: value));
}

final appearanceSettingsProvider =
    StateNotifierProvider<AppearanceSettingsNotifier, AppearanceSettings>(
        (ref) => AppearanceSettingsNotifier());

/// Whether decorative motion should be suppressed: the reader turned on
/// "Reduce motion", or the system's remove-animations accessibility setting is
/// on. Used by the handful of purely-cosmetic animations (the Explore hero
/// sheen, the loading shimmer) so a budget device can skip them.
///
/// Watches [appearanceSettingsProvider], so call it from `build`; the widgets
/// that gate on it wrap their animation in a `TickerMode` driven by this.
bool reduceMotionEnabled(WidgetRef ref) =>
    ref.watch(appearanceSettingsProvider).reduceMotion ||
    WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations;

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
      orElse: () => AppColorScheme.azure,
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
      orElse: () => AppColorScheme.azure,
    );
    return schemePalettes[scheme]?.secondary;
  } catch (_) {
    return null;
  }
}

/// The [ColorScheme] a named preset produces at [brightness].
///
/// This is the one construction the real themes are built from, so a settings
/// swatch painted from it previews the scheme the user would actually get --
/// primary, secondary, outline and on-surface roles included -- instead of an
/// approximation that can drift away from it.
ColorScheme colorSchemeFor(String schemeName, Brightness brightness) {
  if (schemeName.toLowerCase() == 'monochrome') {
    return monochromeScheme(brightness);
  }
  final scheme = ColorScheme.fromSeed(
    seedColor: themeSeedFor(schemeName),
    brightness: brightness,
  );
  final secondary = themeSecondaryFor(schemeName);
  return secondary == null ? scheme : scheme.copyWith(secondary: secondary);
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
    // ThemeData derives its default icon color from the brightness passed to
    // its constructor, and this base is always built light. Without setting it
    // here, every bare Icon(...) stays black in dark mode -- invisible on the
    // black scaffold (e.g. Explore's "manage presets" button).
    iconTheme: IconThemeData(color: fg),
    // The same reasoning as the icon color above, for the disabled state:
    // ThemeData's default disabledColor is black38 from the light base, so a
    // row the active settings cannot honour (the reader's two-pages row on a
    // strip mode) painted black text on the black scaffold and vanished.
    disabledColor: dark ? Colors.white38 : Colors.black38,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      foregroundColor: fg,
      iconTheme: IconThemeData(color: fg),
      // The bar itself is transparent so the scaffold shows through it, but
      // Flutter picks the status bar's icon colour by estimating the bar's
      // *own* background -- and a transparent colour estimates as dark, so a
      // light screen was handed white status-bar icons over a white scaffold
      // and the status bar vanished. The scaffold behind the bar is what the
      // icons actually sit on, so name the style by the theme's brightness
      // instead of letting the framework guess from a transparent fill.
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
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
///
/// The tonal roles matter as much as the primaries: `ColorScheme.light` and
/// `ColorScheme.dark` answer `secondaryContainer`, `onSecondaryContainer` and
/// `outlineVariant` with defaults of their own, which tinted the selected
/// preset card and the reading-progress ring in a scheme that is supposed to
/// carry no hue at all. `tertiaryContainer` and `onTertiaryContainer` are the
/// same trap for the favourite heart on the cover's other corner: left to a
/// default it cannot match the disc the ring wears.
ColorScheme monochromeScheme(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return const ColorScheme.dark(
      primary: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF000000),
      primaryContainer: Color(0xFF2A2A2A),
      onPrimaryContainer: Color(0xFFFFFFFF),
      secondary: Color(0xFFCCCCCC),
      secondaryContainer: Color(0xFF2A2A2A),
      onSecondaryContainer: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFF2A2A2A),
      onTertiaryContainer: Color(0xFFFFFFFF),
      outlineVariant: Color(0xFF3F3F3F),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFFFFFFF),
    );
  }
  return const ColorScheme.light(
    primary: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE0E0E0),
    onPrimaryContainer: Color(0xFF000000),
    secondary: Color(0xFF444444),
    secondaryContainer: Color(0xFFE0E0E0),
    onSecondaryContainer: Color(0xFF000000),
    tertiaryContainer: Color(0xFFE0E0E0),
    onTertiaryContainer: Color(0xFF000000),
    outlineVariant: Color(0xFFC7C7C7),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF000000),
  );
}

/// The app-wide slider look: Material 3 Expressive's own slider, opted into
/// once here instead of being restyled by hand.
///
/// Flutter still defaults to the year-2023 slider -- a 4px track under a 10px
/// circle -- so without this every `Slider` and `RangeSlider` in the app would
/// get the older look. `year2023: false` selects the expressive spec instead:
/// a 16px track, a primary fill over a secondary-container trough, a primary
/// 4x44 handle standing in a gap cut through the track, and a stop dot at
/// every division. Every other field stays null so the framework supplies the
/// spec, which means a spec change reaches the app for free.
///
/// The flag is deprecated only because it is scheduled to default to false and
/// then go away; until it does, setting it is how the spec is requested at all
/// -- the alternative is spelling out each of the dozens of tokens it selects,
/// which would pin the look to whatever they are today.
SliderThemeData _sliderTheme() {
  // ignore: deprecated_member_use
  return const SliderThemeData(year2023: false);
}

/// [scheme] with every surface role flattened to pure black.
///
/// `ColorScheme.fromSeed` fills the `surfaceContainer*` tones in explicitly
/// rather than leaving them to default off `surface`, so overriding `surface`
/// alone would leave cards, sheets and menus sitting on their near-black. Each
/// role is named here so "Black" reaches the chrome that draws itself from the
/// scheme rather than from a literal.
ColorScheme _blackSurfaces(ColorScheme scheme) => scheme.copyWith(
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceBright: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: Colors.black,
      surfaceContainer: Colors.black,
      surfaceContainerHigh: Colors.black,
      surfaceContainerHighest: Colors.black,
      surfaceTint: Colors.black,
    );

/// Creates the final ThemeData for a given brightness. Dark mode uses a pure
/// black scaffold over near-black surfaces, or over pure black throughout when
/// "Black" (AMOLED) is on.
ThemeData _applyBrightness(
  ThemeData base,
  Brightness brightness, {
  required String schemeName,
  required bool amoled,
}) {
  final dark = brightness == Brightness.dark;

  // "Black" only has a dark theme to act on.
  final black = amoled && dark;

  final preset = colorSchemeFor(schemeName, brightness);
  final colorScheme = black ? _blackSurfaces(preset) : preset;

  // The dark scaffold wears the scheme's own surface, what Kotatsu-Redo
  // paints when its Black toggle is off: not a fixed near-black, but the
  // shade the scheme's seed decides -- anything from a soft grey-blue to
  // pure black (Monochrome pins its dark surface to black) -- with "Black"
  // flattening every surface role to black and the scaffold riding along
  // on colorScheme.surface. Light keeps the fixed off-white the light cards
  // lift off of.
  final scaffoldBg = dark
      ? colorScheme.surface
      : const Color(0xFFF8F9FA);

  // Cards and canvas follow the same rule as the scaffold: the scheme's
  // surface, flattened to pure black when "Black" is on. Monochrome's dark
  // scheme already pins surface to black, so it keeps its AMOLED look with
  // no special case of its own.
  final surfaceColor = dark ? colorScheme.surface : Colors.white;

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

  // The line under a row is secondary text, and reads as it at the weight the
  // platform gave it rather than at the heavier `onSurfaceVariant` Material 3
  // reaches for. Kotatsu's preference lists paint their summaries with
  // `?android:textColorSecondary` -- the foreground at a little over half -- so
  // a row's value there sits back from its name instead of reading as a second
  // name. Named once here, so every list's subtitle is the same grey.
  final listTileTheme = base.listTileTheme.copyWith(
    subtitleTextStyle: textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface.withValues(alpha: 0.6),
    ),
  );

  // The one near-black surface the base theme paints on a widget's behalf
  // rather than being spelled out at a call site: the snackbar's slab.
  final snackBarTheme = black
      ? base.snackBarTheme.copyWith(backgroundColor: Colors.black)
      : base.snackBarTheme;

  return base.copyWith(
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBg,
    canvasColor: surfaceColor,
    cardColor: surfaceColor,
    textTheme: textTheme,
    sliderTheme: _sliderTheme(),
    listTileTheme: listTileTheme,
    snackBarTheme: snackBarTheme,
    // Carried on the theme so the widgets that paint their own near-black
    // chrome can ask whether to go black without a provider lookup.
    extensions: [AmoledMode(enabled: black)],
  );
}

/// Derived theme bundle — watch this at the root to drive MaterialApp.
final themeNotifierProvider = Provider<ThemeDataBundle>((ref) {
  final settings = ref.watch(appearanceSettingsProvider);
  final light = _applyBrightness(
    _baseTheme(false),
    Brightness.light,
    schemeName: settings.colorScheme,
    amoled: settings.amoledBlack,
  );
  final dark = _applyBrightness(
    _baseTheme(true),
    Brightness.dark,
    schemeName: settings.colorScheme,
    amoled: settings.amoledBlack,
  );
  return ThemeDataBundle(
    lightTheme: light,
    darkTheme: dark,
    mode: settings.themeMode,
  );
});