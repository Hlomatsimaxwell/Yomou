import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yomou/core/cache/app_cache.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/features/history/screens/history_screen.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

import 'test_fonts.dart';

/// Two behaviours on the History screen, each of which has regressed once.
///
/// The reading-progress ring used to show a percentage and a completed check at
/// the same time, so a finished series said "100%" in one corner and drew a
/// tick in the other. Kotatsu draws one indicator and swaps the label for a
/// check inside it (`ReadingProgressDrawable`), which is what these hold the
/// ring to: a completed item shows the check and no percentage, an in-progress
/// item shows the percentage and no check.
///
/// The filter row gains a pill per pinned source, carrying the source's own
/// icon and name, tapping which narrows history to that source. Pinned is the
/// whole point - a source the reader has not pinned must not be offered - and
/// the pill stays outlined while unselected, like every other chip in the app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // A source pill draws the source's real favicon, which goes through
  // flutter_cache_manager, which asks path_provider where to put its files.
  // There is no plugin behind that channel in a test, so the call throws and
  // the framework reports it as an uncaught error on an otherwise passing test.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => '/tmp/opencode',
      );

  setUpAll(TestFonts.ensureLoaded);

  group('completed indicator', () {
    Widget ring(int progress) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ProgressBadge(progress: progress)),
        ),
      );
    }

    testWidgets('replaces the percentage with a check once finished', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(ring(100));
      expect(find.byIcon(RemixIcons.check_line), findsOneWidget);
      expect(find.text('100%'), findsNothing);

      // The same widget, mid-read: the percentage is back and the check is not.
      await tester.pumpWidget(ring(40));
      expect(find.text('40%'), findsOneWidget);
      expect(find.byIcon(RemixIcons.check_line), findsNothing);
    });

    testWidgets('paints a tonal disc, an accent arc and a real track', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      const boundaryKey = ValueKey('progress-ring');
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4C8DFF));
      late Color accent;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(colorScheme: scheme),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: Consumer(
                    builder: (context, ref, _) {
                      // Captured from the same container the ring reads, rather
                      // than a second one, which would start its own settings
                      // load and leave the scheduler with work to do after the
                      // test has gone.
                      accent = ref.watch(accentProvider);
                      return const ProgressBadge(progress: 40);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // One device pixel per logical pixel, so a pixel coordinate is the
      // logical coordinate and the 28px ring is 28px of buffer.
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final image = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      ))!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;

      Color pixelAt(int x, int y) {
        final i = (y * image.width + x) * 4;
        return Color.fromARGB(
          data.getUint8(i + 3),
          data.getUint8(i),
          data.getUint8(i + 1),
          data.getUint8(i + 2),
        );
      }

      // Which of the ring's three colours a pixel is nearest to. Classifying
      // rather than matching exactly leaves room for the 8-bit round trip and
      // for the anti-aliasing on the edges of a 4.5px stroke.
      String roleOf(Color pixel) {
        final candidates = {
          'disc': scheme.secondaryContainer,
          'arc': accent,
          'track': scheme.outlineVariant,
        };
        var best = '';
        var bestDistance = double.infinity;
        candidates.forEach((name, candidate) {
          final distance =
              (pixel.r - candidate.r).abs() +
              (pixel.g - candidate.g).abs() +
              (pixel.b - candidate.b).abs();
          if (distance < bestDistance) {
            bestDistance = distance;
            best = name;
          }
        });
        return best;
      }

      // The geometry of a 28px ring with a 4.5px stroke: the centre line of the
      // stroke is 11.75px from the middle. At 40% the arc runs from twelve
      // o'clock round to roughly 4:48, and the track takes over from about 5:16
      // the rest of the way round.
      expect(roleOf(pixelAt(14, 2)), 'arc'); // twelve o'clock
      expect(roleOf(pixelAt(22, 6)), 'arc'); // half past one
      expect(roleOf(pixelAt(14, 26)), 'track'); // six o'clock
      expect(roleOf(pixelAt(2, 14)), 'track'); // nine o'clock
      expect(roleOf(pixelAt(14, 22)), 'disc'); // inside the ring
    });

    test('the cover card draws no second completed badge of its own', () {
      // The card used to add a bottom-right tick keyed on the same progress the
      // ring already draws, which is what put two "finished" marks on one
      // cover. Reading the source is deliberately blunt: a widget test would
      // have to render covers, and the regression is a stray condition in this
      // one file.
      final source = File(
        'lib/features/history/screens/history_screen.dart',
      ).readAsStringSync();
      final card = source.substring(
        source.indexOf('class GridHistoryCard'),
        source.indexOf('class DetailedHistoryCard'),
      );

      expect(card, contains('ProgressBadge('));
      expect(card, isNot(contains('progress >= 100')));
    });
  });

  group('pinned source chips', () {
    final db = DatabaseHelper.instance;

    /// The pinned-source registry, as `SourcesNotifier` persists it.
    String registry(List<String> pinned) => jsonEncode([
      for (final name in ['MangaDex', 'MangaKatana'])
        {'name': name, 'isPinned': pinned.contains(name), 'isEnabled': true},
    ]);

    Future<void> seedHistory() async {
      await db.clearHistory();
      await db.saveMangaProgress(
        mangaId: 'dex-1',
        title: 'Dex Title',
        coverUrl: '',
        sourceId: 'mangadex',
        totalChapters: 10,
        lastReadChapter: 10,
      );
      await db.saveMangaProgress(
        mangaId: 'katana-1',
        title: 'Katana Title',
        coverUrl: '',
        sourceId: 'mangakatana',
        totalChapters: 10,
        lastReadChapter: 4,
      );
    }

    /// Pumps the screen and lets its real database reads finish.
    ///
    /// History comes out of sqflite, whose futures complete on a real clock,
    /// while a widget test body runs in fake time - so the I/O has to be given
    /// `runAsync` to land. Pumping, rather than settling, is deliberate too:
    /// the loading spinner is an indeterminate animation.
    Future<void> pumpHistory(WidgetTester tester) async {
      // Warm the image cache manager up in real time. The first lookup arms a
      // ten second cleanup timer; armed from inside `pump` it would land on the
      // fake clock, where the binding fails the test for a timer still pending
      // at teardown. A cache-only lookup asks for nothing over the network.
      await tester.runAsync(
        () => AppImageCache.instance.manager.getFileFromCache('warmup'),
      );

      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(
              fontFamily: TestFonts.family,
              platform: TargetPlatform.android,
            ),
            home: const HistoryScreen(),
          ),
        ),
      );

      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.text('Dex Title').evaluate().isNotEmpty) break;
      }
    }

    testWidgets('offers only pinned sources, and filters history by one', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'pinned_sources_list': registry(['MangaDex']),
      });
      await tester.runAsync(seedHistory);
      await pumpHistory(tester);

      // Only the pinned source gets a pill. MangaKatana is in history but was
      // never pinned, so it must not be offered.
      expect(find.text('MangaDex'), findsOneWidget);
      expect(find.text('MangaKatana'), findsNothing);

      // The pill is outlined while unselected: a transparent fill behind a
      // hairline, never a solid block.
      final decoration =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text('MangaDex'),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color, Colors.transparent);
      expect(decoration.border, isNotNull);

      // Both entries are listed until the pill is used.
      expect(find.text('Dex Title'), findsOneWidget);
      expect(find.text('Katana Title'), findsOneWidget);

      await tester.tap(find.text('MangaDex'));
      await tester.pump();

      expect(find.text('Dex Title'), findsOneWidget);
      expect(find.text('Katana Title'), findsNothing);

      // Using the active pill again clears the filter.
      await tester.tap(find.text('MangaDex'));
      await tester.pump();
      expect(find.text('Katana Title'), findsOneWidget);
    });

    testWidgets('offers nothing when no source is pinned', (tester) async {
      SharedPreferences.setMockInitialValues({
        'pinned_sources_list': registry([]),
      });
      await tester.runAsync(seedHistory);
      await pumpHistory(tester);

      expect(find.text('MangaDex'), findsNothing);
      expect(find.text('MangaKatana'), findsNothing);
      expect(find.text('Dex Title'), findsOneWidget);
    });
  });
}
