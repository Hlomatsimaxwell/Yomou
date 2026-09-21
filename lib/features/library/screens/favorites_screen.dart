import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/hide_on_scroll.dart';
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
        child: HideOnScroll(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildSearchBar(),
            ],
          ),
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

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: mangaCellAspectRatio(context, columns: 3),
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

  Widget _buildMangaCard(BuildContext context, Manga item) {
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Strict 2:3 Aspect Ratio for Cover Image
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
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
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF2C2C2E),
                        child: const Icon(
                          RemixIcons.book_open_line,
                          color: Colors.white38,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      RemixIcons.heart_3_fill,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
                DownloadedMangaBadge(
                  mangaId: item.id,
                  position: const EdgeInsets.only(top: 6, left: 6),
                ),
              ],
            ),
          ),
          const SizedBox(height: kMangaCardTitleGap),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
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
