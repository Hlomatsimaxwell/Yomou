import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
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
  final EdgeInsets? position;

  const DownloadedMangaBadge({
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
    final downloaded = ref.watch(downloadedMangasProvider);
    final hasDownload = downloaded.valueOrNull?.contains(mangaId) ?? false;
    if (!hasDownload) return const SizedBox.shrink();

    return Positioned(
      top: position?.top ?? 6,
      right: position?.right ?? 6,
      left: position?.left,
      bottom: position?.bottom,
      child: Container(
        padding: EdgeInsets.all(size * 0.22),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          RemixIcons.sd_card_line,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}
