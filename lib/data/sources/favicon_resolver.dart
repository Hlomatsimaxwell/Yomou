import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/diagnostics/diag_log.dart';
import 'package:yomou/data/sources/source_network.dart' show DioSource;

/// A candidate logo scraped from a source's homepage, with the size the site
/// advertised for it (0 when it advertises none — the same default the
/// reference's `Favicon` model carries).
class _Icon {
  const _Icon(this.url, this.size);

  final String url;
  final int size;
}

/// A persisted discovery: when it was written and what it held. Stale
/// entries are re-discovered but keep serving until fresh data or a
/// definite miss replaces them.
class _DiskEntry {
  const _DiskEntry(this.time, this.urls);

  final DateTime time;
  final List<String> urls;
}

/// Port of Kotatsu-Redo's source-logo discovery, two halves of one pipeline:
///
/// 1. `FaviconParser` (kotatsu-parsers-redo) fetches the source's homepage and
///    collects every logo the site advertises: PWA manifest icons, any
///    `<link>` whose rel contains "icon" (the same case-sensitive match the
///    Java reference uses, so site spellings like "Shortcut Icon" are skipped
///    there and here alike), plus `rel="apple-touch-icon"` links. A site
///    advertising nothing falls back to `/favicon.ico`.
/// 2. `Favicons.find(sizePx)` then picks candidates by advertised size while
///    the app's `FaviconFetcher` walks them one at a time: the *smallest*
///    icon that still covers the requested pixels goes first (why download a
///    512px asset for a 56dp plate when a 192px one will do), and the rest
///    come largest-to-smallest.
///
/// Results are cached for the session, one lookup per host, shared by every
/// tile of that source; a host whose homepage gives nothing up stays cached
/// as empty for the session, the same shape as the reference's favicon disk
/// cache holding a failure.
///
/// The results also persist to [SharedPreferences] (`favicon:<host>`, 30-day
/// freshness, matching the app's image-cache stale period), so a source's
/// homepage is fetched once and every later session starts from disk like
/// the reference's `LocalStorageCache` does. Homepage fetches run through a
/// small gate (four at a time) so opening the sources wall never fires
/// dozens of them at once.
class FaviconResolver {
  FaviconResolver._();

  /// Session cache: origin -> ordered candidate URLs (possibly empty).
  static final Map<String, List<String>> _cache = {};

  /// Homepage lookups in flight, so N tiles of one source share one fetch.
  static final Map<String, Future<List<String>>> _inFlight = {};

  static const Duration _stale = Duration(days: 30);

  /// How many homepage fetches may run at once.
  static const int _maxConcurrent = 4;

  static int _active = 0;
  static final List<Completer<void>> _gateQueue = [];

  static Future<SharedPreferences>? _prefs;

  static Future<SharedPreferences> get _sharedPrefs =>
      _prefs ??= SharedPreferences.getInstance();

  /// Test seam: replaces the whole discovery for deterministic widget tests.
  @visibleForTesting
  static Future<List<String>> Function(String iconUrl)? debugOverride;

  /// `flutter test` runs (FLUTTER_TEST is set) never hit the network from a
  /// widget test zone; discovery only happens through [debugOverride] there,
  /// so the other suites' tiles fail straight into the letter tile exactly
  /// like they render today.
  static final bool _underTest = () {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }();

  /// Discovers the logos of the site pointed at by [siteUrl], falling back to
  /// [iconUrl]'s origin when no site URL is given. Ordered how a consumer
  /// should try them. Returns null only when neither URL has a usable http(s)
  /// host at all — then there is no homepage to scrape and the declared URL is
  /// all there ever was.
  ///
  /// [siteUrl] matters for catalog sources: their [iconUrl] points at a CDN
  /// (e.g. `cdn.jsdelivr.net` for the Mihon extension index), and scraping the
  /// CDN's homepage discovers the CDN's own favicon rather than the site's.
  static Future<List<String>>? candidates(String iconUrl, {String? siteUrl}) {
    if (_underTest) return debugOverride?.call(iconUrl);
    final origin = _originOf(siteUrl) ?? _originOf(iconUrl);
    if (origin == null) return null;
    final inFlight = _inFlight[origin];
    if (inFlight != null) return inFlight;
    final cached = _cache[origin];
    if (cached != null) return Future.value(cached);
    final future = _load(origin).whenComplete(() => _inFlight.remove(origin));
    _inFlight[origin] = future;
    return future;
  }

  /// The `scheme://host` of a homepage or asset URL, or null when it is not an
  /// absolute http(s) URL.
  static String? _originOf(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    final host = uri?.host;
    final scheme = uri?.scheme ?? '';
    if (host == null ||
        host.isEmpty ||
        scheme != 'https' && scheme != 'http') {
      return null;
    }
    return '$scheme://$host';
  }

