import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:yomou/core/providers/incognito_provider.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/hide_on_scroll.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/core/widgets/search_bar.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';

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

  String _listMode = 'Grid';
  double _gridSize = 3;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _listMode = prefs.getString('suggestions_list_mode') ?? 'Grid';
      _gridSize = prefs.getDouble('suggestions_grid_size') ?? 3.0;
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Re-fetches suggestions (and the genre chip list) across every active
  /// source, forcing the disk cache to be bypassed so the user always sees
  /// fresh results.
  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;

    final sources = sourcesFromRows(ref.read(sourcesProvider));
    for (final source in sources) {
      SourceCache.invalidatePrefix('${source.id}/list/');
      SourceCache.invalidatePrefix('${source.id}/tags');
    }
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      genreTagsAsync.when(
                        data: (tags) => tags.isNotEmpty
                            ? _buildGenreChips(tags)
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                suggestionsAsync.when(
                  data: (mangaList) => _buildMangaList(mangaList),
                  loading: () => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
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
                          AppLocalizations.of(context).failedToLoadSuggestions,
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
                ),
                SliverPadding(
                  padding: EdgeInsets.only(bottom: bottomBarClearance(context)),
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
          icon: RemixIcons.list_unordered,
          label: AppLocalizations.of(context).historyListOptions,
          onTap: () => Navigator.pop(context, 'listOptions'),
        ),
        const IosMenuDivider(),
        IosMenuRow(
          icon: RemixIcons.refresh_line,
          label: AppLocalizations.of(context).refresh,
          onTap: () => Navigator.pop(context, 'update'),
        ),
        const IosMenuDivider(),
        Consumer(
          builder: (context, ref, _) => MenuToggleRow(
            label: AppLocalizations.of(context).incognitoMode,
            value: ref.watch(incognitoProvider),
            onChanged: (v) => ref.read(incognitoProvider.notifier).set(v),
          ),
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
    if (action == 'listOptions') {
      _showListOptionsSheet();
    } else if (action == 'update') {
      await _refresh();
      if (mounted) {
        showIosToast(
          context,
          message: AppLocalizations.of(context).refreshed,
        );
      }
    } else if (action == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }
  }

  Future<void> _showListOptionsSheet() async {
    await showIosSheet(
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
                    AppLocalizations.of(context).historyListMode,
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
                          'Compact',
                          RemixIcons.list_unordered,
                          setSheetState,
                        ),
                        VerticalDivider(
                          width: 1,
                          color: dark ? Colors.white24 : Colors.black12,
                          indent: 8,
                          endIndent: 8,
                        ),
                        _buildSegmentTab(
                          'Details',
                          RemixIcons.list_view,
                          setSheetState,
                        ),
                        VerticalDivider(
                          width: 1,
                          color: dark ? Colors.white24 : Colors.black12,
                          indent: 8,
                          endIndent: 8,
                        ),
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
                          AppLocalizations.of(context).historyGridSize,
                          style: TextStyle(
                            color: dark
                                ? Colors.white70
                                : const Color(0xFF49454F),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).historyGridSizeColumns(_gridSize.toInt()),
                          style: TextStyle(
                            color: dark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: dark
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                        inactiveTrackColor: dark
                            ? Colors.white12
                            : Colors.black12,
                        thumbColor: dark
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                          elevation: 4,
                        ),
                        overlayColor: (dark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.12),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 20,
                        ),
                        tickMarkShape: const RoundSliderTickMarkShape(
                          tickMarkRadius: 2,
                        ),
                        activeTickMarkColor: Colors.transparent,
                        inactiveTickMarkColor: dark
                            ? Colors.white30
                            : Colors.black26,
                      ),
                      child: Slider(
                        value: 7 - _gridSize,
                        min: 1,
                        max: 6,
                        divisions: 5,
                        onChanged: (value) {
                          final actualColumns = 7 - value;
                          setSheetState(() {
                            _gridSize = actualColumns;
                          });
                          setState(() {});
                          _savePreference(
                            'suggestions_grid_size',
                            actualColumns,
                          );
                        },
                      ),
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

  String _modeLabel(BuildContext context, String mode) {
    final l = AppLocalizations.of(context);
    return switch (mode) {
      'Compact' => l.historyCompactMode,
      'Details' => l.historyDetailsMode,
      _ => l.listModeGrid,
    };
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
          _savePreference('suggestions_list_mode', mode);
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
                _modeLabel(context, mode),
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

  Widget _buildMangaList(List<Manga> allManga) {
    final items = allManga.where((m) {
      return _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          child: EmptyState(
            icon: RemixIcons.lightbulb_line,
            title: AppLocalizations.of(context).suggestionsNoResults,
            subtitle: _selectedGenre != null
                ? AppLocalizations.of(context).suggestionsNoGenreResults
                : AppLocalizations.of(context).tryDifferentSearch,
          ),
        ),
      );
    }

    return switch (_listMode) {
      'Compact' => _buildCompactList(context, items),
      'Details' => _buildDetailsList(context, items),
      _ => _buildMangaGrid(items),
    };
  }

  Widget _buildCompactList(BuildContext context, List<Manga> items) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(
          color: dark ? Colors.white12 : Colors.black12,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final manga = items[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Theme.of(context).brightness == Brightness.dark
                    ? null
                    : Border.all(color: Colors.black12),
              ),
              child: CachedMangaImage(
                imageUrl: manga.coverUrl,
                width: 40,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
          ),
          title: Text(
            manga.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            _sourceLabel(manga.sourceId),
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white54
                  : const Color(0xFF49454F),
              fontSize: 12,
            ),
          ),
          trailing: DownloadedMangaBadge(mangaId: manga.id),
          onTap: () => _openManga(manga),
        );
      },
      ),
    );
  }

  Widget _buildDetailsList(BuildContext context, List<Manga> items) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
        final manga = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1E1E20) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openManga(manga),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedMangaImage(
                      imageUrl: manga.coverUrl,
                      width: 60,
                      height: 85,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          manga.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _sourceLabel(manga.sourceId),
                          style: TextStyle(
                            color: dark
                                ? Colors.white70
                                : const Color(0xFF49454F),
                            fontSize: 13,
                          ),
                        ),
                        if (manga.description != null &&
                            manga.description!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            manga.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: dark
                                  ? Colors.white54
                                  : const Color(0xFF49454F),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            DownloadedMangaBadge(mangaId: manga.id),
                            const SizedBox(width: 8),
                            FavoriteBadge(mangaId: manga.id),
                          ],
                        ),
                      ],
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

  String _sourceLabel(String sourceId) {
    final source = getSourceBySourceId(sourceId);
    return source?.name ?? sourceId;
  }

  Widget _buildMangaGrid(List<Manga> allManga) {
    final items = allManga.where((m) {
      return _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          child: EmptyState(
            icon: RemixIcons.lightbulb_line,
            title: AppLocalizations.of(context).suggestionsNoResults,
            subtitle: _selectedGenre != null
                ? AppLocalizations.of(context).suggestionsNoGenreResults
                : AppLocalizations.of(context).tryDifferentSearch,
          ),
        ),
      );
    }

    final columns = _gridSize.round().clamp(1, 7);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: mangaCellAspectRatio(context, columns: columns),
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
              sourceId: manga.sourceId,
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
                        alignment: Alignment.center,
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
