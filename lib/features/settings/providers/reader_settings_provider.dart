import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scale mode ids ("Scale mode" picker).
const kScaleFitCenter = 'fitCenter';
const kScaleFitHeight = 'fitHeight';
const kScaleFitWidth = 'fitWidth';
const kScaleKeepAtStart = 'keepAtStart';

/// Screen orientation ids ("Screen orientation" picker).
///
/// "Default" and "Automatic" are distinct: Default keeps the orientation the
/// reader opened in, so the device cannot rotate out from under a page being
/// read; Automatic follows the device as it turns.
const kOrientDefault = 'default';
const kOrientAutomatic = 'automatic';
const kOrientPortrait = 'portrait';
const kOrientLandscape = 'landscape';

/// Reader background ids ("Background" picker).
const kBgDefault = 'default';
const kBgLight = 'light';
const kBgDark = 'dark';
const kBgWhite = 'white';
const kBgBlack = 'black';

/// Page preload ids ("Preload pages" picker).
const kPreloadAlways = 'always';
const kPreloadWifiOnly = 'wifi';
const kPreloadNever = 'never';

/// Page-flash colour ids ("Flash with" picker).
const kFlashWhite = 'white';
const kFlashBlack = 'black';

/// Global reader defaults, shown in Settings > Reader.
///
/// These are *defaults*: a title the reader already has a stored choice for
/// keeps that choice (see [resolveReaderContext]). Values here are the
/// persistent `rs.*` keys; the per-title keys are the `<mangaId>_reader_*` ones
/// the reader has always written, left untouched for compatibility.
class ReaderSettings {
  const ReaderSettings({
    required this.readingMode,
    required this.scaleMode,
    required this.twoPages,
    required this.fullscreen,
    required this.orientation,
    required this.keepScreenOn,
    required this.showInfoBar,
    required this.transparentInfoBar,
    required this.showChapterPopup,
    required this.background,
    required this.numberedPages,
    required this.volumeButtons,
    required this.invertNavigation,
    required this.reduceMemory,
    required this.preload,
    required this.webtoonGaps,
    required this.flashOnPageChange,
    required this.flashWith,
    required this.flashDurationMs,
    required this.flashEvery,
    required this.webtoonZoomOut,
  });

  factory ReaderSettings.defaults() => const ReaderSettings(
        readingMode: 'webtoon',
        scaleMode: kScaleFitCenter,
        twoPages: false,
        fullscreen: true,
        orientation: kOrientDefault,
        keepScreenOn: true,
        showInfoBar: true,
        transparentInfoBar: true,
        showChapterPopup: true,
        background: kBgDefault,
        numberedPages: false,
        volumeButtons: false,
        invertNavigation: false,
        reduceMemory: false,
        preload: kPreloadAlways,
        webtoonGaps: false,
        flashOnPageChange: false,
        flashWith: kFlashWhite,
        flashDurationMs: 300,
        flashEvery: 1,
        webtoonZoomOut: 0,
      );

  /// Default [ReadingMode] name, matching the enum in the reader.
  final String readingMode;
  final String scaleMode;
  final bool twoPages;
  final bool fullscreen;
  final String orientation;
  final bool keepScreenOn;
  final bool showInfoBar;
  final bool transparentInfoBar;
  final bool showChapterPopup;
  final String background;
  final bool numberedPages;

  /// Volume buttons turn pages rather than changing volume.
  final bool volumeButtons;

  /// Swap the direction of volume and hardware key navigation.
  final bool invertNavigation;
  final bool reduceMemory;
  final String preload;
  final bool webtoonGaps;
  final bool flashOnPageChange;
  final String flashWith;
  final int flashDurationMs;

  /// Flash once every N pages rather than on every page.
  final int flashEvery;

  /// How far a webtoon strip starts zoomed out, 0-50.
  final int webtoonZoomOut;