  /// Disk first, network second: a fresh enough persisted entry answers the
  /// same way the reference's disk cache answers Coil — instantly, with no
  /// homepage traffic at all. A stale or missing entry is re-discovered; a
  /// failed discovery keeps serving whatever the disk had (a stale truth
  /// beats nothing).
  static Future<List<String>> _load(String origin) async {
    final diskEntry = await _readDisk(origin);
    if (diskEntry != null && _fresh(diskEntry)) {
      return _remember(origin, diskEntry.urls);
    }
    List<String> discovered;
    try {
      discovered = await _gated(() => _discover(origin));
    } on Exception {
      // A dead homepage with a stale-but-present entry keeps it; without one
      // the miss is recorded so the session stays consistent with the disk.
      return _remember(origin, diskEntry?.urls ?? const <String>[]);
    }
    unawaited(_writeDisk(origin, discovered));
    return _remember(origin, discovered);
  }

  static bool _fresh(_DiskEntry entry) =>
      DateTime.now().difference(entry.time) < _stale;

  static List<String> _remember(String origin, List<String> urls) {
    _cache[origin] = urls;
    return urls;
  }

  static Future<_DiskEntry?> _readDisk(String origin) async {
    try {
      final prefs = await _sharedPrefs;
      final raw = prefs.getString('favicon:$origin');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      final ms = switch (decoded['t']) {
        final int i => i,
        _ => 0,
      };
      final urls = switch (decoded['urls']) {
        final List l => [for (final e in l) if (e is String) e],
        _ => const <String>[],
      };
      return _DiskEntry(DateTime.fromMillisecondsSinceEpoch(ms), urls);
    } on Exception {
      return null;
    }
  }

  static Future<void> _writeDisk(String origin, List<String> urls) async {
    try {
      final prefs = await _sharedPrefs;
      final payload = jsonEncode({
        't': DateTime.now().millisecondsSinceEpoch,
        'urls': urls,
      });
      await prefs.setString('favicon:$origin', payload);
    } on Exception {
      // A cache write that cannot happen is not a discovery failure.
    }
  }

  /// Runs [task] under the concurrency gate, FIFO.
  static Future<T> _gated<T>(Future<T> Function() task) async {
    if (_active >= _maxConcurrent) {
      final wake = Completer<void>();
      _gateQueue.add(wake);
      await wake.future;
    }
    _active++;
    try {
      return await task();
    } finally {
      _active--;
      if (_gateQueue.isNotEmpty) _gateQueue.removeAt(0).complete();
    }
  }

  /// Plain HTTP client, mirroring the parser library's `WebClient`: a browser
  /// user agent, modest timeouts, plain-text bodies so both HTML and JSON
  /// manifest responses decode here.
  static final Dio _client = Dio(
    BaseOptions(
      headers: {'User-Agent': DioSource.defaultUserAgent},
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      responseType: ResponseType.plain,
    ),
  );

  static Future<List<String>> _discover(String origin) async {
    try {
      final body = (await _client.get<String>(origin)).data ?? '';
      if (body.trim().isEmpty) return const <String>[];
      final home = Uri.parse(origin);

      // The manifest lives at another URL; fetched separately, contributing
      // nothing when it is unreachable or broken — the reference wraps the
      // manifest step in runCatching.
      String? manifestBody;
      final manifestDoc = html_parser.parse(body);
      final manifest = manifestDoc
          .querySelectorAll('link[rel="manifest"]')
          .firstOrNull;
      final manifestHref = _absolute(
        manifest?.attributes['href'],
        home,
        allowTrailingSlash: true,
      );
      if (manifestHref != null) {
        try {
          manifestBody =
              (await _client.get<String>(manifestHref)).data;
        } on Exception {
          // Same as the reference: an unusable manifest is not an error.
        }
      }

      final ordered = parseHomeIcons(
        html: body,
        home: home,
        manifestBody: manifestBody,
      );
      diagSoon(
        'favicons $origin -> ${ordered.length}: '
        '${ordered.take(3).join(', ')}',
      );
      return ordered;
    } on Exception {
      // A dead or Cloudflare-gated homepage: the reference rethrows only the
      // Cloudflare kind up for human resolution; for a favicon probe a miss
      // is simply finished for the session and the tile shows the letter
      // tile.
      return const <String>[];
    }
  }

