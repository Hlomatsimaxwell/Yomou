import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/history/providers/reading_statistics_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// The manga-level statistics sheet, opened from the detail screen's menu.
/// The reference opens one rather than a full screen: the manga's title, a
/// bar chart of recent reading activity, the first-read date as the x-axis
/// marker, and a one-line total under it.
///
/// The reference's sheet is adaptive -- a BottomSheetDialog by default and a
/// SideSheetDialog on tablets -- so this too docks as a right-edge panel on
/// wide windows and slides up from the bottom on everything else.
///
/// The reference counts pages per bar and pages read in total; nothing in
/// this store records pages, so both count chapters.
void showMangaStatsSheet(
  BuildContext context, {
  required String mangaId,
  required String title,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (usesWideLayout(context)) {
    // The same right-edge drawer the history menu opens in: the full height
    // of the window, a third of its width, rounded on the left, no drag
    // handle -- that belongs to the bottom sheet's gesture. Going through
    // the shared shell keeps the two panels one object.
    showIosSheet<void>(
      context,
      builder: (ctx) => _MangaStatsSheet(
        mangaId: mangaId,
        title: title,
        showHandle: false,
      ),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: scheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: _MangaStatsSheet(mangaId: mangaId, title: title, showHandle: true),
    ),
  );
}

class _MangaStatsSheet extends ConsumerWidget {
  const _MangaStatsSheet({
    required this.mangaId,
    required this.title,
    required this.showHandle,
  });

  final String mangaId;
  final String title;
  final bool showHandle;

  // Chart geometry: the box the bars and guides share, and the room the
  // count labels take off its top for themselves.
  static const double _chartHeight = 168;
  static const double _labelBand = 18;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final textColor = dark ? Colors.white : scheme.onSurface;
    final accent = ref.watch(accentProvider);
    final stats = ref.watch(mangaStatsProvider(mangaId));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHandle)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        stats.when(
          loading: () => const SizedBox(
            height: _chartHeight,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => SizedBox(
            height: _chartHeight,
            child: Center(
              child: Text(
                '—',
                style: TextStyle(color: textColor.withValues(alpha: 0.4)),
              ),
            ),
          ),
          data: (data) => _buildChart(data, accent, textColor, scheme),
        ),
        stats.maybeWhen(
          data: (data) => Padding(
            // The x-axis marker: the earliest read, dot on the date, the
            // way the reference marks the chart's start.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: data.firstReadAt == null
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('d MMM').format(data.firstReadAt!),
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.55),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: stats.maybeWhen(
            data: (data) => Text(
              l.chaptersCount(data.totalChapters),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildChart(
    MangaStatsData data,
    Color accent,
    Color textColor,
    ColorScheme scheme,
  ) {
    final maxCount = math.max(1, data.weekCounts.reduce(math.max));
    // What a full bar reaches: the chart minus the label band above it.
    final usable = _chartHeight - _labelBand;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: _chartHeight,
        child: Stack(
          children: [
            // The guides sit over the bar area only, so the top line meets
            // the tallest a bar can draw rather than the label band.
            Positioned(
              top: _labelBand,
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomPaint(
                painter: _GridPainter(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: _labelBand),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final count in data.weekCounts)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // The count rides above its bar, the way the
                          // reference labels each one with its value.
                          SizedBox(
                            height: 16,
                            child: Center(
                              child: Text(
                                count > 0 ? '$count' : '',
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.55),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 14,
                            height: count == 0
                                ? 0
                                : math.max(4, count / maxCount * usable),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four dashed hairlines across the bar area -- the baseline plus a third,
/// two thirds, and the top -- faint enough to give the bars a scale without
/// reading as borders of their own.
class _GridPainter extends CustomPainter {
  _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    for (var i = 0; i < 4; i++) {
      final y = size.height - 1 - i * (size.height - 1) / 3;
      for (var x = 0.0; x < size.width; x += dash + gap) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + dash, size.width), y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.color != color;
}
