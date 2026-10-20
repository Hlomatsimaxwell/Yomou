import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/widgets/storage_usage_bar.dart';

import 'test_fonts.dart';

/// The usage bar on its own: its proportions, its floors, its colours and the
/// legend under it, measured against the two files in the reference that draw
/// it -- `SegmentedBarView.kt` and `layout/preference_memory_usage.xml` --
/// rather than against how it looks at a glance.
void main() {
  setUpAll(TestFonts.ensureLoaded);

  /// The bar at a known width, so every measurement below is a number rather
  /// than a fraction of whatever the test surface happens to be.
  const barWidth = 400.0;

  /// The width left inside the bar once its own inset is taken off each end.
  const trackWidth = barWidth - 2 * StorageUsageBar.inset;

  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;

  StorageUsageSegment segment(String label, int bytes, Color color) =>
      StorageUsageSegment(label: label, bytes: bytes, color: color);

  Future<void> pump(
    WidgetTester tester,
    List<StorageUsageSegment> segments,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: TestFonts.family),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: barWidth,
              child: StorageUsageBar(segments: segments),
            ),
          ),
        ),
      ),
    );
  }

  /// The bar's own box: the one [Container] on the screen as tall as the bar.
  /// The legend's dots are [Container]s too, but they are half that.
  Finder track() => find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxHeight == StorageUsageBar.barHeight,
      );

  /// The legend's dots, in the order the segments were handed over.
  Finder dot() => find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxHeight == 12,
      );

  /// The wedges across the bar, left to right.
  ///
  /// The tree holds them the other way round -- the chip on the left is built
  /// last so that it paints over its neighbour's rounding -- so this sorts
  /// them back into the order they are read.
  List<ColoredBox> wedges(WidgetTester tester) {
    final found = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(StorageUsageBar),
            matching: find.byType(ColoredBox),
          ),
        )
        .toList();
    return found
      ..sort(
        (a, b) => tester
            .getRect(find.byWidget(a))
            .left
            .compareTo(tester.getRect(find.byWidget(b)).left),
      );
  }

  /// How much of the bar each wedge holds, left to right.
  ///
  /// A wedge is drawn as a chip reaching half the bar's height past its own
  /// share, so its box is wider than the share it reports. The share is where
  /// the next chip's box begins, and the last one's runs to the track's right
  /// edge -- the reach past it is clipped by the pill.
  List<double> shares(WidgetTester tester) {
    final rects = [
      for (final wedge in wedges(tester)) tester.getRect(find.byWidget(wedge)),
    ];
    return [
      for (var i = 0; i < rects.length - 1; i++)
        rects[i + 1].left - rects[i].left,
      tester.getRect(track()).right - rects.last.left,
    ];
  }

  /// How tall each wedge was drawn, left to right.
  ///
  /// The other half of a wedge's box: [shares] alone can report a correctly
  /// proportioned bar whose wedges paint nothing, because a wedge is a
  /// childless [ColoredBox] and one of those takes the smallest size its
  /// constraints allow.
  List<double> heights(WidgetTester tester) => [
        for (final wedge in wedges(tester))
          tester.getSize(find.byWidget(wedge)).height,
      ];

  test('the three wedges are the reference\'s hues, not the scheme\'s', () {
    // The reference seeds its wedges with `Color.BLUE`, `Color.GREEN` and
    // `Color.GRAY`, reads each seed's hash as a hue, and paints it at half
    // saturation and half lightness. Those hues are 241, 16 and 88 -- a
    // periwinkle, a terracotta and a yellow-green, none of which an M3 scheme
    // is obliged to have. Nothing here is one of the scheme's accents, so the
    // three are stated rather than read.
    void expectHue(Color color, double hue) {
      final hsl = HSLColor.fromColor(color);
      expect(hsl.hue, closeTo(hue, 1), reason: '$color');
      expect(hsl.saturation, closeTo(0.5, 0.01), reason: '$color');
      expect(hsl.lightness, closeTo(0.5, 0.01), reason: '$color');
    }

    expectHue(StorageUsageBar.savedMangaColor, 241);
    expectHue(StorageUsageBar.pagesCacheColor, 16);
    expectHue(StorageUsageBar.otherCacheColor, 88);

    expect(
      {
        StorageUsageBar.savedMangaColor,
        StorageUsageBar.pagesCacheColor,
        StorageUsageBar.otherCacheColor,
      },
      hasLength(3),
    );
  });

  testWidgets('the bar is the track colour, pill-round, edged in the first wedge',
      (tester) async {
    await pump(tester, [
      segment('Saved manga', 5 * gb, StorageUsageBar.savedMangaColor),
      segment('Pages cache', 108 * mb, StorageUsageBar.pagesCacheColor),
      segment('Available', 324 * gb, const Color(0xFFE0E0E0)),
    ]);

    final box = tester.widget<Container>(track());
    final cs = Theme.of(tester.element(find.byType(StorageUsageBar))).colorScheme;
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, cs.secondaryContainer);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(StorageUsageBar.barHeight / 2),
    );
    expect(box.clipBehavior, Clip.antiAlias);
    expect(tester.getSize(track()).height, StorageUsageBar.barHeight);

    // The reference strokes the whole bar once its wedges are down, in the
    // colour it painted last, which is the first wedge's.
    final border = (box.foregroundDecoration! as BoxDecoration).border! as Border;
    expect(border.top.color, StorageUsageBar.savedMangaColor);
    expect(border.top.width, 1);
  });

  testWidgets('wedge widths are the shares the legend quotes', (tester) async {
    await pump(tester, [
      segment('Saved manga', 20 * gb, StorageUsageBar.savedMangaColor),
      segment('Other cache', 20 * gb, StorageUsageBar.otherCacheColor),
      segment('Available', 60 * gb, const Color(0xFFE0E0E0)),
    ]);

    expect(shares(tester), [
      closeTo(trackWidth * 0.2, 0.01),
      closeTo(trackWidth * 0.2, 0.01),
      // The last one is the remainder the others leave, and here that is the
      // 60 GB the legend calls available.
      closeTo(trackWidth * 0.6, 0.01),
    ]);
  });

  testWidgets('a bucket too small to see is still drawn at the floor',
      (tester) async {
    // 40 MB of each against 60 GB free: a fraction of a pixel, if drawn to
    // scale. Half the bar's height is what each wedge is held up to, which is
    // the difference between a bar that reports a small cache and a bar that
    // reads as empty.
    await pump(tester, [
      segment('Saved manga', 40 * mb, StorageUsageBar.savedMangaColor),
      segment('Pages cache', 40 * mb, StorageUsageBar.pagesCacheColor),
      segment('Available', 60 * gb, const Color(0xFFE0E0E0)),
    ]);

    expect(shares(tester).take(2), [
      StorageUsageBar.barHeight / 2,
      StorageUsageBar.barHeight / 2,
    ]);
  });

  testWidgets('a smaller bucket never draws wider than a bigger one',
      (tester) async {
    // The figures this pane reports on a full device: no saved manga at all,
    // then 70.6 MB of pages cache and 225.2 MB of other cache against 320 GB
    // free. Both shares are a fraction of a pixel, so both sit on the floor
    // and draw as the same sliver -- the legend underneath carries which is
    // which. Under the reference's own rule the floor was the bar's full
    // height for the first wedge and half that for the rest, which here drew
    // the 70 MB cache wider than the 225 MB one: the empty saved-manga bucket
    // is dropped, so the taller floor passes to whatever comes first. A bar
    // that contradicts the numbers below it is worse than one that shows two
    // sub-pixel shares as equal.
    await pump(tester, [
      segment('Pages cache', 70 * mb + 600 * 1024, StorageUsageBar.pagesCacheColor),
      segment('Other cache', 225 * mb, StorageUsageBar.otherCacheColor),
      segment('Available', 320 * gb, const Color(0xFFE0E0E0)),
    ]);

    final drawn = shares(tester);
    expect(drawn.first, StorageUsageBar.barHeight / 2);
    expect(drawn[1], StorageUsageBar.barHeight / 2);
    expect(drawn.first, lessThanOrEqualTo(drawn[1]));
  });

  testWidgets('wideness tracks bytes once the shares clear the floor',
      (tester) async {
    // The other half of the same promise: above the floor the widths are the
    // legend's own proportions, so a bucket three times the size of another
    // is drawn three times as wide.
    await pump(tester, [
      segment('Pages cache', 20 * gb, StorageUsageBar.pagesCacheColor),
      segment('Other cache', 60 * gb, StorageUsageBar.otherCacheColor),
      segment('Available', 40 * gb, const Color(0xFFE0E0E0)),
    ]);

    final drawn = shares(tester);
    expect(drawn[1], closeTo(3 * drawn.first, 0.01));
  });

  testWidgets('every wedge is drawn as tall as the bar itself', (tester) async {
    // The bug the floors above could not reach, and the one the chip drawing
    // could bring back: a wedge is a childless [ColoredBox], which sizes to
    // the smallest side its constraints allow. Left loose in height -- as a
    // centred flex row leaves it -- that side has a minimum of 0, and every
    // wedge lays out as a flat line in the middle of the pill, painting
    // nothing: the track and its hairline become the whole bar, whatever the
    // legend underneath it quotes. Shares are only half the measurement: the
    // wedges have to stand the full height to be seen.
    await pump(tester, [
      segment('Saved manga', 40 * mb, StorageUsageBar.savedMangaColor),
      segment('Pages cache', 40 * mb, StorageUsageBar.pagesCacheColor),
      segment('Available', 60 * gb, const Color(0xFFE0E0E0)),
    ]);

    expect(wedges(tester), hasLength(3));
    expect(heights(tester), [
      for (var i = 0; i < wedges(tester).length; i++) StorageUsageBar.barHeight,
    ]);
    // And they start at the track's own top edge rather than floating in it.
    final trackTop = tester.getRect(track()).top;
    final firstTop = tester.getRect(find.byWidget(wedges(tester).first)).top;
    expect(firstTop, trackTop);
  });

  testWidgets('each wedge is a chip rounded like the pill it sits in',
      (tester) async {
    // The reference draws every segment as a round rect as round as the bar
    // itself, reaching cornerSize past its own share, in reverse order so the
    // chip in front fills the rounding behind it. A wedge therefore reads as
    // a pill of its own tucked under the one before it, rather than as a
    // slice cut from one strip.
    await pump(tester, [
      segment('Saved manga', 20 * gb, StorageUsageBar.savedMangaColor),
      segment('Pages cache', 60 * gb, StorageUsageBar.pagesCacheColor),
      segment('Available', 20 * gb, const Color(0xFFE0E0E0)),
    ]);

    final chips = tester.widgetList<ClipRRect>(
      find.descendant(
        of: find.byType(StorageUsageBar),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(chips, hasLength(3));
    for (final chip in chips) {
      expect(
        chip.borderRadius,
        BorderRadius.circular(StorageUsageBar.barHeight / 2),
      );
    }

    // Each chip reaches half the bar's height into the share behind it, which
    // is the reach the chip in front is painted over. The last one reaches
    // past the track's right edge, where the pill's own clip cuts it.
    final boxes = wedges(tester);
    final rects = [
      for (final box in boxes) tester.getRect(find.byWidget(box)),
    ];
    for (var i = 0; i < rects.length - 1; i++) {
      expect(
        rects[i].right - rects[i + 1].left,
        closeTo(StorageUsageBar.barHeight / 2, 0.01),
      );
    }
    expect(
      rects.last.right - tester.getRect(track()).right,
      closeTo(StorageUsageBar.barHeight / 2, 0.01),
    );

    // Painted right to left, so the chip on the left is drawn last and lies
    // over its neighbour's rounding: the stack holds them in reverse order.
    final stack = tester.widget<Stack>(
      find.descendant(
        of: find.byType(StorageUsageBar),
        matching: find.byType(Stack),
      ),
    );
    expect((stack.children.first as Positioned).left, greaterThan(0));
    expect((stack.children.last as Positioned).left, 0);
  });

  testWidgets('a bucket with nothing in it keeps its legend, not a wedge',
      (tester) async {
    await pump(tester, [
      segment('Saved manga', 5 * gb, StorageUsageBar.savedMangaColor),
      segment('Pages cache', 0, StorageUsageBar.pagesCacheColor),
      segment('Other cache', 0, StorageUsageBar.otherCacheColor),
      segment('Available', 324 * gb, const Color(0xFFE0E0E0)),
    ]);

    expect(find.text('0 B - Pages cache'), findsOneWidget);
    expect(find.text('0 B - Other cache'), findsOneWidget);
    expect(wedges(tester), hasLength(2));
  });

  testWidgets("the legend's dots and gaps are the reference's", (tester) async {
    await pump(tester, [
      segment('Saved manga', 5 * gb, StorageUsageBar.savedMangaColor),
      segment('Available', 324 * gb, const Color(0xFFE0E0E0)),
    ]);

    // A 12 rounded square, not a circle: the reference's own bg_rounded_square.
    expect(tester.getSize(dot().first).width, 12);
    expect(tester.getSize(dot().first).height, 12);
    expect(
      (tester.widget<Container>(dot().first).decoration! as BoxDecoration)
          .borderRadius,
      BorderRadius.circular(4),
    );

    // 12 from the dot to its text (the reference's drawablePadding), 16 from
    // the bar down to the first line (margin_normal) and 8 between lines
    // (margin_small).
    final first = tester.getRect(find.text('5.00 GB - Saved manga'));
    final second = tester.getRect(find.text('324.00 GB - Available'));
    expect(first.left - tester.getRect(dot().first).right, 12);
    expect(first.top - tester.getRect(track()).bottom, 16);
    expect(second.top - first.bottom, 8);
  });
}
