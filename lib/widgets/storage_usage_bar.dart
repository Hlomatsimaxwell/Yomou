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

/// The storage breakdown Kotatsu-Redo draws at the top of its Storage and
/// network screen: one bar cut into proportional wedges, with a legend under
/// it giving each wedge's size and name.
///
/// The wedge colours are the scheme's three accents plus the container colour,
/// which is what the track itself is painted in. That makes "Available" read as
/// the part of the bar nothing is filling, so it needs no label inside the bar
/// and no gap around it -- the bar stays one solid track from end to end.
class StorageUsageBar extends StatelessWidget {
  const StorageUsageBar({super.key, required this.segments});

  /// Top to bottom, in the order they are read and drawn.
  final List<StorageUsageSegment> segments;

  /// The bar's height. This is the one thing on the screen whose size is set
  /// by the drawing rather than by text, so it stays where the inspo puts it.
  static const double barHeight = 18;

  /// How far the bar and the legend dots sit off the list's own padding, which
  /// is the same 16 a row insets itself by: they land on the rows' text guide.
  static const double inset = 16;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // An empty bucket is still worth a legend line -- "0 B" says so -- but a
    // wedge that wide is thinner than a pixel and only blurs the division
    // between its neighbours, so the bar drops it.
    final wedges = [for (final s in segments) if (s.bytes > 0) s];

    return Padding(
      padding: const EdgeInsets.fromLTRB(inset, 0, inset, 8),
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
            child: Row(
              children: [
                // Byte counts as the flex weight, so each wedge is the share of
                // the whole the legend's own numbers report.
                for (final wedge in wedges)
                  Expanded(flex: wedge.bytes, child: ColoredBox(color: wedge.color)),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
