import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/features/settings/screens/appearance_settings_screen.dart';
import 'package:yomou/features/settings/screens/manga_sources_settings_screen.dart';
import 'package:yomou/features/settings/screens/backup_restore_screen.dart';
import 'package:yomou/features/settings/screens/notification_settings_screen.dart';
import 'package:yomou/features/settings/screens/storage_settings_screen.dart';
import 'package:yomou/features/settings/screens/downloads_settings_screen.dart';
import 'package:yomou/features/settings/screens/reader_settings_screen.dart';
import 'package:yomou/features/settings/widgets/settings_group.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/widgets/m3_components.dart';

/// One row in the settings hub.
///
/// [screen] is the category's own screen. It is pushed as a route on a phone
/// and rendered into the detail pane on a wide window, so both layouts show the
/// same categories and the same screens -- the only difference is whether the
/// selection replaced a route or a pane.
class _Category {
  const _Category({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.screen,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Null for a category that is not a screen of its own: [About] opens a
  /// dialog, and [Services] has nothing behind it yet.
  final Widget? screen;

  bool get hasScreen => screen != null;
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialCategory});

  /// Which category the detail pane opens on, by its settings title.
  ///
  /// Set when settings is reached from somewhere that already knows which
  /// section the reader wants -- the reader's own menu opening Settings, for
  /// instance. Those entry points want the two-pane layout with Reader
  /// selected, not a bare push of [ReaderSettingsScreen]: a page with no
  /// category list beside it gives no way to reach any other settings and no
  /// sign the user is inside settings at all.
  ///
  /// Matched by title rather than index so inserting a category cannot silently
  /// point this at the wrong screen. An unmatched or null [initialCategory]
  /// falls back to the first category, which is what a plain open already did.
  final String? initialCategory;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Which category the detail pane is showing. Null until the first build so
  /// the initial selection lands without an extra frame of empty pane.
  int? _selectedIndex;

  /// Resolves [SettingsScreen.initialCategory] to an index into the categories
  /// that have screens, or null when the title matches none of them.
  int? _initialCategoryIndex(List<_Category> selectable) {
    final wanted = widget.initialCategory;
    if (wanted == null) return null;
    final i = selectable.indexWhere((c) => c.title == wanted);
    return i < 0 ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sourceRows =
        ref.watch(sourcesProvider).where((s) => s['name'] != 'Mock Source');
    final sourceList = sourceRows.toList();
    final enabledCount = sourceList.where(isSourceEnabled).length;
    final totalCount = sourceList.length;

    final categories = <_Category>[
      _Category(
        icon: RemixIcons.palette_line,
        title: l.settingsAppearance,
        subtitle: l.settingsAppearanceSubtitle,
        screen: const AppearanceSettingsScreen(),
      ),
      _Category(
        icon: RemixIcons.window_2_line,
        title: l.settingsMangaSources,
        subtitle: l.settingsMangaSourcesSubtitle(enabledCount, totalCount),
        screen: const MangaSourcesSettingsScreen(),
      ),
      _Category(
        icon: RemixIcons.book_open_line,
        title: l.settingsReader,
        subtitle: l.settingsReaderSubtitle,
        screen: const ReaderSettingsScreen(),
      ),
      _Category(
        icon: RemixIcons.refresh_line,
        title: l.settingsStorage,
        subtitle: l.settingsStorageSubtitle,
        screen: const StorageSettingsScreen(),
      ),
      _Category(
        icon: RemixIcons.download_line,
        title: l.settingsDownloads,
        subtitle: l.settingsDownloadsSubtitle,
        screen: const DownloadsSettingsScreen(),
      ),
      _Category(
        icon: RemixIcons.rss_line,
        title: l.settingsNewChapters,
        subtitle: l.settingsNewChaptersSubtitle,
        screen: const NotificationSettingsScreen(),
      ),
      // No screen behind it: tapping this has always done nothing. Now that it
      // can be a selection in a pane, a row that silently does nothing is worse
      // than one that says why.
      _Category(
        icon: RemixIcons.puzzle_2_line,
        title: l.settingsServices,
        subtitle: l.settingsServicesUnavailable,
      ),
      _Category(
        icon: RemixIcons.history_line,
        title: l.settingsBackup,
        subtitle: l.settingsBackupSubtitle,
        screen: const BackupRestoreScreen(),
      ),
    ];

    // Two panes only where there is genuinely room. Below this the app's own
    // side rail has already taken its width, and a category pane on top of
    // that leaves the detail pane narrower than the phone it replaced.
    final twoPane = usesWideLayout(context);

    return Scaffold(
      appBar: SettingsAppBar(title: l.settings),
      body: twoPane
          ? _buildTwoPane(categories)
          : CappedContentWidth(child: _buildCategoryList(categories)),
    );
  }

