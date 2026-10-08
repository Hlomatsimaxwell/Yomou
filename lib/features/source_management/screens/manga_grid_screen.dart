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
import 'package:url_launcher/url_launcher.dart';

import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/data/sources/captcha_gate.dart';
import 'package:yomou/data/sources/source_network.dart';
import 'package:yomou/features/source_management/screens/captcha_solver_screen.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_filter.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/features/settings/providers/grid_density_provider.dart';
import 'package:yomou/features/source_management/screens/manga_filter_sheet.dart';
import 'package:yomou/features/source_management/widgets/manga_preview_pane.dart';
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

  /// Whether the filter pane is showing beside the catalogue.
  ///
  /// Only ever false on a wide layout -- on a phone the filter is a fullscreen
  /// sheet and there is nothing to collapse back to, so a collapsed pane
  /// cannot be the resting state. The header's filter row toggles it, which is
  /// what keeps that control live: with a permanent pane there is no sheet to
  /// open, so tapping it has to mean something else or it would be decoration.
  bool _filterPaneOpen = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  List<Manga> _mangaList = [];
  bool _isLoading = true;
  String? _error;

  /// Set when the source answered with a captcha challenge instead of content.
  CaptchaRequiredException? _captcha;

  // Grid layout preferences (mirrors history/suggestions list options).
  String _listMode = 'Grid';

  /// The density the reader chose, from the one preference all manga grids
  /// share. Null means auto: derive the count from the width.
  ///
  /// Assigned at the top of [build] rather than watched in place because the
  /// grid resolves its columns inside a [LayoutBuilder], which runs during
  /// layout -- after build -- where watching a provider is not allowed.
  int? _gridSize;

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
    if (!mounted) return;
    setState(() {
      _listMode = mode;
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
      final filter = MangaFilter.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
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
    // A wide layout has the filter as a pane already, so the header's filter
    // row shows and hides that pane rather than pushing a route over the top
    // of it.
    //
    // The preview counts as covering the filter, so tapping this while a
    // preview is up brings the filter forward instead of hiding the pane --
    // the preview is not what the user asked to dismiss, and closing the pane
    // would have taken it anyway. Only a visible filter is one tap to hide.
    if (usesWideLayout(context)) {
      setState(
        () => _filterPaneOpen =
            !_filterPaneOpen || _previewManga != null,
      );
      return;
    }
    final source = getSourceByName(widget.sourceName);
    final result = await showMangaFilterSheet(
      context,
      initial: _filter,
      tags: _tags,
      presetsKey: 'source_presets_${source.id}',
      onSave: _saveFilter,
    );
    if (result == null) return;
    _applyFilter(result);
  }

  /// Adopts a new filter and refetches.
  ///
  /// Shared by the sheet's return value and the pane's apply button: the pane
  /// has no route to return through, so it hands the filter over directly and
  /// this is what turns it into a reload. Clearing the tag chip selection
  /// matters here -- the two filter the same list by different means, and
  /// leaving a client-side tag active on top of a freshly applied source-side
  /// filter would silently intersect them.
  void _applyFilter(MangaFilter filter) {
    setState(() {
      _filter = filter;
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
      _captcha = null;
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
        arg: usingFilter ? filter.cacheKey : (tag ?? ''),
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
    } on CaptchaRequiredException catch (e) {
      setState(() {
        _captcha = e;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Opens the solver, then retries the request with the earned cookie.
  Future<void> _solveCaptcha() async {
    final captcha = _captcha;
    if (captcha == null) return;
    final source = getSourceByName(widget.sourceName);

    // Sources that share one site share one network profile, so the cookie has
    // to be stored under the key the HTTP client actually reads - not the
    // source's own id, or the solve is saved where nothing will look for it.
    final networkId = source is DioSource
        ? (source as DioSource).networkSourceId
        : source.id;

    // The clearance cookie is bound to the user agent, so the browser has to
    // present the same one the HTTP client uses.
    final config = await SourceNetworkConfig.forSource(networkId);
    final userAgent =
        config.userAgent ??
        source.headers?['User-Agent'] ??
        DioSource.defaultUserAgent;

    if (!mounted) return;
    final solved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CaptchaSolverScreen(
          sourceId: networkId,
          url: captcha.challengeUrl,
          userAgent: userAgent,
        ),
      ),
    );
    if (solved == true) {
      await _loadManga(forceRefresh: true);
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
        arg: usingFilter ? filter.cacheKey : (tag ?? ''),
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

    // A dice roll is a decision to leave the grid, not a browse, so it opens
    // the screen outright even where a cover tap would only preview.
    _openDetail(randomManga);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _gridSize = ref.watch(gridDensityProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

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
      body: _buildBody(context, dark, scheme),
    );
  }

  /// The catalogue, with the side pane when there is one to show.
  ///
  /// The pane is a single slot holding whichever of the two is live: the filter
  /// normally, or a manga's preview once a cover is tapped. It stays on screen
  /// after the filter is closed if a preview is showing, and disappears only
  /// when neither is -- collapsing the filter while a preview is up would take
  /// the preview with it, which is not what closing the filter asks for.
  Widget _buildBody(BuildContext context, bool dark, ColorScheme scheme) {
    final catalogue = _buildCatalogueScroll(context, dark, scheme);
    if (!usesWideLayout(context)) return catalogue;
    final showPane = _filterPaneOpen || _previewManga != null;
    if (!showPane) return catalogue;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: catalogue),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: dark ? Colors.white12 : Colors.black12,
        ),
        _buildFilterPane(context, dark),
      ],
    );
  }

  /// The catalogue column: source header, quick filters, and the grid or list.
  ///
  /// Its own scroll view either way. On a wide layout it is one pane of two
  /// and must not inherit the pane's scroll, or scrolling the filter would
  /// drag the catalogue with it.
  Widget _buildCatalogueScroll(
    BuildContext context,
    bool dark,
    ColorScheme scheme,
  ) {
    final displayedManga = _mangaList.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return RefreshIndicator(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SourceIcon(
                        name: widget.sourceName,
                        iconUrl: getSourceByName(widget.sourceName).iconUrl,
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
              else if (_captcha != null)
                _CaptchaRequiredView(
                  onSolve: _solveCaptcha,
                  onOpenInBrowser: () {
                    final uri = Uri.tryParse(_captcha!.challengeUrl);
                    if (uri != null) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
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
    );
  }

  /// The filter as a permanent pane beside the catalogue.
  ///
  /// Same controls as the sheet; see [MangaFilterSheet] on why the apply path
  /// differs. Fixed width rather than a flex share: the filter's sections are
  /// rows of genre pills, and a pane that flexes would either wrap them into a
  /// ragged ladder on a very wide window or start clipping them on a merely
  /// tablet-sized one.
  Widget _buildFilterPane(BuildContext context, bool dark) {
    final source = getSourceByName(widget.sourceName);
    final preview = _previewManga;
    return SizedBox(
      width: 340,
      // A preview slides in over the filter rather than replacing it, so
      // closing the preview reveals the filter still as the user left it --
      // half-made genre selections and all. Rebuilding the filter from
      // [_filter] instead would silently discard whatever was typed but not
      // yet applied.
      //
      // The filter is only mounted while it is actually open, so a pane left
      // showing just a preview does not keep a whole second scroll view alive
      // behind it.
      child: Stack(
        children: [
          if (_filterPaneOpen)
            Positioned.fill(
              child: MangaFilterSheet(
                initial: _filter,
                tags: _tags,
                presetsKey: 'source_presets_${source.id}',
                onSave: _saveFilter,
                inline: true,
                onApplied: _applyFilter,
                onClose: () => setState(() => _filterPaneOpen = false),
              ),
            ),
          if (preview != null)
            Positioned.fill(
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: MangaPreviewPane(
                  manga: preview,
                  onRead: () => _openDetail(preview, autoStartReader: true),
                  onOpenFull: () => _openDetail(preview),
                  onClose: () => setState(() => _previewManga = null),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The manga whose preview is showing, or null when the filter is on top.
  Manga? _previewManga;

  /// Tapping a cover.
  ///
  /// A wide layout previews it in the pane instead of leaving the grid, which
  /// is the point of the pane: browsing stays where it was, so a cover that
  /// turns out not to be interesting costs a tap rather than a trip back
  /// through the stack. Anywhere narrower there is no room for a pane beside
  /// the grid, so the cover opens the screen directly as it always has.
  void _onMangaTap(Manga item) {
    if (usesWideLayout(context)) {
      _selectPreview(item);
      return;
    }
    _openDetail(item);
  }

  void _selectPreview(Manga manga) {
    if (_previewManga?.id == manga.id) return;
    setState(() => _previewManga = manga);
  }

  /// Open the full detail screen, optionally starting the reader on arrival.
  Future<void> _openDetail(Manga manga, {bool autoStartReader = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDetailScreen(
          mangaId: manga.id,
          title: manga.title,
          imageUrl: manga.coverUrl,
          sourceId: manga.sourceId,
          autoStartReader: autoStartReader,
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
                        _buildSegmentTab(
                          'List',
                          RemixIcons.list_view,
                          setSheetState,
                        ),
                        const SizedBox(width: 8),
                        _buildSegmentTab(
                          'Grid',
                          RemixIcons.grid_line,
                          setSheetState,
                        ),
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
                            color: dark
                                ? Colors.white70
                                : const Color(0xFF49454F),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _l.sourceGridSizeColumns(
                            _gridSize ?? mangaGridColumns(context),
                          ),
                          style: TextStyle(
                            color: dark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      // The same track every other manga grid uses. This one
                      // had its own 2..5 range and its own `7 - value`
                      // arithmetic, so a reader who set a density here got a
                      // different number than the same slider gave elsewhere,
                      // and the ends of neither agreed with what the grid drew.
                      value: mangaGridSliderPositionForColumns(
                        // The label can read past the track: with no stored
                        // choice the width decides, and a wide window decides
                        // more than six.
                        (_gridSize ?? mangaGridColumns(context))
                            .clamp(
                              kMangaGridSliderMinColumns,
                              kMangaGridSliderMaxColumns,
                            )
                            .toDouble(),
                      ),
                      min: kMangaGridSliderMinColumns.toDouble(),
                      max: kMangaGridSliderMaxColumns.toDouble(),
                      divisions:
                          kMangaGridSliderMaxColumns -
                          kMangaGridSliderMinColumns,
                      activeColor: dark
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      inactiveColor: dark ? Colors.white12 : Colors.black12,
                      onChanged: (value) {
                        final actualColumns =
                            mangaGridColumnsForSliderPosition(value);
                        setSheetState(() => _gridSize = actualColumns);
                        setState(() {});
                        // One density for every manga grid, so a choice made
                        // for a source catalogue also holds on History and
                        // Favourites.
                        ref
                            .read(gridDensityProvider.notifier)
                            .setColumns(actualColumns);
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

    // On auto this resolves the same count as every other manga grid, because
    // the ceiling lives in [mangaGridColumns] rather than at each call site. It
    // used to be clamped to 5 here and nowhere else, which made this the one
    // screen where a wide window's eight columns were thrown away: a source
    // catalogue showed five oversized covers beside eight compact ones on
    // History. When the reader has chosen a density, that choice is used as-is.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Measured from the constraints rather than the viewport: on a wide
      // layout this grid shares the row with the filter pane, so the viewport
      // is 340px wider than the grid actually is. Deriving columns from the
      // viewport there would size eight cells into space that holds six and a
      // half, and every cover would come out narrower than intended.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = mangaGridColumnsFor(
            context,
            userColumns: _gridSize,
            availableWidth: width,
          );
          final fontSize = mangaCardTitleFontSize(columns);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: mangaCellAspectRatio(
                context,
                columns: columns,
                titleFontSize: fontSize,
                availableWidth: width,
                // No padding to subtract: [width] already had this Padding's own
                // 16 taken off it by the LayoutBuilder above, and the default of
                // 16 subtracted a second set. The cell came out measured from 32px
                // narrower than the cell it was then given, so every cover here
                // was sized for a narrower column than the one it painted into
                // and the title's second line sat that much closer to the edge.
                horizontalPadding: 0,
              ),
              crossAxisSpacing: kMangaGridCrossSpacing,
              mainAxisSpacing: kMangaGridRowSpacing,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildMangaCard(context, item, fontSize);
            },
          );
        },
      ),
    );
  }

  Widget _buildMangaListRow(BuildContext context, Manga item) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _onMangaTap(item),
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

  Widget _buildMangaCard(BuildContext context, Manga item, double titleFontSize) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _onMangaTap(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Flexible(
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                // The size the cell was measured at, not a fixed 12: a cell
                // sized for a 10pt title and drawn with a 12pt one clips the
                // second line of every title long enough to need one.
                fontSize: titleFontSize,
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

/// "This source requires solving a captcha" placeholder with a Solve button.
class _CaptchaRequiredView extends StatelessWidget {
  const _CaptchaRequiredView({
    required this.onSolve,
    required this.onOpenInBrowser,
  });

  final VoidCallback onSolve;
  final VoidCallback onOpenInBrowser;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 72,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                l10n.captchaRequiredTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onSolve,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(l10n.captchaSolve),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onOpenInBrowser,
              child: Text(l10n.openInBrowser),
            ),
          ],
        ),
      ),
    );
  }
}
