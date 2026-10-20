import 'package:flutter/material.dart';
import 'package:yomou/core/storage/storage_stats.dart';

/// One wedge of the usage bar, and the legend line that names it.
class StorageUsageSegment {
  const StorageUsageSegment({
    required this.label,
    required this.bytes,
    required this.color,
  });

  final String label;

  final int bytes;

  final Color color;
}

/// The colour the reference draws a wedge in, from the seed it happens to pass.
///
/// Kotatsu seeds its three wedges from `Color.BLUE`, `Color.GREEN` and
/// `Color.GRAY`, takes `|seed.hashCode() % 360|` as a hue and paints it at half
/// saturation and half lightness. The hues are arbitrary -- 241, 16 and 88 --
/// but fixed, which is what makes them portable as three numbers rather than as
/// a call this code would have to make. The reference then rotates each one up
/// to 15 degrees toward the theme's surface container so a wedge sits with the
/// theme rather than next to it; that nudge happens in HCT, a colour space
/// nothing else here touches, so it is left out and the raw hue is used.
Color _referenceHue(double hue) => HSLColor.fromAHSL(1, hue, 0.5, 0.5).toColor();

/// The storage breakdown Kotatsu-Redo draws at the top of its Storage and
/// network screen: one bar cut into proportional wedges, with a legend under
/// it giving each wedge's size and name.
///
/// Each wedge is drawn as a chip of its own -- a round rect as round as the
/// pill it sits in, reaching half the bar's height past its share so the chip
/// in front fills its rounding -- rather than as a slice cut out of one strip.
///
/// The three filled wedges take the reference's own colours rather than the
/// scheme's accents, because the reference's are not the scheme's: they are
/// hue-derived, and only the fourth -- the container colour the track itself is
/// painted in -- comes from the theme. That fourth one is what makes
/// "Available" read as the part of the bar nothing is filling, so it needs no
/// colour of its own and no gap around it, and the bar stays one solid track
/// from end to end.
class StorageUsageBar extends StatelessWidget {
  const StorageUsageBar({super.key, required this.segments});

  /// Top to bottom, in the order they are read and drawn.
  ///
  /// The last one is the bar's unfilled remainder -- the pane hands the
  /// available-space bucket over last -- so it takes whatever width the wedges
  /// before it leave behind.
  final List<StorageUsageSegment> segments;

  /// The wedge colour for saved manga: `Color.BLUE`'s hash, hue 241.
  static final Color savedMangaColor = _referenceHue(241);

  /// The wedge colour for the image cache: `Color.GREEN`'s hash, hue 16.
  static final Color pagesCacheColor = _referenceHue(16);

  /// The wedge colour for everything else cached: `Color.GRAY`'s hash, hue 88.
  static final Color otherCacheColor = _referenceHue(88);

  /// The bar's height. This is the one thing on the screen whose size is set
  /// by the drawing rather than by text, so it stays where the inspo puts it.
  static const double barHeight = 18;

  /// How far the bar and the legend dots sit off the list's own padding, which
  /// is the same 16 a row insets itself by: they land on the rows' text guide.
  static const double inset = 16;

