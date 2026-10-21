import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/theme/amoled.dart';
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:yomou/widgets/manga_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/data/models/manga_source.dart';
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
import 'package:yomou/data/providers/source_usage_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
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

  /// When the grid is showing the results of a live title search rather than
  /// the plain popular/tag/filter listing. While true the local title-substring
  /// filter is skipped so remote results are shown verbatim.
  bool _searchMode = false;

  /// Debounces live title search: a pause in typing refetches from the source.
  Timer? _searchDebounce;

  List<Manga> _mangaList = [];
  bool _isLoading = true;
  String? _error;

  /// Set when the source answered with a captcha challenge instead of content.
  CaptchaRequiredException? _captcha;

  // Grid layout preferences (mirrors history/suggestions list options).
  String _listMode = 'Grid';

  /// The cover size the reader chose, as a percentage of a normal cell, from
  /// the one preference every manga grid shares. 100 is the design size.
  ///
  /// Assigned at the top of [build] rather than watched in place because the
  /// grid resolves its columns inside a [LayoutBuilder], which runs during
  /// layout -- after build -- where watching a provider is not allowed.
  double _gridSize = kMangaGridSizeDefault;

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
    // Opening a source's catalogue is what "using" a source means, so this is
    // where the Last used order gets its timestamp.
    ref.read(sourceLastUsedProvider.notifier).markUsed(widget.sourceName);
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
    // A filter is "browsing", not searching: drop any live query first so the
    // two don't silently intersect (the search has priority in _loadSpec).
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _filter = filter;
      _activeTag = null;
      _selectedFilterIndex = -1;
      _searchQuery = '';
      _searchMode = false;
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
    // The query this outgoing request answers, captured now: a live search can
    // race ahead while it is in flight, and a stale response must not clobber
    // the results for the query the field currently holds.
    final queryAtLoad = _searchQuery.trim();
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
      final spec = _loadSpec(source, 1);
      final searching = queryAtLoad.isNotEmpty;
      final manga = await SourceCache.mangaList(
        sourceId: source.id,
        kind: spec.kind,
        arg: spec.arg,
        page: 1,
        forceRefresh: forceRefresh,
        fetch: spec.fetch,
      );
      if (!mounted) return;
      if (queryAtLoad != _searchQuery.trim()) return;
      setState(() {
        _mangaList = manga;
        _isLoading = false;
        _searchMode = searching;
        _seenIds
          ..clear()
          ..addAll(manga.map((m) => m.id));
      });
    } on CaptchaRequiredException catch (e) {
      if (!mounted || queryAtLoad != _searchQuery.trim()) return;
      setState(() {
        _captcha = e;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || queryAtLoad != _searchQuery.trim()) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Which listing the grid is showing and how to fetch a given page of it.
  ///
  /// An active title search takes precedence; otherwise the tag and the filter
  /// beat the plain popular listing. Kept in one place so the initial load and
  /// the "load more" pagination can never disagree about what to fetch next.
  ({String kind, String arg, Future<List<Manga>> Function() fetch}) _loadSpec(
    MangaSource source,
    int page,
  ) {
    final tag = _activeTag;
    final filter = _filter;
    final query = _searchQuery.trim();
    final searching = query.isNotEmpty;
    final usingFilter = !searching && tag == null && !filter.isDefault;
    final kind = searching
        ? 'search'
        : usingFilter
        ? 'filter'
        : (tag != null ? 'tag' : 'popular');
    final arg =
        searching ? query : (usingFilter ? filter.cacheKey : (tag ?? ''));
    final fetch = searching
        ? () => source.searchByTitle(query, page: page)
        : tag != null
        ? () => source.searchMangaByTags([tag], page: page)
        : usingFilter
        ? () => source.searchWithFilter(filter, page: page)
        : () => source.getPopularManga(page: page);
    return (kind: kind, arg: arg, fetch: fetch);
  }

  /// Live title search as the user types: keep the instant local filter over
  /// whatever is loaded, then once they pause, ask the source for real results.
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      // Field emptied — back to the plain popular/tag/filter listing.
      _loadManga();
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _loadManga(),
    );
  }

  /// The keyboard's search action fires a remote search immediately.
  void _submitRemoteSearch() {
    _searchDebounce?.cancel();
    if (_searchQuery.trim().isNotEmpty) _loadManga();
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
      final spec = _loadSpec(source, next);
      final queryAtLoad = _searchQuery.trim();
      final manga = await SourceCache.mangaList(
        sourceId: source.id,
        kind: spec.kind,
        arg: spec.arg,
        page: next,
        fetch: spec.fetch,
      );
      if (!mounted) return;
      if (queryAtLoad != _searchQuery.trim()) {
        // The grid moved on (new query / tag / filter) while this page was in
        // flight; don't append it to the wrong listing.
        setState(() => _isLoadingMore = false);
        return;
      }
      // Sources occasionally repeat titles across pages; keep the grid clean.
      final fresh = <Manga>[];
      for (final m in manga) {
        if (_seenIds.add(m.id)) fresh.add(m);
      }
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
    // Picking a tag chip is "browsing", not searching: drop any live query so
    // the tag listing isn't hidden behind the search's priority in _loadSpec.
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _activeTag = tag;
      _selectedFilterIndex = tag == null ? -1 : _tags.indexOf(tag);
      _searchQuery = '';
      _searchMode = false;
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
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _gridSize = ref.watch(appearanceSettingsProvider).gridSize;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            MdiIcons.arrowLeft,
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
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _submitRemoteSearch(),
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
              _isSearching ? MdiIcons.close : MdiIcons.magnify,
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
            ),
            onPressed: () {
              _searchDebounce?.cancel();
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
                _isSearching = !_isSearching;
              });
              // Closing the field puts the regular listing back — the grid may
              // currently be showing remote search results.
              if (!_isSearching) _loadManga();
            },
          ),
          // Updated dice button tap handler
          IconButton(
            icon: Icon(
              Icons.casino_outlined,
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
            ),
            onPressed: _openRandomManga,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              icon: Icon(
                MdiIcons.dotsVertical,
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
    // The pane floats beside the catalogue as a rounded card rather than
    // sitting in a full-height column of its own. That is the reference's own
    // shape -- its side pane is a Material card inset by the same margins on
    // three sides -- and it is what lets the grid keep the width a divider and
    // a flush edge would have taken, at no cost to the pane: the corners read
    // as a card because of the margin around them, not because of anything the
    // pane does itself.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: catalogue),
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
    final displayedManga = _searchMode
        ? _mangaList
        : _mangaList.where((item) {
            if (_searchQuery.isEmpty) return true;
            return item.title.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

    return RefreshIndicator(
      color: dark ? Colors.white : scheme.primary,
      backgroundColor: dark ? amoled(context, 0xFF2C2C2E) : Colors.white,
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
                              MdiIcons.filterOutline,
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
                          icon: const Icon(MdiIcons.refresh),
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
  /// differs.
  ///
  /// Sized the way the reference sizes its side pane: a share of the window
  /// rather than a fixed number, held between the two ends of its own range. A
  /// fixed width could only ever be right for one window -- 340 is a phone's
  /// pane and a rounding error beside an 8-column grid -- while the share is
  /// what keeps the pane and the catalogue in proportion as the window grows.
  ///
  /// The clamps are the part a bare percentage gets wrong. Below 800 wide a
  /// uniform 40% would fall under the 320 the filter's genre pills need to sit
  /// in two columns instead of a ladder of one; above 1500 it would run past
  /// 600, which is where a text column stops reading well and the extra width
  /// is better spent on covers. That is the reference's 320-600dp range, and
  /// its 0.4 share, in logical pixels.
  Widget _buildFilterPane(BuildContext context, bool dark) {
    final source = getSourceByName(widget.sourceName);
    final preview = _previewManga;
    final width =
        (MediaQuery.sizeOf(context).width * _kPaneWidthFraction).clamp(
      _kPaneWidthMin,
      _kPaneWidthMax,
    );
    return SizedBox(
      width: width,
      // A preview slides in over the filter rather than replacing it, so
      // closing the preview reveals the filter still as the user left it --
      // half-made genre selections and all. Rebuilding the filter from
      // [_filter] instead would silently discard whatever was typed but not
      // yet applied.
      //
      // The filter is only mounted while it is actually open, so a pane left
      // showing just a preview does not keep a whole second scroll view alive
      // behind it.
      child: Padding(
        // The reference's own insets: an equal margin on both sides and the
        // bottom, and the tighter grid spacing above, so the card's top edge
        // lines up with the first row of covers rather than sitting a grid
        // gap below it.
        padding: const EdgeInsets.fromLTRB(
          _kPaneGap,
          _kPaneGapTop,
          _kPaneGap,
          _kPaneGap,
        ),
        child: Card.outlined(
          // Zero because the padding above is the pane's whole margin. Left at
          // its default this adds a second 4 of its own and the card stops
          // lining up with the insets it was measured for.
          margin: EdgeInsets.zero,
          // The M3 card outline role, which is the one the reference's own
          // Material card draws its border in. Elevation is left off: the app
          // paints no shadows anywhere, and an outlined card is the shape that
          // does not need one.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kPaneCorner),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          // One clip for both occupants: whichever of them is showing, its own
          // scroll cannot paint over the card's rounded corners.
          clipBehavior: Clip.antiAlias,
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
                // No fill of its own: the card behind the preview is already
                // the surface, so painting the scaffold colour here would put a
                // square-cornered square back inside a rounded card.
                Positioned.fill(
                  child: MangaPreviewPane(
                    manga: preview,
                    onRead: () => _openDetail(preview, autoStartReader: true),
                    onOpenFull: () => _openDetail(preview),
                    onClose: () => setState(() => _previewManga = null),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The pane's width, as the reference sets it: a 0.4 share of the window,
  /// clamped to a 320-600 logical-pixel range.
  static const _kPaneWidthFraction = 0.4;
  static const _kPaneWidthMin = 320.0;
  static const _kPaneWidthMax = 600.0;

  /// The air around the pane card, matching the reference's side-pane margins
  /// and grid spacing.
  static const _kPaneGap = 8.0;
  static const _kPaneGapTop = 4.0;

  /// Its corner radius, off Material 3's own card shape.
  static const _kPaneCorner = 12.0;

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
          heroTag: mangaCoverHeroTag(
            sourceId: manga.sourceId,
            mangaId: manga.id,
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
          icon: MdiIcons.filterOutline,
          label: l.sourceFilter,
          onTap: () {
            Navigator.pop(context);
            _openFilterSheet();
          },
        ),
        IosMenuRow(
          icon: MdiIcons.formatListBulleted,
          label: l.sourceListOptions,
          onTap: () {
            Navigator.pop(context);
            _showListOptionsSheet();
          },
        ),
        IosMenuRow(
          icon: MdiIcons.cogOutline,
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
                          MdiIcons.viewListOutline,
                          setSheetState,
                        ),
                        const SizedBox(width: 8),
                        _buildSegmentTab(
                          'Grid',
                          MdiIcons.viewGridOutline,
                          setSheetState,
                        ),
                      ],
                    ),
                  ),
                  if (_listMode == 'Grid') ...[
                    const SizedBox(height: 24),
                    Text(
                      _l.appearanceGridSize(_gridSize.round()),
                      style: TextStyle(
                        color: dark ? Colors.white70 : const Color(0xFF49454F),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      // Left to right is small to large, which is what a size
                      // control reads as: dragging right grows every cover and
                      // the grid drops a column to make room. The old slider
                      // pointed the same way -- it counted columns backwards
                      // from the far end -- but kept its own 2..5 range, so the
                      // ends of this track never agreed with the four screens
                      // that share the setting.
                      value: _gridSize,
                      min: kMangaGridSizeMin.toDouble(),
                      max: kMangaGridSizeMax.toDouble(),
                      divisions: kMangaGridSizeDivisions,
                      onChanged: (value) {
                        setSheetState(() => _gridSize = value);
                        setState(() {});
                        // One size for every manga grid, so a choice made for
                        // a source catalogue also holds on History and
                        // Favourites.
                        ref
                            .read(appearanceSettingsProvider.notifier)
                            .setGridSize(value);
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
    final primary = Theme.of(context).colorScheme.primary;
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
                  color: isSelected
                      ? (dark ? Colors.white : primary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? (dark ? Colors.white : primary)
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
                            ? (dark ? Colors.black : Colors.white)
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
        icon: MdiIcons.bookOpenVariant,
        title: AppLocalizations.of(context).noMangaFound,
        subtitle: AppLocalizations.of(context).tryDifferentSearch,
      );
    }

    if (_listMode == 'List') {
      return Column(
        children: [for (final item in items) _buildMangaListRow(context, item)],
      );
    }

    // The same arithmetic as every other manga grid, because the rule lives in
    // [mangaGridColumns] rather than at each call site. It used to be clamped
    // to 5 here and nowhere else, which made this the one screen where a wide
    // window's eight columns were thrown away: a source catalogue showed five
    // oversized covers beside eight compact ones on History.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Measured from the constraints rather than the viewport: on a wide
      // layout this grid shares the row with the filter pane, so the viewport
      // is the pane's width wider than the grid actually is. Deriving columns
      // from the viewport there would size eight cells into space that holds
      // six and a half, and every cover would come out narrower than intended.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = mangaGridColumns(
            context,
            gridSize: _gridSize,
            availableWidth: width,
            // No padding to subtract, for the same reason the aspect ratio
            // below passes one: this LayoutBuilder is inside the Padding, so
            // [width] has already had its 16 off each side and the default
            // would take a second set out of it.
            horizontalPadding: 0,
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
            MangaCoverHero(
              tag: mangaCoverHeroTag(
                sourceId: item.sourceId,
                mangaId: item.id,
              ),
              child: ClipRRect(
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
                        MdiIcons.bookOpenVariant,
                        color: Colors.white38,
                        size: 20,
                      ),
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
              MdiIcons.chevronRight,
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
            aspectRatio: kMangaCoverAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MangaCoverHero(
                  tag: mangaCoverHeroTag(
                    sourceId: item.sourceId,
                    mangaId: item.id,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: dark
                        ? CachedMangaImage(
                            imageUrl: item.coverUrl,
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
                              imageUrl: item.coverUrl,
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