  /// The reference's `FaviconParser.parseFavicons` verbatim, minus the
  /// network: scrape [html] against the homepage [home], fold in the PWA
  /// manifest ([manifestBody], when its link was reachable), fall back to
  /// `/favicon.ico`, dedupe, size-sort, and hand the trial order back.
  @visibleForTesting
  static List<String> parseHomeIcons({
    required String html,
    required Uri home,
    String? manifestBody,
  }) {
    final doc = html_parser.parse(html);
    final icons = <_Icon>[];

    // Kotlin parses the manifest first (`getElementsByAttributeValue("rel",
    // "manifest")`, an exact rel match), then sweeps the icon links.
    if (manifestBody != null) {
      icons.addAll(_parseManifest(manifestBody, home));
    }

    for (final link in doc.querySelectorAll('link')) {
      final rel = link.attributes['rel'] ?? '';
      final isIcon = rel.contains('icon'); // case-sensitive, as in the reference
      final isTouch = rel == 'apple-touch-icon';
      if (!isIcon && !isTouch) continue;
      final href = _absolute(link.attributes['href'], home);
      if (href == null) continue;
      icons.add(_Icon(href, parseSize(link.attributes['sizes'] ?? '')));
    }

    if (icons.isEmpty) {
      // The reference's createFallback: the site published no link tags.
      icons.add(_Icon('${home.origin}/favicon.ico', 0));
    }

    // Kotlin's Favicons dedupes through HashSet equality on (url, size) and
    // sorts descending by size, stable for ties, keeping the site's own
    // advertisement order among equal sizes.
    final seen = <String>{};
    final deduped = <_Icon>[];
    for (final icon in icons) {
      if (seen.add('${icon.url}\u0000${icon.size}')) deduped.add(icon);
    }
    final positions = {for (final (i, icon) in deduped.indexed) icon: i};
    deduped.sort((a, b) {
      final bySize = b.size.compareTo(a.size);
      // Dart's sort is not stable; the site's own advertisement order
      // settles size ties, the same way the reference's stable sort does.
      return bySize != 0 ? bySize : positions[a]! - positions[b]!;
    });
    return tryOrder(
      [for (final icon in deduped) (icon.url, icon.size)],
      plateSizePx(),
    );
  }

  /// Resolves an HTML-attribute-relative href (or the manifest URL) against
  /// the homepage, and rejects the kinds the reference's parsers reject:
  /// empty hrefs and — icon links only — hrefs ending in '/', which are site
  /// roots rather than logos (the manifest link itself is exempt from that
  /// guard there too).
  static String? _absolute(
    String? raw,
    Uri home, {
    bool allowTrailingSlash = false,
  }) {
    if (raw == null || raw.isEmpty || raw.startsWith('#')) return null;
    if (!allowTrailingSlash && raw.endsWith('/')) return null;
    final resolved = home.resolve(raw);
    if (resolved.host.isEmpty) return null;
    return resolved.toString();
  }

  /// PWA manifest icons. `src` values resolve against the *site*, not the
  /// manifest path, exactly like the reference's `resolveLink()` applied to
  /// the manifest entries (absolutely there so odd srcs resolve to the same
  /// bytes they do in the reference).
  static List<_Icon> _parseManifest(String body, Uri home) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return const <_Icon>[];
    }
    if (decoded is! Map<String, Object?>) return const <_Icon>[];
    final rawIcons = decoded['icons'];
    if (rawIcons is! List) return const <_Icon>[];
    final origin = '${home.scheme}://${home.host}';
    final result = <_Icon>[];
    for (final entry in rawIcons) {
      if (entry is! Map) continue;
      final src = entry['src'];
      final sizes = entry['sizes'];
      final resolved = switch (src) {
        final String s when s.startsWith('http:') || s.startsWith('https:') => s,
        final String s when s.isEmpty => '',
        final String s when s.startsWith('/') => '$origin$s',
        final String s => '$origin/$s',
        _ => '',
      };
      if (resolved.isEmpty) continue;
      result.add(_Icon(resolved, parseSize(sizes is String ? sizes : '')));
    }
    return result;
  }

  /// `Favicon.parseSize`: first whitespace-separated token, split on x/X/*,
  /// first integer piece, or 0 when the attribute is absent/`any`/garbage.
  static int parseSize(String sizes) {
    if (sizes.isEmpty || sizes == 'any') return 0;
    final token = sizes.split(' ').first;
    for (final piece in token.split(RegExp('[xX*]'))) {
      final value = int.tryParse(piece);
      if (value != null) return value;
    }
    return 0;
  }

  /// The plate renders at most its own pixel span; this is the pixel size
  /// `Favicons.find` is called with in the reference for the standard 56dp
  /// tile (`size * devicePixelRatio` on a large phone, floored).
  static int plateSizePx() => 168;

  /// `Favicons.find` driven to exhaustion: repeatedly the chosen icon and
  /// then removing it, so the trial order comes out (a) ascending among
  /// icons that cover [px] pixels, then (b) descending among those that do
  /// not — the exact sequence `FaviconFetcher` follows while it removes
  /// candidates one by one. With no covering icon at all it starts at the
  /// largest, which is also what `find` returns in that situation.
  @visibleForTesting
  static List<String> tryOrder(List<(String url, int size)> desc, int px) {
    final remaining = List<(String, int)>.of(desc);
    final ordered = <String>[];
    while (remaining.isNotEmpty) {
      (String, int)? chosen;
      for (final icon in remaining) {
        if (chosen == null || icon.$2 >= px) {
          chosen = icon;
        } else {
          break;
        }
      }
      remaining.remove(chosen!);
      ordered.add(chosen.$1);
    }
    return ordered;
  }
}
