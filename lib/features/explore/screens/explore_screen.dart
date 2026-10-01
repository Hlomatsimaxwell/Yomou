import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/core/widgets/tab_header.dart';
import 'package:yomou/core/widgets/responsive.dart' show usesWideLayout;
import 'package:yomou/core/widgets/manga_grid_metrics.dart';
import 'package:yomou/core/widgets/search_bar.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/explore/screens/global_search_screen.dart';
import 'package:yomou/features/explore/widgets/featured_carousel.dart';
import 'package:yomou/features/library/screens/bookmarks_screen.dart';
import 'package:yomou/features/library/screens/downloads_screen.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';
import 'package:yomou/features/source_management/screens/manga_grid_screen.dart';
import 'package:yomou/features/source_management/screens/manga_sources_screen.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/suggestions/providers/suggestions_provider.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/core/providers/incognito_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/source_icon.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  bool _loadingRandom = false;

  final List<Map<String, dynamic>> _quickButtons = [
    {
      'icon': RemixIcons.sd_card_line,
      'labelKey': 'storage',
      'type': 'downloads',
    },
    {
      'icon': RemixIcons.bookmark_3_line,
      'labelKey': 'bookmarks',
      'type': 'bookmarks',
    },
    {'icon': RemixIcons.dice_line, 'labelKey': 'random', 'type': 'random'},
    {
      'icon': RemixIcons.download_line,
      'labelKey': 'downloads',
      'type': 'downloads',
    },
  ];

  String _quickLabel(String key) {
    final l = AppLocalizations.of(context);
    return switch (key) {
      'storage' => l.exploreLocalStorage,
      'bookmarks' => l.bookmarksTitle,
      'random' => l.exploreRandom,
      _ => l.downloads,
    };
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(visibleSourceRowsProvider);
    final showInGrid = ref.watch(showSourcesInGridProvider);
    final enabledSources = sources.where(isSourceEnabled).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: TabHeader(
          mode: usesWideLayout(context)
              ? TabHeaderMode.fixed
              : TabHeaderMode.collapsing,
          title: AppLocalizations.of(context).explore,
          searchBar: _buildSearchBar(),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomBarClearance(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildQuickButtonsGrid(),
                  const SizedBox(height: 20),
                  const FeaturedCarousel(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    AppLocalizations.of(context).mangaSources,
                    actionLabel: AppLocalizations.of(context).exploreManage,
                    actionColor: Theme.of(context).colorScheme.primary,
                    onMorePressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageSourcesScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  showInGrid
                      ? _buildSourcesGrid(enabledSources)
                      : _buildSourcesList(enabledSources),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return YomouSearchBar.tappable(
      hintText: AppLocalizations.of(context).searchManga,
      trailing: AppSheetPress(
        onTap: () async {
          final action = await showIosMenuPanel<String>(
            context,
            children: [
              IosMenuRow(
                icon: RemixIcons.equalizer_line,
                label: AppLocalizations.of(context).manageSources,
                onTap: () => Navigator.pop(context, 'manage'),
              ),
              const IosMenuDivider(),
              Consumer(
                builder: (context, ref, _) => MenuToggleRow(
                  label: AppLocalizations.of(context).incognitoMode,
                  value: ref.watch(incognitoProvider),
                  onChanged: (v) =>
                      ref.read(incognitoProvider.notifier).set(v),
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
          // The sheet had to await a tap, and this screen is free to be
          // gone by the time it returns. Pushing on a dead context throws.
          if (!mounted) return;
          if (action == 'manage') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageSourcesScreen(),
              ),
            );
          } else if (action == 'settings') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            RemixIcons.more_2_line,
            color: dark ? Colors.white70 : Colors.black54,
            size: 22,
          ),
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GlobalSearchScreen()),
        );
      },
    );
  }

  Widget _buildQuickButtonsGrid() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pillColor = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF8F9FA);
    final fgColor = dark ? Colors.white : const Color(0xFF1C1B1F);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 4.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 10,
        ),
        itemCount: _quickButtons.length,
        itemBuilder: (context, index) {
          final btn = _quickButtons[index];
          final isRandom = btn['type'] == 'random';
          return AppPress(
            onTap: () => _handleQuickButton(btn['type'] as String),
            child: Container(
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(16),
                border: dark
                    ? Border.all(color: Colors.white.withValues(alpha: 0.06))
                    : Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    if (isRandom && _loadingRandom)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: dark ? Colors.white38 : Colors.black38,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Icon(btn['icon'] as IconData, color: fgColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _quickLabel(btn['labelKey'] as String),
                        style: TextStyle(
                          color: fgColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
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

  Future<void> _refresh() async {
    final rows = ref.read(visibleSourceRowsProvider);
    for (final row in rows) {
      if (!isSourceEnabled(row)) continue;
      final name = row['name'] as String? ?? '';
      if (name.isEmpty) continue;
      try {
        final src = getSourceByName(name);
        SourceCache.invalidatePrefix('${src.id}/list/');
      } catch (_) {
        // Source registry hiccup: skip, the rest still refresh.
      }
    }
    ref.invalidate(suggestionsProvider(null));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _handleQuickButton(String type) async {
    switch (type) {
      case 'downloads':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DownloadsScreen()),
        );
        break;
      case 'bookmarks':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BookmarksScreen()),
        );
        break;
      case 'random':
        await _openRandomManga();
        break;
    }
  }

  Future<void> _openRandomManga() async {
    if (_loadingRandom) return;
    setState(() => _loadingRandom = true);
    try {
      final sources = resolveActiveSources(ref.read(visibleSourceRowsProvider));
      if (sources.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).noRandomRightNow),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Pick a random source, then a random manga from its popular pool. If a
      // source yields nothing (down, rate-limited, empty), try the next one.
      final random = Random();
      final order = [...sources]..shuffle(random);
      Manga? pick;
      for (final source in order) {
        try {
          final pool = await SourceCache.mangaList(
            sourceId: source.id,
            kind: 'popular',
            page: 1,
            fetch: () => source.getPopularManga(page: 1),
          ).timeout(const Duration(seconds: 10), onTimeout: () => const []);
          if (pool.isNotEmpty) {
            pick = pool[random.nextInt(pool.length)];
            break;
          }
        } catch (_) {
          // Try the next source.
        }
      }

      if (pick == null || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).noRandomRightNow),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final manga = pick;
      await Navigator.push(
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).couldNotFindRandom),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRandom = false);
    }
  }

  Widget _buildSectionHeader(
    String title, {
    String? actionLabel,
    Color? actionColor,
    required VoidCallback onMorePressed,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: onMorePressed,
            style: TextButton.styleFrom(
              foregroundColor:
                  actionColor ?? (dark ? Colors.white70 : const Color(0xFF49454F)),
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: Text(actionLabel ?? l.exploreMore),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesList(List<Map<String, dynamic>> sources) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 2,
      ),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        final name = source['name'] as String;
        final language = source['language'] as String? ?? '';
        final iconUrl = source['iconUrl'] as String? ?? '';

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MangaGridScreen(sourceName: name),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SourceIcon(name: name, iconUrl: iconUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark
                              ? Colors.white
                              : const Color(0xFF212121),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (language.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          language,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: dark
                                ? Colors.white54
                                : const Color(0xFF9E9E9E),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  RemixIcons.arrow_right_s_line,
                  size: 20,
                  color: dark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourcesGrid(List<Map<String, dynamic>> sources) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _sourceGridPadding,
        vertical: 8,
      ),
      // Measured from the constraints rather than the window. The nav rail sits
      // beside this screen on a wide layout and takes 80px off it, and
      // MediaQuery still reports the window width down here, so columns derived
      // from it would size cells for space this grid does not have.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _SourceCardLayout.resolve(
            context,
            constraints.maxWidth,
          );
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: layout.columns,
              // Measured from the same icon and label sizes the card paints with,
              // not a constant: the cell is exactly as tall as its contents at
              // every column count, so no width leaves a row of empty space.
              childAspectRatio: layout.aspectRatio,
              crossAxisSpacing: _sourceGridCrossSpacing,
              mainAxisSpacing: _sourceGridRowSpacing,
            ),
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              final isPinned = source['isPinned'] == true;
              final name = source['name'] as String;
              final iconUrl = source['iconUrl'] as String? ?? '';
              // Inset with the plate rather than fixed, so the pin keeps its
              // place on the corner as the plate grows.
              final pinInset = (layout.iconSize * 0.07).roundToDouble();

              // The universal rounded-square plate, sized to fill the cell it is
              // given rather than to sit in the middle of it. The shape comes
              // from SourceIcon, which scales its own corner radius with it.
              return AppPress(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MangaGridScreen(sourceName: name),
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SourceIcon(
                          name: name,
                          iconUrl: iconUrl,
                          size: layout.iconSize,
                        ),
                        if (isPinned)
                          Positioned(
                            left: pinInset,
                            bottom: pinInset,
                            child: Transform.rotate(
                              angle: -0.785398,
                              child: Icon(
                                RemixIcons.pushpin_2_fill,
                                size: 12,
                                color: dark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: _sourceGridLabelGap),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: dark ? Colors.white : const Color(0xFF1C1B1F),
                          fontSize: layout.labelSize,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Horizontal padding of the sources wall: the same 16 every other grid uses.
const double _sourceGridPadding = 16;
const double _sourceGridCrossSpacing = 10;
const double _sourceGridRowSpacing = 10;

/// Gap between the icon plate and the name under it.
const double _sourceGridLabelGap = 4;

/// Cell width the sources wall aims for.
///
/// Wider than the 100 a manga cover cell uses, because this cell carries a name
/// under the plate as well as the plate: 96 is about the narrowest width at
/// which a source logo and a two-line name are both still legible.
const double _sourceGridTargetCellWidth = 96;

/// Ceiling on the column count.
///
/// Past this the plates are small enough that the logo inside one stops being
/// identifiable, so a wider window spends the extra width on fewer, larger cells
/// instead of more of them -- the same reasoning as the manga grid's ceiling,
/// and the reason this is not a max-extent delegate: that one can only ever add
/// columns, and has no way to hold the plate at a size that stays legible.
const int _sourceGridMaxColumns = 10;

/// Columns at which the source name drops a size, for the same reason a manga
/// title does: the cell is narrower, so the same words need less of it.
const int _sourceGridCompactColumns = 7;

/// The four numbers a source card's geometry resolves to.
class _SourceCardLayout {
  const _SourceCardLayout({
    required this.columns,
    required this.iconSize,
    required this.labelSize,
    required this.aspectRatio,
  });

  /// Resolves the wall's geometry from the width it was actually given.
  ///
  /// The plate and the cell are derived together on purpose. A fixed icon in a
  /// cell whose width follows the window is what left a 64px plate adrift in a
  /// 285px cell on a desktop -- four columns per row, four fifths of each one
  /// empty.
  factory _SourceCardLayout.resolve(BuildContext context, double width) {
    final columns = mangaGridColumns(
      context,
      // The horizontal padding is already off by the time this runs.
      horizontalPadding: 0,
      crossSpacing: _sourceGridCrossSpacing,
      targetCellWidth: _sourceGridTargetCellWidth,
      // Four at the narrow end, which is what a phone has always shown. The
      // plate has a floor size, so a fifth column there would only crush it.
      minColumns: 4,
      maxColumns: _sourceGridMaxColumns,
      availableWidth: width,
    );

    final cellWidth =
        (width - (columns - 1) * _sourceGridCrossSpacing) / columns;
    // Fills the cell rather than sitting in the middle of it, with a floor so a
    // narrow cell cannot crush the plate and a ceiling so a wide one cannot
    // stretch a logo past the size it was drawn for.
    final iconSize = (cellWidth - 28).clamp(56.0, 96.0);
    final labelSize = columns >= 9
        ? 11.0
        : columns >= _sourceGridCompactColumns
        ? 12.0
        : 13.0;

    // Two name lines are always reserved. Source names are long enough that a
    // one-line cell ellipsises most of them, and a truncated name is worse than
    // a little spare height under the few that fit on one.
    //
    // Plus the same slack the manga cells add, for the same reason: the fit is
    // exact on paper and short in practice, because the grid rounds its cell
    // height and the Text rounds its own line box. Sharing the constant is the
    // point -- two numbers with one meaning must not drift apart.
    final height =
        iconSize +
        _sourceGridLabelGap +
        labelSize * 1.2 * 2 +
        kMangaCardTitleSlack;

    return _SourceCardLayout(
      columns: columns,
      iconSize: iconSize,
      labelSize: labelSize,
      aspectRatio: cellWidth / height,
    );
  }

  final int columns;
  final double iconSize;
  final double labelSize;
  final double aspectRatio;
}
