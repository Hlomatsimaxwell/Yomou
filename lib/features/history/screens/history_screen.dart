import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/features/explore/screens/global_search_screen.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/library/screens/edit_manga_screen.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/ios/ios_nav_bar.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/core/widgets/search_bar.dart';

class ProgressBadge extends StatelessWidget {
  final int progress;

  const ProgressBadge({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final double value = (progress / 100).clamp(0.0, 1.0);

    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF8E8E93),
              ),
            ),
          ),
          Text(
            '$progress%',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _selectedFilter = -1;
  bool _isIncognitoMode = false;
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';

  String _listMode = 'Grid';
  double _gridSize = 3;
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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();

    final listMode = prefs.getString('history_list_mode') ?? 'Grid';
    final gridSize = prefs.getDouble('history_grid_size') ?? 3.0;
    final sortingOrder =
        prefs.getString('history_sorting_order') ?? 'Last read';
    final isGrouped = prefs.getBool('history_is_grouped') ?? true;

    setState(() {
      _listMode = listMode;
      _gridSize = gridSize;
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
            return AlertDialog(
              backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
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
                  Icon(RemixIcons.delete_bin_5_line, color: fg, size: 28),
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
                  _buildRadioOption(
                    title: AppLocalizations.of(context).historyClearLastHours,
                    value: 0,
                    groupValue: selectedOption,
                    onChanged: (val) =>
                        setDialogState(() => selectedOption = val!),
                  ),
                  _buildRadioOption(
                    title: AppLocalizations.of(context).historyClearToday,
                    value: 1,
                    groupValue: selectedOption,
                    onChanged: (val) =>
                        setDialogState(() => selectedOption = val!),
                  ),
                  _buildRadioOption(
                    title: AppLocalizations.of(
                      context,
                    ).historyClearNotFavorites,
                    value: 2,
                    groupValue: selectedOption,
                    onChanged: (val) =>
                        setDialogState(() => selectedOption = val!),
                  ),
                  _buildRadioOption(
                    title: AppLocalizations.of(context).historyClearAll,
                    value: 3,
                    groupValue: selectedOption,
                    onChanged: (val) =>
                        setDialogState(() => selectedOption = val!),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context).historyUpdated,
                        ),
                      ),
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

  Widget _buildRadioOption({
    required String title,
    required int value,
    required int groupValue,
    required ValueChanged<int?> onChanged,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = dark
        ? Colors.white
        : Theme.of(context).colorScheme.primary;
    return AppPress(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Radio<int>(
              value: value,
              groupValue: groupValue,
              activeColor: activeColor,
              fillColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.selected)) {
                  return activeColor;
                }
                return dark ? Colors.white70 : Colors.black38;
              }),
              onChanged: onChanged,
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).historyListMode,
                    style: TextStyle(
                      color: dark ? Colors.white70 : const Color(0xFF49454F),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: dark ? Colors.white24 : Colors.black12,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildSegmentTab(
                          'Compact',
                          RemixIcons.list_unordered,
                          setSheetState,
                        ),
                        VerticalDivider(
                          width: 1,
                          color: dark ? Colors.white24 : Colors.black12,
                          indent: 8,
                          endIndent: 8,
                        ),
                        _buildSegmentTab(
                          'Details',
                          RemixIcons.list_view,
                          setSheetState,
                        ),
                        VerticalDivider(
                          width: 1,
                          color: dark ? Colors.white24 : Colors.black12,
                          indent: 8,
                          endIndent: 8,
                        ),
                        _buildSegmentTab(
                          'Grid',
                          RemixIcons.grid_line,
                          setSheetState,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).historyGridSize,
                        style: TextStyle(
                          color: dark
                              ? Colors.white70
                              : const Color(0xFF49454F),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).historyGridSizeColumns(_gridSize.toInt()),
                        style: TextStyle(
                          color: dark ? Colors.white54 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      activeTrackColor: dark
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      inactiveTrackColor: dark
                          ? Colors.white12
                          : Colors.black12,
                      thumbColor: dark
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                        elevation: 4,
                      ),
                      overlayColor: (dark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.12),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 20,
                      ),
                      tickMarkShape: const RoundSliderTickMarkShape(
                        tickMarkRadius: 2,
                      ),
                      activeTickMarkColor: Colors.transparent,
                      inactiveTickMarkColor: dark
                          ? Colors.white30
                          : Colors.black26,
                    ),
                    child: Slider(
                      value: 7 - _gridSize,
                      min: 1,
                      max: 6,
                      divisions: 5,
                      onChanged: (value) {
                        final actualColumns = 7 - value;

                        setSheetState(() {
                          _gridSize = actualColumns;
                        });
                        setState(() {});
                        _savePreference('history_grid_size', actualColumns);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).historySortingOrder,
                    style: TextStyle(
                      color: dark ? Colors.white70 : const Color(0xFF49454F),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF2C2C2E) : Colors.white,
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
                            ? const Color(0xFF2C2C2E)
                            : Colors.white,
                        isExpanded: true,
                        icon: Icon(
                          RemixIcons.arrow_drop_down_line,
                          color: dark
                              ? Colors.white70
                              : const Color(0xFF49454F),
                        ),
                        style: TextStyle(
                          color: dark ? Colors.white : const Color(0xFF1C1B1F),
                          fontSize: 15,
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
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            RemixIcons.list_unordered,
                            color: dark
                                ? Colors.white70
                                : const Color(0xFF49454F),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context).historyGroup,
                            style: TextStyle(
                              color: dark
                                  ? Colors.white
                                  : const Color(0xFF1C1B1F),
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
                            ? const Color(0xFF2C2C2E)
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
            );
          },
        );
      },
    );
  }

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = dark
        ? const Color(0xFF6B6F76)
        : Theme.of(context).colorScheme.primary;
    final fg = isSelected
        ? Colors.white
        : (dark ? Colors.white : const Color(0xFF1C1B1F));
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _exitSelection();
          setSheetState(() => _listMode = mode);
          setState(() {});
          _savePreference('history_list_mode', mode);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(height: 2),
              Text(
                _modeLabel(context, mode),
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOverflowMenu(BuildContext context) async {
    final l = AppLocalizations.of(context);
    showIosSheet(
      context,
      builder: (context) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
        final divider = dark ? Colors.white12 : Colors.black12;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSheetRow(
                icon: RemixIcons.delete_bin_5_line,
                label: l.historyClearTitle,
                color: fg,
                onTap: () {
                  Navigator.pop(context);
                  _showClearHistoryDialog(context);
                },
              ),
              Divider(color: divider, height: 1, thickness: 1),
              _buildSheetRow(
                icon: RemixIcons.list_unordered,
                label: l.historyListOptions,
                color: fg,
                onTap: () {
                  Navigator.pop(context);
                  _showListOptionsSheet(context);
                },
              ),
              Divider(color: divider, height: 1, thickness: 1),
              _buildSheetRow(
                icon: RemixIcons.pie_chart_2_line,
                label: l.historyStatistics,
                color: fg,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              Divider(color: divider, height: 1, thickness: 1),
              _buildSheetRow(
                icon: RemixIcons.eye_off_line,
                label: l.incognitoMode,
                color: fg,
                trailing: Switch(
                  value: _isIncognitoMode,
                  activeThumbColor: dark ? Colors.black : Colors.white,
                  activeTrackColor: dark
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                  inactiveThumbColor: dark ? Colors.white54 : Colors.black54,
                  inactiveTrackColor: dark
                      ? const Color(0xFF2C2C2E)
                      : Colors.black12,
                  onChanged: (value) {
                    setState(() => _isIncognitoMode = value);
                  },
                ),
              ),
              Divider(color: divider, height: 1, thickness: 1),
              _buildSheetRow(
                icon: RemixIcons.settings_3_line,
                label: l.settings,
                color: fg,
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
          ),
        );
      },
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
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(historyRevisionProvider, (prev, next) {
      if (next != prev) _loadFromProvider();
    });
    ref.listen<int>(downloadsRevisionProvider, (prev, next) {
      if (next != prev) _loadFromProvider();
    });

    final filteredList = _historyItems.where((item) {
      if (_searchQuery.isNotEmpty &&
          !item['title'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          )) {
        return false;
      }

      if (_selectedFilter == 0) {
        return item['hasDownloadedChapters'] == true;
      } else if (_selectedFilter == 1) {
        final unread = (item['newChapters'] as int?) ?? 0;
        return unread > 0;
      } else if (_selectedFilter == 2) {
        return (item['progress'] as int) >= 100;
      }

      return true;
    }).toList();

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
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomBarClearance(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                if (_isSelecting)
                  _buildSelectionBar(context)
                else ...[
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildFilterChips(),
                ],
                const SizedBox(height: 16),
                if (filteredList.isEmpty)
                  EmptyState(
                    icon: RemixIcons.history_line,
                    title: AppLocalizations.of(context).historyEmptyTitle,
                    subtitle: AppLocalizations.of(context).historyEmptySubtitle,
                  )
                else if (_isGrouped)
                  ...groupedHistory.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
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
                        _buildHistoryLayout(context, entry.value),
                        const SizedBox(height: 12),
                      ],
                    );
                  })
                else
                  _buildHistoryLayout(context, filteredList),
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
    return YomouSearchBar.tappable(
      hintText: AppLocalizations.of(context).searchManga,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GlobalSearchScreen()),
        );
      },
      trailing: GestureDetector(
        onTapDown: (TapDownDetails details) {
          _showOverflowMenu(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(RemixIcons.more_2_line, color: iconColor, size: 22),
        ),
      ),
    );
  }

  bool get _isSelecting => _selectedMangaIds.isNotEmpty;

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);

    Widget navAction(IconData icon, VoidCallback onTap) {
      return Center(
        child: AppPress(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: fg, size: 22),
          ),
        ),
      );
    }

    return IosNavBar(
      showBack: false,
      leading: navAction(RemixIcons.close_line, _exitSelection),
      titleWidget: Text(
        AppLocalizations.of(
          context,
        ).historySelectedCount(_selectedMangaIds.length),
        style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w600),
      ),
      actions: [
        navAction(RemixIcons.delete_bin_5_line, _deleteSelected),
        navAction(RemixIcons.share_2_line, _showComingSoon),
        navAction(RemixIcons.more_2_line, _showSelectionActions),
      ],
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

  void _showComingSoon() {
    showIosToast(
      context,
      message: AppLocalizations.of(context).historyComingSoon,
      duration: const Duration(seconds: 2),
    );
  }

  void _showSelectionActions() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    final l = AppLocalizations.of(context);

    void stub() {
      Navigator.pop(context);
      _showComingSoon();
    }

    showIosSheet(
      context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSheetRow(
                icon: RemixIcons.bookmark_3_line,
                label: l.save,
                color: fg,
                onTap: stub,
              ),
              Divider(
                color: dark ? Colors.white12 : Colors.black12,
                height: 1,
                thickness: 1,
              ),
              _buildSheetRow(
                icon: RemixIcons.heart_3_line,
                label: l.favorite,
                color: fg,
                onTap: () {
                  Navigator.pop(context);
                  _favoriteSelected();
                },
              ),
              Divider(
                color: dark ? Colors.white12 : Colors.black12,
                height: 1,
                thickness: 1,
              ),
              _buildSheetRow(
                icon: RemixIcons.exchange_2_line,
                label: l.replaceSource,
                color: fg,
                onTap: stub,
              ),
              Divider(
                color: dark ? Colors.white12 : Colors.black12,
                height: 1,
                thickness: 1,
              ),
              _buildSheetRow(
                icon: RemixIcons.edit_line,
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
              Divider(
                color: dark ? Colors.white12 : Colors.black12,
                height: 1,
                thickness: 1,
              ),
              _buildSheetRow(
                icon: RemixIcons.check_double_line,
                label: l.historyMarkCompleted,
                color: fg,
                onTap: stub,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _favoriteSelected() async {
    final ids = _selectedMangaIds.toList();
    if (ids.isEmpty) return;

    var added = 0;
    for (final mangaId in ids) {
      if (await DatabaseHelper.instance.getIsFavorite(mangaId)) continue;
      final row = await DatabaseHelper.instance.getManga(mangaId);
      if (row == null) continue;
      await DatabaseHelper.instance.setFavorite(
        mangaId: mangaId,
        title: (row['title'] as String?) ?? '',
        coverUrl: row['coverUrl'] as String?,
        sourceId: row['sourceId'] as String?,
        isFavorite: true,
      );
      added++;
    }
    if (!mounted) return;

    final l = AppLocalizations.of(context);
    setState(_selectedMangaIds.clear);
    if (added > 0) {
      bumpFavoritesRevision(ref);
    }
    showIosToast(
      context,
      message: added > 0
          ? l.historyFavoritedCount(added)
          : l.historyAlreadyFavorite,
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

  Widget _buildFilterChips() {
    final filters = [
      {'icon': RemixIcons.sd_card_line, 'labelKey': 'onDevice'},
      {'icon': RemixIcons.file_history_line, 'labelKey': 'newChapters'},
      {'icon': RemixIcons.check_double_line, 'labelKey': 'completed'},
    ];

    final l = AppLocalizations.of(context);
    final labels = [
      l.historyOnDevice,
      l.historyNewChapters,
      l.historyCompleted,
    ];

    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(filters.length, (index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == index;

          final Color bg = dark
              ? (isSelected ? Colors.white : Colors.transparent)
              : (isSelected ? primary : const Color(0xFFE2E8F0));
          final Color fg = dark
              ? (isSelected ? Colors.black : Colors.white)
              : (isSelected ? Colors.white : const Color(0xFF334155));

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = isSelected ? -1 : index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: dark
                    ? Border.all(
                        color: isSelected ? Colors.white : Colors.white38,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(filter['icon'] as IconData, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHistoryLayout(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    if (_listMode == 'Compact') {
      return _buildCompactList(context, items);
    } else if (_listMode == 'Details') {
      return _buildDetailsList(context, items);
    } else {
      return _buildGridSection(context, items);
    }
  }

  Widget _buildCompactList(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (context, index) => Divider(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white12
            : Colors.black12,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return CompactHistoryCard(
          item: item,
          onTap: () => _navigateToDetail(context, item),
        );
      },
    );
  }

  Widget _buildDetailsList(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return DetailedHistoryCard(
          item: item,
          onTap: () => _navigateToDetail(context, item),
        );
      },
    );
  }

  Widget _buildGridSection(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridSize.toInt(),
          childAspectRatio: mangaCellAspectRatio(
            context,
            columns: _gridSize.toInt(),
            titleFontSize: _gridSize >= 4 ? 10 : 12,
          ),
          crossAxisSpacing: kMangaGridCrossSpacing,
          mainAxisSpacing: kMangaGridRowSpacing,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GridHistoryCard(
            item: item,
            gridSize: _gridSize,
            isSelected: _selectedMangaIds.contains(item['mangaId']),
            onTap: () => _handleGridCardTap(context, item),
            onLongPress: () => _enterSelection(item['mangaId'] as String),
          );
        },
      ),
    );
  }
}

class GridHistoryCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final double gridSize;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const GridHistoryCard({
    super.key,
    required this.item,
    required this.gridSize,
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
    final isFavorited = widget.item['isFavorite'] == true;
    final bool isCompactGrid = widget.gridSize >= 4;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: dark ? null : Border.all(color: Colors.black12),
                    ),
                    child: CachedMangaImage(
                      imageUrl: widget.item['coverUrl'],
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF2C2C2E),
                        child: const Icon(
                          RemixIcons.book_open_line,
                          color: Colors.white38,
                          size: 20,
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
                          RemixIcons.check_line,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 6,
                  left: 6,
                  right: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
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
                            if (hasDownloadedChapters)
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  RemixIcons.sd_card_line,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            if (isFavorited)
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  RemixIcons.heart_3_fill,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ProgressBadge(progress: progress),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kMangaCardTitleGap),
          Expanded(
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
        color: dark ? const Color(0xFF1E1E20) : Colors.white,
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedMangaImage(
                  imageUrl: widget.item['coverUrl'],
                  width: 60,
                  height: 85,
                  fit: BoxFit.cover,
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
                    LinearProgressIndicator(
                      value: (widget.item['progress'] as int) / 100,
                      backgroundColor: dark ? Colors.white12 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        dark
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                      ),
                      minHeight: 3,
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
      leading: ClipRRect(
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.item['progress']}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      onTap: widget.onTap,
    );
  }
}
