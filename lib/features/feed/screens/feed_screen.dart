import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/features/explore/screens/global_search_screen.dart';
import 'package:yomou/features/feed/providers/updates_provider.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/hide_on_scroll.dart';
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
        child: HideOnScroll(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildSearchBar(context),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomBarClearance(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        // The newest release group's label ("Today") doubles
                        // as the screen header, sitting next to refresh.
                        _buildSectionHeader(context, updates.first.dateGroup),
                        const SizedBox(height: 8),
                        ..._groupByDate(context, updates, skipFirstLabel: true),
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
              ],
            ),
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

  Widget _buildSectionHeader(BuildContext context, String label) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
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

  // Groups updates (already sorted by date desc) into date-grouped sections.
  // With [skipFirstLabel], the newest group's label is not repeated below the
  // header (which already shows it next to the refresh control).
  List<Widget> _groupByDate(
    BuildContext context,
    List<MangaUpdate> updates, {
    bool skipFirstLabel = false,
  }) {
    final groups = <String, List<MangaUpdate>>{};
    for (final u in updates) {
      groups.putIfAbsent(u.dateGroup, () => []).add(u);
    }

    final sections = groups.entries.toList();
    return [
      for (var i = 0; i < sections.length; i++)
        _buildDateGroupSection(
          context,
          sections[i].key,
          sections[i].value,
          showLabel: !(skipFirstLabel && i == 0),
        ),
    ];
  }

  Widget _buildDateGroupSection(
    BuildContext context,
    String dateGroup,
    List<MangaUpdate> items, {
    bool showLabel = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
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
                    sourceId: update.sourceId,
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
                if (update.hasUnseenUpdate) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
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
