import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/data/sources/favicon_resolver.dart';
import 'package:yomou/widgets/source_icon.dart';
import 'dart:async';
import 'test_fonts.dart';

Uri _home() => Uri.parse('https://www.example-manga.com');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A failing source logo goes through flutter_cache_manager, which asks
  // path_provider where to put its files. There is no plugin behind that
  // channel in a test, so the call throws and the framework reports it as an
  // uncaught error on an otherwise passing test.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => '/tmp/opencode',
      );

  setUpAll(TestFonts.ensureLoaded);

  tearDown(() {
    FaviconResolver.debugOverride = null;
  });

  group('FaviconParser port (the homepage scrape)', () {
    test(
        'manifest icons, icon links and touch icons land in find-order: '
        'the smallest covering the plate first, the rest largest-first', () {
      const html = '''
<html><head>
  <link rel="manifest" href="/site.manifest">
  <link rel="shortcut icon" href="static/img/fav.png" type="image/png">
  <link rel="icon" sizes="192x192" href="//cdn.other.net/big.png">
  <link rel="apple-touch-icon" sizes="180x180" href="/apple.png">
  <link rel="stylesheet" href="/style.css">
</head><body></body></html>''';
      const manifest = '''
{"name":"Ex","icons":[
  {"src":"icons/touch-512.png","sizes":"512x512","type":"image/png"},
  {"src":"https://www.example-manga.com/icons/touch-32.png","sizes":"32x32"}
]}''';

      final order = FaviconResolver.parseHomeIcons(
        html: html,
        home: _home(),
        manifestBody: manifest,
      );

      // The plate's 168 pixels are covered by the 180 icon — the smallest
      // covering tile goes first — then the remaining covers largest-first,
      // then everything under the plate, still largest-first.
      expect(order, [
        // 180
        'https://www.example-manga.com/apple.png',
        // 192, resolved off the protocol-relative href
        'https://cdn.other.net/big.png',
        // 512 manifest entry, its src glued onto the site root exactly the
        // way the reference's resolveLink() does
        'https://www.example-manga.com/icons/touch-512.png',
        // 32 absolute manifest entry passes through untouched
        'https://www.example-manga.com/icons/touch-32.png',
        // sizes-less links count as 0, so they trail the pack — and the
        // relative href resolves against the homepage
        'https://www.example-manga.com/static/img/fav.png',
      ]);
    });

    test('a site that advertises nothing falls back to /favicon.ico', () {
      const html =
          '<html><head><link rel="stylesheet" href="/style.css"></head></html>';
      expect(FaviconResolver.parseHomeIcons(html: html, home: _home()), [
        'https://www.example-manga.com/favicon.ico',
      ]);
    });

    test('site roots are rejected and sizes parse like Favicon.parseSize', () {
      const html = '''
<html><head>
  <link rel="icon" sizes="any" href="/">
  <link rel="icon" sizes="32x32 16x16" href="/small.ico">
  <link rel="apple-touch-icon" sizes="X128" href="/weird.png">
</head></html>''';
      final order = FaviconResolver.parseHomeIcons(html: html, home: _home());
      // `sizes="any"` parses to 0 and the site root href is dropped; the odd
      // "X128" split still yields 128 in the reference (its first integer
      // piece wins), so /weird.png leads /small.ico on size.
      expect(order, [
        'https://www.example-manga.com/weird.png',
        'https://www.example-manga.com/small.ico',
      ]);
    });

    test('a duplicate advertisement keeps only one candidate', () {
      const html = '''
<html><head>
  <link rel="icon" sizes="16x16" href="/favicon.ico">
  <link rel="icon" sizes="16x16" href="/favicon.ico">
</head></html>''';
      expect(FaviconResolver.parseHomeIcons(html: html, home: _home()), [
        'https://www.example-manga.com/favicon.ico',
      ]);
    });

    test('hostless or non-http icon URLs have nothing to scrape', () {
      expect(FaviconResolver.candidates('assets/source_icons/x.png'), isNull);
      expect(FaviconResolver.candidates('ftp://host.example/favicon.ico'), isNull);
      expect(FaviconResolver.candidates('not a url'), isNull);
    });

    test('under flutter_test without an override, discovery stays offline', () {
      // Real homepage HTTP never fires from a widget test zone: the resolver
      // yields the offline "nothing to scrape" answer and the plate falls to
      // its letter tile, exactly the behaviour every suite already sees.
      expect(FaviconResolver.candidates('https://declared.example/primary.ico'),
          isNull);
    });
  });

  testWidgets(
      'the plate holds the letter tile while the discovery runs, then walks '
      'the recovered candidates; the declared URL only comes after the walk',
      (tester) async {
    final discoveries = <String>[];
    final attempted = <String>[];
    final wake = Completer<List<String>>();
    FaviconResolver.debugOverride = (iconUrl) {
      // Defer the answer: the resolver's own future is what the plate waits
      // on, so the walk cannot start early.
      return wake.future.then((_) {
        discoveries.add(iconUrl);
        return const [
          'https://recovery.example/manifest-192.png',
          'https://recovery.example/apple-180.png',
        ];
      });
    };
    // A strictly in-frame fake logo: placeholder for one frame, then its own
    // error. The walk cascades through it on plain frame pumps, unlike the
    // real loader whose cache-manager machinery cannot run under the test
    // clock.
    SourceIcon.debugImageLoader = ({
      key,
      required imageUrl,
      required fit,
      decodeWidth,
      required httpHeaders,
      required placeholder,
      required errorWidget,
    }) {
      attempted.add(imageUrl);
      return _FailingFakeImage(
        key: key,
        placeholder: () => placeholder(_StubContext(), imageUrl),
        error: () => errorWidget(_StubContext(), imageUrl, 'stub'),
      );
    };

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SourceIcon(
                name: 'MangaKings',
                iconUrl: 'https://declared.example/primary.ico',
                size: 56,
              ),
            ),
          ),
        ),
      ),
    );

    // While the discovery is unresolved, nothing is attempted and the letter
    // tile holds the plate.
    await tester.pump();
    expect(attempted, isEmpty);
    expect(find.text('M'), findsOneWidget);
    expect(discoveries, isEmpty);

    // Release the discovery: the declared URL never runs first — the walk
    // goes straight through the recovered candidates, and the letter tile is
    // only where the walk ends. The site was scraped exactly once.
    wake.complete(const []);
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(attempted, [
      'https://recovery.example/manifest-192.png',
      'https://recovery.example/apple-180.png',
      // the declared URL, after the walk is spent
      'https://declared.example/primary.ico',
    ]);
    expect(find.text('M'), findsOneWidget);
    expect(discoveries, ['https://declared.example/primary.ico']);
  });

  testWidgets(
      'a source the discovery could not help falls back to its declared URL',
      (tester) async {
    FaviconResolver.debugOverride = (iconUrl) async => const <String>[];
    final attempted = <String>[];
    SourceIcon.debugImageLoader = ({
      key,
      required imageUrl,
      required fit,
      decodeWidth,
      required httpHeaders,
      required placeholder,
      required errorWidget,
    }) {
      // An image that simply never finishes: the placeholder holds.
      attempted.add(imageUrl);
      return placeholder(_StubContext(), imageUrl) ?? const SizedBox.shrink();
    };

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SourceIcon(
                name: 'MangaKings',
                iconUrl: 'https://declared.example/primary.ico',
                size: 56,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // An empty discovery is the reference's 'homepage had nothing': declared
    // URL after the walk.
    expect(attempted, ['https://declared.example/primary.ico']);
  });
}

/// Placeholder and error callbacks receive a [BuildContext] that only ever
/// goes straight back; the fake loader's callbacks ignore theirs, so the
/// stub is enough.
class _StubContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Fails its own logo after one rendered frame: placeholder when mounted, the
/// [SourceIcon]-provided error builder once a frame has passed. No timers, no
/// network — the whole failure walk runs on plain frame pumps.
class _FailingFakeImage extends StatefulWidget {
  const _FailingFakeImage({
    super.key,
    required this.placeholder,
    required this.error,
  });

  final Widget? Function() placeholder;
  final Widget? Function() error;

  @override
  State<_FailingFakeImage> createState() => _FailingFakeImageState();
}

class _FailingFakeImageState extends State<_FailingFakeImage> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      _failed ? (widget.error() ?? const SizedBox.shrink()) : widget.placeholder() ?? const SizedBox.shrink();
}
