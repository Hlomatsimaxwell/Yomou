import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/downloads_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';

/// Small SD-card badge shown on a manga cover when at least one chapter of
/// that manga has been downloaded. Watches the downloads provider so it stays
/// in sync everywhere the badge appears.
///
/// Returns a [Positioned] widget, so it should be placed as a child of the
/// cover's [Stack].
class DownloadedMangaBadge extends ConsumerWidget {
  final String mangaId;
  final double size;
  final double iconSize;

  /// Which corner of the cover the badge is pinned to. Only the four corner
  /// values of [Alignment] are meaningful here; a centred one would set no
  /// edge at all and leave the badge to the enclosing [Stack]'s alignment.
  ///
  /// Defaults opposite the favourite heart. Both badges used to sit at the
  /// top-right corner, where the heart - opaque, the same size, painted after
  /// this one - hid the download mark on every title that was downloaded *and*
  /// favourited.
  final Alignment alignment;

  /// Distance from the two cover edges that [alignment] names.
  final double inset;

  const DownloadedMangaBadge({
    super.key,
    required this.mangaId,
    this.size = 24,
    this.iconSize = 14,
    this.alignment = Alignment.topLeft,
    this.inset = 6,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(
      alignment.x != 0 && alignment.y != 0,
      'DownloadedMangaBadge pins to a corner of the cover',
    );
    if (!ref.watch(appearanceSettingsProvider).showListBadges) {
      return const SizedBox.shrink();
    }
    final downloaded = ref.watch(downloadedMangasProvider);
    final hasDownload = downloaded.valueOrNull?.contains(mangaId) ?? false;

    final scheme = Theme.of(context).colorScheme;
    // The heart wears tertiaryContainer; this one takes primaryContainer, so
    // two marks on one cover stay two marks. The black54 it replaces was the
    // only cover indicator that ignored the theme, and over dark artwork its
    // disc disappeared into the image, leaving the glyph floating.
    final disc = Container(
      padding: EdgeInsets.all(size * 0.22),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        MdiIcons.sd,
        color: scheme.onPrimaryContainer,
        size: iconSize,
      ),
    );

    // Mounted and animated like the favourite heart beside it, so the two
    // cover marks behave the same way.
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
          scale: hasDownload ? 1 : 0,
          duration: duration,
          curve: hasDownload ? Curves.easeOutBack : Curves.easeIn,
          child: AnimatedOpacity(
            opacity: hasDownload ? 1 : 0,
            duration: duration,
            child: disc,
          ),
        ),
      ),
    );
  }
}