  ReaderSettings copyWith({
    String? readingMode,
    String? scaleMode,
    bool? twoPages,
    bool? fullscreen,
    String? orientation,
    bool? keepScreenOn,
    bool? showInfoBar,
    bool? transparentInfoBar,
    bool? showChapterPopup,
    String? background,
    bool? numberedPages,
    bool? volumeButtons,
    bool? invertNavigation,
    bool? reduceMemory,
    String? preload,
    bool? webtoonGaps,
    bool? flashOnPageChange,
    String? flashWith,
    int? flashDurationMs,
    int? flashEvery,
    int? webtoonZoomOut,
  }) =>
      ReaderSettings(
        readingMode: readingMode ?? this.readingMode,
        scaleMode: scaleMode ?? this.scaleMode,
        twoPages: twoPages ?? this.twoPages,
        fullscreen: fullscreen ?? this.fullscreen,
        orientation: orientation ?? this.orientation,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        showInfoBar: showInfoBar ?? this.showInfoBar,
        transparentInfoBar: transparentInfoBar ?? this.transparentInfoBar,
        showChapterPopup: showChapterPopup ?? this.showChapterPopup,
        background: background ?? this.background,
        numberedPages: numberedPages ?? this.numberedPages,
        volumeButtons: volumeButtons ?? this.volumeButtons,
        invertNavigation: invertNavigation ?? this.invertNavigation,
        reduceMemory: reduceMemory ?? this.reduceMemory,
        preload: preload ?? this.preload,
        webtoonGaps: webtoonGaps ?? this.webtoonGaps,
        flashOnPageChange: flashOnPageChange ?? this.flashOnPageChange,
        flashWith: flashWith ?? this.flashWith,
        flashDurationMs: flashDurationMs ?? this.flashDurationMs,
        flashEvery: flashEvery ?? this.flashEvery,
        webtoonZoomOut: webtoonZoomOut ?? this.webtoonZoomOut,
      );
}

/// Image-cache budget, toggled by "Reduce memory consumption". A long webtoon
/// chapter holds whole decoded bitmaps, so this is the reader's real peak
/// memory cost; the low profile also pulls in fewer pages ahead.
class MemoryProfile {
  const MemoryProfile({
    required this.imageCacheBytes,
    required this.prefetchWindow,
  });

  final int imageCacheBytes;

  /// How many pages ahead the reader is willing to prefetch.
  final int prefetchWindow;

  static const MemoryProfile normal =
      MemoryProfile(imageCacheBytes: 160 << 20, prefetchWindow: 8);
  static const MemoryProfile low =
      MemoryProfile(imageCacheBytes: 48 << 20, prefetchWindow: 2);

  static MemoryProfile forReduceMemory(bool reduce) =>
      reduce ? low : normal;
}

/// Per-title overrides and host capabilities the reader needs, resolved once
/// when the reader opens.
class ReaderContext {
  const ReaderContext({
    required this.settings,
    required this.overridden,
  });

  final ReaderSettings settings;

  /// Per-title keys that actually won, so the reader can keep writing them.
  final Set<String> overridden;
}

/// Resolves the effective settings for [mangaId].
///
/// A `<mangaId>_reader_*` key that the reader has already written wins, so
/// every per-title choice made before Settings existed keeps working exactly
/// as it did. Anything the reader never stored per-title falls back to the
/// global default from Settings > Reader.
Future<ReaderContext> resolveReaderContext(String? mangaId) async {
  final settings = await _ReaderSettingsPersistence.load();
  final overridden = <String>{};
  if (mangaId == null || mangaId.isEmpty) {
    return ReaderContext(settings: settings, overridden: overridden);
  }

  final prefs = await SharedPreferences.getInstance();

  String? mode;
  if (prefs.containsKey('${mangaId}_reader_mode')) {
    mode = prefs.getString('${mangaId}_reader_mode');
    overridden.add('reader_mode');
  }
  // Legacy: orientation was a boolean landscape lock. `false` meant "don't
  // force rotation", which is the "Default" (keep as opened) value today.
  final rotate = prefs.getBool('${mangaId}_reader_rotate_screen');
  bool? twoPages;
  if (prefs.containsKey('${mangaId}_reader_two_pages')) {
    twoPages = prefs.getBool('${mangaId}_reader_two_pages');
    overridden.add('reader_two_pages');
  }
  double? brightness;
  if (prefs.containsKey('${mangaId}_reader_brightness')) {
    brightness = prefs.getDouble('${mangaId}_reader_brightness');
    overridden.add('reader_brightness');
  }
  if (rotate != null) overridden.add('reader_rotate_screen');

  if (mode == null &&
      rotate == null &&
      twoPages == null &&
      brightness == null) {
    return ReaderContext(settings: settings, overridden: overridden);
  }

  // Brightness is deliberately absent: it has no global row, so the reader's
  // own colour-correction dialog remains the only thing that writes it.
  return ReaderContext(
    settings: settings.copyWith(
      readingMode: mode,
      orientation: rotate == null
          ? null
          : (rotate ? kOrientLandscape : kOrientDefault),
      twoPages: twoPages,
    ),
    overridden: overridden,
  );
}

