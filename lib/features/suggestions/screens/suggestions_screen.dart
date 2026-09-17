import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:yomou/features/suggestions/providers/suggestions_provider.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/core/widgets/search_bar.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';
import 'package:yomou/features/source_management/screens/manga_sources_screen.dart';

class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  String? _selectedGenre; // null: personalised, non-null: filter by genre
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _refreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Re-fetches suggestions (and the genre chip list) from the source, forcing
  /// the disk cache to be bypassed so the user always sees fresh results.
  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;

    final source = ref.read(currentSourceProvider);
    SourceCache.invalidatePrefix('${source.id}/list/');
    SourceCache.invalidatePrefix('${source.id}/tags');
    ref.invalidate(genreTagsProvider);
    ref.invalidate(suggestionsProvider(_selectedGenre));
    try {
      await ref.read(suggestionsProvider(_selectedGenre).future);
    } catch (_) {}
    _refreshing = false;
  }

  @override
  Widget build(BuildContext context) {
    // Passing _selectedGenre as the family key; provider re-fetches when it changes.
    final suggestionsAsync = ref.watch(suggestionsProvider(_selectedGenre));
    final genreTagsAsync = ref.watch(genreTagsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomBarClearance(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildSearchBar(),
                const SizedBox(height: 12),
                genreTagsAsync.when(
                  data: (tags) => tags.isNotEmpty
                      ? _buildGenreChips(tags)
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                suggestionsAsync.when(
                  data: (mangaList) => _buildMangaGrid(mangaList),
                  loading: () => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).failedToLoadSuggestions,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white54
                              : const Color(0xFF49454F),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
      trailing: AppSheetPress(
        onTap: _showMenu,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            RemixIcons.more_2_line,
            color: dark ? Colors.white70 : Colors.black54,
            size: 22,
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu() async {
    final action = await showIosMenuPanel<String>(
      context,
      children: [
        IosMenuRow(
          icon: RemixIcons.equalizer_line,
          label: AppLocalizations.of(context).manageSources,
          onTap: () => Navigator.pop(context, 'manage'),
        ),
        const IosMenuDivider(),
        IosMenuRow(
          icon: RemixIcons.settings_3_line,
          label: AppLocalizations.of(context).settings,
          onTap: () => Navigator.pop(context, 'settings'),
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'manage') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManageSourcesScreen()),
      );
    } else if (action == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }
  }

  Widget _buildGenreChips(List<String> tags) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length,
        itemBuilder: (context, index) {
          final tag = tags[index];
          final isSelected = _selectedGenre == tag;

          final Color bg = dark
              ? (isSelected ? Colors.white : Colors.transparent)
              : (isSelected ? primary : const Color(0xFFE2E8F0));
          final Color fg = dark
              ? (isSelected ? Colors.black : Colors.white)
              : (isSelected ? Colors.white : const Color(0xFF334155));

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGenre = isSelected ? null : tag;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(RemixIcons.price_tag_3_line, size: 16, color: fg),
                    const SizedBox(width: 6),
                    Text(
                      tag,
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
        },
      ),
    );
  }

  Widget _buildMangaGrid(List<Manga> allManga) {
    final items = allManga.where((m) {
      return _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (items.isEmpty) {
      return EmptyState(
        icon: RemixIcons.lightbulb_line,
        title: AppLocalizations.of(context).suggestionsNoResults,
        subtitle: _selectedGenre != null
            ? AppLocalizations.of(context).suggestionsNoGenreResults
            : AppLocalizations.of(context).tryDifferentSearch,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: mangaCellAspectRatio(context, columns: 3),
          crossAxisSpacing: kMangaGridCrossSpacing,
          mainAxisSpacing: kMangaGridRowSpacing,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final manga = items[index];
          return _buildMangaCard(context, manga);
        },
      ),
    );
  }

  Widget _buildMangaCard(BuildContext context, Manga manga) {
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
              mangaId: manga.id,
              title: manga.title,
              imageUrl: manga.coverUrl,
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
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: dark ? null : Border.all(color: Colors.black12),
                    ),
                    child: CachedMangaImage(
                      imageUrl: manga.coverUrl,
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
