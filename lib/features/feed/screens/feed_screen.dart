import 'package:yomou/core/theme/amoled.dart';
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:yomou/widgets/manga_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:yomou/features/explore/screens/global_search_screen.dart';
import 'package:yomou/features/feed/providers/updates_provider.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/core/widgets/search_bar.dart';
import 'package:yomou/core/widgets/tab_header.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/responsive.dart' show usesWideLayout;
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/favorite_badge.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/providers/incognito_provider.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Persist the badge count after every scan so cold starts are cheap and
    // never trigger the heavy library scan themselves.
    ref.listenManual(updatesProvider, (prev, next) {
      next.whenData((updates) async {
        final total = updates.fold<int>(
          0,
          (sum, u) => sum + (u.hasUnseenUpdate ? u.newCount : 0),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(kUpdatesBadgePrefKey, total);
        if (mounted) ref.invalidate(updatesBadgeProvider);
      });
    });
  }

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

  Future<void> _clearUpdatesDialog() async {
    final l = AppLocalizations.of(context);
    var clearCounters = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final dark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              title: Text(l.clearUpdates),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.clearUpdatesPrompt),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: clearCounters,
                        onChanged: (v) =>
                            setDialogState(() => clearCounters = v ?? true),
                      ),
                      Expanded(child: Text(l.clearNewChaptersCounters)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l.clear),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.clearUpdates(clearNewChapters: clearCounters);
    if (!mounted) return;
    ref.invalidate(updatesProvider);
    await _refresh();
    if (!mounted) return;
    showIosToast(
      context,
      message: l.clearUpdates,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updatesAsync = ref.watch(updatesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: TabHeader(
        mode: usesWideLayout(context)
            ? TabHeaderMode.fixed
            : TabHeaderMode.collapsing,
        title: AppLocalizations.of(context).updates,
        searchBar: _buildSearchBar(context),
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
                      icon: MdiIcons.rss,
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
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return YomouSearchBar.tappable(
      hintText: AppLocalizations.of(context).searchManga,
      trailing: AppSheetPress(
        onTap: () async {
          final action = await showIosMenuPanel<String>(
            context,
            children: [
              IosMenuRow(
                icon: MdiIcons.refresh,
                label: AppLocalizations.of(context).refresh,
                onTap: () => Navigator.pop(context, 'refresh'),
              ),
              const IosMenuDivider(),
              IosMenuRow(
                icon: MdiIcons.deleteSweepOutline,
                label: AppLocalizations.of(context).clearUpdates,
                onTap: () => Navigator.pop(context, 'clear'),
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
                icon: MdiIcons.cogOutline,
                label: AppLocalizations.of(context).settings,
                onTap: () => Navigator.pop(context, 'settings'),
              ),
            ],
          );
          if (!mounted) return;
          if (action == 'refresh') {
            await _refresh();
          } else if (action == 'clear') {
            await _clearUpdatesDialog();
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
            MdiIcons.dotsVertical,
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
                    MdiIcons.refresh,
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
                    heroTag: mangaCoverHeroTag(
                      sourceId: update.sourceId,
                      mangaId: update.mangaId,
                    ),
                  ),
                ),
              );
            },
            leading: Stack(
              children: [
                MangaCoverHero(
                  tag: mangaCoverHeroTag(
                    sourceId: update.sourceId,
                    mangaId: update.mangaId,
                  ),
                  child: ClipRRect(
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
                          color: amoled(context, 0xFF2C2C2E),
                          alignment: Alignment.center,
                          child: const Icon(
                            MdiIcons.bookOpenVariant,
                            color: Colors.white38,
                          ),
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
