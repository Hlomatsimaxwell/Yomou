import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/data/providers/source_sort.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/features/source_management/screens/manga_grid_screen.dart';
import 'package:yomou/features/source_management/screens/source_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/source_icon.dart';

class ManageSourcesScreen extends ConsumerStatefulWidget {
  const ManageSourcesScreen({super.key});

  @override
  ConsumerState<ManageSourcesScreen> createState() =>
      _ManageSourcesScreenState();
}

class _ManageSourcesScreenState extends ConsumerState<ManageSourcesScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sources = ref.watch(sortedSourceRowsProvider);
    final disableNsfw = ref.watch(disableNsfwProvider);
    // Reordering only means anything in Manual: with any other sort the list is
    // derived, so a drag would be undone on the next rebuild.
    final canReorder = ref.watch(sourceSortOrderProvider) == SourceSortOrder.manual;

    final filteredSources = sources.where((source) {
      if (_searchQuery.isEmpty) return true;
      return source['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
    }).toList();
    // Search narrows the rows, so a drag while filtering would move a row past
    // hidden ones. Reorder only on the unfiltered list.
    final reorderable = canReorder && _searchQuery.isEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            MdiIcons.arrowLeft,
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
                  hintText: AppLocalizations.of(context).searchSources,
                  hintStyle: TextStyle(
                    color: dark ? Colors.white54 : Colors.black54,
                  ),
                  border: InputBorder.none,
                ),
              )
            : Text(
                AppLocalizations.of(context).manageSources,
                style: TextStyle(
                  color: dark ? Colors.white : const Color(0xFF1C1B1F),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? MdiIcons.close : MdiIcons.magnify,
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
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: AppSheetPress(
              onTap: () {
                showIosMenuPanel(
                  context,
                  children: [
                    MenuToggleRow(
                      label: AppLocalizations.of(context).disableNsfw,
                      value: disableNsfw,
                      onChanged: (v) => ref
                          .read(cacheSettingsProvider.notifier)
                          .setDisableNsfw(v),
                    ),
                  ],
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  MdiIcons.dotsVertical,
                  color: (dark ? Colors.white : const Color(0xFF1C1B1F))
                      .withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildList(
        context,
        filteredSources,
        reorderable: reorderable,
        canReorder: canReorder,
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Map<String, dynamic>> sources, {
    required bool reorderable,
    required bool canReorder,
  }) {
    Widget tile(BuildContext context, int index) {
      final source = sources[index];
      final sourceName = source['name'] as String;
      final isPinned = source['isPinned'] == true;
      final isEnabled = isSourceEnabled(source);
      final activeSourceId = ref.read(currentSourceProvider).id;
      final isActive = getSourceByName(sourceName).id == activeSourceId;
      final dark = Theme.of(context).brightness == Brightness.dark;
      final l = AppLocalizations.of(context);

      return ListTile(
        // ReorderableListView identifies rows by key; the source name is
        // stable and unique.
        key: ValueKey(sourceName),
        onTap: () {
          if (!isEnabled) {
            showIosToast(
              context,
              message: l.cannotSelectDisabledSource,
              duration: const Duration(seconds: 2),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MangaGridScreen(sourceName: sourceName),
            ),
          );
        },
        // Long-press drag is the reorder gesture; when it is unavailable, say
        // why instead of leaving the press dead.
        onLongPress: reorderable
            ? null
            : () {
                showIosToast(
                  context,
                  message: canReorder
                      ? l.sourcesReorderClearSearch
                      : l.sourcesReorderManualOnly,
                  duration: const Duration(seconds: 2),
                );
              },
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Opacity(
          opacity: isEnabled ? 1 : 0.4,
          child: SizedBox(
            width: 56,
            height: 56,
            child: SourceIcon(
              name: sourceName,
              iconUrl: source['iconUrl'] as String? ?? '',
            ),
          ),
        ),
        title: Row(
          children: [
            if (isPinned) ...[
              Icon(
                MdiIcons.pin,
                color: dark ? Colors.white30 : const Color(0xFFBDBDBD),
                size: 12,
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                sourceName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: (dark ? Colors.white : const Color(0xFF212121))
                      .withValues(alpha: isEnabled ? 1 : 0.4),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          isEnabled ? source['language'] as String : l.disabled,
          style: TextStyle(
            color: (dark ? Colors.white54 : const Color(0xFF9E9E9E))
                .withValues(alpha: isEnabled ? 1 : 0.4),
            fontSize: 12,
          ),
        ),
        trailing: IosMenuButton<String>(
          items: [
            IosMenuItem(
              value: 'top',
              label: AppLocalizations.of(context).toTop,
              icon: MdiIcons.formatVerticalAlignTop,
            ),
            IosMenuItem(
              value: 'pin',
              label: AppLocalizations.of(context).pin,
              icon: isPinned
                  ? MdiIcons.checkboxBlank
                  : MdiIcons.checkboxBlankOutline,
            ),
            IosMenuItem(
              value: 'enabled',
              label: isEnabled ? l.disableSource : l.enableSource,
              icon: isEnabled
                  ? MdiIcons.pauseCircleOutline
                  : MdiIcons.playCircleOutline,
            ),
            IosMenuItem(
              value: 'shortcut',
              label: AppLocalizations.of(context).createShortcut,
              icon: MdiIcons.openInNew,
            ),
            IosMenuItem(
              value: 'settings',
              label: AppLocalizations.of(context).settings,
              icon: MdiIcons.cogOutline,
            ),
          ],
          onSelected: (value) {
            if (value == 'top') {
              ref.read(sourcesProvider.notifier).moveToTop(sourceName);
            } else if (value == 'pin') {
              ref.read(sourcesProvider.notifier).togglePin(sourceName);
            } else if (value == 'enabled') {
              if (isEnabled && isActive) {
                showIosToast(
                  context,
                  message: l.cannotDisableActiveSource,
                  duration: const Duration(seconds: 2),
                );
              } else {
                ref.read(sourcesProvider.notifier).toggleEnabled(sourceName);
              }
            } else if (value == 'settings') {
              final src = getSourceByName(sourceName);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SourceSettingsScreen(
                    sourceId: src.id,
                    sourceName: sourceName,
                  ),
                ),
              );
            }
          },
        ),
      );
    }

    if (!reorderable) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: sources.length,
        itemBuilder: tile,
      );
    }

    // Long-press-the-row drag on every platform (the default handles only
    // appear on desktop and would sit under the trailing menu).
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      buildDefaultDragHandles: false,
      itemCount: sources.length,
      onReorder: (oldIndex, newIndex) {
        // ReorderableListView reports the gap before the row was lifted, so a
        // downward move is one index too far.
        if (newIndex > oldIndex) newIndex -= 1;
        ref.read(sourcesProvider.notifier).reorder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) => ReorderableDelayedDragStartListener(
        // The key has to sit on the direct child of the list, which is this
        // listener rather than the tile it wraps.
        key: ValueKey(sources[index]['name'] as String),
        index: index,
        child: tile(context, index),
      ),
    );
  }
}
