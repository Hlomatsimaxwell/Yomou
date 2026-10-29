import 'package:yomou/core/theme/amoled.dart';
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:yomou/widgets/manga_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/widgets/source_icon.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';
import 'package:yomou/core/widgets/ios/ios_nav_bar.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/widgets/material_symbol.dart';
import 'package:yomou/core/widgets/tab_header.dart';
import 'package:yomou/core/widgets/responsive.dart' show usesWideLayout;
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/core/widgets/search_bar.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/share.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/core/providers/incognito_provider.dart';
import 'package:yomou/core/providers/selection_provider.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/features/library/screens/edit_manga_screen.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedMangaIds = {};
  int _selectedFilter = -1;
  String? _selectedSourceId;

  double _gridSize = kMangaGridSizeDefault;

  bool get _isSelecting => _selectedMangaIds.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredItems(List<Map<String, dynamic>> items) {
    var result = items;
    if (_searchQuery.isNotEmpty) {
      result = result
          .where(
            (m) => (m['title'] as String).toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }
    if (_selectedSourceId != null) {
      result = result.where((m) => m['sourceId'] == _selectedSourceId).toList();
    }
    if (_selectedFilter == 0) {
      result = result.where((m) => m['hasDownloadedChapters'] == true).toList();
    } else if (_selectedFilter == 1) {
      result = result
          .where((m) => ((m['newChapters'] as int?) ?? 0) > 0)
          .toList();
    } else if (_selectedFilter == 2) {
      result = result.where((m) => (m['progress'] as int) >= 100).toList();
    }
    return result;
  }

  List<MangaSource> get _pinnedSources {
    final pinned = <MangaSource>[];
    for (final row in ref.read(sourcesProvider)) {
      if (row['isPinned'] != true) continue;
      final name = row['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final source = getSourceByName(name);
      if (source.name != name) continue;
      pinned.add(source);
    }
    return pinned;
  }

  List<String> get _visibleFavoriteIds {
    final async = ref.read(favoritesDetailProvider);
    final items = async.valueOrNull ?? const <Map<String, dynamic>>[];
    return _filteredItems(items).map((m) => m['mangaId'] as String).toList();
  }

  bool get _allVisibleSelected {
    final ids = _visibleFavoriteIds;
    return ids.isNotEmpty && ids.every(_selectedMangaIds.contains);
  }

  void _toggleSelectAll() {
    final ids = _visibleFavoriteIds;
    setState(() {
      if (_allVisibleSelected) {
        _selectedMangaIds.clear();
      } else {
        _selectedMangaIds.addAll(ids);
      }
    });
    ref.read(selectionActiveProvider.notifier).state = _selectedMangaIds.isNotEmpty;
  }

  bool get _selectedAllPinned {
    if (_selectedMangaIds.isEmpty) return false;
    final pinned = ref.read(pinnedFavoritesProvider).valueOrNull ?? const <String>{};
    for (final id in _selectedMangaIds) {
      if (!pinned.contains(id)) return false;
    }
    return true;
  }

  void _enterSelection(String mangaId) {
    setState(() => _selectedMangaIds.add(mangaId));
    ref.read(selectionActiveProvider.notifier).state = true;
  }

  void _toggleSelect(String mangaId) {
    setState(() {
      if (!_selectedMangaIds.remove(mangaId)) {
        _selectedMangaIds.add(mangaId);
      }
    });
    ref.read(selectionActiveProvider.notifier).state = _selectedMangaIds.isNotEmpty;
  }

  void _exitSelection() {
    if (!_isSelecting) return;
    setState(_selectedMangaIds.clear);
    ref.read(selectionActiveProvider.notifier).state = false;
  }

  void _handleGridCardTap(Map<String, dynamic> item) {
    final mangaId = item['mangaId'] as String;
    if (_isSelecting) {
      _toggleSelect(mangaId);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MangaDetailScreen(
            mangaId: mangaId,
            title: item['title'] as String,
            imageUrl: (item['coverUrl'] as String?) ?? '',
            sourceId: (item['sourceId'] as String?) ?? '',
          ),
        ),
      );
    }
  }

  Future<void> _shareSelected() async {
    final ids = _selectedMangaIds.toList();
    if (ids.isEmpty) return;
    final details = ref.read(favoritesDetailProvider).valueOrNull ?? const [];
    final buffer = StringBuffer();
    for (final mangaId in ids) {
      final item = details.firstWhere(
        (e) => e['mangaId'] == mangaId,
        orElse: () => const <String, dynamic>{},
      );
      if (item.isEmpty) continue;
      final title = (item['title'] as String?) ?? '';
      final sourceId = item['sourceId'] as String?;
      final source = sourceId == null ? null : getSourceBySourceId(sourceId);
      final siteUrl = source == null ? '' : source.websiteMangaUrl(mangaId);
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(title);
      if (siteUrl.isNotEmpty) {
        buffer.write('\n');
        buffer.write(siteUrl);
      }
    }
    if (buffer.isEmpty) return;
    await shareText(buffer.toString());
  }

  Future<void> _pinSelected({required bool pin}) async {
    final ids = _selectedMangaIds.toList();
    if (ids.isEmpty) return;
    for (final id in ids) {
      await DatabaseHelper.instance.setPinned(mangaId: id, isPinned: pin);
    }
    if (!mounted) return;
    setState(_selectedMangaIds.clear);
    ref.read(selectionActiveProvider.notifier).state = false;
    ref.read(favoritesRevisionProvider.notifier).state++;
  }

  Future<void> _removeSelected() async {
    final ids = _selectedMangaIds.toList();
    if (ids.isEmpty) return;
    for (final id in ids) {
      await DatabaseHelper.instance.setFavorite(
        mangaId: id,
        title: '',
        isFavorite: false,
      );
    }
    if (!mounted) return;
    setState(_selectedMangaIds.clear);
    ref.read(selectionActiveProvider.notifier).state = false;
    ref.read(favoritesRevisionProvider.notifier).state++;
  }

  Future<void> _markCompletedSelected() async {
    final ids = _selectedMangaIds.toList();
    if (ids.isEmpty) return;
    final wasIncognito = incognitoActive;
    incognitoActive = false;
    var changed = 0;
    try {
      final details = ref.read(favoritesDetailProvider).valueOrNull ?? const [];
      for (final mangaId in ids) {
        final item = details.firstWhere(
          (e) => e['mangaId'] == mangaId,
          orElse: () => const <String, dynamic>{},
        );
        if (item.isEmpty) continue;
        final title = (item['title'] as String?) ?? '';
        final sourceId = item['sourceId'] as String?;
        final source = sourceId == null ? null : getSourceBySourceId(sourceId);

        int total = (item['totalReleasedChapters'] as int?) ?? 0;
        // favorites detail doesn't store total; fetch from DB row via getManga
        final row = await DatabaseHelper.instance.getManga(mangaId);
        if (total <= 0) total = (row?['totalChapters'] as int?) ?? 0;

        if (total <= 0 && source != null) {
          try {
            final d = await SourceCache.mangaDetails(
              sourceId: source.id,
              mangaId: mangaId,
              forceRefresh: true,
              fetch: () => source.getMangaDetails(mangaId),
            );
            if (d != null && d.totalChapters > 0) {
              total = d.totalChapters;
              await DatabaseHelper.instance.upsertManga(
                mangaId: mangaId,
                title: d.title.isNotEmpty ? d.title : title,
                coverUrl: d.coverUrl,
                sourceId: sourceId,
                totalChapters: total,
              );
            }
          } catch (_) {}
        }
        if (total <= 0 && source != null) {
          try {
            final chapters = await SourceCache.chapters(
              sourceId: source.id,
              mangaId: mangaId,
              forceRefresh: true,
              fetch: () => source.getChapters(mangaId),
            );
            if (chapters.isNotEmpty) {
              var maxNum = 0.0;
              for (final c in chapters) {
                final n = double.tryParse(c.chapterNumber) ?? 0;
                if (n > maxNum) maxNum = n;
              }
              total = maxNum > 0 ? maxNum.round() : chapters.length;
              if (total > 0) {
                await DatabaseHelper.instance.upsertManga(
                  mangaId: mangaId,
                  title: title,
                  coverUrl: (item['coverUrl'] as String?) ?? '',
                  sourceId: sourceId,
                  totalChapters: total,
                );
              }
            }
          } catch (_) {}
        }
        if (total <= 0) continue;

        await DatabaseHelper.instance.saveMangaProgress(
          mangaId: mangaId,
          title: title,
          coverUrl: (item['coverUrl'] as String?) ?? '',
          sourceId: sourceId,
          totalChapters: total,
          lastReadChapter: total.toDouble(),
          lastReadPage: 0,
          lastReadAt: DateTime.now(),
        );
        changed++;
      }
    } finally {
      incognitoActive = wasIncognito;
    }
    if (!mounted) return;
    setState(_selectedMangaIds.clear);
    ref.read(selectionActiveProvider.notifier).state = false;
    ref.read(favoritesRevisionProvider.notifier).state++;
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    showIosToast(
      context,
      message: changed > 0
          ? '${l.historyMarkCompleted} ($changed)'
          : 'No chapter info found',
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _openEditForSelected() async {
    if (_selectedMangaIds.length != 1) return;
    final mangaId = _selectedMangaIds.first;
    final details = ref.read(favoritesDetailProvider).valueOrNull ?? const [];
    final item = details.firstWhere(
      (e) => e['mangaId'] == mangaId,
      orElse: () => const <String, dynamic>{},
    );
    final row = await DatabaseHelper.instance.getManga(mangaId);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditMangaScreen(
          mangaId: mangaId,
          title: (row?['title'] as String?) ?? (item['title'] as String? ?? ''),
          imageUrl: (row?['coverUrl'] as String?) ?? (item['coverUrl'] as String? ?? ''),
          sourceId: (row?['sourceId'] as String?) ?? (item['sourceId'] as String? ?? ''),
        ),
      ),
    );
    _exitSelection();
    if (!mounted) return;
    ref.read(favoritesRevisionProvider.notifier).state++;
  }

  Widget _buildSelectionBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final barBg = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.08),
      cs.surface,
    );
    final fg = cs.onSurface;
    final actionFg = cs.onSurface.withValues(alpha: 0.6);
    final showLabels = MediaQuery.of(context).size.width > 600;
    final wide = MediaQuery.of(context).size.width >= 900;
    final allPinned = _selectedAllPinned;

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
                        label.toUpperCase(),
                        style: TextStyle(
                          color: actionFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  )
                : icon,
          ),
        ),
      );
    }

    final actions = <Widget>[
      navAction(
        Icon(MdiIcons.shareVariant, color: actionFg, size: 22),
        _shareSelected,
        label: l.share,
      ),
      navAction(
        Icon(
          allPinned ? MdiIcons.pinOff : MdiIcons.pin,
          color: actionFg,
          size: 22,
        ),
        () => _pinSelected(pin: !allPinned),
        label: allPinned ? 'Unpin' : 'Pin',
      ),
      navAction(
        Icon(MdiIcons.deleteOutline, color: actionFg, size: 22),
        _removeSelected,
        label: l.delete,
      ),
    ];

    if (wide) {
      actions.addAll([
        navAction(
          Icon(MdiIcons.pencilOutline, color: actionFg, size: 22),
          _openEditForSelected,
          label: l.historyEdit,
        ),
        navAction(
          MaterialSymbol(
            MaterialSymbol.selectAll,
            color: actionFg,
            size: 22,
          ),
          _toggleSelectAll,
          label: l.selectAll,
        ),
      ]);
    } else {
      actions.add(
        navAction(
          Icon(MdiIcons.dotsVertical, color: actionFg, size: 22),
          () => _showSelectionActions(context),
        ),
      );
    }

    return Container(
      color: barBg,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: IosNavBar(
        showBack: false,
        flat: true,
        safeArea: false,
        height: 64,
        leading: navAction(
          Icon(MdiIcons.close, color: actionFg, size: 22),
          _exitSelection,
        ),
        titleWidget: Text(
          '${_selectedMangaIds.length}',
          style: TextStyle(
            color: fg,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: actions,
      ),
    );
  }

  void _showSelectionActions(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    final l = AppLocalizations.of(context);
    final allPinned = _selectedAllPinned;

    showIosSheet(
      context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSheetRow(
                icon: allPinned ? MdiIcons.pinOff : MdiIcons.pin,
                label: allPinned ? 'Unpin' : 'Pin',
                color: fg,
                onTap: () {
                  Navigator.pop(context);
                  _pinSelected(pin: !allPinned);
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
              _buildSheetRow(
                icon: MdiIcons.selectAll,
                label: l.selectAll,
                color: fg,
                onTap: () {
                  Navigator.pop(context);
                  _toggleSelectAll();
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
    required VoidCallback onTap,
  }) {
    return AppPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _gridSize = ref.watch(appearanceSettingsProvider).gridSize;
    final favoritesAsync = ref.watch(favoritesDetailProvider);
    final pinned = ref.watch(pinnedFavoritesProvider).valueOrNull ?? const <String>{};

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: TabHeader(
        mode: usesWideLayout(context)
            ? TabHeaderMode.fixed
            : TabHeaderMode.collapsing,
        title: AppLocalizations.of(context).favorites,
        leading: _isSelecting ? _buildSelectionBar(context) : null,
        searchBar: _isSelecting ? const SizedBox.shrink() : _buildSearchBar(),
        body: favoritesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              AppLocalizations.of(context).favoritesCouldNotLoad,
            ),
          ),
          data: (items) {
            final displayed = _filteredItems(items);
            if (displayed.isEmpty && items.isEmpty) {
              final l = AppLocalizations.of(context);
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: EmptyState(
                        icon: MdiIcons.heartOutline,
                        title: _searchQuery.isNotEmpty
                            ? AppLocalizations.of(context).favoritesNoMatch
                            : l.favoritesEmpty,
                        subtitle: l.favoritesEmptySubtitle,
                      ),
                    ),
                  ),
                ],
              );
            }
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (ref.watch(appearanceSettingsProvider).showQuickFilters) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: _buildFilterChips()),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
                _buildMangaGrid(displayed, pinned),
                SliverPadding(
                  padding: EdgeInsets.only(bottom: bottomBarClearance(context)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return YomouSearchBar.text(
      hintText: AppLocalizations.of(context).searchManga,
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      clearVisible: _searchQuery.isNotEmpty,
      onClear: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
        });
      },
      trailing: AppSheetPress(
        onTap: () async {
          final action = await showIosMenuPanel<String>(
            context,
            children: [
              IosMenuRow(
                icon: MdiIcons.viewGridOutline,
                label: AppLocalizations.of(context).historyListOptions,
                onTap: () => Navigator.pop(context, 'listOptions'),
              ),
              const IosMenuDivider(),
              Consumer(
                builder: (context, ref, _) => MenuToggleRow(
                  label: AppLocalizations.of(context).incognitoMode,
                  value: ref.watch(incognitoProvider),
                  onChanged: (v) =>
                      ref.read(incognitoProvider.notifier).set(v),
                ),
              ),
              const IosMenuDivider(),
              IosMenuRow(
                icon: MdiIcons.cogOutline,
                label: AppLocalizations.of(context).settings,
                onTap: () => Navigator.pop(context, 'settings'),
              ),
            ],
          );
          if (!mounted) return;
          if (action == 'listOptions') {
            _showGridOptionsSheet();
          } else if (action == 'settings') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            MdiIcons.dotsVertical,
            color: dark ? Colors.white70 : Colors.black54,
            size: 22,
          ),
        ),
      ),
    );
  }

  void _showGridOptionsSheet() {
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
                    AppLocalizations.of(
                      context,
                    ).appearanceGridSize(_gridSize.round()),
                    style: TextStyle(
                      color: dark ? Colors.white70 : const Color(0xFF49454F),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _gridSize,
                    min: kMangaGridSizeMin.toDouble(),
                    max: kMangaGridSizeMax.toDouble(),
                    divisions: kMangaGridSizeDivisions,
                    onChanged: (value) {
                      setSheetState(() {
                        _gridSize = value;
                      });
                      setState(() {});
                      ref
                          .read(appearanceSettingsProvider.notifier)
                          .setGridSize(value);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int _resolvedColumns(BuildContext context, [double? availableWidth]) =>
      mangaGridColumns(
        context,
        gridSize: _gridSize,
        availableWidth: availableWidth,
      );

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
          for (final source in _pinnedSources)
            _filterChip(
              isSelected: _selectedSourceId == source.id,
              leading: SourceIcon(
                name: source.name,
                iconUrl: source.iconUrl,
                siteUrl: source.websiteUrl,
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
        : (dark ? Colors.white70 : const Color(0xFF49454F));
    return AppPress(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? fill : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? fill : (dark ? Colors.white24 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 6)],
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMangaGrid(List<Map<String, dynamic>> items, Set<String> pinned) {
    if (items.isEmpty) {
      // handled by caller; keep empty sliver
    }
    if (items.isEmpty) {
      return SliverToBoxAdapter(child: const SizedBox.shrink());
    }

    return SliverLayoutBuilder(
      builder: (context, sliverConstraints) {
        final availableWidth = sliverConstraints.crossAxisExtent;
        final columns = _resolvedColumns(context, availableWidth);
        return SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: kMangaGridHorizontalPadding,
          ),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: mangaCellAspectRatio(
                context,
                columns: columns,
                titleFontSize: mangaCardTitleFontSize(columns),
                availableWidth: availableWidth,
              ),
              crossAxisSpacing: kMangaGridCrossSpacing,
              mainAxisSpacing: kMangaGridRowSpacing,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildMangaCard(context, item, columns, pinned);
            },
          ),
        );
      },
    );
  }

  Widget _buildMangaCard(
    BuildContext context,
    Map<String, dynamic> item,
    int columns,
    Set<String> pinned,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = dark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final mangaId = item['mangaId'] as String;
    final isSelected = _selectedMangaIds.contains(mangaId);
    final isPinned = pinned.contains(mangaId);
    return GestureDetector(
      onTap: () => _handleGridCardTap(item),
      onLongPress: () => _enterSelection(mangaId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: kMangaCoverAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MangaCoverHero(
                  tag: mangaCoverHeroTag(
                    sourceId: (item['sourceId'] as String?) ?? '',
                    mangaId: mangaId,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: dark
                        ? CachedMangaImage(
                            imageUrl: (item['coverUrl'] as String?) ?? '',
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              color: amoled(context, 0xFF2C2C2E),
                              alignment: Alignment.center,
                              child: const Icon(
                                MdiIcons.bookOpenVariant,
                                color: Colors.white38,
                                size: 28,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: CachedMangaImage(
                              imageUrl: (item['coverUrl'] as String?) ?? '',
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(
                                  MdiIcons.bookOpenVariant,
                                  color: Colors.black38,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                DownloadedMangaBadge(mangaId: mangaId),
                FavoriteBadge(mangaId: mangaId),
                if (isPinned)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.black.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        MdiIcons.pin,
                        color: dark ? Colors.white : Colors.black87,
                        size: 14,
                      ),
                    ),
                  ),
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
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
              ],
            ),
          ),
          const SizedBox(height: kMangaCardTitleGap),
          Flexible(
            child: Text(
              (item['title'] as String?) ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: titleColor,
                fontSize: mangaCardTitleFontSize(columns),
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
