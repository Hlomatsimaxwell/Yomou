import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/explore/widgets/featured_carousel.dart';
import 'package:yomou/features/suggestions/providers/suggestions_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/l10n/generated/app_localizations_en.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

import 'test_fonts.dart';

/// The featured hero was a fixed 204px tall with a fixed 104x150 cover and a
/// fixed 0.94 page fraction, so it was squeezed on one end and stretched on the
/// other: a 320dp phone gave the title 130px to work with at a fixed 18pt,
/// and a 1245px desktop window made the same card a 1095x204 strip with a
/// 104px cover adrift in it and a 70px peek at the neighbour.
///
/// These hold it to being derived: one measurement, everything proportional to
/// it, and the three bugs that came out of it -- a dot row whose selected pill
/// was painted in the unselected colour, a watermark drawn on top of the title,
/// and a failed feed that took the whole hero away without saying why.
void main() {
  setUpAll(TestFonts.ensureLoaded);

  final l10n = AppLocalizationsEn();
  var pumpId = 0;

  Manga entry(int i, {String? description, List<String> tags = const []}) =>
      Manga(
        id: '$i',
        title: 'Series number $i with a name of an ordinary length',
        coverUrl: '',
        description: description,
        sourceId: 'mangadex',
        tags: tags,
      );

  /// A feed the size the provider actually builds, so the spread over it is the
  /// real one.
  List<Manga> feed(int n) => [for (var i = 0; i < n; i++) entry(i)];

  Widget host(Future<List<Manga>> Function() create) {
    return ProviderScope(
      // A key per pump, so each one gets a fresh container. Riverpod keeps an
      // already-overridden provider's resolved value when the scope is updated
      // in place, so re-pumping the same tree with different data would quietly
      // keep showing the first data -- which would make every "and now the feed
      // is different" assertion in here a lie.
      key: ValueKey(pumpId++),
      overrides: [suggestionsProvider.overrideWith((ref, _) => create())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          fontFamily: TestFonts.family,
          platform: TargetPlatform.android,
        ),
        home: const Scaffold(body: FeaturedCarousel()),
      ),
    );
  }

  /// Fixed frames rather than `pumpAndSettle`.
  ///
  /// The card runs a sheen that repeats forever and the skeleton pulses
  /// forever, so the tree never settles and `pumpAndSettle` would sit there
  /// until it timed out. Twelve 60ms frames is enough for the provider, the
  /// layout and a page snap.
  Future<void> settle(WidgetTester tester, [int frames = 12]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpAt(
    WidgetTester tester,
    double width,
    Future<List<Manga>> Function() create,
  ) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(create));
    await settle(tester);
  }

  Future<void> pumpFeed(WidgetTester tester, double width, List<Manga>? data) =>
      pumpAt(tester, width, () async => data ?? const []);

  /// The page fraction the carousel actually built its controller with.
  double fraction(WidgetTester tester) => tester
      .widget<PageView>(find.byType(PageView))
      .controller!
      .viewportFraction;

  /// The painted card: inside the page, inside the gutter.
  double cardWidth(WidgetTester tester) =>
      tester.getSize(find.byType(AppPress).first).width;

  /// The height the hero occupies, whichever of the three states it is in.
  ///
  /// Read off the box each state puts in the same slot rather than off a widget
  /// that only one of them has: the loaded state has a page, the failed one has
  /// none, and the skeleton has neither. Not `find.byType(FadeTransition)` --
  /// the route underneath puts those in as well, and matching one of those
  /// would have measured MaterialApp's page transition instead of the card.
  double height(WidgetTester tester) => tester
      .getSize(
        find
            .descendant(
              of: find.byType(LayoutBuilder),
              matching: find.byType(SizedBox),
            )
            .first,
      )
      .height;

  /// Whole cards on screen at this window, counted off the geometry rather than
  /// read off a field.
  int cardsAt(WidgetTester tester, double width) =>
      (width / (fraction(tester) * width)).floor();

  /// What is left of the window once every card that fits has been laid out,
  /// less the gutter the next card's page starts with.
  ///
  /// Not `width - pageWidth`: that is what is left after *one* page, which is
  /// only the same number when there is exactly one card.
  double sliverAt(WidgetTester tester, double width) {
    final page = fraction(tester) * width;
    return width - (width / page).floor() * page - 8;
  }

  /// The dot row, in order.
  List<AnimatedContainer> dots(WidgetTester tester) => tester
      .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
      .toList();

  /// The watermark: the framed index number in the card's corner.
  bool isWatermark(Widget child) =>
      child is Positioned &&
      child.child is Text &&
      ((child.child as Text)).data == '01';

  Color dotColor(AnimatedContainer dot) =>
      (dot.decoration! as BoxDecoration).color!;

  /// AnimatedContainer folds its `width`/`height` arguments into constraints.
  double dotWidth(AnimatedContainer dot) => dot.constraints!.minWidth;

  Future<void> swipeTo(WidgetTester tester, int page) async {
    await tester.drag(find.byType(PageView), const Offset(-340, 0));
    await settle(tester, 20);
  }

  group('the card follows the width it is given', () {
    testWidgets('the peek is the same sliver at every width', (tester) async {
      // The old 0.94 was a 6% peek: 19px on a 320dp phone and 75px on a
      // 1245px window, which showed a readable slice of the next card's title
      // before the user had swiped anything.
      //
      // Measured off the leftover page: the sliver itself plus the gutter the
      // next page starts with, 24 of card and 8 of gutter.
      for (final width in [320.0, 360.0, 412.0, 600.0, 872.0, 1165.0, 1920.0]) {
        await pumpFeed(tester, width, feed(40));
        final sliver = sliverAt(tester, width);
        expect(
          sliver,
          closeTo(24.0, 0.01),
          reason: 'a ${sliver.toStringAsFixed(1)}px sliver at ${width}px',
        );
      }
    });

    testWidgets('one card on a phone, more of them as the window grows', (
      tester,
    ) async {
      // Derived from a target card width rather than a table of breakpoints, so
      // a width nobody named still gets the count that keeps a card legible.
      // The thresholds follow from the arithmetic: two cards need a window of
      // twice the 420 target plus the gutter and the sliver.
      final expected = {
        320.0: 1,
        360.0: 1,
        600.0: 1,
        871.0: 1,
        872.0: 2,
        1165.0: 2,
        1291.0: 2,
        1292.0: 3,
        1920.0: 3,
      };
      for (final entry in expected.entries) {
        await pumpFeed(tester, entry.key, feed(40));
        expect(
          cardsAt(tester, entry.key),
          entry.value,
          reason: 'cards at ${entry.key}px',
        );
      }
    });

    testWidgets('a card stays near its target width instead of stretching', (
      tester,
    ) async {
      // This is the complaint in one number. A 5.4:1 strip on a desktop and a
      // 3:1 letterbox on an ultrawide are both this test failing. The upper end
      // is generous because just below a step from one card to two, the single
      // card it still has is nearly twice the target width -- that is what
      // flooring a divisor does, and the same shape the manga grids have.
      for (var width = 320.0; width <= 1920.0; width += 20) {
        await pumpFeed(tester, width, feed(40));
        final card = cardWidth(tester);
        expect(
          card,
          inInclusiveRange(260.0, 840.0),
          reason: 'a ${card.toStringAsFixed(1)}px card at ${width}px',
        );
        // And the height is the rule itself, floor and backstop and all:
        // min(max(what it needs, card * 0.6), 380). The 0.6 wins everywhere
        // except the run-up to a step from one card to two, where the single
        // card gets nearly twice the target width and the 380 backstop is what
        // stops it becoming a wall.
        expect(
          height(tester),
          greaterThanOrEqualTo(math.min(card * 0.6, 380.0)),
        );
        expect(height(tester), lessThanOrEqualTo(380.0));
      }
    });

    testWidgets('the height follows the card instead of staying 204', (
      tester,
    ) async {
      await pumpFeed(tester, 360, feed(40));
      final phone = height(tester);
      await pumpFeed(tester, 1165, feed(40));
      final desktop = height(tester);

      // A phone keeps very nearly the card it has always had -- 187 against the
      // fixed 204 -- and a desktop gets 330 instead of the same 204. Both are
      // about 1.7:1, which is the point: one proportion, every width.
      expect(phone, closeTo(187.0, 1.5));
      expect(desktop, closeTo(330.0, 1.5));
      expect(desktop / (550.5), closeTo(0.6, 0.01));
    });

    testWidgets('the cover is sized off the card, not fixed at 104', (
      tester,
    ) async {
      // Measured on the art itself, inside the plate's padding and the spine.
      Future<double> artAt(double width) async {
        await pumpFeed(tester, width, feed(40));
        return tester.getSize(find.byType(CachedMangaImage).first).width;
      }

      // A phone's card is not wide enough to buy more than the 104 the app has
      // always drawn, so it holds the floor: the hero's cover must not shrink.
      final narrow = await artAt(320);
      final phone = await artAt(360);
      expect(narrow, closeTo(93.1, 0.3));
      expect(phone, closeTo(93.1, 0.3), reason: 'still at the floor at 360');

      // Past that it is a third of the card, and on a desktop it takes the
      // ceiling -- with the plate's own padding and spine scaled to match, so
      // the art is 152 rather than a fixed 93 in a 168 cover.
      final tablet = await artAt(600);
      final desktop = await artAt(1165);
      expect(tablet, greaterThan(phone));
      expect(desktop, closeTo(152.0, 0.3));
      expect(desktop, greaterThan(phone * 1.6));
    });

    testWidgets('nothing overflows at any width', (tester) async {
      for (var width = 320.0; width <= 1920.0; width += 40) {
        await pumpFeed(tester, width, feed(40));
        expect(
          tester.takeException(),
          isNull,
          reason: 'something overflowed at ${width}px',
        );
      }
    });
  });

  group('the dot row', () {
    testWidgets('the selected dot is painted in the selected colour', (
      tester,
    ) async {
      // The bug this pins: the widths were compared against the page index and
      // the colours against the index wrapped into the feed, so the wide pill
      // was drawn in the unselected colour on every card, forever.
      await pumpFeed(tester, 1165, feed(40));
      final scheme = Theme.of(
        tester.element(find.byType(PageView)),
      ).colorScheme;

      expect(dots(tester), hasLength(12));
      expect(dotColor(dots(tester)[0]), scheme.primary);
      expect(dotWidth(dots(tester)[0]), 20.0);
      expect(dotColor(dots(tester)[1]), isNot(scheme.primary));
      expect(dotWidth(dots(tester)[1]), 6.0);
    });

    testWidgets('the selection follows a swipe', (tester) async {
      await pumpFeed(tester, 1165, feed(40));
      final scheme = Theme.of(
        tester.element(find.byType(PageView)),
      ).colorScheme;

      await swipeTo(tester, 1);
      expect(dotColor(dots(tester)[1]), scheme.primary);
      expect(dotWidth(dots(tester)[1]), 20.0);
      expect(dotColor(dots(tester)[0]), isNot(scheme.primary));
      expect(dotWidth(dots(tester)[0]), 6.0);
    });
  });

  group('the watermark', () {
    testWidgets('paints behind the title rather than on top of it', (
      tester,
    ) async {
      // A Stack paints in order, and this number was declared after the row
      // that holds the title, the description and the cover -- so a 110pt grey
      // "01" sat on top of all of them.
      await pumpFeed(tester, 1165, feed(40));
      // The card's own Stack, found by what is in it rather than taken in tree
      // order: the framed cover holds a Stack of its own, and that one has
      // Positioneds whose children are Containers, not the watermark's Text.
      final stack = tester
          .widgetList<Stack>(
            find.descendant(
              of: find.byType(AppPress),
              matching: find.byType(Stack),
            ),
          )
          .firstWhere((s) => s.children.any(isWatermark));

      final mark = stack.children.indexWhere(isWatermark);
      final row = stack.children.indexWhere((child) => child is Row);

      expect(mark, isNonNegative, reason: 'no watermark on the card');
      expect(row, isNonNegative, reason: 'no content row on the card');
      expect(
        mark,
        lessThan(row),
        reason: 'the watermark is painted after the title, so over it',
      );
    });
  });

  group('what the card says under the title', () {
    testWidgets('the description when the source gave one', (tester) async {
      await pumpFeed(tester, 360, [
        entry(0, description: 'A real synopsis from the listing row.'),
      ]);
      // findsWidgets, not findsOneWidget: a PageView keeps the neighbouring
      // pages built, so a one-item feed paints the same card three times.
      expect(find.text('A real synopsis from the listing row.'), findsWidgets);
    });

    testWidgets("the manga's own genres when it gave none", (tester) async {
      await pumpFeed(tester, 360, [
        entry(0, tags: ['Action', 'Fantasy', 'Drama', 'Romance', 'Comedy']),
      ]);
      // Three of them, because that is all the two lines have room for.
      expect(find.text('Action · Fantasy · Drama'), findsWidgets);
    });

    testWidgets('nothing at all when it has neither', (tester) async {
      // No invented sentence in the slot a description belongs in. Most listing
      // rows carry neither a description nor tags, so this is the common case
      // and the card is a title, a source and a cover.
      await pumpFeed(tester, 360, [entry(0)]);
      expect(find.textContaining('Discover this pick'), findsNothing);
      expect(find.textContaining('Series number 0'), findsWidgets);
    });

    testWidgets('the height does not change when the blurb is absent', (
      tester,
    ) async {
      // The height is measured off the cover and the proportion floor, so a
      // card with no second line is the same shape rather than a shorter one
      // that makes the row jump as pages are swiped.
      await pumpFeed(tester, 360, [entry(0)]);
      final bare = height(tester);
      await pumpFeed(tester, 360, [
        entry(0, description: 'A real synopsis from the listing row.'),
      ]);
      expect(height(tester), closeTo(bare, 0.01));
    });
  });

  group('a feed that fails', () {
    Future<List<Manga>> boom() async => throw StateError('feed is down');

    testWidgets('says so, with the reason, instead of vanishing', (
      tester,
    ) async {
      // `else if (featured.isNotEmpty)` meant a failed feed and an unloaded one
      // looked identical: Explore simply had no hero and no way to ask again.
      await pumpAt(tester, 360, boom);
      expect(find.text(l10n.failedToLoadSuggestions), findsOneWidget);
      expect(find.textContaining('feed is down'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('offers a retry, and tapping it does not throw', (
      tester,
    ) async {
      await pumpAt(tester, 360, boom);
      await tester.tap(find.text(l10n.retry));
      await settle(tester);
      expect(tester.takeException(), isNull);
      // Invalidating re-runs the provider, which fails again in this harness;
      // what matters is that the control is live and the state survives it.
      expect(find.text(l10n.retry), findsOneWidget);
    });

    testWidgets('keeps the hero footprint so the page does not jump', (
      tester,
    ) async {
      await pumpFeed(tester, 360, feed(40));
      final loaded = height(tester);
      await pumpAt(tester, 360, boom);
      expect(height(tester), loaded);
    });
  });

  group('the loading skeleton', () {
    testWidgets('has the shape of the card it stands in for', (tester) async {
      final never = Completer<List<Manga>>();
      await pumpAt(tester, 360, () => never.future);
      await settle(tester, 4);

      // It was a fixed 204 with a hardcoded 82x118 plate, so it jumped when the
      // feed arrived at any width the layout had moved away from.
      expect(height(tester), closeTo(187.0, 1.5));
      expect(find.byType(CachedMangaImage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('what the carousel picks off the feed', () {
    testWidgets('samples the feed instead of taking its head', (tester) async {
      // Taking the first twelve of a forty-item feed put exactly the twelve
      // covers the Suggestions tab opens with onto this row, in the same order.
      await pumpFeed(tester, 1165, feed(40));
      expect(
        find.text(feed(40).first.title),
        findsWidgets,
        reason: 'the first card is still the first pick',
      );

      // Spaced across the feed, so the second card is the fourth item, not the
      // second. Twelve picks out of forty steps three at a time.
      await swipeTo(tester, 1);
      expect(find.text(feed(40)[3].title), findsWidgets);
      expect(find.text(feed(40)[1].title), findsNothing);
    });

    testWidgets('shows twelve of them and a dot for each', (tester) async {
      await pumpFeed(tester, 1165, feed(40));
      expect(dots(tester), hasLength(12));

      await pumpFeed(tester, 1165, feed(5));
      expect(dots(tester), hasLength(5), reason: 'a short feed shows short');
    });

    testWidgets('an empty feed shows nothing at all', (tester) async {
      await pumpFeed(tester, 360, const []);
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(AnimatedContainer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
