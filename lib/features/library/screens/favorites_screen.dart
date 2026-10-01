import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/tab_header.dart';
import 'package:yomou/core/widgets/responsive.dart' show usesWideLayout;
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/core/widgets/search_bar.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: TabHeader(
          mode: usesWideLayout(context)
              ? TabHeaderMode.fixed
              : TabHeaderMode.collapsing,
          title: AppLocalizations.of(context).favorites,
          searchBar: _buildSearchBar(),
          body: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 16,
                  child: favoritesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (_) => const SizedBox.shrink(),
                  ),
                ),
              ),
              favoritesAsync.when(
                loading: () => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).favoritesCouldNotLoad,
                        style: TextStyle(
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white54
                                  : const Color(0xFF49454F),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                data: (items) {
                  List<Manga> displayed = items;
                  if (_searchQuery.isNotEmpty) {
                    displayed = items
                        .where(
                          (m) => m.title.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();
                  }
                  return _buildMangaGrid(displayed);
                },
              ),
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottomBarClearance(context)),
              ),
            ],
          ),
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
      trailing: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          RemixIcons.more_2_line,
          color: dark ? Colors.white70 : Colors.black54,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildMangaGrid(List<Manga> items) {
    if (items.isEmpty) {
      final l = AppLocalizations.of(context);
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          child: EmptyState(
            icon: RemixIcons.heart_3_line,
            title: _searchQuery.isNotEmpty
                ? l.favoritesNoMatch
                : l.favoritesEmpty,
            subtitle: l.favoritesEmptySubtitle,
          ),
        ),
      );
    }

    final columns = mangaGridColumns(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: mangaCellAspectRatio(
            context,
            columns: columns,
            // Measured from the resolved column count, the same rule and the
            // same bounds the history and source grids use. A cell sized for a
            // 10pt title and drawn with a 12pt one clips the second line of
            // every title long enough to need one.
            titleFontSize: mangaCardTitleFontSize(columns),
          ),
          crossAxisSpacing: kMangaGridCrossSpacing,
          mainAxisSpacing: kMangaGridRowSpacing,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildMangaCard(context, item, columns);
        },
      ),
    );
  }

  /// [columns] is the resolved count, not a stored setting: the grid measures
  /// its cells with it, so the title has to be drawn with the same value.
  Widget _buildMangaCard(BuildContext context, Manga item, int columns) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = dark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
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
        children: [
          // Strict 2:3 Aspect Ratio for Cover Image
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  // No explicit width or height. Asking for infinity is the
                  // one size the cover decode cap refuses, which had this grid
                  // pulling every favourite in at full source resolution --
                  // roughly 18MB a cover -- while the other grids asked for
                  // their real tile size and were capped.
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
                // The shared badges, so turning list badges off in Appearance
                // reaches this grid too. It used to draw its own heart inline,
                // which ignored the setting and did not update when a title was
                // removed from favourites.
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
