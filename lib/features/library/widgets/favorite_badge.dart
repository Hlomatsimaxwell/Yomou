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
  final EdgeInsets? position;

  const FavoriteBadge({
    super.key,
    required this.mangaId,
    this.size = 24,
    this.iconSize = 14,
    this.position,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appearanceSettingsProvider).showListBadges) {
      return const SizedBox.shrink();
    }
    final favorites = ref.watch(favoritesProvider);
    final isFavorite =
        favorites.valueOrNull?.any((m) => m.id == mangaId) ?? false;
    if (!isFavorite) return const SizedBox.shrink();

    return Positioned(
      top: position?.top ?? 6,
      right: position?.right ?? 6,
      left: position?.left,
      bottom: position?.bottom,
      child: Container(
        padding: EdgeInsets.all(size * 0.22),
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          RemixIcons.heart_3_fill,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}