class _ReaderSettingsPersistence {
  static const _kMode = 'rs.mode';
  static const _kScale = 'rs.scale';
  static const _kTwoPages = 'rs.twoPages';
  static const _kFullscreen = 'rs.fullscreen';
  static const _kOrientation = 'rs.orientation';
  static const _kKeepScreenOn = 'rs.keepScreenOn';
  static const _kShowInfoBar = 'rs.showInfoBar';
  static const _kTransparentBar = 'rs.transparentBar';
  static const _kChapterPopup = 'rs.chapterPopup';
  static const _kBackground = 'rs.background';
  static const _kNumberedPages = 'rs.numberedPages';
  static const _kVolume = 'rs.volume';
  static const _kInvertNav = 'rs.invertNav';
  static const _kReduceMemory = 'rs.reduceMemory';
  static const _kPreload = 'rs.preload';
  static const _kWebtoonGaps = 'rs.webtoonGaps';
  static const _kFlashOnChange = 'rs.flashOnChange';
  static const _kFlashWith = 'rs.flashWith';
  static const _kFlashDuration = 'rs.flashDuration';
  static const _kFlashEvery = 'rs.flashEvery';
  static const _kWebtoonZoomOut = 'rs.webtoonZoomOut';

  /// Global keys an earlier iteration wrote that nothing reads any more. They
  /// are removed once so a retired setting cannot linger in prefs and look like
  /// a live one to whoever debugs the app next.
  static const List<String> _retiredKeys = [
    'rs.brightness',
    'rs.memory',
    'rs.imageMemory',
    'rs.wideColor',
  ];

  static Future<ReaderSettings> load() async {
    final p = await SharedPreferences.getInstance();
    for (final key in _retiredKeys) {
      if (p.containsKey(key)) await p.remove(key);
    }
    return ReaderSettings(
      readingMode: p.getString(_kMode) ?? 'webtoon',
      scaleMode: p.getString(_kScale) ?? kScaleFitCenter,
      twoPages: p.getBool(_kTwoPages) ?? false,
      fullscreen: p.getBool(_kFullscreen) ?? true,
      orientation: p.getString(_kOrientation) ?? kOrientDefault,
      keepScreenOn: p.getBool(_kKeepScreenOn) ?? true,
      showInfoBar: p.getBool(_kShowInfoBar) ?? true,
      transparentInfoBar: p.getBool(_kTransparentBar) ?? true,
      showChapterPopup: p.getBool(_kChapterPopup) ?? true,
      background: p.getString(_kBackground) ?? kBgDefault,
      numberedPages: p.getBool(_kNumberedPages) ?? false,
      volumeButtons: p.getBool(_kVolume) ?? false,
      invertNavigation: p.getBool(_kInvertNav) ?? false,
      reduceMemory: p.getBool(_kReduceMemory) ?? false,
      preload: p.getString(_kPreload) ?? kPreloadAlways,
      webtoonGaps: p.getBool(_kWebtoonGaps) ?? false,
      flashOnPageChange: p.getBool(_kFlashOnChange) ?? false,
      flashWith: p.getString(_kFlashWith) ?? kFlashWhite,
      flashDurationMs: p.getInt(_kFlashDuration) ?? 300,
      flashEvery: p.getInt(_kFlashEvery) ?? 1,
      webtoonZoomOut: p.getInt(_kWebtoonZoomOut) ?? 0,
    );
  }

