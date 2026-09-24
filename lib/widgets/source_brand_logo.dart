import 'package:flutter/material.dart';
import 'package:yomou/widgets/safe_image.dart';

/// Premium source "Logo Card": every source icon sits on a rounded-square
/// background plate so light/white logos stay visible against the screen.
///
/// * Plate: rounded square (radius ≈ 22% of size), very light grey/white in
///   light mode, elevated panel in dark mode, with a hairline border.
/// * Logo: rendered with [BoxFit.contain] and internal padding so it is never
///   cropped or stretched, and never touches the plate edges.
/// * Fallback: when no logo exists, the plate holds a soft deterministic
///   gradient brand tile with a single letter.
class SourceBrandLogo extends StatelessWidget {
  const SourceBrandLogo({
    super.key,
    required this.name,
    this.iconUrl = '',
    this.size = 40,
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

    final radius = size * 0.22;
    final padding = size * 0.12;

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
            ? Padding(
                padding: EdgeInsets.all(padding),
                child: SafeNetworkImage(
                  imageUrl: iconUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (context, url, error) => fallback(),
                ),
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