import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/features/settings/providers/grid_density_provider.dart';

enum ListMode { compact, details, grid }

class RelatedMangaScreen extends ConsumerStatefulWidget {
  final String title;
  final List<Manga>? relatedManga;

  const RelatedMangaScreen({
    super.key,
    this.title = 'Related manga',
    this.relatedManga,
  });

  @override
  ConsumerState<RelatedMangaScreen> createState() =>
      _RelatedMangaScreenState();
}

class _RelatedMangaScreenState extends ConsumerState<RelatedMangaScreen> {
  ListMode _selectedMode = ListMode.grid;

  /// The density the reader chose, from the one preference all manga grids
  /// share. Null means auto: derive the count from the width.
  int? _gridSize;

  final List<Manga> _fallbackItems = [
    Manga(
      id: '1',
      sourceId: 'mock',
      title: 'Record of Demon Annihilation',
      coverUrl: 'https://picsum.photos/seed/rel1/300/450',
    ),
    Manga(
      id: '2',
      sourceId: 'mock',
      title: 'A Substitute Bride to the Reaper D...',
      coverUrl: 'https://picsum.photos/seed/rel2/300/450',
    ),
    Manga(
      id: '3',
      sourceId: 'mock',
      title: 'Reincarnation of the Fist King',
      coverUrl: 'https://picsum.photos/seed/rel3/300/450',
    ),
    Manga(
      id: '4',
      sourceId: 'mock',
      title: 'The Hounds of Sisyphus',
      coverUrl: 'https://picsum.photos/seed/rel4/300/450',
    ),
    Manga(
      id: '5',
      sourceId: 'mock',
      title: 'The Divine Witch Will Find ...',
      coverUrl: 'https://picsum.photos/seed/rel5/300/450',
    ),
    Manga(
      id: '6',
      sourceId: 'mock',
      title: 'I Became the Scoundrel of the...',
      coverUrl: 'https://picsum.photos/seed/rel6/300/450',
    ),
    Manga(
      id: '7',
      sourceId: 'mock',
      title: 'Necromancer of a Prestigious ...',
      coverUrl: 'https://picsum.photos/seed/rel7/300/450',
    ),
  ];

  List<Manga> get _items =>
      (widget.relatedManga != null && widget.relatedManga!.isNotEmpty)
      ? widget.relatedManga!
      : _fallbackItems;

  void _showListOptionsBottomSheet() {
    showIosSheet(
      context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            final scheme = Theme.of(context).colorScheme;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'List mode',
                    style: TextStyle(
                      color: dark ? Colors.white : scheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Segmented Mode Selector
                  Container(
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFEBEFEF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildModeButton(
                          context,
                          label: 'Compact',
                          icon: RemixIcons.drag_drop_line,
                          mode: ListMode.compact,
                          setSheetState: setSheetState,
                        ),
                        _buildModeButton(
                          context,
                          label: 'Details',
                          icon: RemixIcons.list_unordered,
                          mode: ListMode.details,
                          setSheetState: setSheetState,
                        ),
                        _buildModeButton(
                          context,
                          label: 'Grid',
                          icon: RemixIcons.grid_line,
                          mode: ListMode.grid,
                          setSheetState: setSheetState,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Grid Size Slider
                  if (_selectedMode == ListMode.grid) ...[
                    Text(
                      'Grid size',
                      style: TextStyle(
                        color: dark ? Colors.white : scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: dark ? Colors.white : scheme.primary,
                        inactiveTrackColor: dark
                            ? Colors.white24
                            : Colors.black26,
                        thumbColor: dark ? Colors.white : scheme.primary,
                        overlayColor: dark ? Colors.white12 : Colors.black12,
                        trackHeight: 12,
                      ),
                      child: Slider(
                        // Same track and same direction as every other manga
                        // grid's slider. This one kept its own 2..4 range with
                        // the value passed straight through, so the thumb sat
                        // at the opposite end from the four screens that
                        // reverse it -- drag right here and you got more
                        // columns, drag right there and you got fewer.
                        value: mangaGridSliderPositionForColumns(
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
                        onChanged: (value) {
                          final columns = mangaGridColumnsForSliderPosition(
                            value,
                          );
                          setSheetState(() => _gridSize = columns);
                          setState(() {});
                          // One density for every manga grid, so this choice
                          // follows the reader back to History and Favourites.
                          ref
                              .read(gridDensityProvider.notifier)
                              .setColumns(columns);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required ListMode mode,
    required StateSetter setSheetState,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setSheetState(() => _selectedMode = mode);
          setState(() => _selectedMode = mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (dark
                      ? const Color(0xFF3A3A3C)
                      : Theme.of(context).colorScheme.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (dark ? Colors.white54 : const Color(0xFF49454F)),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (dark ? Colors.white54 : const Color(0xFF49454F)),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _gridSize = ref.watch(gridDensityProvider);
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
        actions: [
          IosMenuButton<String>(
            items: const [
              IosMenuItem(
                value: 'options',
                label: 'List options',
                icon: RemixIcons.equalizer_line,
              ),
            ],
            onSelected: (value) {
              if (value == 'options') {
                _showListOptionsBottomSheet();
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              widget.title,
              style: TextStyle(
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBodyContent()),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final items = _items;
    switch (_selectedMode) {
      case ListMode.grid:
        final columns = mangaGridColumnsFor(context, userColumns: _gridSize);
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: kMangaGridCrossSpacing,
            mainAxisSpacing: kMangaGridRowSpacing,
            childAspectRatio: mangaCellAspectRatio(context, columns: columns),
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: () => _openManga(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: dark
                              ? CachedMangaImage(
                                  imageUrl: item.coverUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: const Color(0xFF2C2C2E),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          RemixIcons.book_open_line,
                                          color: Colors.white38,
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
                                    width: double.infinity,
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: Colors.black12,
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            RemixIcons.book_open_line,
                                            color: Colors.black38,
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
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark ? Colors.white : onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            );
          },
        );

      case ListMode.compact:
      case ListMode.details:
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final isDetails = _selectedMode == ListMode.details;

            return GestureDetector(
              onTap: () => _openManga(item),
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: dark
                            ? CachedMangaImage(
                                imageUrl: item.coverUrl,
                                width: isDetails ? 60 : 45,
                                height: isDetails ? 80 : 60,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  width: isDetails ? 60 : 45,
                                  height: isDetails ? 80 : 60,
                                  color: const Color(0xFF2C2C2E),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    RemixIcons.book_open_line,
                                    color: Colors.white38,
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: CachedMangaImage(
                                  imageUrl: item.coverUrl,
                                  width: isDetails ? 60 : 45,
                                  height: isDetails ? 80 : 60,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        width: isDetails ? 60 : 45,
                                        height: isDetails ? 80 : 60,
                                        color: Colors.black12,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          RemixIcons.book_open_line,
                                          color: Colors.black38,
                                        ),
                                      ),
                                ),
                              ),
                      ),
                      DownloadedMangaBadge(
                        mangaId: item.id,
                        size: 16,
                        iconSize: 10,
                      ),
                      FavoriteBadge(
                        mangaId: item.id,
                        size: 16,
                        iconSize: 10,
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: dark ? Colors.white : onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
    }
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
}
