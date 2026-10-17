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

  /// The wedges across the bar, left to right.
  List<ColoredBox> wedges(WidgetTester tester) => tester
      .widgetList<ColoredBox>(
        find.descendant(
          of: find.byType(StorageUsageBar),
          matching: find.byType(ColoredBox),
        ),
      )
      .toList();

  /// How wide each wedge was drawn, left to right.
  List<double> widths(WidgetTester tester) => [
        for (var i = 0; i < wedges(tester).length; i++)
          tester
              .getSize(
                find
                    .descendant(
                      of: find.byType(StorageUsageBar),
                      matching: find.byType(ColoredBox),
                    )
                    .at(i),
              )
              .width,
      ];

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

    expect(widths(tester), [
      closeTo(trackWidth * 0.2, 0.01),
      closeTo(trackWidth * 0.2, 0.01),
      // The last one is the remainder the others leave, and here that is the
      // 60 GB the legend calls available.
      closeTo(trackWidth * 0.6, 0.01),
    ]);
  });

  testWidgets('a bucket too small to see is still drawn at the reference\'s floor',
      (tester) async {
    // 40 MB of each against 60 GB free: a tenth of a pixel, if drawn to scale.
    // The reference coerces every segment width to at least half the bar's
    // height, and the first one to the bar's full height, and so does this --
    // which is the difference between a bar that reports a small cache and a
    // bar that reads as empty.
    await pump(tester, [
      segment('Saved manga', 40 * mb, StorageUsageBar.savedMangaColor),
      segment('Pages cache', 40 * mb, StorageUsageBar.pagesCacheColor),
      segment('Available', 60 * gb, const Color(0xFFE0E0E0)),
    ]);

    expect(widths(tester).take(2), [
      StorageUsageBar.barHeight,
      StorageUsageBar.barHeight / 2,
    ]);
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
