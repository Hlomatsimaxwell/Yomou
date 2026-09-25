import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/core/widgets/ios/ios_menu.dart';
import 'package:yomou/features/source_management/screens/manga_grid_screen.dart';
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
    final sources = ref.watch(visibleSourceRowsProvider);
    final activeSourceId = ref.watch(currentSourceProvider).id;
    final disableNsfw = ref.watch(disableNsfwProvider);
    final sortOrder = ref.watch(sourceSortOrderProvider);
    final l = AppLocalizations.of(context);

    final filteredSources = sources.where((source) {
      if (_searchQuery.isEmpty) return true;
      return source['name'].toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
    }).toList();
    if (sortOrder == 'name') {
      filteredSources.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
    }

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
                  RemixIcons.more_2_line,
                  color: (dark ? Colors.white : const Color(0xFF1C1B1F))
                      .withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: filteredSources.length,
        itemBuilder: (context, index) {
          final source = filteredSources[index];
          final sourceName = source['name'] as String;
          final isPinned = source['isPinned'] == true;
          final isEnabled = isSourceEnabled(source);
          final isActive = getSourceByName(sourceName).id == activeSourceId;

          return ListTile(
            // --- ADDED ONTAP LOGIC HERE ---
            onTap: () {
              if (!isEnabled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l.cannotSelectDisabledSource),
                    duration: const Duration(seconds: 2),
                  ),
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
            // ------------------------------
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
                    RemixIcons.pushpin_2_fill,
                    color: dark
                        ? Colors.white30
                        : const Color(0xFFBDBDBD),
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
                color: (dark
                        ? Colors.white54
                        : const Color(0xFF9E9E9E))
                    .withValues(alpha: isEnabled ? 1 : 0.4),
                fontSize: 12,
              ),
            ),
            trailing: IosMenuButton<String>(
              items: [
                IosMenuItem(
                  value: 'top',
                  label: AppLocalizations.of(context).toTop,
                  icon: RemixIcons.align_top,
                ),
                IosMenuItem(
                  value: 'pin',
                  label: AppLocalizations.of(context).pin,
                  icon: isPinned
                      ? RemixIcons.checkbox_fill
                      : RemixIcons.checkbox_blank_line,
                ),
                IosMenuItem(
                  value: 'enabled',
                  label: isEnabled ? l.disableSource : l.enableSource,
                  icon: isEnabled
                      ? RemixIcons.pause_circle_line
                      : RemixIcons.play_circle_line,
                ),
                IosMenuItem(
                  value: 'shortcut',
                  label: AppLocalizations.of(context).createShortcut,
                  icon: RemixIcons.external_link_line,
                ),
                IosMenuItem(
                  value: 'settings',
                  label: AppLocalizations.of(context).settings,
                  icon: RemixIcons.settings_3_line,
                ),
              ],
              onSelected: (value) {
                if (value == 'top') {
                  ref.read(sourcesProvider.notifier).moveToTop(sourceName);
                } else if (value == 'pin') {
                  ref.read(sourcesProvider.notifier).togglePin(sourceName);
                } else if (value == 'enabled') {
                  if (isEnabled && isActive) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l.cannotDisableActiveSource),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else {
                    ref
                        .read(sourcesProvider.notifier)
                        .toggleEnabled(sourceName);
                  }
                }
              },
            ),
          );
        },
      ),
    );
  }
}
