import 'package:flutter/material.dart';

/// A "hat and glasses" incognito glyph.
///
/// The app's bundled icon sets (Remix Icon, Material) have no incognito mark,
/// and the nearest -- Remix Icon's `spy` -- reads as a robot. This paints the
/// classic fedora-and-glasses silhouette instead, at any size and theme colour.
class IncognitoIcon extends StatelessWidget {
  const IncognitoIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _IncognitoPainter(resolved)),
    );
  }
}

class _IncognitoPainter extends CustomPainter {
  const _IncognitoPainter(this.color);

  final Color color;

  // Authored on a 24x24 grid (source: Material Design Icons' `incognito`),
  // scaled to the painted box. Non-zero winding gives the lens cut-outs.
  static final Path _glyph = Path()
    ..moveTo(17.060, 13.000)
    ..cubicTo(15.200, 13.000, 13.640, 14.330, 13.240, 16.100)
    ..cubicTo(12.290, 15.690, 11.420, 15.800, 10.760, 16.090)
    ..cubicTo(10.350, 14.310, 8.790, 13.000, 6.940, 13.000)
    ..cubicTo(4.770, 13.000, 3.000, 14.790, 3.000, 17.000)
    ..cubicTo(3.000, 19.210, 4.770, 21.000, 6.940, 21.000)
    ..cubicTo(9.000, 21.000, 10.680, 19.380, 10.840, 17.320)
    ..cubicTo(11.180, 17.080, 12.070, 16.630, 13.160, 17.340)
    ..cubicTo(13.340, 19.390, 15.000, 21.000, 17.060, 21.000)
    ..cubicTo(19.230, 21.000, 21.000, 19.210, 21.000, 17.000)
    ..cubicTo(21.000, 14.790, 19.230, 13.000, 17.060, 13.000)
    ..moveTo(6.940, 19.860)
    ..cubicTo(5.380, 19.860, 4.130, 18.580, 4.130, 17.000)
    ..cubicTo(4.130, 15.420, 5.390, 14.140, 6.940, 14.140)
    ..cubicTo(8.500, 14.140, 9.750, 15.420, 9.750, 17.000)
    ..cubicTo(9.750, 18.580, 8.500, 19.860, 6.940, 19.860)
    ..moveTo(17.060, 19.860)
    ..cubicTo(15.500, 19.860, 14.250, 18.580, 14.250, 17.000)
    ..cubicTo(14.250, 15.420, 15.500, 14.140, 17.060, 14.140)
    ..cubicTo(18.620, 14.140, 19.880, 15.420, 19.880, 17.000)
    ..cubicTo(19.880, 18.580, 18.610, 19.860, 17.060, 19.860)
    ..moveTo(22.000, 10.500)
    ..lineTo(2.000, 10.500)
    ..lineTo(2.000, 12.000)
    ..lineTo(22.000, 12.000)
    ..close()
    ..moveTo(15.530, 2.630)
    ..cubicTo(15.310, 2.140, 14.750, 1.880, 14.220, 2.050)
    ..lineTo(12.000, 2.790)
    ..lineTo(9.770, 2.050)
    ..lineTo(9.720, 2.040)
    ..cubicTo(9.190, 1.890, 8.630, 2.170, 8.430, 2.680)
    // Seated onto the brim (source stops at y=9, leaving a visible gap).
    ..lineTo(6.000, 11.000)
    ..lineTo(18.000, 11.000)
    ..lineTo(15.560, 2.680)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawPath(
      _glyph,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IncognitoPainter oldDelegate) =>
      oldDelegate.color != color;
}
