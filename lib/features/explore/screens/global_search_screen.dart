import 'package:remixicon/remixicon.dart';
import 'dart:async';
import 'dart:convert';
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/explore/providers/search_provider.dart';
import 'package:yomou/features/explore/screens/global_search_results_screen.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/providers/incognito_provider.dart';
import 'package:yomou/features/suggestions/providers/suggestions_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  static const String _historyKey = 'user_search_history';

  String _currentQuery = '';
  String _debouncedQuery = '';
  Timer? _debounce;
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedHistory = prefs.getString(_historyKey);
    if (savedHistory != null) {
      final List<dynamic> decoded = jsonDecode(savedHistory);
      if (mounted) {
        setState(() {
          _searchHistory = decoded.cast<String>();
        });
      }
    }
  }

  Future<void> _addQueryToHistoryAndSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    if (!incognitoActive) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _searchHistory.remove(trimmed);
        _searchHistory.insert(0, trimmed);
      });
      await prefs.setString(_historyKey, jsonEncode(_searchHistory));
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlobalSearchResultsScreen(searchQuery: trimmed),
      ),
    );
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    setState(() {
      _searchHistory.clear();
    });
  }

  void _onQueryChanged(String value) {
    setState(() => _currentQuery = value);
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _debouncedQuery = '');
      return;
    }
    // Debounce live search as the user types.
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _debouncedQuery = query);
    });
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
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
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(
            color: dark ? Colors.white : const Color(0xFF1C1B1F),
            fontSize: 16,
          ),
          cursorColor: dark ? Colors.white : const Color(0xFF1C1B1F),
          textInputAction: TextInputAction.search,
          onChanged: _onQueryChanged,
          onSubmitted: (value) => _addQueryToHistoryAndSearch(value),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).searchHintAny,
            hintStyle: TextStyle(
              color: dark ? Colors.white54 : Colors.black54,
              fontSize: 15,
            ),
            border: InputBorder.none,
            suffixIcon: _currentQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      RemixIcons.close_line,
                      color: dark ? Colors.white70 : const Color(0xFF49454F),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onQueryChanged('');
                    },
                  )
                : null,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IosMenuButton<String>(
              items: [
                IosMenuItem(
                  value: 'clear_history',
                  label: AppLocalizations.of(context).clearSearchHistory,
                  icon: RemixIcons.delete_bin_6_line,
                ),
              ],
              onSelected: (value) {
                if (value == 'clear_history') {
                  _clearSearchHistory();
                }
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: dark ? Colors.white24 : Colors.black26, height: 1),
            const SizedBox(height: 12),
            _currentQuery.isEmpty
                ? _buildInitialView()
                : _buildTypingSuggestionsView(),
          ],
        ),
      ),
    );
  }

  // Displayed before the user starts typing.
  Widget _buildInitialView() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final genreTagsAsync = ref.watch(genreTagsProvider);
    final trendingAsync = ref.watch(trendingMangaProvider);
    final suggestions = ref.watch(appearanceSettingsProvider).searchSuggestions;

    // "Trending" and "Popular" share the same popular-manga data; honoring
    // either toggle keeps the row visible.
    final showTrending =
        (suggestions['trending'] ?? true) || (suggestions['popular'] ?? true);
    final showHistory = suggestions['history'] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Genre chips (real tags from the source).
        genreTagsAsync.when(
          data: (tags) => SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final genre = tags[index];
                return GestureDetector(
                  onTap: () {
                    _searchController.text = genre;
                    _addQueryToHistoryAndSearch(genre);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: dark
                          ? Colors.transparent
                          : const Color(0xFFE2E8F0),
                      border: dark ? Border.all(color: Colors.white38) : null,
                    ),
                    child: Text(
                      genre,
                      style: TextStyle(
                        color: dark ? Colors.white : const Color(0xFF334155),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        // Trending (real popular manga).
        if (showTrending)
          trendingAsync.when(
          data: (trending) => trending.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel(
                      AppLocalizations.of(context).suggestionTrending,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: trending.length,
                        itemBuilder: (context, index) {
                          final manga = trending[index];
                          return _buildTrendingCard(manga);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        // Search history.
        if (showHistory)
          ..._searchHistory.map(
          (query) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(
              RemixIcons.history_line,
              color: dark ? Colors.white70 : const Color(0xFF49454F),
            ),
            title: Text(
              query,
              style: TextStyle(
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              RemixIcons.arrow_left_up_line,
              color: dark ? Colors.white54 : Colors.black54,
            ),
            onTap: () {
              _searchController.text = query;
              _addQueryToHistoryAndSearch(query);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? Colors.white : Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTrendingCard(Manga manga) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _openManga(manga),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: dark ? null : Border.all(color: Colors.black12),
                    ),
                    child: CachedMangaImage(
                      imageUrl: manga.coverUrl,
                      height: 140,
                      width: 100,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: dark ? const Color(0xFF2C2C2E) : Colors.black12,
                        height: 140,
                        width: 100,
                        child: Icon(
                          RemixIcons.book_open_line,
                          color: dark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  ),
                ),
                DownloadedMangaBadge(mangaId: manga.id, size: 20, iconSize: 12),
                FavoriteBadge(mangaId: manga.id, size: 20, iconSize: 12),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              manga.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Live search results while the user is typing.
  Widget _buildTypingSuggestionsView() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final queryLower = _currentQuery.toLowerCase();
    final filteredHistory = _searchHistory
        .where((q) => q.toLowerCase().contains(queryLower))
        .toList();
    final showHistory =
        ref.watch(appearanceSettingsProvider).searchSuggestions['history'] ??
        true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHistory)
          ...filteredHistory.map(
          (query) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(
              RemixIcons.history_line,
              color: dark ? Colors.white70 : const Color(0xFF49454F),
            ),
            title: Text(
              query,
              style: TextStyle(
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              RemixIcons.arrow_left_up_line,
              color: dark ? Colors.white54 : Colors.black54,
            ),
            onTap: () {
              _searchController.text = query;
              _addQueryToHistoryAndSearch(query);
            },
          ),
        ),

        if (_debouncedQuery.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: dark ? Colors.white54 : Colors.black54,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Searching "$_currentQuery"...',
                  style: TextStyle(
                    color: dark ? Colors.white54 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          _buildLiveResults(_debouncedQuery),
      ],
    );
  }

  Widget _buildLiveResults(String query) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final resultsAsync = ref.watch(searchResultsProvider(query));

    return resultsAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return EmptyState(
            icon: RemixIcons.search_2_line,
            title: AppLocalizations.of(context).noResultsFound,
            subtitle: AppLocalizations.of(context).tryDifferentSearch,
            verticalPadding: 24,
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: mangaCellAspectRatio(context, columns: 3),
            crossAxisSpacing: kMangaGridCrossSpacing,
            mainAxisSpacing: kMangaGridRowSpacing,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final manga = results[index];
            return GestureDetector(
              onTap: () {
                _addQueryToHistoryAndSearch(query);
                _openManga(manga);
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
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: dark
                                  ? null
                                  : Border.all(color: Colors.black12),
                            ),
                            child: CachedMangaImage(
                              imageUrl: manga.coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                color: dark
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.black12,
                                child: Icon(
                                  RemixIcons.book_open_line,
                                  color: dark ? Colors.white38 : Colors.black38,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DownloadedMangaBadge(mangaId: manga.id),
                        FavoriteBadge(mangaId: manga.id),
                      ],
                    ),
                  ),
                  const SizedBox(height: kMangaCardTitleGap),
                  Text(
                    manga.title,
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
          },
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(
            color: dark ? Colors.white54 : Colors.black54,
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          AppLocalizations.of(context).failedToSearch,
          style: TextStyle(
            color: dark ? Colors.white54 : Colors.black54,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
