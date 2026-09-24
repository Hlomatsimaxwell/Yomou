import 'package:remixicon/remixicon.dart';
import 'dart:math';
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

class MangaGridScreen extends ConsumerStatefulWidget {
  final String sourceName;

  const MangaGridScreen({super.key, required this.sourceName});

  @override
  ConsumerState<MangaGridScreen> createState() => _MangaGridScreenState();
}

class _MangaGridScreenState extends ConsumerState<MangaGridScreen> {
  int _selectedFilterIndex = -1;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  List<Manga> _mangaList = [];
  bool _isLoading = true;
  String? _error;

  final List<String> _filters = [
    'Genres',
    'Web Comic',
    'Reincarnation',
    'Martial Arts',
    'Action',
    'Romance',
  ];

  @override
  void initState() {
    super.initState();
    _loadManga();
  }

  Future<void> _loadManga({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final source = getSourceByName(widget.sourceName);
      final manga = await SourceCache.mangaList(
        sourceId: source.id,
        kind: 'popular',
        page: 1,
        forceRefresh: forceRefresh,
        fetch: source.getPopularManga,
      );
      setState(() {
        _mangaList = manga;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final source = getSourceByName(widget.sourceName);
    SourceCache.invalidatePrefix('${source.id}/list/popular/');
    await _loadManga(forceRefresh: true);
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
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: dark ? Colors.white : scheme.primary,
        backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
        onRefresh: _refresh,
        child: SingleChildScrollView(
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
                    Text(
                      widget.sourceName,
                      style: TextStyle(
                        color: dark ? Colors.white : scheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
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
                          AppLocalizations.of(context).filterUpdated,
                          style: TextStyle(
                            color: dark ? Colors.white : scheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (ref.watch(appearanceSettingsProvider).showQuickFilters)
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
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;
          final isGenresButton = index == 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilterIndex = isSelected ? -1 : index;
                });
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
                    if (isGenresButton) ...[
                      Icon(
                        RemixIcons.equalizer_line,
                        size: 16,
                        color: isSelected
                            ? Colors.black
                            : (dark
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _filters[index],
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
          final item = items[index];
          return _buildMangaCard(context, item);
        },
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