  static Future<void> save(ReaderSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMode, s.readingMode);
    await p.setString(_kScale, s.scaleMode);
    await p.setBool(_kTwoPages, s.twoPages);
    await p.setBool(_kFullscreen, s.fullscreen);
    await p.setString(_kOrientation, s.orientation);
    await p.setBool(_kKeepScreenOn, s.keepScreenOn);
    await p.setBool(_kShowInfoBar, s.showInfoBar);
    await p.setBool(_kTransparentBar, s.transparentInfoBar);
    await p.setBool(_kChapterPopup, s.showChapterPopup);
    await p.setString(_kBackground, s.background);
    await p.setBool(_kNumberedPages, s.numberedPages);
    await p.setBool(_kVolume, s.volumeButtons);
    await p.setBool(_kInvertNav, s.invertNavigation);
    await p.setBool(_kReduceMemory, s.reduceMemory);
    await p.setString(_kPreload, s.preload);
    await p.setBool(_kWebtoonGaps, s.webtoonGaps);
    await p.setBool(_kFlashOnChange, s.flashOnPageChange);
    await p.setString(_kFlashWith, s.flashWith);
    await p.setInt(_kFlashDuration, s.flashDurationMs);
    await p.setInt(_kFlashEvery, s.flashEvery);
    await p.setInt(_kWebtoonZoomOut, s.webtoonZoomOut);
  }
}

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  ReaderSettingsNotifier() : super(ReaderSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    state = await _ReaderSettingsPersistence.load();
  }

  Future<void> _update(ReaderSettings next) async {
    state = next;
    await _ReaderSettingsPersistence.save(next);
  }

  Future<void> setReadingMode(String mode) =>
      _update(state.copyWith(readingMode: mode));

  Future<void> setScaleMode(String mode) => _update(state.copyWith(scaleMode: mode));

  Future<void> setTwoPages(bool value) => _update(state.copyWith(twoPages: value));

  Future<void> setFullscreen(bool value) => _update(state.copyWith(fullscreen: value));

  Future<void> setOrientation(String value) =>
      _update(state.copyWith(orientation: value));

  /// Applied to the window immediately: the reader holds the screen awake
  /// only while it is open, and a persisted value that took effect on next
  /// launch would leave the screen dimming mid-chapter.
  Future<void> setKeepScreenOn(bool value) async {
    await _update(state.copyWith(keepScreenOn: value));
  }

  Future<void> setShowInfoBar(bool value) =>
      _update(state.copyWith(showInfoBar: value));

  Future<void> setTransparentInfoBar(bool value) =>
      _update(state.copyWith(transparentInfoBar: value));

  Future<void> setShowChapterPopup(bool value) =>
      _update(state.copyWith(showChapterPopup: value));

  Future<void> setBackground(String value) =>
      _update(state.copyWith(background: value));

  Future<void> setNumberedPages(bool value) =>
      _update(state.copyWith(numberedPages: value));

  Future<void> setVolumeButtons(bool value) =>
      _update(state.copyWith(volumeButtons: value));

  Future<void> setInvertNavigation(bool value) =>
      _update(state.copyWith(invertNavigation: value));

  Future<void> setReduceMemory(bool value) =>
      _update(state.copyWith(reduceMemory: value));

  Future<void> setPreload(String value) => _update(state.copyWith(preload: value));

  Future<void> setWebtoonGaps(bool value) =>
      _update(state.copyWith(webtoonGaps: value));

  Future<void> setFlashOnPageChange(bool value) =>
      _update(state.copyWith(flashOnPageChange: value));

  Future<void> setFlashWith(String value) => _update(state.copyWith(flashWith: value));

  Future<void> setFlashDuration(int ms) =>
      _update(state.copyWith(flashDurationMs: ms));

  Future<void> setFlashEvery(int pages) =>
      _update(state.copyWith(flashEvery: pages));

  Future<void> setWebtoonZoomOut(int value) =>
      _update(state.copyWith(webtoonZoomOut: value));
}

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
        (ref) => ReaderSettingsNotifier());

/// Host window controls the reader needs. Every method degrades to a safe
/// default rather than throwing, because a missing platform side must not take
/// the reader down.
class ReaderPlatform {
  const ReaderPlatform._();

  static const MethodChannel _channel =
      MethodChannel('com.hlomatsi.yomou/display');

  /// Holds the window awake while the reader is open. Returns whether the
  /// request reached the platform, so the caller can tell "asked and refused"
  /// apart from "there was nothing there to ask".
  static Future<bool> setKeepScreenOn(bool enabled) async {
    try {
      return await _channel
              .invokeMethod<bool>('setKeepScreenOn', {'enabled': enabled}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Whether the active network is unmetered, which is what "Only on Wi-Fi"
  /// preload needs. Falls back to true (preload) when unknown, so a failed
  /// probe never silently stops preloading.
  static Future<bool> isUnmetered() async {
    try {
      return await _channel.invokeMethod<bool>('isUnmetered') ?? true;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }
}
