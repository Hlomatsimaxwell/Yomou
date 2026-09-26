import 'package:remixicon/remixicon.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_filter.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/features/source_management/screens/manga_filter_sheet.dart';
import 'package:yomou/features/source_management/screens/source_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/source_icon.dart';

class MangaGridScreen extends ConsumerStatefulWidget {
  final String sourceName;

  const MangaGridScreen({super.key, required this.sourceName});

  @override
  ConsumerState<MangaGridScreen> createState() => _MangaGridScreenState();
}

class _MangaGridScreenState extends ConsumerState<MangaGridScreen> {
  AppLocalizations get _l => AppLocalizations.of(context);

  int _selectedFilterIndex = -1;
  String? _activeTag;
  List<String> _tags = const <String>[];
  MangaFilter _filter = const MangaFilter();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  List<Manga> _mangaList = [];
  bool _isLoading = true;
  String? _error;

  // Grid layout preferences (mirrors history/suggestions list options).
  String _listMode = 'Grid';
  double _gridSize = 3;

  // Continuous ("endless") scrolling state: page 1 loads first, then scrolling
  // near the bottom fetches the next page and appends it, forever.
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final Set<String> _seenIds = {};
  final ScrollController _scrollController = ScrollController();

  // Real genre/theme tags offered by the current source (via getAvailableTags);
  // empty when the source exposes no tag list. The "Genres" placeholder chips
  // were dropped in favour of these source-backed tags, which actually filter
  // the grid through searchMangaByTags.

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTags();
    _loadLayoutPrefs();
    _initGrid();
  }

  Future<void> _loadLayoutPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('manga_grid_list_mode') ?? 'Grid';
    final size = prefs.getDouble('manga_grid_grid_size') ?? 3.0;
    if (!mounted) return;
    setState(() {
      _listMode = mode;
      _gridSize = size;
    });
  }

  Future<void> _saveLayoutPref(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  Future<void> _initGrid() async {
    await _loadPersistedFilter();
    if (!mounted) return;
    await _loadManga();
  }

  Future<void> _loadPersistedFilter() async {
    try {
      final source = getSourceByName(widget.sourceName);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('source_filter_${source.id}');
      if (raw == null) return;
      final filter = MangaFilter.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!mounted) return;
      if (filter.isDefault) return;
      setState(() => _filter = filter);
    } catch (_) {
      // No saved filter — use defaults.
    }
  }

  Future<void> _saveFilter(MangaFilter filter) async {
    final source = getSourceByName(widget.sourceName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'source_filter_${source.id}',
      jsonEncode(filter.toJson()),
    );
  }

  Future<void> _openFilterSheet() async {
    final source = getSourceByName(widget.sourceName);
    final result = await showMangaFilterSheet(
      context,
      initial: _filter,
      tags: _tags,
      presetsKey: 'source_presets_${source.id}',
      onSave: _saveFilter,
    );
    if (result == null) return;
    setState(() {
      _filter = result;
      _activeTag = null;
      _selectedFilterIndex = -1;
    });
    _loadManga();
  }

  Future<void> _loadTags() async {
    try {
      final source = getSourceByName(widget.sourceName);
      final tags = await SourceCache.tags(
        sourceId: source.id,
        fetch: source.getAvailableTags,
      );
      if (!mounted) return;
      setState(() => _tags = tags);
    } catch (_) {
      // No tag list available — leave the row hidden.
    }
  }

  Future<void> _loadManga({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _isLoadingMore = false;
    });
    try {
      final source = getSourceByName(widget.sourceName);
      final tag = _activeTag;
      final filter = _filter;
      final usingFilter = tag == null && !filter.isDefault;
      final manga = await SourceCache.mangaList(
        sourceId: source.id,
        kind: usingFilter ? 'filter' : (tag != null ? 'tag' : 'popular'),
        arg: usingFilter
            ? filter.cacheKey
            : (tag ?? ''),
        page: 1,
        forceRefresh: forceRefresh,
        fetch: tag != null
            ? () => source.searchMangaByTags([tag])
            : usingFilter
                ? () => source.searchWithFilter(filter)
                : source.getPopularManga,
      );
      setState(() {
        _mangaList = manga;
        _isLoading = false;
        _seenIds
          ..clear()
          ..addAll(manga.map((m) => m.id));
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Near the bottom, kick off the next page (once at a time).
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    final next = _page + 1;
    setState(() => _isLoadingMore = true);
    try {
      final source = getSourceByName(widget.sourceName);
      final tag = _activeTag;
      final filter = _filter;
      final usingFilter = tag == null && !filter.isDefault;
      final manga = await SourceCache.mangaList(
        sourceId: source.id,
        kind: usingFilter ? 'filter' : (tag != null ? 'tag' : 'popular'),
        arg: usingFilter
            ? filter.cacheKey
            : (tag ?? ''),
        page: next,
        fetch: tag != null
            ? () => source.searchMangaByTags([tag], page: next)
            : usingFilter
                ? () => source.searchWithFilter(filter, page: next)
                : () => source.getPopularManga(page: next),
      );
      // Sources occasionally repeat titles across pages; keep the grid clean.
      final fresh = <Manga>[];
      for (final m in manga) {
        if (_seenIds.add(m.id)) fresh.add(m);
      }
      if (!mounted) return;
      setState(() {
        _page = next;
        _mangaList = [..._mangaList, ...fresh];
        _isLoadingMore = false;
        // An empty page means we hit the end of the catalog.
        if (manga.isEmpty) _hasMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Stop paginating quietly (the existing content stays usable).
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    final source = getSourceByName(widget.sourceName);
    SourceCache.invalidatePrefix('${source.id}/list/');
    await _loadManga(forceRefresh: true);
  }

  void _applyTag(String? tag) {
    setState(() {
      _activeTag = tag;
      _selectedFilterIndex = tag == null ? -1 : _tags.indexOf(tag);
    });
    _loadManga();
  }

  String _sortLabel(AppLocalizations l) {
    for (final (code, label) in kFilterSorts) {
      if (code == _filter.sort) return label;
    }
    return l.filterUpdated;
  }

  void _openRandomManga() {
    if (_mangaList.isEmpty) return;

    final random = Random();
    final randomManga = _mangaList[random.nextInt(_mangaList.length)];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDetailScreen(
          mangaId: randomManga.id,
          title: randomManga.title,
          imageUrl: randomManga.coverUrl,
          sourceId: randomManga.sourceId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final displayedManga = _mangaList.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            RemixIcons.arrow_left_line,
            color: dark ? Colors.white : const Color(0xFF1C1B1F),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  color: dark ? Colors.white : const Color(0xFF1C1B1F),
                  fontSize: 18,
                ),
                cursorColor: dark ? Colors.white : const Color(0xFF1C1B1F),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchCatalog,
                  hintStyle: TextStyle(
                    color: dark ? Colors.white54 : Colors.black54,
                  ),
                  border: InputBorder.none,
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? RemixIcons.close_line : RemixIcons.search_line,
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          // Updated dice button tap handler
          IconButton(
            icon: Icon(
              RemixIcons.dice_line,
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
            ),
            onPressed: _openRandomManga,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              icon: Icon(
                RemixIcons.more_2_line,
                color: dark ? Colors.white : const Color(0xFF1C1B1F),
              ),
              onPressed: _showGridMenu,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: dark ? Colors.white : scheme.primary,
        backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
        onRefresh: _refresh,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SourceIcon(
                          name: widget.sourceName,
                          iconUrl:
                              getSourceByName(widget.sourceName).iconUrl,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.sourceName,
                          style: TextStyle(
                            color: dark ? Colors.white : scheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openFilterSheet,
                          child: Row(
                            children: [
                              Icon(
                                RemixIcons.filter_line,
                                color: dark
                                    ? Colors.white70
                                    : const Color(0xFF49454F),
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sortLabel(AppLocalizations.of(context)),
                                style: TextStyle(
                                  color: dark ? Colors.white : scheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (ref.watch(appearanceSettingsProvider).showQuickFilters &&
                  _tags.isNotEmpty)
                _buildFilterChips(),
              const SizedBox(height: 16),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: dark ? Colors.white70 : scheme.primary,
                    ),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          AppLocalizations.of(context).failedToLoadManga,
                          style: TextStyle(
                            color: dark
                                ? Colors.white70
                                : const Color(0xFF49454F),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: dark ? Colors.white38 : Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _loadManga,
                          icon: const Icon(RemixIcons.refresh_line),
                          label: Text(AppLocalizations.of(context).retry),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: dark
                                ? Colors.white
                                : scheme.onSurface,
                            side: BorderSide(
                              color: dark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildMangaGrid(displayedManga),
              if (_isLoadingMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: dark ? Colors.white54 : scheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGridMenu() async {
    final l = _l;
    final source = getSourceByName(widget.sourceName);
    await showIosMenuPanel<void>(
      context,
      children: [
        IosMenuRow(
          icon: RemixIcons.filter_line,
          label: l.sourceFilter,
          onTap: () {
            Navigator.pop(context);
            _openFilterSheet();
          },
        ),
        IosMenuRow(
          icon: RemixIcons.list_unordered,
          label: l.sourceListOptions,
          onTap: () {
            Navigator.pop(context);
            _showListOptionsSheet();
          },
        ),
        IosMenuRow(
          icon: RemixIcons.settings_3_line,
          label: l.settings,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SourceSettingsScreen(
                  sourceId: source.id,
                  sourceName: widget.sourceName,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showListOptionsSheet() {
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
                    _l.sourceListMode,
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
                        _buildSegmentTab('List', RemixIcons.list_view, setSheetState),
                        const SizedBox(width: 8),
                        _buildSegmentTab('Grid', RemixIcons.grid_line, setSheetState),
                      ],
                    ),
                  ),
                  if (_listMode == 'Grid') ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _l.sourceGridSize,
                          style: TextStyle(
                            color:
                                dark ? Colors.white70 : const Color(0xFF49454F),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _l.sourceGridSizeColumns(_gridSize.toInt()),
                          style: TextStyle(
                            color: dark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: 7 - _gridSize,
                      min: 1,
                      max: 6,
                      divisions: 5,
                      activeColor: dark
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      inactiveColor: dark ? Colors.white12 : Colors.black12,
                      onChanged: (value) {
                        final actualColumns = 7 - value;
                        setSheetState(() => _gridSize = actualColumns);
                        setState(() {});
                        _saveLayoutPref('manga_grid_grid_size', actualColumns);
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
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
          setSheetState(() => _listMode = mode);
          setState(() {});
          _saveLayoutPref('manga_grid_list_mode', mode);
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
                mode == 'Grid' ? _l.listModeGrid : _l.listModeList,
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

  Widget _buildFilterChips() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tags.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                final tag = _tags[index];
                _applyTag(isSelected ? null : tag);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : (dark ? Colors.white38 : Colors.black38),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _tags[index],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : (dark
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMangaGrid(List<Manga> items) {
    if (items.isEmpty) {
      return EmptyState(
        icon: RemixIcons.book_open_line,
        title: AppLocalizations.of(context).noMangaFound,
        subtitle: AppLocalizations.of(context).tryDifferentSearch,
      );
    }

    if (_listMode == 'List') {
      return Column(
        children: [for (final item in items) _buildMangaListRow(context, item)],
      );
    }

    final columns = _gridSize.round().clamp(2, 5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: mangaCellAspectRatio(context, columns: columns),
          crossAxisSpacing: kMangaGridCrossSpacing,
          mainAxisSpacing: kMangaGridRowSpacing,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildMangaCard(context, item);
        },
      ),
    );
  }

  Widget _buildMangaListRow(BuildContext context, Manga item) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MangaDetailScreen(
              mangaId: item.id,
              title: item.title,
              imageUrl: item.coverUrl,
              sourceId: item.sourceId,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 52,
                height: 76,
                child: CachedMangaImage(
                  imageUrl: item.coverUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: dark ? const Color(0xFF2C2C2E) : Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(
                      RemixIcons.book_open_line,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              RemixIcons.arrow_right_s_line,
              size: 20,
              color: dark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMangaCard(BuildContext context, Manga item) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MangaDetailScreen(
              mangaId: item.id,
              title: item.title,
              imageUrl: item.coverUrl,
              sourceId: item.sourceId,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: dark
                      ? CachedMangaImage(
                          imageUrl: item.coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF2C2C2E),
                            alignment: Alignment.center,
                            child: const Icon(
                              RemixIcons.book_open_line,
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
                            imageUrl: item.coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const Icon(
                                RemixIcons.book_open_line,
                                color: Colors.black38,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                ),
                DownloadedMangaBadge(mangaId: item.id),
                            FavoriteBadge(mangaId: item.id),
              ],
            ),
          ),
          const SizedBox(height: kMangaCardTitleGap),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: dark
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
