import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/ios/ios_nav_bar.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/history/providers/reading_statistics_provider.dart';
import 'package:yomou/features/history/widgets/donut_chart.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Flat, vibrant palette cycling across the donut segments ("Other" is grey).
const List<Color> _slicePalette = [
  Color(0xFF7C5AFF),
  Color(0xFF3DDC84),
  Color(0xFF4C8DFF),
  Color(0xFFFF9F45),
  Color(0xFFFF5C8A),
  Color(0xFF14B8A6),
];
const Color _otherSliceColor = Color(0xFF9A9FA5);

/// How many top manga get their own segment; everything else folds into the
/// grey "Other manga" slice.
const int _maxNamedSlices = 5;

/// Reading statistics: a donut of time per manga (filterable by time range and
/// favorites) plus a breathable, divider-free legend.
class ReadingStatisticsScreen extends ConsumerStatefulWidget {
  const ReadingStatisticsScreen({super.key});

  @override
  ConsumerState<ReadingStatisticsScreen> createState() =>
      _ReadingStatisticsScreenState();
}

class _ReadingStatisticsScreenState
    extends ConsumerState<ReadingStatisticsScreen> {
  String? _selectedMangaId;

  static String _minutesLabel(AppLocalizations l, int minutes) =>
      minutes == 1 ? l.statsMinute : l.statsMinutes(minutes);

  void _showTimeRangePicker() {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);

    showIosSheet(
      context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final range in StatsTimeRange.values) ...[
                _buildRadioRow(
                  label: _rangeLabel(l, range),
                  selected: ref.read(statsRangeProvider) == range,
                  fg: fg,
                  onTap: () {
                    ref.read(statsRangeProvider.notifier).state = range;
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showOverflowMenu() {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);

    showIosSheet(
      context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppPress(
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmClearStatistics();
                },
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Icon(RemixIcons.delete_bin_5_line, color: fg, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l.statsClear,
                          style: TextStyle(
                            color: fg,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClearStatistics() async {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: dark ? BorderSide.none : const BorderSide(color: Colors.black12),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(RemixIcons.delete_bin_5_line, color: fg, size: 26),
            const SizedBox(height: 12),
            Text(
              l.statsClearTitle,
              style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l.statsClearMessage,
              style: TextStyle(
                color: dark ? Colors.white54 : const Color(0xFF49454F),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel, style: TextStyle(color: fg, fontSize: 15)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l.statsClear,
              style: TextStyle(
                color: dark ? Colors.white : const Color(0xFFB3261E),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await DatabaseHelper.instance.clearStatisticsData();
    ref.invalidate(readingStatisticsProvider);
    ref.invalidate(historyProvider);
    if (!mounted) return;
    showIosToast(context, message: l.statsCleared);
  }

  Widget _buildRadioRow({
    required String label,
    required bool selected,
    required Color fg,
    required VoidCallback onTap,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return AppPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : Colors.transparent,
                border: Border.all(
                  color: selected ? accent : Colors.black26,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(RemixIcons.check_line, color: Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _rangeLabel(AppLocalizations l, StatsTimeRange range) =>
      switch (range) {
        StatsTimeRange.day => l.statsTimeDay,
        StatsTimeRange.week => l.statsTimeWeek,
        StatsTimeRange.month => l.statsTimeMonth,
        StatsTimeRange.threeMonths => l.statsTimeThreeMonths,
        StatsTimeRange.allTime => l.statsTimeAllTime,
      };

  Widget _buildFilters() {
    final l = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final favoritesOnly = ref.watch(statsFavoritesOnlyProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionPill(
              leading: const Icon(RemixIcons.time_line, size: 17),
              label: _rangeLabel(l, ref.watch(statsRangeProvider)),
              trailing: const Icon(RemixIcons.arrow_down_s_line, size: 18),
              onTap: _showTimeRangePicker,
            ),
            const SizedBox(width: 10),
            _ActionPill(
              leading: Icon(
                favoritesOnly ? RemixIcons.check_line : RemixIcons.heart_3_line,
                size: 17,
                color: favoritesOnly ? accent : null,
              ),
              label: l.statsFavorites,
              foreground: favoritesOnly ? accent : null,
              tint: favoritesOnly ? accent.withValues(alpha: 0.16) : null,
              border: favoritesOnly ? accent.withValues(alpha: 0.35) : null,
              onTap: () {
                ref
                    .read(statsFavoritesOnlyProvider.notifier)
                    .update((v) => !v);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statsAsync = ref.watch(readingStatisticsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            IosNavBar(
              showBack: true,
              title: l.readingStatistics,
              actions: [
                AppPress(
                  onTap: _showOverflowMenu,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(RemixIcons.more_2_line, size: 22),
                  ),
                ),
              ],
            ),
            _buildFilters(),
            Expanded(
              child: statsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Text(
                    l.favoritesCouldNotLoad,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white54
                          : const Color(0xFF49454F),
                    ),
                  ),
                ),
                data: (slices) {
                  if (slices.isEmpty) {
                    return EmptyState(
                      icon: RemixIcons.pie_chart_2_line,
                      title: l.statsEmptyTitle,
                      subtitle: l.statsEmptySubtitle,
                    );
                  }
                  final named = slices.take(_maxNamedSlices).toList();
                  final rest = slices.skip(_maxNamedSlices).toList();
                  final hasOther = rest.isNotEmpty;
                  final otherMinutes =
                      rest.fold<int>(0, (sum, s) => sum + s.minutes);
                  final totalMinutes =
                      named.fold<int>(0, (sum, s) => sum + s.minutes) +
                      otherMinutes;

                  final donutSlices = [
                    for (var i = 0; i < named.length; i++)
                      DonutSlice(
                        id: named[i].mangaId,
                        value: named[i].minutes.toDouble(),
                        color: _slicePalette[i % _slicePalette.length],
                      ),
                    if (hasOther)
                      DonutSlice(
                        id: 'other',
                        value: otherMinutes.toDouble(),
                        color: _otherSliceColor,
                      ),
                  ];

                  if (_selectedMangaId != null &&
                      !donutSlices.any((s) => s.id == _selectedMangaId)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedMangaId = null);
                    });
                  }

                  return ListView(
                    padding: EdgeInsets.only(
                      top: 12,
                      bottom: bottomBarClearance(context) + 20,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 650),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) => DonutChart(
                                  slices: donutSlices,
                                  selectedId: _selectedMangaId,
                                  progress: value,
                                  thickness: 34,
                                  onSliceTap: (id) => setState(
                                    () => _selectedMangaId = _selectedMangaId == id
                                        ? null
                                        : id,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l.statsTotal.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.1,
                                      fontWeight: FontWeight.w500,
                                      color: mutedText(context),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : const Color(0xFF1C1B1F),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
const SizedBox(height: 12),
                      for (var i = 0; i < named.length; i++)
                        _LegendTile(
                          color: _slicePalette[i % _slicePalette.length],
                          title: named[i].title,
                          subtitle: _minutesLabel(l, named[i].minutes),
                          highlighted: _selectedMangaId == named[i].mangaId,
                        ),
                      if (hasOther)
                        _LegendTile(
                          color: _otherSliceColor,
                          title: l.statsOtherManga,
                          subtitle: _minutesLabel(l, otherMinutes),
                          highlighted: _selectedMangaId == 'other',
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color mutedText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white54
      : const Color(0xFF8A8A8E);
}

/// A rounded action chip used for the time-range and favorites filters.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.leading,
    required this.label,
    required this.onTap,
    this.trailing,
    this.foreground,
    this.tint,
    this.border,
  });

  final Widget leading;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  final Color? foreground;
  final Color? tint;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = foreground ??
        (dark ? Colors.white : const Color(0xFF49454F));
    return AppPress(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: tint ?? (dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F3F5)),
          borderRadius: BorderRadius.circular(22),
          border: border != null
              ? Border.all(color: border!)
              : (dark ? Border.all(color: const Color(0xFF2C2C30)) : null),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DefaultTextStyle.merge(
              style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500),
              child: leading,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 2),
              IconTheme(
                data: IconThemeData(color: fg),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One row in the legend: flat color swatch, bold title, muted time subtitle.
class _LegendTile extends StatelessWidget {
  const _LegendTile({
    required this.color,
    required this.title,
    required this.subtitle,
    this.highlighted = false,
  });

  final Color color;
  final String title;
  final String subtitle;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: highlighted
            ? accent.withValues(alpha: dark ? 0.20 : 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? Colors.white : const Color(0xFF1C1C1F),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: dark ? Colors.white54 : const Color(0xFF8A8A8E),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}