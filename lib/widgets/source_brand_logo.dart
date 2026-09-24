import 'package:flutter/material.dart';
import 'package:yomou/widgets/safe_image.dart';

/// Premium source brand tile: loads the source's own logo (rounded square)
/// when available; otherwise falls back to a rounded square with a subtle
/// deterministic gradient and a single brand letter.
class SourceBrandLogo extends StatelessWidget {
  const SourceBrandLogo({
    super.key,
    required this.name,
    this.iconUrl = '',
    this.size = 48,
  });

  final String name;
  final String iconUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '?' : name[0];

    Widget fallback() => _BrandFallback(
      name: name,
      letter: letter,
      colors: _gradientColors(name),
      fontSize: size * 0.46,
    );

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
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