  Widget _buildTwoPane(List<_Category> categories) {
    // Defaults to the first category so the detail pane is never empty: an
    // empty pane on a large screen reads as a failed load rather than as an
    // invitation to pick something.
    final selectable = categories.where((c) => c.hasScreen).toList();
    final index = _selectedIndex ?? _initialCategoryIndex(selectable) ?? 0;
    final current = selectable[index.clamp(0, selectable.length - 1)];

    return Row(
      children: [
        SizedBox(
          width: kSettingsCategoryPaneWidth,
          // Its own fill, so the two columns are two planes instead of one
          // surface split by a line.
          child: ColoredBox(
            color: SettingsSurfaces.sidebar(context),
            child: _buildCategoryList(
              categories,
              selected: current,
              onSelect: (c) {
                final i = selectable.indexOf(c);
                if (i >= 0) setState(() => _selectedIndex = i);
              },
            ),
          ),
        ),
        VerticalDivider(
          width: 1,
          color: SettingsSurfaces.columnDivider(context),
        ),
        Expanded(
          // The scope is what tells each category screen it is in a pane, so
          // its app bar drops the back arrow that would otherwise pop the whole
          // settings route.
          child: SettingsPaneScope(
            // Tinted here rather than by each category screen: the pane is one
            // surface that the six screens all sit on, so if each painted its
            // own background the seams between them would be the only place the
            // tone could go wrong. A Theme rather than a ColoredBox because
            // every one of those screens is a Scaffold, and a Scaffold paints
            // the theme's background over anything behind it.
            child: Theme(
              data: Theme.of(context).copyWith(
                scaffoldBackgroundColor: SettingsSurfaces.pane(context),
              ),
              child: KeyedSubtree(
                // Keyed on the category so switching panes rebuilds the screen
                // instead of reusing the previous one's element tree.
                key: ValueKey(current.title),
                child: current.screen!,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList(
    List<_Category> categories, {
    _Category? selected,
    ValueChanged<_Category>? onSelect,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final c in categories)
          _buildSettingTile(
            category: c,
            selected: onSelect != null && identical(c, selected),
            onTap: () {
              if (c.hasScreen && onSelect != null) {
                onSelect(c);
                return;
              }
              if (!c.hasScreen) {
                if (c.icon == RemixIcons.information_line) {
                  _showAboutDialog(context);
                }
                return;
              }
              // A phone has no category pane, so tapping a row pushes that
              // category's own screen. [initialCategory] is deliberately not
              // honoured here: it is about which row the *hub* opens on, and on
              // a phone the hub is never on screen by the time a row is tapped.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => c.screen!),
              );
            },
          ),
        _buildAboutTile(context: context),
      ],
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    _showAboutDialogWith(context, info);
  }

  void _showAboutDialogWith(BuildContext context, PackageInfo? info) {
    final l = AppLocalizations.of(context);
    final rows = <List<String>>[
      [l.settingsAboutVersion, info?.version ?? '--'],
      [l.settingsAboutBuild, info?.buildNumber ?? '--'],
      [l.settingsAboutPackage, info?.packageName ?? '--'],
    ];
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            l.settingsAbout,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${row[0]}:  ',
                          style: TextStyle(
                            color: dark ? Colors.white54 : const Color(0xFF49454F),
                          ),
                        ),
                        TextSpan(
                          text: row[1],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: dark ? Colors.white : const Color(0xFF1C1B1F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l.filterCancel,
                style: TextStyle(
                  color: dark ? Colors.white70 : const Color(0xFF49454F),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAboutTile({required BuildContext context}) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final subtitle = info == null
            ? '--'
            : 'Version ${info.version} (${info.buildNumber})';
        return _buildSettingTile(
          category: _Category(
            icon: RemixIcons.information_line,
            title: AppLocalizations.of(context).settingsAbout,
            subtitle: subtitle,
          ),
          onTap: () => _showAboutDialogWith(context, info),
        );
      },
    );
  }

  Widget _buildSettingTile({
    required _Category category,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    // Services has no screen behind it, so it reads as unavailable rather than
    // as a row that happens to do nothing.
    final enabled = category.hasScreen || category.icon == RemixIcons.information_line;
    final foreground = !enabled
        ? (dark ? Colors.white38 : Colors.black38)
        : (selected ? accent : null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        // A filled container rather than a translucent wash over the sidebar:
        // with the detail pane now carrying its own tint, the selection has to
        // be a solid shape to read as the current page instead of as a
        // highlight competing with the pane's colour.
        color: selected
            ? (dark
                ? accent.withValues(alpha: 0.32)
                : accent.withValues(alpha: 0.14))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(category.icon, size: 24, color: foreground),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: TextStyle(
                          fontSize: 15,
                          // Only the current row is bold, so the eye can find
                          // it in a column where every row is a 15pt label.
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          category.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: foreground ??
                                (dark ? Colors.white54 : const Color(0xFF49454F)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}