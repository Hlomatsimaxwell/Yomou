import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../data/models/manga_source.dart';
import '../../data/providers/sources_provider.dart';

/// Headless bring-up check for sources whose content needs a browser to
/// appear (Cloudflare-challenged SPAs).
///
/// Enabled with a compile-time list of source ids, so it never runs in a
/// normal build:
///
/// ```
/// flutter run --dart-define=YOMOU_SELFTEST=mangafire-en
/// ```
///
/// It walks the same path the browse screen uses — popular listing, then
/// details for the first title — and prints one `SELFTEST` line per step, so
/// `adb logcat` shows exactly which stage returns nothing.
class SourceSelfTest {
  const SourceSelfTest._();

  static final List<String> enabledIds = _splitIds(
    String.fromEnvironment('YOMOU_SELFTEST'),
  );

  static bool get enabled => enabledIds.isNotEmpty;

  static List<String> _splitIds(String raw) {
    if (raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// Runs after the first frame so the navigator (and therefore the hidden
  /// WebView overlay) exists.
  static void schedule() {
    if (!enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => run());
  }

  static Future<void> run() async {
    for (final id in enabledIds) {
      final source = _sourceFor(id);
      if (source == null) {
        _log('$id UNKNOWN SOURCE ID');
        continue;
      }
      _log('$id start (${source.name})');
      final sw = Stopwatch()..start();
      try {
        final list = await source.getPopularManga();
        _log(
          '$id popular -> ${list.length} titles in ${sw.elapsedMilliseconds}ms',
        );
        if (list.isEmpty) continue;
        final first = list.first;
        _log('$id first -> id=${first.id} title=${first.title}');
        final dsw = Stopwatch()..start();
        final details = await source.getMangaDetails(first.id);
        _log(
          '$id details -> ${details?.id.isEmpty ?? true ? 'EMPTY' : 'ok'} '
          'chapters=${details?.totalChapters} tags=${details?.tags.length} '
          'translations=${details?.translations.length} '
          'in ${dsw.elapsedMilliseconds}ms',
        );
        if (details == null || details.id.isEmpty) continue;
        final csw = Stopwatch()..start();
        final chapters = await source.getChapters(details.id);
        _log(
          '$id chapters -> ${chapters.length} in ${csw.elapsedMilliseconds}ms',
        );
        if (chapters.isEmpty) continue;
        for (final c in chapters.take(3)) {
          _log(
            '$id   chapter id=${c.id} num="${c.chapterNumber}" '
            'title="${c.title}" lang=${c.scanlator} url=${c.url}',
          );
        }
        final psw = Stopwatch()..start();
        final pages = await source.getPageUrls(chapters.first.id);
        _log('$id pages -> ${pages.length} in ${psw.elapsedMilliseconds}ms');
        for (final p in pages.take(2)) {
          _log('$id   page $p');
        }
      } catch (e, st) {
        _log('$id FAILED: $e');
        if (kDebugMode) debugPrint('$st');
      }
    }
    _log('done');
  }

  static MangaSource? _sourceFor(String id) {
    for (final name in _allNames) {
      final source = getSourceByName(name);
      if (source.id == id) return source;
    }
    return null;
  }

  /// Every name the registry can build, discovered lazily through the public
  /// lookup: names are stable, so probing the known variants is enough.
  static const List<String> _allNames = [
    'MangaDex',
    'MangaDex Español',
    'MangaDex Portuguese BR',
    'MangaFire English',
    'MangaFire Spanish',
    'MangaFire Spanish Latin',
    'MangaFire French',
    'MangaFire Japanese',
    'MangaFire Portuguese',
    'MangaFire Portuguese Brazil',
    'MangaBall English',
  ];

  /// Synchronous on purpose: the throttled printer drops lines when the app
  /// is also logging request failures, and a silent self-test is useless.
  static void _log(String message) =>
      debugPrintSynchronously('SELFTEST $message');
}
