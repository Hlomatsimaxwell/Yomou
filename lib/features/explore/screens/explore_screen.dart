import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/core/widgets/search_bar.dart';
import 'package:yomou/features/explore/screens/global_search_screen.dart';
import 'package:yomou/features/library/screens/bookmarks_screen.dart';
import 'package:yomou/features/library/screens/downloads_screen.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';
import 'package:yomou/features/source_management/screens/manga_grid_screen.dart';
import 'package:yomou/features/source_management/screens/manga_sources_screen.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/safe_image.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  bool _incognitoMode = false;
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
    final sources = ref.watch(sourcesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomBarClearance(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildQuickButtonsGrid(),
              const SizedBox(height: 24),
              _buildSectionHeader(
                AppLocalizations.of(context).mangaSources,
                actionLabel: AppLocalizations.of(context).exploreManage,
                onMorePressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageSourcesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildSourcesGrid(sources),
            ],
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
              MenuToggleRow(
                label: AppLocalizations.of(context).incognitoMode,
                value: _incognitoMode,
                onChanged: (v) => setState(() => _incognitoMode = v),
              ),
              const IosMenuDivider(),
              IosMenuRow(
                icon: RemixIcons.settings_3_line,
                label: AppLocalizations.of(context).settings,
                onTap: () => Navigator.pop(context, 'settings'),
              ),
            ],
          );
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
    final cardColor = dark ? const Color(0xFF2C2C2E) : Colors.white;
    final fgColor = dark ? Colors.white : const Color(0xFF1C1B1F);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _quickButtons.length,
        itemBuilder: (context, index) {
          final btn = _quickButtons[index];
          final isRandom = btn['type'] == 'random';
          return AppPress(
            onTap: () => _handleQuickButton(btn['type'] as String),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: dark ? null : Border.all(color: Colors.black12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (isRandom && _loadingRandom)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: dark ? Colors.white38 : Colors.black38,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Icon(btn['icon'] as IconData, color: fgColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _quickLabel(btn['labelKey'] as String),
                        style: TextStyle(
                          color: fgColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
      final source = ref.read(currentSourceProvider);
      final pool = await SourceCache.mangaList(
        sourceId: source.id,
        kind: 'popular',
        page: 1,
        fetch: () => source.getPopularManga(page: 1),
      );
      if (pool.isEmpty || !mounted) {
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
      final index = DateTime.now().millisecondsSinceEpoch % pool.length;
      final manga = pool[index];
      if (!mounted) return;
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
              foregroundColor: dark ? Colors.white70 : const Color(0xFF49454F),
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

  Widget _buildSourcesGrid(List<Map<String, dynamic>> sources) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tileBg = dark ? const Color(0xFF242424) : Colors.white;
    final tileBorder = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black12;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.74,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: sources.length,
        itemBuilder: (context, index) {
          final source = sources[index];
          final isPinned = source['isPinned'] == true;
          final name = source['name'] as String;
          final iconUrl = source['iconUrl'] as String? ?? '';
          final fallbackLetter = name.isEmpty ? '?' : name[0];
          final fallbackColor = _deterministicColor(name);

          Widget fallbackTile() => Center(
            child: Text(
              fallbackLetter,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : const Color(0xFF1C1B1F),
              ),
            ),
          );

          Widget tileIcon;
          if (iconUrl.isNotEmpty) {
            tileIcon = ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: fallbackColor,
                child: SafeNetworkImage(
                  imageUrl: iconUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (context, url, error) => fallbackTile(),
                ),
              ),
            );
          } else {
            tileIcon = fallbackTile();
          }

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MangaGridScreen(sourceName: name),
                ),
              );
            },
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: iconUrl.isNotEmpty ? tileBg : fallbackColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tileBorder, width: 1),
                      ),
                      child: tileIcon,
                    ),
                    if (isPinned)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Transform.rotate(
                          angle: -0.785398,
                          child: Icon(
                            RemixIcons.pushpin_2_fill,
                            size: 14,
                            color: dark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? Colors.white : const Color(0xFF1C1B1F),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _deterministicColor(String name) {
    int hash = 0;
    for (final codeUnit in name.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.35, 0.35).toColor();
  }
}
