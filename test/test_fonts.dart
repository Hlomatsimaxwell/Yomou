import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real Roboto into the test font collection.
///
/// Widget tests measure text with a fallback font that draws every glyph as a
/// square of side `fontSize`, so a 13-character label comes out exactly 13
/// `fontSize` wide. That is fine for finding a layout that has gone wrong and
/// useless for asking whether a label fits: it is about 1.8x wider than Roboto
/// for lowercase, so a cell sized to satisfy it is a cell sized for a font the
/// app does not ship.
///
/// The font comes from the Flutter SDK's own material font cache, which is where
/// the app's Roboto comes from too, so a measurement here is the measurement the
/// device makes.
class TestFonts {
  static bool _loaded = false;

  /// The family name the tests measure against.
  static const String family = 'Roboto';

  /// Loads Roboto once per test process. A no-op after the first call.
  ///
  /// Throws if the SDK's font cache cannot be found, because a test that quietly
  /// measures against the wrong font and passes is worse than one that fails.
  static Future<void> ensureLoaded() async {
    if (_loaded) return;

    final ttf = _findRoboto();
    if (ttf == null) {
      throw StateError(
        'Could not find Roboto-Regular.ttf in the Flutter SDK. A test that '
        'measures text needs the real font; without it the fallback draws every '
        'glyph as a full-em square and every width is wrong by about 1.8x.',
      );
    }

    final bytes = await File(ttf).readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
    _loaded = true;
  }

  /// Wraps [body] with Roboto installed as the default family.
  ///
  /// Widgets that set no font family fall back to the platform default, which in
  /// a test is the square-glyph font, so a test that wants real widths has to
  /// name the family on the theme rather than rely on the default.
  static Future<void> withRoboto(Future<void> Function() body) async {
    await ensureLoaded();
    return body();
  }

  static String? _findRoboto() {
    // The SDK root is the directory holding bin/cache, which is either next to
    // the running Dart binary or given by FLUTTER_ROOT.
    final roots = <String>[
      if (Platform.environment['FLUTTER_ROOT'] != null)
        Platform.environment['FLUTTER_ROOT']!,
      // <sdk>/bin/cache/dart-sdk/bin/dart -> up five is <sdk>
      _up(Platform.resolvedExecutable, 5),
    ];

    const relative =
        'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf';
    for (final root in roots) {
      final candidate = File('$root/$relative');
      if (candidate.existsSync()) return candidate.path;
    }
    return null;
  }

  static String _up(String path, int levels) {
    var dir = File(path).parent;
    for (var i = 0; i < levels; i++) {
      dir = dir.parent;
    }
    return dir.path;
  }
}
