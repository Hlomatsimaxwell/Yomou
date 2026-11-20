import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Remembers how tall each page image is relative to its width.
///
/// The vertical reader lays a page out at the screen width and lets the image
/// choose its height, so until the image arrives a page's height is only a
/// guess. That guess is wrong for most pages: a webtoon panel is often four to
/// eight screens tall while a manga page is about one and a half, so every page
/// grew or shrank when its image decoded and pushed everything below it. That
/// movement is what made a slider seek land on the wrong page -- the reader
/// computed the target offset from the heights it had at that moment, then the
/// strip rearranged itself underneath.
///
/// A page's ratio is a property of its image, so once a page has been shown it
/// is kept here. The next time that page is laid out -- scrolling back over it,
/// reopening the chapter, or after a restart -- the placeholder reserves its
/// real height and the pages below it stay put.
class PageGeometryCache {
  PageGeometryCache({
    this.maxEntries = 3000,
    this.saveDelay = const Duration(seconds: 3),
  });

  static final PageGeometryCache instance = PageGeometryCache();

  /// Most ratios kept. Each entry is a URL and a small number, so the cap is
  /// about a few hundred kilobytes of JSON rather than a memory concern; it is
  /// there to stop a long-running install growing the file forever.
  final int maxEntries;

  /// How long writes are batched before the file is rewritten.
  final Duration saveDelay;

  static const _fileName = 'page_geometry.json';
  static const _version = 1;

  /// Ratio of height to width, oldest entry first so the cap drops the pages
  /// that were seen longest ago.
  final Map<String, double> _ratios = <String, double>{};

  bool _loaded = false;
  Future<void>? _loading;
  Timer? _saveTimer;
  bool _dirty = false;

  /// Test hook: use this directory instead of the application-support one.
  @visibleForTesting
  Directory? debugDirectory;

  /// The remembered ratio for [key], or null when this page has not been shown
  /// yet (or the cache has not finished loading).
  double? ratioFor(String key) {
    if (key.isEmpty) return null;
    return _ratios[key];
  }

  /// Reads the saved ratios once. Safe to call from every reader session.
  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final file = await _file();
      if (file != null && await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          final raw = decoded['ratios'];
          if (raw is Map<String, dynamic>) {
            for (final entry in raw.entries) {
              final value = entry.value;
              if (value is num && value > 0) {
                _ratios[entry.key] = value.toDouble();
              }
            }
          }
        }
      }
    } catch (_) {
      // A corrupt or unreadable file is not worth failing a reader over: the
      // ratios are an optimisation and every page will simply be measured
      // again as it is shown.
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  /// Records that an image of [width] x [height] pixels was shown for [key].
  ///
  /// [width] and [height] are the decoded image's own dimensions, so the ratio
  /// is independent of the screen, the zoom level and the decode width.
  void remember(String key, int width, int height) {
    if (key.isEmpty || width <= 0 || height <= 0) return;
    final ratio = double.parse((height / width).toStringAsFixed(4));
    if (_ratios[key] == ratio) return;
    _ratios.remove(key);
    _ratios[key] = ratio;
    while (_ratios.length > maxEntries) {
      _ratios.remove(_ratios.keys.first);
    }
    _scheduleSave();
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(flush()));
  }

  /// Writes the pending changes now. Called by the save timer and on teardown.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return;
    _dirty = false;
    try {
      final file = await _file();
      if (file == null) return;
      await file.writeAsString(
        jsonEncode({'v': _version, 'ratios': _ratios}),
        flush: true,
      );
    } catch (_) {
      // Losing the file only costs the next session a re-measure.
    }
  }

  /// Forgets every remembered ratio, e.g. when the user resets the app.
  Future<void> clear() async {
    _ratios.clear();
    _saveTimer?.cancel();
    _saveTimer = null;
    _dirty = false;
    try {
      final file = await _file();
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<File?> _file() async {
    final override = debugDirectory;
    if (override != null) {
      await override.create(recursive: true);
      return File(p.join(override.path, _fileName));
    }
    final base = await getApplicationSupportDirectory();
    return File(p.join(base.path, _fileName));
  }
}
