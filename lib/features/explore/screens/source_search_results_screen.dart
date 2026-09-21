import 'dart:convert';
import 'dart:math';
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/hide_on_scroll.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/providers/incognito_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

class SourceSearchResultsScreen extends StatefulWidget {
  final MangaSource source;
  final String query;
  final String? genre;

  const SourceSearchResultsScreen({
    super.key,
    required this.source,
    required this.query,
    this.genre,
  });

  @override
  State<SourceSearchResultsScreen> createState() =>
      _SourceSearchResultsScreenState();
}

class _SourceSearchResultsScreenState extends State<SourceSearchResultsScreen> {
  static const int _pageSize = 20;

  late final MangaSource _source = widget.source;
  String _filterQuery = '';
  List<String> _genres = [];
  String? _selectedGenre;
  bool _genrePrefixSelected = false;

  final List<Manga> _mangaList = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _searchHistory = [];
  bool _showHistory = false;
  int _page = 1;
  bool _hasMore = false;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _filterQuery = widget.query;
    _selectedGenre = widget.genre;
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onFocusChange);
    _loadSearchHistory();
    _loadGenres();
    _runSearch();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _showHistory =
          _searchFocusNode.hasFocus && _searchController.text.isEmpty;
    });
  }

  String get _historyKey => 'source_search_history_${_source.id}';

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_historyKey);
    if (saved != null && mounted) {
      setState(() => _searchHistory = List<String>.from(jsonDecode(saved)));
    }
  }

  Future<void> _saveToHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    if (incognitoActive) return;
    setState(() {
      _searchHistory.remove(trimmed);
      _searchHistory.insert(0, trimmed);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_searchHistory));
  }

  Future<void> _removeFromHistory(String query) async {
    setState(() => _searchHistory.remove(query));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_searchHistory));
  }

  Future<void> _clearSearchHistory() async {
    setState(() => _searchHistory.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<void> _loadGenres() async {
    final tags = await SourceCache.tags(
      sourceId: _source.id,
      fetch: _source.getAvailableTags,
    );
    if (mounted) {
      setState(() => _genres = tags);
    }
  }

  Future<List<Manga>> _fetchPage(int page, {bool forceRefresh = false}) async {
    if (_selectedGenre != null) {
      return SourceCache.mangaList(
        sourceId: _source.id,
        kind: 'tags',
        arg: _selectedGenre!.toLowerCase(),
        page: page,
        forceRefresh: forceRefresh,
        fetch: () => _source.searchMangaByTags([_selectedGenre!], page: page),
      );
    }
    if (_filterQuery.isNotEmpty) {
      return SourceCache.mangaList(
        sourceId: _source.id,
        kind: 'title',
        arg: _filterQuery.toLowerCase(),
        page: page,
        forceRefresh: forceRefresh,
        fetch: () => _source.searchByTitle(_filterQuery, page: page),
      );
    }
    return SourceCache.mangaList(
      sourceId: _source.id,
      kind: 'popular',
      page: page,
      forceRefresh: forceRefresh,
      fetch: () => _source.getPopularManga(page: page),
    );
  }

  Future<void> _refresh() async {
    final kind = _selectedGenre != null
        ? 'tags'
        : (_filterQuery.isNotEmpty ? 'title' : 'popular');
    SourceCache.invalidatePrefix('${_source.id}/list/$kind/');
    await _loadGenres();
    await _runSearch(forceRefresh: true);
  }

  /// Bounds a single-page fetch so a hanging source can't stall the screen.
  Future<List<Manga>> _bounded(Future<List<Manga>> future) =>
      future.timeout(const Duration(seconds: 10), onTimeout: () => const []);

  Future<void> _runSearch({bool forceRefresh = false}) async {
    setState(() {
      _page = 1;
      _mangaList.clear();
      _hasMore = false;
      _isInitialLoading = true;
      _isLoadingMore = false;
      _error = null;
    });

    try {
      final results = await _bounded(
        _fetchPage(_page, forceRefresh: forceRefresh),
      );
      if (!mounted) return;
      setState(() {
        _mangaList.addAll(results);
        _hasMore = results.length >= _pageSize;
        _isInitialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isInitialLoading || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final results = await _bounded(_fetchPage(nextPage));
      if (!mounted) return;

      final existingIds = _mangaList.map((m) => m.id).toSet();
      final fresh = results.where((m) => !existingIds.contains(m.id)).toList();

      setState(() {
        _page = nextPage;
        if (fresh.isEmpty) {
          // Nothing new: the source has no further pages (e.g. Manganato's
          // single-page search). Stop paginating to avoid infinite duplicates.
          _hasMore = false;
        } else {
          _mangaList.addAll(fresh);
          _hasMore = results.length >= _pageSize;
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _clearSearchQuery() {
    setState(() {
      _filterQuery = '';
      _showHistory = false;
    });
    _runSearch();
  }

  void _selectGenre(String? genre) {
    setState(() => _selectedGenre = genre);
    _runSearch();
  }

  void _openManga(Manga manga) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDetailScreen(
          mangaId: manga.id,
          title: manga.title,
          imageUrl: manga.coverUrl,
          sourceId: manga.sourceId,
        ),
      ),
    );
  }

  void _openRandomManga() {
    if (_mangaList.isEmpty) return;
    final random = Random();
    final randomManga = _mangaList[random.nextInt(_mangaList.length)];
    _openManga(randomManga);
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _filterQuery = query;
      _showHistory = false;
    });
    _saveToHistory(query);
    _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            RemixIcons.arrow_left_line,
            color: dark ? Colors.white : const Color(0xFF1C1B1F),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.source.name,
          style: TextStyle(
            color: dark ? Colors.white : const Color(0xFF1C1B1F),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).randomMangaTooltip,
            icon: Icon(
              RemixIcons.dice_line,
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
            ),
            onPressed: _openRandomManga,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IosMenuButton<String>(
              items: [
                IosMenuItem(
                  value: 'refresh',
                  label: AppLocalizations.of(context).refreshResults,
                  icon: RemixIcons.refresh_line,
                ),
                IosMenuItem(
                  value: 'clear_query',
                  label: AppLocalizations.of(context).clearSearchQuery,
                  icon: RemixIcons.close_line,
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'refresh':
                    _refresh();
                  case 'clear_query':
                    _clearSearchQuery();
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: HideOnScroll(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(dark),
              if (_showHistory && _searchHistory.isNotEmpty)
                _buildRecentSearches(dark),
            ],
          ),
          body: _buildResults(),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F5),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              RemixIcons.search_line,
              size: 18,
              color: dark ? Colors.white54 : Colors.black38,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(
                  color: dark ? Colors.white : const Color(0xFF1C1B1F),
                  fontSize: 15,
                ),
                cursorColor: dark ? Colors.white : const Color(0xFF1C1B1F),
                textInputAction: TextInputAction.search,
                onSubmitted: _submitSearch,
                onChanged: (value) {
                  setState(() {
                    _showHistory = _searchFocusNode.hasFocus && value.isEmpty;
                  });
                },
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchThisSource,
                  hintStyle: TextStyle(
                    color: dark ? Colors.white38 : Colors.black38,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(bottom: 2),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(
                  RemixIcons.close_line,
                  size: 18,
                  color: dark ? Colors.white54 : Colors.black38,
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _showHistory = _searchFocusNode.hasFocus);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearches(bool dark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent',
                style: TextStyle(
                  color: dark ? Colors.white70 : Colors.black45,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: _clearSearchHistory,
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    color: dark ? Colors.white54 : Colors.black38,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searchHistory.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final query = _searchHistory[index];
              return Dismissible(
                key: ValueKey(query),
                onDismissed: (_) => _removeFromHistory(query),
                child: GestureDetector(
                  onTap: () {
                    _searchController.text = query;
                    _submitSearch(query);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          RemixIcons.history_line,
                          size: 14,
                          color:
                              dark ? Colors.white54 : Colors.black38,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          query,
                          style: TextStyle(
                            color: dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildFilterChips() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chips = <Widget>[];

    // Active search query chip (tap X to clear).
    if (_filterQuery.isNotEmpty) {
      final query = _filterQuery;
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: _clearSearchQuery,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFEBEFEF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dark ? Colors.white38 : Colors.black12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    RemixIcons.search_line,
                    size: 16,
                    color: dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dark
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    RemixIcons.close_line,
                    size: 16,
                    color: dark ? Colors.white70 : const Color(0xFF49454F),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 'Genres' prefix chip.
    chips.add(
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () {
            setState(() => _genrePrefixSelected = !_genrePrefixSelected);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _genrePrefixSelected
                  ? (dark
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary)
                  : (dark ? Colors.transparent : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
              border: dark
                  ? Border.all(
                      color: _genrePrefixSelected
                          ? Colors.white
                          : Colors.white38,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  RemixIcons.equalizer_line,
                  size: 16,
                  color: _genrePrefixSelected
                      ? (dark ? Colors.black : Colors.white)
                      : (dark ? Colors.white : const Color(0xFF334155)),
                ),
                const SizedBox(width: 6),
                Text(
                  'Genres',
                  style: TextStyle(
                    color: _genrePrefixSelected
                        ? (dark ? Colors.black : Colors.white)
                        : (dark ? Colors.white : const Color(0xFF334155)),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Genre tag chips.
    for (final genre in _genres) {
      final isSelected = _selectedGenre == genre;
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => _selectGenre(isSelected ? null : genre),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary)
                    : (dark ? Colors.transparent : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
                border: dark
                    ? Border.all(
                        color: isSelected ? Colors.white : Colors.white38,
                      )
                    : null,
              ),
              child: Text(
                genre,
                style: TextStyle(
                  color: isSelected
                      ? (dark ? Colors.black : Colors.white)
                      : (dark ? Colors.white : const Color(0xFF334155)),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips,
      ),
    );
  }

  Widget _buildResults() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_isInitialLoading && _mangaList.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: dark ? Colors.white70 : const Color(0xFF49454F),
        ),
      );
    }

    if (_error != null && _mangaList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Failed to load results',
              style: TextStyle(
                color: dark ? Colors.white70 : const Color(0xFF49454F),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _runSearch,
              icon: const Icon(RemixIcons.refresh_line),
              label: Text(AppLocalizations.of(context).retry),
              style: OutlinedButton.styleFrom(
                foregroundColor: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                side: dark
                    ? const BorderSide(color: Colors.white38)
                    : const BorderSide(color: Colors.black38),
              ),
            ),
          ],
        ),
      );
    }

    if (_mangaList.isEmpty) {
      return EmptyState(
        icon: RemixIcons.search_2_line,
        title: AppLocalizations.of(context).noMangaFound,
        subtitle: AppLocalizations.of(context).tryDifferentSearch,
      );
    }

    return RefreshIndicator(
      color: dark ? Colors.white : Theme.of(context).colorScheme.onSurface,
      backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildFilterChips()),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: mangaCellAspectRatio(context, columns: 3),
                crossAxisSpacing: kMangaGridCrossSpacing,
                mainAxisSpacing: kMangaGridRowSpacing,
              ),
              itemCount: _mangaList.length,
              itemBuilder: (context, index) {
                final manga = _mangaList[index];
                return _buildCard(context, manga);
              },
            ),
          ),
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Manga item) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _openManga(item),
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
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: dark ? null : Border.all(color: Colors.black12),
                    ),
                    child: CachedMangaImage(
                      imageUrl: item.coverUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: dark ? const Color(0xFF2C2C2E) : Colors.black12,
                        child: Icon(
                          RemixIcons.book_open_line,
                          color: dark ? Colors.white38 : Colors.black38,
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
