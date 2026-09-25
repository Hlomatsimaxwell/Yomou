import 'package:flutter/material.dart';
import 'package:yomou/widgets/safe_image.dart';

/// Universal "Premium Icon Plate": every source icon, everywhere, sits on the
/// exact same rounded square so grids read as a uniform "gallery of apps" and
/// lists read as one straight vertical line of identical geometry.
///
/// * Plate: fixed 56×56, radius 16dp, solid background (`#F5F5F5` off-white in
///   light mode, elevated panel in dark mode) with a hairline border. Never
///   transparent.
/// * Logo: full-bleed app-icon style — clipped with [ClipRRect] into the
///   rounded square and [BoxFit.cover] so it fills the plate edge to edge like
///   a launcher icon, exactly matching the letter-tile fallback.
/// * Fallback: when no logo exists, the plate holds a soft deterministic
///   gradient brand tile with a single letter — a rounded square, never a
///   circle.
/// * Non-default sizes scale radius proportionally so the plate keeps its
///   rounded-square identity at every visual weight.
class SourceIcon extends StatelessWidget {
  const SourceIcon({
    super.key,
    required this.name,
    this.iconUrl = '',
    this.size = 56,
  });

  final String name;
  final String iconUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final letter = name.isEmpty ? '?' : name[0];

    Widget fallback() => _BrandFallback(
      name: name,
      letter: letter,
      colors: _gradientColors(name),
      fontSize: size * 0.42,
    );

    // The mandatory plate geometry. At the standard 56dp the spec is exact:
    // radius 16dp. Smaller chips scale proportionally so they never collapse
    // into circles.
    final radius = size >= 40 ? 16.0 : size * (16 / 56);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: iconUrl.isNotEmpty
            ? SafeNetworkImage(
                imageUrl: iconUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorWidget: (context, url, error) => fallback(),
              )
            : fallback(),
      ),
    );
  }
}

class _BrandFallback extends StatelessWidget {
  const _BrandFallback({
    required this.name,
    required this.letter,
    required this.colors,
    required this.fontSize,
  });

  final String name;
  final String letter;
  final List<Color> colors;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [
              Shadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

List<Color> _gradientColors(String name) {
  int hash = 0;
  for (final codeUnit in name.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
  }
  final hue = (hash % 360).toDouble();
  return [
    HSLColor.fromAHSL(1, hue, 0.32, 0.66).toColor(),
    HSLColor.fromAHSL(1, hue, 0.38, 0.52).toColor(),
  ];
}