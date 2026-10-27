import 'dart:math' as math;

import 'package:yomou/core/theme/amoled.dart';
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:yomou/widgets/material_symbol.dart';
import 'package:yomou/widgets/manga_hero.dart';
import 'package:yomou/widgets/source_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/library/screens/edit_manga_screen.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/incognito_icon.dart';
import 'package:yomou/core/widgets/tab_header.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/widgets/ios/ios_nav_bar.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/core/widgets/responsive.dart' show usesWideLayout;
import 'package:yomou/core/providers/incognito_provider.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/history/screens/reading_statistics_screen.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/core/widgets/search_bar.dart';
import 'package:yomou/core/app_update/app_update_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reading-progress ring, pinned to the top-right of a cover.
///
/// Painted in Kotatsu's Material 3 Expressive style (`ProgressDrawable
/// .Expressive`): a filled tonal disc, the read portion as an arc in the accent
/// colour from twelve o'clock, and - the part a stock [CircularProgressIndicator]
/// cannot do - the remainder drawn as a real track, offset from the arc by a gap
/// at each end. The gap is dropped at the extremes, where there is either no
/// indicator or no track for it to be separated from.
///
/// The gap is Kotatsu's 14 degrees at this size as well. Their drawable, and
/// this one, round the arc ends, and a round cap reaches further round a small
/// circle than a wide one - at 28px it swallows most of the 14 degrees, so the
/// ring reads as one continuous stroke with a soft joint rather than as two
/// clearly separated pieces. That is the reference, so it is the behaviour here.
///
/// The ring doubles as the "completed" mark: once the last chapter has been
/// read the percentage is replaced by a check *inside the same ring*, which is
/// what Kotatsu's `ReadingProgressDrawable` does - it draws `ic_check` in place
/// of the label when `ReadingProgress.isCompleted(percent)`. The two signals
/// are deliberately mutually exclusive; a "100%" bubble and a separate check
/// badge say the same thing twice, in two different corners.
class ProgressBadge extends ConsumerWidget {
  final int progress;

  const ProgressBadge({super.key, required this.progress});

