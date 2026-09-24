import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One slice in a [DonutChart]: a manga's share + its flat palette color.
class DonutSlice {
  const DonutSlice({
    required this.id,
    required this.value,
    required this.color,
  });

  final String id;
  final double value;
  final Color color;
}

/// Dependency-free segmented donut chart with a hollow center. Segments grow
/// via [progress] (0→1) so range switches animate smoothly; tapping a segment
/// selects its [id] (drawn enlarged, others dimmed).
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.selectedId,
    this.onSliceTap,
    this.progress = 1,
    this.size = 240,
    this.thickness = 32,
  });

  final List<DonutSlice> slices;
  final String? selectedId;
  final ValueChanged<String>? onSliceTap;
  final double progress;
  final double size;
  final double thickness;

  void _handleTapUp(BuildContext context, TapUpDetails details, Offset center) {
    if (onSliceTap == null || slices.isEmpty) return;
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
    final radius = math.sqrt(dx * dx + dy * dy);
    if (radius > size / 2 || radius < size / 2 - thickness - 8) return;

    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    const gap = 0.045;
    final sweepTotal = 2 * math.pi * progress;
    var cursor = 0.0;
    for (final slice in slices) {
      final sweep = slice.value / total * sweepTotal;
      final slot = sweep > 0 && slices.length > 1 ? sweep - gap : sweep;
      if (slot > 0 && angle >= cursor && angle < cursor + slot) {
        onSliceTap!(slice.id);
        return;
      }
      cursor += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = size / 2;
    return GestureDetector(
      onTapUp: (details) => _handleTapUp(context, details, Offset(center, center)),
      child: CustomPaint(
        size: Size.square(size),
        painter: _DonutPainter(
          slices: slices,
          selectedId: selectedId,
          progress: progress,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.selectedId,
    required this.progress,
    required this.thickness,
  });

  final List<DonutSlice> slices;
  final String? selectedId;
  final double progress;
  final double thickness;

  static const double _gap = 0.045;

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final center = size.center(Offset.zero);
    final baseRadius = size.width / 2 - thickness / 2;
    const start = -math.pi / 2;
    const sweepTotal = 2 * math.pi;

    canvas.save();
    var cursor = start;
    for (final slice in slices) {
      final sweep = slice.value / total * sweepTotal * progress;
      final gap = sweep > 0 && slices.length > 1 ? _gap : 0.0;
      final drawSweep = sweep - gap;
      if (drawSweep <= 0) continue;

      final isSelected = slice.id == selectedId && selectedId != null;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt
        ..color = isSelected
            ? slice.color
            : (selectedId != null
                  ? slice.color.withValues(alpha: 0.28)
                  : slice.color);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: baseRadius),
        cursor,
        drawSweep,
        false,
        paint,
      );
      cursor += sweep;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.progress != progress ||
      oldDelegate.thickness != thickness;
}