  /// The width the wedge at [bytes] earns across a bar [width] wide, held up
  /// to a floor of half the bar's height.
  ///
  /// Byte counts are the weights, so a wedge is the share of the whole that the
  /// legend's own numbers report. The floor is what keeps a small bucket a
  /// visible sliver instead of a fraction of a pixel: without it a 40 MB cache
  /// against 60 GB free draws nothing at all, and the bar reads as empty on a
  /// device that is anything but.
  ///
  /// One floor for every wedge, where the reference gives its first one the
  /// bar's full height and the rest [barHeight] / 2. That quirk is harmless in
  /// the reference because its first wedge is saved manga, usually the largest
  /// of the three. Here an empty saved-manga bucket is dropped, so the taller
  /// floor passes to whatever fills first -- on a full device, the smaller of
  /// two caches -- and the bar draws 70 MB wider than 225 MB. A bar chart that
  /// reverses two of its own bars misreports worse than one that shows two
  /// sub-pixel shares as the same sliver, so the small floor is the only one.
  static double _wedgeWidth({
    required double width,
    required int bytes,
    required int total,
  }) {
    final share = width * bytes / total;
    return share < barHeight / 2 ? barHeight / 2 : share;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // An empty bucket is still worth a legend line -- "0 B" says so -- but a
    // wedge that wide is thinner than a pixel and only blurs the division
    // between its neighbours, so the bar drops it, exactly as the reference
    // drops a segment at zero percent.
    final wedges = [for (final s in segments) if (s.bytes > 0) s];
    final total = segments.fold<int>(0, (sum, s) => sum + s.bytes);

    return Padding(
      // 20 under the legend is the last line's own `screen_padding` margin plus
      // the row's own `paddingBottom`, which is what the reference leaves
      // between this block and the row that follows it.
      padding: const EdgeInsets.fromLTRB(inset, 0, inset, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: barHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(barHeight / 2),
            ),
            // The reference strokes the whole bar once its wedges are down, in
            // the colour it painted last -- the first wedge's -- so the pill
            // carries a hairline edge. As a foreground it does not inset the
            // wedges beneath it, which a border on the box itself would.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(barHeight / 2),
              border: Border.all(
                color: wedges.isEmpty
                    ? Colors.transparent
                    : wedges.first.color,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (total <= 0) return const SizedBox.expand();
                // Where each wedge starts, and how much of the bar it holds:
                // the share its bytes earn or the floor, with the last one
                // taking whatever the others leave -- the remainder the pane
                // hands over last.
                final shares = <double>[];
                final offsets = <double>[];
                var placed = 0.0;
                for (var i = 0; i < wedges.length; i++) {
                  final share = i == wedges.length - 1
                      ? constraints.maxWidth - placed
                      : _wedgeWidth(
                          width: constraints.maxWidth,
                          bytes: wedges[i].bytes,
                          total: total,
                        );
                  offsets.add(placed);
                  shares.add(share);
                  placed += share;
                }
                // Drawn right to left, the way the reference walks its
                // segments: each wedge is a round rect reaching half the bar's
                // height past its own share, and the one on the left is
                // painted last, so it lies over that reach. The rounding of a
                // chip is therefore filled with the chip in front of it rather
                // than with the track, and every wedge reads as a pill of its
                // own tucked under the one before it. The bar's own pill clips
                // the ends, so the first chip's left rounding and the last
                // one's reach are cut to the track.
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = wedges.length - 1; i >= 0; i--)
                      Positioned(
                        left: offsets[i],
                        top: 0,
                        bottom: 0,
                        width: shares[i] + barHeight / 2,
                        // Tight top to bottom: a childless ColoredBox sizes
                        // itself to the smallest side its constraints allow,
                        // and this is what holds that side at the bar's own
                        // height instead of at zero.
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(barHeight / 2),
                          child: ColoredBox(color: wedges[i].color),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // 8 here plus the first line's own 8 is the reference's
          // `margin_normal`; the lines after it keep just their own 8
          // (`margin_small`).
          const SizedBox(height: 8),
          for (final segment in segments) _LegendLine(segment: segment),
        ],
      ),
    );
  }
}

/// A legend line: the segment's dot, then its size and name.
///
/// Size first, name second, the order Kotatsu-Redo's own pattern puts them in:
/// the number is what the reader is looking for, and the name only says what
/// the number belongs to.
class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.segment});

  final StorageUsageSegment segment;

  /// The dot is a rounded square rather than a circle, so it reads as a chip
  /// taken out of the bar above rather than as a bullet before the label.
  static const double _dotSize = 12;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              color: segment.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${formatBytes(segment.bytes)} - ${segment.label}',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
