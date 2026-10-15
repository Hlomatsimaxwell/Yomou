import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import '../providers/favorites_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';

/// Small heart badge shown on a manga cover when the manga is in the
/// user's favorites. Watches the favorites provider so it stays in sync
/// everywhere the badge appears.
///
/// Returns a [Positioned] widget, so it should be placed as a child of the
/// cover's [Stack].
class FavoriteBadge extends ConsumerWidget {
  final String mangaId;
  final double size;
  final double iconSize;

  /// Which corner of the cover the badge is pinned to. Only the four corner
  /// values of [Alignment] are meaningful here; a centred one would set no
  /// edge at all and leave the badge to the enclosing [Stack]'s alignment.
  final Alignment alignment;

  /// Distance from the two cover edges that [alignment] names.
  final double inset;

  const FavoriteBadge({
    super.key,
    required this.mangaId,
    this.size = 24,
    this.iconSize = 14,
    this.alignment = Alignment.topRight,
    this.inset = 6,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(
      alignment.x != 0 && alignment.y != 0,
      'FavoriteBadge pins to a corner of the cover',
    );
    if (!ref.watch(appearanceSettingsProvider).showListBadges) {
      return const SizedBox.shrink();
    }
    final favorites = ref.watch(favoritesProvider);
    final isFavorite =
        favorites.valueOrNull?.any((m) => m.id == mangaId) ?? false;

    final scheme = Theme.of(context).colorScheme;
    // A tonal disc, the same shape language as the reading-progress ring that
    // sits in the opposite corner (which is tinted secondaryContainer), so the
    // two read as one system. The red this used to hardcode was the only colour
    // on a cover that ignored the theme -- wrong in monochrome, in the dynamic
    // schemes and in dark mode alike.
    final disc = Container(
      padding: EdgeInsets.all(size * 0.22),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        RemixIcons.heart_3_fill,
        color: scheme.onTertiaryContainer,
        size: iconSize,
      ),
    );

    // Stays mounted and animates rather than being swapped in and out, so
    // favouriting a title reads as a state change instead of a repaint.
    final duration = reduceMotionEnabled(ref)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Positioned(
      top: alignment.y < 0 ? inset : null,
      bottom: alignment.y > 0 ? inset : null,
      left: alignment.x < 0 ? inset : null,
      right: alignment.x > 0 ? inset : null,
      child: IgnorePointer(
        child: AnimatedScale(
          scale: isFavorite ? 1 : 0,
          duration: duration,
          // easeOutBack overshoots on the way in, which is the little pop a
          // heart wants. On the way out it would overshoot past zero into a
          // mirrored badge, so removal gets a plain easeIn.
          curve: isFavorite ? Curves.easeOutBack : Curves.easeIn,
          child: AnimatedOpacity(
            opacity: isFavorite ? 1 : 0,
            duration: duration,
            child: disc,
          ),
        ),
      ),
    );
  }
}