  /// Kotatsu's own numbers: `card_indicator_size` is the 32dp disc, and the
  /// Expressive ring style paints a 5dp stroke. The disc, arc and track are its
  /// colours too (`secondaryContainer`, the accent, `outlineVariant`).
  static const double _size = 32;
  static const double _strokeWidth = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appearanceSettingsProvider).showReadingProgress) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final value = (progress / 100).clamp(0.0, 1.0);
    final completed = progress >= 100;

    return SizedBox(
      width: _size,
      height: _size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ExpressiveRingPainter(
                  value: value,
                  arcColor: ref.watch(accentProvider),
                  trackColor: scheme.outlineVariant,
                  strokeWidth: _strokeWidth,
                ),
              ),
            ),
            if (completed)
              Icon(
                MdiIcons.check,
                color: scheme.onSecondaryContainer,
                // Kotatsu scales the check to 0.6 of the ring's bounds.
                size: _size * 0.6,
              )
            else
              Text(
                '$progress%',
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints the Expressive progress ring under [ProgressBadge]'s label.
///
/// Two arcs rather than a [CircularProgressIndicator]: the widget's
/// `backgroundColor` is a full 360 degree ring with no separation, which is
/// exactly what the Expressive track is not.
class _ExpressiveRingPainter extends CustomPainter {
  const _ExpressiveRingPainter({
    required this.value,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double value;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;

  /// Separation between the active indicator and the track, per M3 Expressive.
  static const double _gapDegrees = 14;

  /// Twelve o'clock, which is where both arcs are measured from.
  static const double _startDegrees = -90;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Half the stroke sits outside this radius, so the ring lands flush with
    // the disc instead of overhanging it.
    final bounds = Rect.fromCircle(
      center: center,
      radius: size.shortestSide / 2 - strokeWidth / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final sweep = 360 * value;
    final gap = (sweep > 0 && sweep < 360) ? _gapDegrees : 0.0;

    // The track is drawn first and the indicator over it, so a full ring reads
    // as solid progress rather than progress with a seam in it.
    final trackSweep = 360 - sweep - gap * 2;
    if (trackSweep > 0) {
      paint.color = trackColor;
      canvas.drawArc(
        bounds,
        _radians(_startDegrees + sweep + gap),
        _radians(trackSweep),
        false,
        paint,
      );
    }

    if (sweep > 0) {
      paint.color = arcColor;
      canvas.drawArc(
        bounds,
        _radians(_startDegrees),
        _radians(sweep),
        false,
        paint,
      );
    }
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(_ExpressiveRingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.arcColor != arcColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _selectedFilter = -1;

  /// The source a pinned-source chip has narrowed the list to, as a source id,
  /// or null when no source chip is active. Kept separate from
  /// [_selectedFilter] so a source and a filter combine instead of replacing
  /// one another: "on device, from this source" is a question worth asking.
  String? _selectedSourceId;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _listMode = 'Grid';

  /// The reader's grid size, from the one preference every manga grid shares.
  ///
  /// Kept as a field rather than read from the provider everywhere because the
  /// grid resolves its columns inside a [SliverLayoutBuilder], which runs
  /// during layout rather than during build -- watching a provider there is not
  /// allowed. It is synced from the provider at the top of [build].
  double _gridSize = kMangaGridSizeDefault;

  String _sortingOrder = 'Last read';
  bool _isGrouped = true;

  final List<String> _sortOptions = [
    'Added',
    'Oldest',
    'Progress',
    'Unread',
    'Name',
    'Name reversed',
    'New chapters',
    'Last read',
    'Long time ago read',
    'Updated',
  ];

  List<Map<String, dynamic>> _historyItems = [];

  final Set<String> _selectedMangaIds = {};

  @override
  void initState() {
    super.initState();
    // Reload whenever reading progress/history or downloads change (e.g.
    // backup import), even if this (possibly alive-in-background) tab isn't
    // reopened. Uses listenManual because ref.listen is only valid during
    // build in Riverpod 2.6.x.
    ref.listenManual(historyRevisionProvider, (previous, next) {
      if (previous != next) _loadFromProvider();
    });
    ref.listenManual(downloadsRevisionProvider, (previous, next) {
      if (previous != next) _loadFromProvider();
    });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();

    final listMode = prefs.getString('history_list_mode') ?? 'Grid';
    final sortingOrder =
        prefs.getString('history_sorting_order') ?? 'Last read';
    final isGrouped = prefs.getBool('history_is_grouped') ?? true;

    setState(() {
      _listMode = listMode;
      _sortingOrder = sortingOrder;
      _isGrouped = isGrouped;
    });

    await _loadFromProvider();
  }

  Future<void> _loadFromProvider() async {
    final rows = await DatabaseHelper.instance.getHistory();
    final downloaded = await DatabaseHelper.instance.getMangaIdsWithDownloads();
    final items = mapHistoryRows(rows, downloadedMangaIds: downloaded);
    if (mounted) {
      setState(() => _historyItems = items);
    }
  }

  // Pull-to-refresh and the overflow-menu "Refresh" action reload history
  // straight from the database (imports/edits land immediately), then re-fetch
  // each series' metadata from its source so covers/titles/chapter counts
  // stay current.
  Future<void> _refreshHistory() async {
    await _refreshHistoryMetadata();
    if (!mounted) return;
    await _loadFromProvider();
    bumpHistoryRevision(ref);
    if (mounted) {
      showIosToast(context, message: AppLocalizations.of(context).refreshed);
    }
  }

  Future<void> _refreshHistoryMetadata() async {
    try {
      final rows = await DatabaseHelper.instance.getHistory();
      final seen = <String>{};
      var batch = <Future<void>>[];
      for (final row in rows) {
        final mangaId = (row['mangaId'] as String?) ?? '';
        final sourceId = (row['sourceId'] as String?) ?? '';
        if (mangaId.isEmpty || sourceId.isEmpty || seen.contains(mangaId)) {
          continue;
        }
        seen.add(mangaId);
        batch.add(_refreshOneEntry(mangaId, sourceId));
        if (batch.length >= 4) {
          await Future.wait(batch);
          batch = <Future<void>>[];
        }
      }
      await Future.wait(batch);
    } catch (_) {
      // Best-effort: a failed source refresh never blocks the reload below.
    }
  }

  Future<void> _refreshOneEntry(String mangaId, String sourceId) async {
    try {
      final source = getSourceBySourceId(sourceId);
      if (source == null) return;
      final details = await SourceCache.mangaDetails(
        sourceId: source.id,
        mangaId: mangaId,
        forceRefresh: true,
        fetch: () => source.getMangaDetails(mangaId),
      );
      if (details == null || details.id.isEmpty) return;
      await DatabaseHelper.instance.upsertManga(
        mangaId: mangaId,
        title: details.title,
        coverUrl: details.coverUrl,
        sourceId: sourceId,
        totalChapters: details.totalChapters,
      );
    } catch (_) {
      // A single unresolvable series should not fail the whole refresh.
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is bool) await prefs.setBool(key, value);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getDateGroupHeader(DateTime lastReadAt) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(lastReadAt.year, lastReadAt.month, lastReadAt.day);
    final diffDays = today.difference(date).inDays;

    if (diffDays <= 0) return l.historyGroupToday;
    if (diffDays == 1) return l.historyGroupYesterday;
    if (diffDays <= 7) return l.historyGroupDaysAgo(diffDays);

    // Older than a week: label by formatted calendar date.
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final monthName = monthNames[date.month - 1];
    final yearSuffix = date.year == now.year ? '' : ', ${date.year}';
    return '$monthName ${date.day}$yearSuffix';
  }

  void _navigateToDetail(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDetailScreen(
          mangaId: item['mangaId'],
          title: item['title'],
          imageUrl: item['coverUrl'],
          sourceId: item['sourceId'],
          heroTag: mangaCoverHeroTag(
            sourceId: item['sourceId'],
            mangaId: item['mangaId'],
          ),
        ),
      ),
    );

    // Refresh history from the DB (progress may have changed while reading).
    if (mounted) await _loadFromProvider();
    bumpHistoryRevision(ref);
  }

  Future<void> _clearHistory(int option) async {
    if (option == 3) {
      await DatabaseHelper.instance.clearHistory();
      if (mounted) await _loadFromProvider();
      bumpHistoryRevision(ref);
      return;
    }

    final now = DateTime.now();
    final cutoff = option == 0
        ? now.subtract(const Duration(hours: 2))
        : DateTime(now.year, now.month, now.day);
    final remaining = _historyItems.where((item) {
      final dt = DateTime.parse(item['lastReadAt']);
      if (option == 0) return !dt.isAfter(cutoff);
      // option == 1: keep items read before today
      return DateTime(dt.year, dt.month, dt.day).isBefore(cutoff);
    }).toList();

    final removedIds = _historyItems
        .where((item) => !remaining.contains(item))
        .map((item) => item['mangaId'])
        .toSet();

    final db = await DatabaseHelper.instance.database;
    for (final id in removedIds) {
      await db.delete('manga', where: 'mangaId = ?', whereArgs: [id]);
    }
    if (mounted) await _loadFromProvider();
    bumpHistoryRevision(ref);
  }

  void _showClearHistoryDialog(BuildContext context) {
    int selectedOption = 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
            // One handler for both the radio dot and the row around it, so a
            // tap on the label lands in the same place as a tap on the dot.
            void select(int? val) =>
                setDialogState(() => selectedOption = val ?? 0);
            return AlertDialog(
              backgroundColor: dark ? amoled(context, 0xFF2C2C2E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: dark
                    ? BorderSide.none
                    : const BorderSide(color: Colors.black12),
              ),
              contentPadding: const EdgeInsets.only(top: 20, bottom: 8),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MdiIcons.deleteOutline, color: fg, size: 28),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context).historyClearTitle,
                    style: TextStyle(
                      color: fg,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // The group owns the selection now, so each option below
                  // only declares its own value. `selectedOption` lives in
                  // the dialog's StatefulBuilder, which is what the group
                  // reads; the rows call the same `select` handler it does.
                  RadioGroup<int>(
                    groupValue: selectedOption,
                    onChanged: select,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRadioOption(
                          title: AppLocalizations.of(
                            context,
                          ).historyClearLastHours,
                          value: 0,
                          onSelect: select,
                        ),
                        _buildRadioOption(
                          title: AppLocalizations.of(
                            context,
                          ).historyClearToday,
                          value: 1,
                          onSelect: select,
                        ),
                        _buildRadioOption(
                          title: AppLocalizations.of(
                            context,
                          ).historyClearNotFavorites,
                          value: 2,
                          onSelect: select,
                        ),
                        _buildRadioOption(
                          title: AppLocalizations.of(context).historyClearAll,
                          value: 3,
                          onSelect: select,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context).cancel,
                    style: TextStyle(
                      color: dark ? Colors.white : const Color(0xFF49454F),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _clearHistory(selectedOption);
                    showIosToast(
                      context,
                      message: AppLocalizations.of(context).historyUpdated,
                    );
                  },
                  child: Text(
                    AppLocalizations.of(context).historyClear,
                    style: TextStyle(
                      color: dark ? Colors.white : const Color(0xFF49454F),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// One choice row. The selected value comes from the enclosing
  /// [RadioGroup], so the row only declares its own [value] and hands the rest
  /// of its tap target to [onSelect], the very handler the group calls.
  Widget _buildRadioOption({
    required String title,
    required int value,
    required ValueChanged<int?> onSelect,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = dark
        ? Colors.white
        : Theme.of(context).colorScheme.primary;
    return AppPress(
      onTap: () => onSelect(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Radio<int>(
              value: value,
              activeColor: activeColor,
              fillColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.selected)) {
                  return activeColor;
                }
                return dark ? Colors.white70 : Colors.black38;
              }),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: dark ? Colors.white : const Color(0xFF1C1B1F),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showListOptionsSheet(BuildContext context) {
    showIosSheet(
      context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            final cs = Theme.of(context).colorScheme;
            // One gap between sections, so the panel breathes evenly instead of
            // at 24/20/20 depending on which row was edited last.
            const sectionGap = SizedBox(height: 28);
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    AppLocalizations.of(context).historyListMode,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    // One unit: a single track holding three equal segments, with
                    // the hairline on the track rather than on each button. The
                    // fixed 8px gaps this used to have read as three separate
                    // pills that happened to sit next to each other, and the
                    // 26px radius turned each of them into a lozenge.
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildSegmentTab(
                          'Compact',
                          MdiIcons.formatListBulleted,
                          setSheetState,
                        ),
                        _buildSegmentTab(
                          'Details',
                          MdiIcons.viewListOutline,
                          setSheetState,
                        ),
                        _buildSegmentTab(
                          'Grid',
                          MdiIcons.viewGridOutline,
                          setSheetState,
                        ),
                      ],
                    ),
                  ),
                  sectionGap,
                  _gridSizeLabel(context, cs),
                  const SizedBox(height: 10),
                  Slider(
                    // Left to right is small to large, which is what a size
                    // control reads as: dragging right grows every cover and
                    // the grid drops a column to make room. The old slider
                    // pointed the same way -- it counted columns backwards from
                    // the far end, so a higher thumb meant fewer, larger covers
                    // either way. The unit is new, not the direction.
                    //
                    // Always live. It used to be disabled on a wide window,
                    // where the count was derived from the width and the stored
                    // number was only ever a floor -- a control that could be
                    // dragged without changing a single pixel. The size is now
                    // the reader's everywhere, so moving it does change the
                    // grid on a tablet too.
                    value: _gridSize,
                    min: kMangaGridSizeMin.toDouble(),
                    max: kMangaGridSizeMax.toDouble(),
                    divisions: kMangaGridSizeDivisions,
                    label: '${_gridSize.round()}%',
                    onChanged: (value) {
                      setSheetState(() {
                        _gridSize = value;
                      });
                      setState(() {});
                      // One preference for every manga grid, so this choice
                      // follows the reader to explore, search and the
                      // source browser as well.
                      ref
                          .read(appearanceSettingsProvider.notifier)
                          .setGridSize(value);
                    },
                  ),
                  sectionGap,
                  Text(
                    AppLocalizations.of(context).historySortingOrder,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: dark ? amoled(context, 0xFF2C2C2E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: dark ? Colors.white12 : Colors.black12,
                        width: 1,
                      ),
                      boxShadow: dark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortingOrder,
                        dropdownColor: dark
                      ? amoled(context, 0xFF2C2C2E)
                      : Colors.white,
                        isExpanded: true,
                        icon: Icon(
                          MdiIcons.menuDown,
                          color: dark
                        ? Colors.white70
                        : const Color(0xFF49454F),
                        ),
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        items: _sortOptions.map((value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(_sortLabel(context, value)),
                            );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue == null) return;

                          setSheetState(() {
                              _sortingOrder = newValue;
                          });
                          setState(() {});
                          _savePreference('history_sorting_order', newValue);
                        },
                      ),
                    ),
                  ),
                  sectionGap,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            MdiIcons.formatListBulleted,
                            color: dark
                          ? Colors.white70
                          : const Color(0xFF49454F),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context).historyGroup,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isGrouped,
                        activeThumbColor: dark ? Colors.black : Colors.white,
                        activeTrackColor: dark
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                        inactiveThumbColor: dark
                      ? Colors.white54
                      : Colors.black54,
                        inactiveTrackColor: dark
                      ? amoled(context, 0xFF2C2C2E)
                      : Colors.black12,
                        onChanged: (value) {
                          setSheetState(() {
                              _isGrouped = value;
                          });
                          setState(() {});
                          _savePreference('history_is_grouped', value);
                        },
                      ),
                    ],
                  ),
                ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Columns the history grid actually renders at [_gridSize].
  ///
  /// No clamp of its own. It used to end in `.clamp(2, 7)`, which was this
  /// screen quietly holding every other grid to a ceiling one lower than the one
  /// they all share -- so on a wide window History showed seven columns while
  /// Favourites and a source catalogue showed eight, and the cells did not match
  /// between tabs of the same library. [mangaGridColumns] holds the count to
  /// [kMangaGridMinColumns] and to nothing else, so there is no second opinion
  /// left to add here.
  int _resolvedColumns(BuildContext context, [double? availableWidth]) =>
      mangaGridColumns(
        context,
        gridSize: _gridSize,
        availableWidth: availableWidth,
      );

  String _modeLabel(BuildContext context, String mode) {
    final l = AppLocalizations.of(context);
    return switch (mode) {
      'Compact' => l.historyCompactMode,
      'Details' => l.historyDetailsMode,
      _ => l.listModeGrid,
    };
  }

  String _sortLabel(BuildContext context, String value) {
    final l = AppLocalizations.of(context);
    return switch (value) {
      'Added' => l.historySortAdded,
      'Oldest' => l.historySortOldest,
      'Progress' => l.historySortProgress,
      'Unread' => l.historySortUnread,
      'Name' => l.historySortName,
      'Name reversed' => l.historySortNameReversed,
      'New chapters' => l.historySortNewChapters,
      'Long time ago read' => l.historySortLongAgo,
      'Updated' => l.historySortUpdated,
      _ => l.historySortLastRead,
    };
  }

  Widget _buildSegmentTab(
    String mode,
    IconData icon,
    StateSetter setSheetState,
  ) {
    final isSelected = _listMode == mode;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _exitSelection();
          setSheetState(() => _listMode = mode);
          setState(() {});
          _savePreference('history_list_mode', mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 46,
          decoration: BoxDecoration(
            // The live mode is a solid accent block in the track. A raised
            // neutral chip -- what the two-option settings rows use -- would not
            // say which of three modes is live at a glance, and the accent is
            // the page's own colour rather than a fourth grey.
            color: isSelected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                size: 19,
              ),
              const SizedBox(height: 2),
              Text(
                _modeLabel(context, mode),
                style: TextStyle(
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The grid-size caption with its value split out, so the caption stays muted
  /// and the number carries the weight.
  ///
  /// [AppLocalizations.appearanceGridSize] renders as one string ("Grid size:
  /// 100%"). Splitting the value back out of it keeps the two tones without
  /// adding a key -- and so a string in every locale -- just for the caption.
  Widget _gridSizeLabel(BuildContext context, ColorScheme cs) {
    final value = '${_gridSize.round()}%';
    final label = AppLocalizations.of(context).appearanceGridSize(
      _gridSize.round(),
    );
    final caption = TextStyle(
      color: cs.onSurfaceVariant,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    final at = label.indexOf(value);
    if (at < 0) return Text(label, style: caption);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label.substring(0, at), style: caption),
          TextSpan(
            text: value,
            style: caption.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: label.substring(at + value.length), style: caption),
        ],
      ),
    );
  }

  void _showOverflowMenu(BuildContext context) async {
    final l = AppLocalizations.of(context);
    await showIosMenuPanel<void>(
      context,
      children: [
        IosMenuRow(
          icon: MdiIcons.refresh,
          label: l.refresh,
          onTap: () {
            Navigator.pop(context);
            _refreshHistory();
          },
        ),
        IosMenuRow(
          icon: MdiIcons.deleteOutline,
          label: l.historyClearTitle,
          destructive: true,
          onTap: () {
            Navigator.pop(context);
            _showClearHistoryDialog(context);
          },
        ),
        IosMenuRow(
          icon: MdiIcons.formatListBulleted,
          label: l.historyListOptions,
          onTap: () {
            Navigator.pop(context);
            _showListOptionsSheet(context);
          },
        ),
        IosMenuRow(
          icon: MdiIcons.chartDonut,
          label: l.historyStatistics,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReadingStatisticsScreen(),
              ),
            );
          },
        ),
        const IosMenuDivider(),
        Consumer(
          builder: (context, ref, _) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            final fg = dark
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface;
            return AppSheetPress(
              onTap: () {},
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    const SizedBox(width: 18),
                    Icon(
                      MdiIcons.eyeOffOutline,
                      size: 20,
                      color: fg.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        l.incognitoMode,
                        style: TextStyle(fontSize: 16, color: fg),
                      ),
                    ),
                    Switch(
                      value: ref.watch(incognitoProvider),
                      activeThumbColor: dark ? Colors.black : Colors.white,
                      activeTrackColor: dark
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      inactiveThumbColor:
                          dark ? Colors.white54 : Colors.black54,
                      inactiveTrackColor: dark
                          ? amoled(context, 0xFF2C2C2E)
                          : Colors.black12,
                      onChanged: (value) {
                        ref.read(incognitoProvider.notifier).set(value);
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            );
          },
        ),
        const IosMenuDivider(),
        IosMenuRow(
          icon: MdiIcons.cogOutline,
          label: l.settings,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSheetRow({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceSettingsProvider);
    final showIncognito = ref.watch(incognitoProvider);
    _gridSize = appearance.gridSize;

    // A pinned source can be unpinned in Manage sources while its pill is the
    // active filter, which would leave the list filtered by a pill that is no
    // longer on screen. Clearing the field here rather than in a listener is
    // safe because the filter is evaluated just below, so the frame that
    // notices the unpin is the frame that stops filtering by it.
    if (_selectedSourceId != null &&
        !_pinnedSources.any((source) => source.id == _selectedSourceId)) {
      _selectedSourceId = null;
    }

    final filteredList = _historyItems.where(_matchesHistoryFilter).toList();

    filteredList.sort((a, b) {
      final aTime = DateTime.parse(a['lastReadAt']);
      final bTime = DateTime.parse(b['lastReadAt']);

      if (_sortingOrder == 'Last read') {
        return bTime.compareTo(aTime);
      } else if (_sortingOrder == 'Long time ago read') {
        return aTime.compareTo(bTime);
      } else if (_sortingOrder == 'Name') {
        return a['title'].toString().compareTo(b['title'].toString());
      } else if (_sortingOrder == 'Name reversed') {
        return b['title'].toString().compareTo(a['title'].toString());
      } else if (_sortingOrder == 'Progress') {
        return (b['progress'] as int).compareTo(a['progress'] as int);
      } else if (_sortingOrder == 'Unread') {
        return (b['newChapters'] as int).compareTo(a['newChapters'] as int);
      }
      return 0;
    });

    final Map<String, List<Map<String, dynamic>>> groupedHistory = {};
    if (_isGrouped) {
      for (var item in filteredList) {
        final date = DateTime.parse(item['lastReadAt']);
        final header = _getDateGroupHeader(date);
        groupedHistory.putIfAbsent(header, () => []).add(item);
      }
      // Within each group, most recently read first. A manga re-read should
      // jump to the front of its group (e.g. the grid) immediately.
      for (final entry in groupedHistory.entries) {
        entry.value.sort(
          (a, b) => DateTime.parse(
            b['lastReadAt'],
          ).compareTo(DateTime.parse(a['lastReadAt'])),
        );
      }
      // Order sections from newest calendar day to oldest. The first item in
      // each group is its most recent read, so it anchors the section order.
      final sortedEntries = groupedHistory.entries.toList()
        ..sort((a, b) {
          final dtA = DateTime.parse(a.value.first['lastReadAt']);
          final dtB = DateTime.parse(b.value.first['lastReadAt']);
          return DateTime(
            dtB.year,
            dtB.month,
            dtB.day,
          ).compareTo(DateTime(dtA.year, dtA.month, dtA.day));
        });
      groupedHistory.clear();
      for (final entry in sortedEntries) {
        groupedHistory[entry.key] = entry.value;
      }
    }

    return PopScope(
      canPop: !_isSelecting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exitSelection();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // Same shape as the Suggestions screen: RefreshIndicator wraps the
        // header, the search bar is the collapsible header on a phone, and the
        // filter chips scroll away with the list. On a wide window TabHeader
        // pins a title beside the search bar instead, since there is room for
        // one and the rail no longer carries a label. HideOnScroll only
        // collapses while a header-height of content remains below, so a
        // history shorter than the header stays put instead of displacing its
        // content.
        body: RefreshIndicator(
          onRefresh: _refreshHistory,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          child: TabHeader(
            mode: usesWideLayout(context)
                ? TabHeaderMode.fixed
                : TabHeaderMode.collapsing,
            title: AppLocalizations.of(context).history,
            leading: _isSelecting ? _buildSelectionBar(context) : null,
            searchBar: _isSelecting ? const SizedBox.shrink() : _buildSearchBar(),
            body: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (appearance.showQuickFilters) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: _buildFilterChips()),
                ],
                if (showIncognito)
                  SliverToBoxAdapter(child: _buildIncognitoIndicator()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (filteredList.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: _searchQuery.isNotEmpty
                          ? MdiIcons.magnify
                          : MdiIcons.history,
                      title: _searchQuery.isNotEmpty
                          ? AppLocalizations.of(context).noResultsFound
                          : AppLocalizations.of(context).historyEmptyTitle,
                      subtitle: _searchQuery.isNotEmpty
                          ? null
                          : AppLocalizations.of(context).historyEmptySubtitle,
                    ),
                  )
                else if (_isGrouped)
                  ...groupedHistory.entries.expand(
                    (entry) => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF1C1B1F),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      _buildHistorySliver(context, entry.value),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                  )
                else
                  _buildHistorySliver(context, filteredList),
                SliverToBoxAdapter(
                  child: SizedBox(height: bottomBarClearance(context)),
                ),
              ],
            ),
          ),
        ),
      ),
  );
  }

  Widget _buildSearchBar() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = dark ? Colors.white70 : Colors.black54;
    return YomouSearchBar.text(
      hintText: AppLocalizations.of(context).searchManga,
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final update = ref.watch(appUpdateProvider).valueOrNull;
              if (update == null) return const SizedBox.shrink();
              return AppPress(
                onTap: () async {
                  final uri = Uri.parse(update.apkUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Tooltip(
                    message: 'Update available: ${update.version}',
                    child: Icon(MdiIcons.download, color: iconColor, size: 22),
                  ),
                ),
              );
            },
          ),
          if (_searchQuery.isNotEmpty)
            AppPress(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(MdiIcons.close, color: iconColor, size: 20),
              ),
            ),
          GestureDetector(
            onTapDown: (TapDownDetails details) {
              _showOverflowMenu(context);
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(MdiIcons.dotsVertical, color: iconColor, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isSelecting => _selectedMangaIds.isNotEmpty;

  // Whether a history entry passes the active search text and filter chip.
  bool _matchesHistoryFilter(Map<String, dynamic> item) {
    if (_searchQuery.isNotEmpty &&
        !item['title'].toString().toLowerCase().contains(
          _searchQuery.toLowerCase(),
        )) {
      return false;
    }
    if (_selectedSourceId != null && item['sourceId'] != _selectedSourceId) {
      return false;
    }
    if (_selectedFilter == 0) return item['hasDownloadedChapters'] == true;
    if (_selectedFilter == 1) return ((item['newChapters'] as int?) ?? 0) > 0;
    if (_selectedFilter == 2) return (item['progress'] as int) >= 100;
    return true;
  }

  List<String> get _visibleHistoryIds => _historyItems
      .where(_matchesHistoryFilter)
      .map((e) => e['mangaId'] as String)
      .toList();

  bool get _allVisibleSelected {
    final ids = _visibleHistoryIds;
    return ids.isNotEmpty && ids.every(_selectedMangaIds.contains);
  }

  // Selects every visible entry, or clears the selection if they all are.
  void _toggleSelectAll() {
    final ids = _visibleHistoryIds;
    setState(() {
      if (_allVisibleSelected) {
        _selectedMangaIds.clear();
      } else {
        _selectedMangaIds.addAll(ids);
      }
    });
  }

  // True when every selected history entry is already a favorite.
  bool get _selectedAllFavorited {
    if (_selectedMangaIds.isEmpty) return false;
    for (final id in _selectedMangaIds) {
      final item = _historyItems.firstWhere(
        (e) => e['mangaId'] == id,
        orElse: () => const <String, dynamic>{},
      );
      if (item['isFavorite'] != true) return false;
    }
    return true;
  }

  void _enterSelection(String mangaId) {
    setState(() => _selectedMangaIds.add(mangaId));
  }

  void _toggleSelect(String mangaId) {
    setState(() {
      if (!_selectedMangaIds.remove(mangaId)) {
        _selectedMangaIds.add(mangaId);
      }
    });
  }

  void _exitSelection() {
    if (!_isSelecting) return;
    setState(_selectedMangaIds.clear);
  }

  void _handleGridCardTap(BuildContext context, Map<String, dynamic> item) {
    final mangaId = item['mangaId'] as String;
    if (_isSelecting) {
      _toggleSelect(mangaId);
    } else {
      _navigateToDetail(context, item);
    }
  }

  Widget _buildSelectionBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    // Kotatsu-Redo paints its action mode with Material's
    // m3_appbar_overlay_color: the theme's primary at 8% over the surface
    // role, which both lifts the bar off the page and moves with the palette.
    // The status bar above it is set to the same colour, so the fill starts
    // at the very top of the window rather than at the bar's own top edge.
    final barBg = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.08),
      cs.surface,
    );
    // The title/count stays at full strength; the actions sit back at "medium
    // emphasis" (on-surface at 60%), which is what Kotatsu's action items
    // resolve to. Colour-role based, so it follows light/dark and the preset.
    final fg = cs.onSurface;
    final actionFg = cs.onSurface.withValues(alpha: 0.6);
    // Mirror Kotatsu-Redo's showAsAction="ifRoom|withText": show icon + text
    // labels when there's enough width, fall back to icons only on narrow
    // screens (phones).
    final showLabels = MediaQuery.of(context).size.width > 600;

    Widget navAction(Widget icon, VoidCallback onTap, {String? label}) {
      return Center(
        child: AppPress(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: showLabels && label != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: actionFg,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : icon,
          ),
        ),
      );
    }

    // The bar itself is flat: the colour is painted by this box so it can run
    // behind the status bar, the way Kotatsu colours the window's status bar
    // along with the action bar. TabHeader leaves the inset to us.
    return Container(
      color: barBg,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: IosNavBar(
        showBack: false,
        flat: true,
        safeArea: false,
        leading: navAction(
          Icon(MdiIcons.close, color: actionFg, size: 22),
          _exitSelection,
        ),
        titleWidget: Text(
          l.historySelectedCount(_selectedMangaIds.length),
          style: TextStyle(
            color: fg,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          navAction(
            MaterialSymbol(
              MaterialSymbol.selectAll,
              color: actionFg,
              size: 22,
            ),
            _toggleSelectAll,
            label: l.selectAll,
          ),
          navAction(
            Icon(MdiIcons.deleteOutline, color: actionFg, size: 22),
            _deleteSelected,
            label: l.delete,
          ),
          navAction(
            Icon(MdiIcons.dotsVertical, color: actionFg, size: 22),
            _showSelectionActions,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedMangaIds.toList();
    if (ids.isEmpty) return;

    final removed = await DatabaseHelper.instance.deleteFromHistory(ids);
    if (!mounted) return;

    setState(_selectedMangaIds.clear);
    await _loadFromProvider();
    bumpHistoryRevision(ref);
    if (!mounted) return;

    final l = AppLocalizations.of(context);
    showIosUndoToast(
      context,
      message: l.historyRemovedCount(ids.length),
      undoLabel: l.historyUndo,
      onUndo: () => _restoreRemoved(removed.manga, removed.progress),
    );
  }

  Future<void> _restoreRemoved(
    List<Map<String, dynamic>> mangaRows,
    List<Map<String, dynamic>> progressRows,
  ) async {
    await DatabaseHelper.instance.restoreHistoryRows(mangaRows, progressRows);
    if (!mounted) return;
    await _loadFromProvider();
    bumpHistoryRevision(ref);
  }

  void _showSelectionActions() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    final l = AppLocalizations.of(context);
    final allFavorited = _selectedAllFavorited;

    showIosSheet(
      context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSheetRow(
                icon: allFavorited
                    ? MdiIcons.heart
                    : MdiIcons.heartOutline,
                label: allFavorited ? l.removeFromFavorites : l.favorite,
                color: fg,
                onTap: () {
                  Navigator.pop(context);
                  _favoriteSelected(remove: allFavorited);
                },
              ),
              _buildSheetRow(
                icon: MdiIcons.pencilOutline,
                label: l.historyEdit,
                color: fg,
                onTap: () {
                  Navigator.pop(context);
                  if (_selectedMangaIds.length == 1) {
                    _openEditForSelected();
                  } else {
                    showIosToast(
                      context,
                      message: l.editSelectOneToEdit,
                      duration: const Duration(seconds: 2),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _favoriteSelected({bool remove = false}) async {
    final ids = _selectedMangaIds.toList();
    if (ids.isEmpty) return;

    var changed = 0;
    for (final mangaId in ids) {
      final isFav = await DatabaseHelper.instance.getIsFavorite(mangaId);
      if (remove) {
        if (!isFav) continue;
        await DatabaseHelper.instance.setFavorite(
          mangaId: mangaId,
          title: '',
          isFavorite: false,
        );
      } else {
        if (isFav) continue;
        final row = await DatabaseHelper.instance.getManga(mangaId);
        if (row == null) continue;
        await DatabaseHelper.instance.setFavorite(
          mangaId: mangaId,
          title: (row['title'] as String?) ?? '',
          coverUrl: row['coverUrl'] as String?,
          sourceId: row['sourceId'] as String?,
          isFavorite: true,
        );
      }
      changed++;
    }
    if (!mounted) return;

    final l = AppLocalizations.of(context);
    setState(_selectedMangaIds.clear);
    if (changed > 0) {
      bumpFavoritesRevision(ref);
      await _loadFromProvider();
      if (!mounted) return;
    }
    final message = remove
        ? (changed > 0
              ? l.historyUnfavoritedCount(changed)
              : l.historyNotFavorite)
        : (changed > 0
              ? l.historyFavoritedCount(changed)
              : l.historyAlreadyFavorite);
    showIosToast(
      context,
      message: message,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _openEditForSelected() async {
    final mangaId = _selectedMangaIds.first;
    final row = await DatabaseHelper.instance.getManga(mangaId);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditMangaScreen(
          mangaId: mangaId,
          title: (row?['title'] as String?) ?? '',
          imageUrl: (row?['coverUrl'] as String?) ?? '',
          sourceId: (row?['sourceId'] as String?) ?? '',
        ),
      ),
    );
    _exitSelection();
    if (!mounted) return;
    await _loadFromProvider();
    bumpHistoryRevision(ref);
  }

  /// The reader's pinned sources, resolved through the registry.
  ///
  /// Rows the registry cannot resolve are dropped rather than shown:
  /// [getSourceByName] answers a name it does not know with MangaDex, so a
  /// mis-registered row would wear one source's name while filtering by another
  /// source's history.
  List<MangaSource> get _pinnedSources {
    final pinned = <MangaSource>[];
    for (final row in ref.watch(sourcesProvider)) {
      if (row['isPinned'] != true) continue;
      final name = row['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final source = getSourceByName(name);
      if (source.name != name) continue;
      pinned.add(source);
    }
    return pinned;
  }

  /// One pill in the History filter row.
  ///
  /// Shared by the filter macros and the pinned sources so the two groups
  /// cannot drift apart. Outlined while unselected, filled once selected, and
  /// the border takes the fill's own colour when selected so that toggling a
  /// pill never changes its size.
  Widget _filterChip({
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
    IconData? icon,
    Widget? leading,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? Colors.white : Theme.of(context).colorScheme.primary;
    final fg = isSelected
        ? (dark ? Colors.black : Colors.white)
        : (dark ? Colors.white : const Color(0xFF334155));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? fill : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? fill
                : (dark ? Colors.white38 : Colors.black38),
          ),
        ),
        child: Row(
          children: [
            if (icon != null) Icon(icon, size: 14, color: fg),
            ?leading,
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'icon': MdiIcons.sd, 'labelKey': 'onDevice'},
      {'icon': MdiIcons.fileClockOutline, 'labelKey': 'newChapters'},
      {'icon': MdiIcons.checkAll, 'labelKey': 'completed'},
    ];

    final l = AppLocalizations.of(context);
    final labels = [
      l.historyOnDevice,
      l.historyNewChapters,
      l.historyCompleted,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var index = 0; index < filters.length; index++)
            _filterChip(
              isSelected: _selectedFilter == index,
              icon: filters[index]['icon'] as IconData,
              label: labels[index],
              onTap: () => setState(() {
                _selectedFilter = _selectedFilter == index ? -1 : index;
              }),
            ),
          // Pinned sources, as branded pills: the source's own icon and then its
          // name, which is the shape Kotatsu gives a source quick-filter chip.
          // Only pinned sources are offered - pinning is the deliberate "I read
          // this one" gesture, and listing every source here would just be a
          // second catalogue.
          for (final source in _pinnedSources)
            _filterChip(
              isSelected: _selectedSourceId == source.id,
              leading: SourceIcon(
                name: source.name,
                iconUrl: source.iconUrl,
                size: 14,
              ),
              label: source.name,
              onTap: () => setState(() {
                _selectedSourceId = _selectedSourceId == source.id
                    ? null
                    : source.id;
              }),
            ),
        ],
      ),
    );
  }

  /// A quiet reminder that incognito is on.
  ///
  /// Sits between the filter chips and the grid: while it is visible the
  /// "progress is not saved" contract is stated where a reader would otherwise
  /// wonder why a series they just opened never appears here.
  Widget _buildIncognitoIndicator() {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IncognitoIcon(
            size: 24,
            color: onSurface.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.incognitoMode,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onSurface.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  l.incognitoNoSaveHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    // Noticeably lighter than the label above it, so the two
                    // lines read as a heading and its caption rather than as
                    // one block.
                    color: onSurface.withValues(alpha: 0.45),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sliver counterpart of the three list modes, so the scroll view builds only
  /// the rows on screen instead of the entire history up front.
  ///
  /// The horizontal padding and grid delegate match the old nested
  /// `Padding` + `GridView`, so cell sizes are unchanged; `CustomScrollView`
  /// takes no `padding`, hence the trailing sliver for the bottom clearance.
  Widget _buildHistorySliver(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    if (_listMode == 'Compact') {
      // Odd indices are the 1px separators between cards, matching the
      // `ListView.separated` this replaces.
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index.isOdd) return const SizedBox(height: 1);
              final item = items[index ~/ 2];
              return CompactHistoryCard(
                item: item,
                onTap: () => _navigateToDetail(context, item),
              );
            },
            childCount: items.isEmpty ? 0 : items.length * 2 - 1,
          ),
        ),
      );
    } else if (_listMode == 'Details') {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              return DetailedHistoryCard(
                item: item,
                onTap: () => _navigateToDetail(context, item),
              );
            },
            childCount: items.length,
          ),
        ),
      );
    }
    // Measured from the constraints rather than the viewport. The nav rail sits
    // beside this screen on a wide layout and takes 80px off it, and MediaQuery
    // still reports the window width down here, so a count derived from it would
    // size cells for space this grid does not have. crossAxisExtent is measured
    // before the SliverPadding below, which is what [mangaCellAspectRatio]
    // expects: it takes the width including the grid's own padding and subtracts
    // that padding itself.
    return SliverLayoutBuilder(
      builder: (context, sliverConstraints) {
        final availableWidth = sliverConstraints.crossAxisExtent;
        final columns = _resolvedColumns(context, availableWidth);
        return SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: kMangaGridHorizontalPadding,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: mangaCellAspectRatio(
                context,
                columns: columns,
                // Tied to the resolved count, not the stored setting: once a
                // tablet derives 8 columns the titles have to shrink to match,
                // or they overflow a cell sized for the old density.
                titleFontSize: mangaCardTitleFontSize(columns),
                availableWidth: availableWidth,
              ),
              crossAxisSpacing: kMangaGridCrossSpacing,
              mainAxisSpacing: kMangaGridRowSpacing,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return GridHistoryCard(
                  item: item,
                  columns: columns,
                  isSelected: _selectedMangaIds.contains(item['mangaId']),
                  onTap: () => _handleGridCardTap(context, item),
                  onLongPress: () => _enterSelection(item['mangaId'] as String),
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }
}

class GridHistoryCard extends StatefulWidget {
  final Map<String, dynamic> item;

  /// Columns the grid actually resolved to.
  ///
  /// The card shrinks its title at four columns, so it has to be told how many
  /// columns there really are: with no stored density the count is derived from
  /// the window and can be well past any position on the slider, and a card
  /// still painting a 12pt title into a cell measured for 10pt is what pushes
  /// the second line out of the cell.
  final int columns;

  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const GridHistoryCard({
    super.key,
    required this.item,
    required this.columns,
    this.isSelected = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<GridHistoryCard> createState() => _GridHistoryCardState();
}

class _GridHistoryCardState extends State<GridHistoryCard> {
  @override
  Widget build(BuildContext context) {
    final progress = widget.item['progress'] as int;
    final newChapters = widget.item['newChapters'] as int;
    final hasDownloadedChapters = widget.item['hasDownloadedChapters'] == true;
    final bool isCompactGrid =
        widget.columns >= kMangaCardCompactColumns;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: kMangaCoverAspectRatio,
            child: Stack(
              children: [
                MangaCoverHero(
                  tag: mangaCoverHeroTag(
                    sourceId: widget.item['sourceId'] as String?,
                    mangaId: widget.item['mangaId'] as String,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: dark
                              ? null
                              : Border.all(color: Colors.black12),
                        ),
                        child: CachedMangaImage(
                          imageUrl: widget.item['coverUrl'],
                          // Read the tile's real size instead of asking for
                          // infinity. Infinity is the one width the decode cap
                          // refuses, which left this the only history mode
                          // decoding covers at full source resolution - around
                          // 18MB each, and every tile at once because the grid
                          // is shrink-wrapped rather than lazy. The delegate
                          // already hands this tile a tight width, so there is
                          // nothing to guess.
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: amoled(context, 0xFF2C2C2E),
                            alignment: Alignment.center,
                            child: const Icon(
                              MdiIcons.bookOpenVariant,
                              color: Colors.white38,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          MdiIcons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                // Favourite heart, pinned to the top-left corner and drawn by
                // the shared badge. The inline copy this replaced read the
                // history row's own isFavorite flag, so it ignored a title
                // being unfavourited anywhere else until the list reloaded.
                FavoriteBadge(
                  mangaId: widget.item['mangaId'] as String,
                  alignment: Alignment.topLeft,
                ),
                // Reading-progress bubble, pinned to the top-right corner at
                // Kotatsu's own offset (`card_indicator_offset`, 8dp).
                Positioned(
                  top: 8,
                  right: 8,
                  child: ProgressBadge(progress: progress),
                ),
                // New-chapter count and download flag, bottom-left. Down here
                // rather than sharing the heart's corner so each corner holds
                // exactly one kind of signal.
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Consumer(
                    builder: (context, ref, _) {
                      if (!ref
                          .watch(appearanceSettingsProvider)
                          .showListBadges) {
                        return const SizedBox.shrink();
                      }
                      if (newChapters <= 0 && !hasDownloadedChapters) {
                        return const SizedBox.shrink();
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (newChapters > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$newChapters',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (newChapters > 0 && hasDownloadedChapters)
                            const SizedBox(width: 4),
                          if (hasDownloadedChapters)
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                MdiIcons.sd,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kMangaCardTitleGap),
          Flexible(
            child: Text(
              widget.item['title'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: isCompactGrid ? 10 : 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailedHistoryCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const DetailedHistoryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<DetailedHistoryCard> createState() => _DetailedHistoryCardState();
}

class _DetailedHistoryCardState extends State<DetailedHistoryCard> {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: dark ? amoled(context, 0xFF1E1E20) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: AppPress(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              MangaCoverHero(
                tag: mangaCoverHeroTag(
                  sourceId: widget.item['sourceId'] as String?,
                  mangaId: widget.item['mangaId'] as String,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedMangaImage(
                    imageUrl: widget.item['coverUrl'],
                    width: 60,
                    height: 85,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item['title'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).historyLastReadChapter(widget.item['lastReadChapter']),
                      style: TextStyle(
                        color: dark ? Colors.white70 : const Color(0xFF49454F),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        if (!ref
                            .watch(appearanceSettingsProvider)
                            .showReadingProgress) {
                          return const SizedBox.shrink();
                        }
                        return LinearProgressIndicator(
                          value: (widget.item['progress'] as int) / 100,
                          backgroundColor: dark
                              ? Colors.white12
                              : Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ref.watch(accentProvider),
                          ),
                          minHeight: 3,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompactHistoryCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const CompactHistoryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<CompactHistoryCard> createState() => _CompactHistoryCardState();
}

class _CompactHistoryCardState extends State<CompactHistoryCard> {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: MangaCoverHero(
        tag: mangaCoverHeroTag(
          sourceId: widget.item['sourceId'] as String?,
          mangaId: widget.item['mangaId'] as String,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: dark ? null : Border.all(color: Colors.black12),
            ),
            child: CachedMangaImage(
              imageUrl: widget.item['coverUrl'],
              width: 40,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      title: Text(
        widget.item['title'],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        AppLocalizations.of(
          context,
        ).historyChapterShort(widget.item['lastReadChapter']),
        style: TextStyle(
          color: dark ? Colors.white54 : const Color(0xFF49454F),
          fontSize: 12,
        ),
      ),
      trailing: Consumer(
        builder: (context, ref, _) {
          if (!ref.watch(appearanceSettingsProvider).showReadingProgress) {
            return const SizedBox.shrink();
          }
          return Text(
            '${widget.item['progress']}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
      onTap: widget.onTap,
    );
  }
}
