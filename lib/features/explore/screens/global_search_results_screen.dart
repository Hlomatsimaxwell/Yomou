import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/explore/providers/search_provider.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/features/explore/screens/source_search_results_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';

class GlobalSearchResultsScreen extends ConsumerStatefulWidget {
  final String searchQuery;

  const GlobalSearchResultsScreen({super.key, required this.searchQuery});

  @override
  ConsumerState<GlobalSearchResultsScreen> createState() =>
      _GlobalSearchResultsScreenState();
}

class _GlobalSearchResultsScreenState
    extends ConsumerState<GlobalSearchResultsScreen> {
  late TextEditingController _searchController;
  late String _activeQuery;
  bool _showFailedSources = false;

  @override
  void initState() {
    super.initState();
    _activeQuery = widget.searchQuery;
    _searchController = TextEditingController(text: _activeQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _activeQuery = query);
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

  void _openShowAll(SourceSearchResult result) {
    final source =
        getSourceBySourceId(result.sourceId) ??
        getSourceByName(result.sourceName);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SourceSearchResultsScreen(source: source, query: _activeQuery),
      ),
    );
  }

  Future<void> _refresh() async {
    final sources = resolveActiveSources(ref.read(sourcesProvider));
    for (final source in sources) {
      SourceCache.invalidatePrefix('${source.id}/list/');
    }
    ref.invalidate(globalSearchProvider(_activeQuery));
    await ref.read(globalSearchProvider(_activeQuery).future);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final resultsAsync = ref.watch(globalSearchProvider(_activeQuery));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: dark ? Colors.white : Theme.of(context).colorScheme.onSurface,
        backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSearchSliverBar(dark),
            ...resultsAsync.when(
              loading: () => const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppLocalizations.of(context).failedToSearch,
                          style: TextStyle(
                            color:
                                dark ? Colors.white70 : const Color(0xFF49454F),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            e.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  dark ? Colors.white38 : Colors.black38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              data: (results) => _buildResultSlivers(results, dark),
            ),
          ],
        ),
      ),
    );
  }

  // Floating app bar that hides while scrolling down and snaps back on the
  // tiniest upward scroll, keeping the search field out of the way while the
  // user browses results.
  Widget _buildSearchSliverBar(bool dark) {
    return SliverAppBar(
      floating: true,
      snap: true,
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
        style: TextStyle(
          color: dark ? Colors.white : const Color(0xFF1C1B1F),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        cursorColor: dark ? Colors.white : const Color(0xFF1C1B1F),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) => _submitSearch(),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).searchEllipsis,
          hintStyle: TextStyle(
            color: dark ? Colors.white54 : Colors.black54,
            fontSize: 16,
          ),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: Icon(
              RemixIcons.close_line,
              color: dark ? Colors.white70 : const Color(0xFF49454F),
            ),
            onPressed: () {
              _searchController.clear();
              _submitSearch();
            },
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: _showFailedSources
              ? AppLocalizations.of(context).hideFailedSources
              : AppLocalizations.of(context).showFailedSources,
          icon: Icon(
            _showFailedSources
                ? RemixIcons.globe_line
                : RemixIcons.global_off_line,
            color: _showFailedSources
                ? Colors.orange
                : (dark ? Colors.white : const Color(0xFF1C1B1F)),
          ),
          onPressed: () {
            setState(() => _showFailedSources = !_showFailedSources);
          },
        ),
        IconButton(
          icon: Icon(
            RemixIcons.search_line,
            color: dark ? Colors.white : const Color(0xFF1C1B1F),
          ),
          onPressed: _submitSearch,
        ),
      ],
    );
  }

  List<Widget> _buildResultSlivers(
    List<SourceSearchResult> results,
    bool dark,
  ) {
    // Default: hide empty and failed sources.
    final visible = _showFailedSources
        ? results
        : results.where((r) => r.hasResults && !r.hasError).toList();

    if (visible.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: RemixIcons.search_2_line,
            title: AppLocalizations.of(context).noResultsFound,
            subtitle: AppLocalizations.of(context).tryDifferentSearch,
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        sliver: SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (context, index) =>
              _buildSourceSection(visible[index]),
        ),
      ),
    ];
  }

  Widget _buildSourceSection(SourceSearchResult result) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                result.sourceName,
                style: TextStyle(
                  color: dark
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (result.hasResults)
                TextButton(
                  onPressed: () => _openShowAll(result),
                  style: TextButton.styleFrom(
                    foregroundColor: dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(
                          context,
                        ).showAllCount(result.manga.length),
                        style: TextStyle(
                          color: dark
                              ? Colors.white70
                              : const Color(0xFF49454F),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        RemixIcons.arrow_right_s_line,
                        color: dark ? Colors.white70 : const Color(0xFF49454F),
                        size: 18,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (result.hasResults)
          _buildResultRow(result.manga)
        else
          _buildFailedRow(result),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildResultRow(List<Manga> manga) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: manga.length,
        itemBuilder: (context, index) {
          final item = manga[index];
          return GestureDetector(
            onTap: () => _openManga(item),
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
                            border: dark
                                ? null
                                : Border.all(color: Colors.black12),
                          ),
                          child: CachedMangaImage(
                            imageUrl: item.coverUrl,
                            height: 140,
                            width: 100,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              color: dark
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.black12,
                              height: 140,
                              width: 100,
                              alignment: Alignment.center,
                              child: Icon(
                                RemixIcons.book_open_line,
                                color: dark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        ),
                      ),
                      DownloadedMangaBadge(
                        mangaId: item.id,
                        size: 20,
                        iconSize: 12,
                      ),
                      FavoriteBadge(mangaId: item.id, size: 20, iconSize: 12),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFailedRow(SourceSearchResult result) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dark ? Colors.white12 : Colors.black12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              result.hasError
                  ? RemixIcons.error_warning_line
                  : RemixIcons.search_2_line,
              color: dark ? Colors.white38 : Colors.black38,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.hasError
                    ? (result.errorMessage ??
                          AppLocalizations.of(context).sourceFailed)
                    : AppLocalizations.of(context).contentNotFoundRemoved,
                style: TextStyle(
                  color: dark ? Colors.white54 : Colors.black54,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
