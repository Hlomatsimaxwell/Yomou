import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/features/explore/screens/global_search_screen.dart';
import 'package:yomou/features/feed/providers/updates_provider.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/core/widgets/search_bar.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final result = ref.refresh(updatesProvider.future);
      await result;
    } catch (_) {
      // Swallow; the error branch of the body shows the failure state.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final updatesAsync = ref.watch(updatesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomBarClearance(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildSearchBar(context),
              const SizedBox(height: 12),
              _buildSectionHeader(context),
              const SizedBox(height: 12),
              updatesAsync.when(
                data: (updates) {
                  if (updates.isEmpty) {
                    return EmptyState(
                      icon: RemixIcons.rss_line,
                      title: AppLocalizations.of(context).feedNoNewUpdates,
                      subtitle: AppLocalizations.of(context).feedUpdatesHint,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUpdatesCarousel(context, updates),
                      const SizedBox(height: 20),
                      ..._groupByDate(context, updates),
                    ],
                  );
                },
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
                      AppLocalizations.of(context).failedToLoadUpdates,
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
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return YomouSearchBar.tappable(
      hintText: AppLocalizations.of(context).searchManga,
      trailing: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          RemixIcons.more_2_line,
          color: dark ? Colors.white70 : Colors.black54,
          size: 22,
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

  Widget _buildSectionHeader(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context).updatesTitle,
            style: TextStyle(
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: _refreshing ? null : _refresh,
            child: Row(
              children: [
                if (_refreshing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: dark
                          ? Colors.white70
                          : Theme.of(context).colorScheme.primary,
                    ),
                  )
                else
                  Icon(
                    RemixIcons.refresh_line,
                    color: dark ? Colors.white70 : const Color(0xFF49454F),
                    size: 15,
                  ),
                const SizedBox(width: 4),
                Text(
                  _refreshing
                      ? AppLocalizations.of(context).checking
                      : AppLocalizations.of(context).refresh,
                  style: TextStyle(
                    color: dark ? Colors.white70 : const Color(0xFF49454F),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesCarousel(
    BuildContext context,
    List<MangaUpdate> updates,
  ) {
    final previews = updates.take(6).toList();

    return SizedBox(
      height: 185,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: previews.length,
        itemBuilder: (context, index) {
          final update = previews[index];
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
                    mangaId: update.mangaId,
                    title: update.title,
                    imageUrl: update.coverUrl,
                  ),
                ),
              );
            },
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Stack(
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
                              imageUrl: update.coverUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFF2C2C2E),
                                child: const Icon(
                                  RemixIcons.book_open_line,
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${update.newCount}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              update.isFavorite
                                  ? RemixIcons.heart_3_fill
                                  : RemixIcons.heart_3_line,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                        DownloadedMangaBadge(
                          mangaId: update.mangaId,
                          position: const EdgeInsets.only(bottom: 6, right: 6),
                          size: 20,
                          iconSize: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    update.title,
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
            ),
          );
        },
      ),
    );
  }

  // Groups updates (already sorted by date desc) into date-grouped sections.
  List<Widget> _groupByDate(BuildContext context, List<MangaUpdate> updates) {
    final groups = <String, List<MangaUpdate>>{};
    for (final u in updates) {
      groups.putIfAbsent(u.dateGroup, () => []).add(u);
    }

    return [
      for (final entry in groups.entries)
        _buildDateGroupSection(context, entry.key, entry.value),
    ];
  }

  Widget _buildDateGroupSection(
    BuildContext context,
    String dateGroup,
    List<MangaUpdate> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            dateGroup,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF1C1B1F),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...items.map((update) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MangaDetailScreen(
                    mangaId: update.mangaId,
                    title: update.title,
                    imageUrl: update.coverUrl,
                  ),
                ),
              );
            },
            leading: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: dark ? null : Border.all(color: Colors.black12),
                    ),
                    child: CachedMangaImage(
                      imageUrl: update.coverUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF2C2C2E),
                        child: const Icon(
                          RemixIcons.book_open_line,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
                DownloadedMangaBadge(
                  mangaId: update.mangaId,
                  size: 16,
                  iconSize: 10,
                ),
                FavoriteBadge(mangaId: update.mangaId, size: 16, iconSize: 10),
              ],
            ),
            title: Text(
              update.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${update.newCount} new · ${update.latestChapterTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark ? Colors.white54 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}
