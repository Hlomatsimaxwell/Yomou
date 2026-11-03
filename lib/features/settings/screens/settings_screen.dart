import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/core/notifications/notification_service.dart';
import 'package:yomou/core/widgets/kotatsu_icon.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/features/settings/screens/about_settings_screen.dart';
import 'package:yomou/features/settings/screens/appearance_settings_screen.dart';
import 'package:yomou/features/settings/screens/accounts_sync_screen.dart';
import 'package:yomou/features/settings/screens/manga_sources_settings_screen.dart';
import 'package:yomou/features/settings/screens/backup_restore_screen.dart';
import 'package:yomou/features/settings/screens/privacy_policy_screen.dart';
import 'package:yomou/features/settings/screens/terms_of_service_screen.dart';
import 'package:yomou/features/settings/screens/reset_settings_screen.dart';
import 'package:yomou/features/settings/screens/notification_settings_screen.dart';
import 'package:yomou/features/settings/screens/storage_settings_screen.dart';
import 'package:yomou/features/settings/screens/downloads_settings_screen.dart';
import 'package:yomou/features/settings/screens/reader_settings_screen.dart';
import 'package:yomou/features/settings/widgets/settings_surfaces.dart';
import 'package:yomou/features/source_management/screens/manga_sources_screen.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/widgets/m3_components.dart';

/// One row in the settings hub.
///
/// [screen] is the category's own screen. It is pushed as a route on a phone
/// and rendered into the detail pane on a wide window, so both layouts show the
/// same categories and the same screens -- the only difference is whether the
/// selection replaced a route or a pane.
class _Category {
  const _Category({
    required this.group,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.screen,
  });

  /// The heading this row sits under. Rows are listed group by group, so the
  /// hub reads as a handful of short sections instead of one long column.
  final String group;

  /// A glyph from the set ported out of Kotatsu-Redo, by asset name.
  final String icon;
  final String title;
  final String subtitle;

  /// Null for a category that is not a screen of its own: [Services] has
  /// nothing behind it yet.
  final Widget? screen;

  bool get hasScreen => screen != null;
}

/// The About row's glyph. It is also used by Terms of service, so nothing may
/// key behaviour off the icon alone.
const _aboutIcon = 'ic_info_outline';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialCategory, this.initialDetail});

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

  /// A screen to open in the detail pane instead of [initialCategory]'s own,
  /// for a sub-screen reached from somewhere that has no pane to open it in.
  ///
  /// Only the wide layout has a pane, so a caller that wants this checks the
  /// window before it gets here -- see [openManageSources]. The reader leaves
  /// it the way they leave any pane screen: by picking a category, which clears
  /// this, or by the screen's own back arrow.
  final Widget? initialDetail;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Which category the detail pane is showing. Null until the first build so
  /// the initial selection lands without an extra frame of empty pane.
  int? _selectedIndex;

  /// The screen the detail pane is showing in place of the selected category,
  /// or null when it is showing the category itself.
  ///
  /// A settings sub-screen is a detail of the category it hangs off rather than
  /// a page of its own, so on a wide window it opens here, over the category,
  /// with the category list still beside it. Nothing about it is history: the
  /// list is how the reader leaves, and picking a category there closes it.
  Widget? _detail;

  /// Whether the hub is filtering itself down to the rows that match
  /// [_searchQuery]. The field takes up no room until it is asked for, so the
  /// hub looks the same as it always did until the search is opened.
  bool _searching = false;

  final TextEditingController _searchQuery = TextEditingController();

  /// The running build, shown as the About row's subtitle. Loaded once so the
  /// hub does not rebuild a FutureBuilder on every keystroke of the search.
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _detail = widget.initialDetail;
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    }).catchError((_) {
      // A platform without package info leaves the subtitle at "--".
    });
  }

  @override
  void dispose() {
    _searchQuery.dispose();
    super.dispose();
  }

  /// Shows [screen] in the detail pane in place of the selected category.
  void _openInPane(Widget screen) => setState(() => _detail = screen);

  /// Puts the detail pane back on the selected category.
  void _closeInPane() {
    if (_detail != null) setState(() => _detail = null);
  }

  void _startSearch() => setState(() => _searching = true);

  void _endSearch() {
    _searchQuery.clear();
    setState(() => _searching = false);
  }

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
    final sourceList = ref.watch(sourcesProvider).toList();
    final disableNsfw = ref.watch(disableNsfwProvider);
    final enabledCount = sourceList
        .where((s) => isSourceEnabled(s) && !(disableNsfw && isNsfwSource(s)))
        .length;
    final totalCount = sourceList.length;

    final categories = <_Category>[
      // Reading: how pages are shown and how the reader behaves.
      _Category(
        group: l.settingsGroupReading,
        icon: 'ic_appearance',
        title: l.settingsAppearance,
        subtitle: l.settingsAppearanceSubtitle,
        screen: const AppearanceSettingsScreen(),
      ),
      _Category(
        group: l.settingsGroupReading,
        icon: 'ic_book_page',
        title: l.settingsReader,
        subtitle: l.settingsReaderSubtitle,
        screen: const ReaderSettingsScreen(),
      ),
      // Finding manga: where titles come from and how new chapters are found.
      _Category(
        group: l.settingsGroupFinding,
        icon: 'ic_manga_source',
        title: l.settingsMangaSources,
        subtitle: l.settingsMangaSourcesSubtitle(enabledCount, totalCount),
        screen: const MangaSourcesSettingsScreen(),
      ),
      // Notifications are a mobile feature (see [NotificationService.supported]):
      // offering the row on a desktop build would be a switch with nothing
      // behind it, so it is absent rather than dead.
      if (NotificationService.supported)
        _Category(
          group: l.settingsGroupFinding,
          icon: 'ic_feed',
          title: l.settingsNewChapters,
          subtitle: l.settingsNewChaptersSubtitle,
          screen: const NotificationSettingsScreen(),
        ),
      // Your data: what the app keeps and how to move or clear it.
      _Category(
        group: l.settingsGroupData,
        icon: 'ic_usage',
        title: l.settingsStorage,
        subtitle: l.settingsStorageSubtitle,
        screen: const StorageSettingsScreen(),
      ),
      _Category(
        group: l.settingsGroupData,
        icon: 'ic_download',
        title: l.settingsDownloads,
        subtitle: l.settingsDownloadsSubtitle,
        screen: const DownloadsSettingsScreen(),
      ),
      _Category(
        group: l.settingsGroupData,
        icon: 'ic_backup_restore',
        title: l.settingsBackup,
        subtitle: l.settingsBackupSubtitle,
        screen: const BackupRestoreScreen(),
      ),
      _Category(
        group: l.settingsGroupData,
        icon: 'ic_user',
        title: l.settingsAccountsSync,
        subtitle: l.settingsAccountsSyncSubtitle,
        screen: const AccountsSyncScreen(),
      ),
      _Category(
        group: l.settingsGroupData,
        icon: 'ic_restore',
        title: l.settingsReset,
        subtitle: l.settingsResetSubtitle,
        screen: const ResetSettingsScreen(),
      ),
      // App: everything about the app itself rather than the library.
      // No screen behind it: tapping this has always done nothing. Now that it
      // can be a selection in a pane, a row that silently does nothing is worse
      // than one that says why.
      _Category(
        group: l.settingsGroupApp,
        icon: 'ic_services',
        title: l.settingsServices,
        subtitle: l.settingsServicesUnavailable,
      ),
      _Category(
        group: l.settingsGroupApp,
        icon: 'ic_lock',
        title: l.privacyPolicy,
        subtitle: l.privacyPolicySubtitle,
        screen: const PrivacyPolicyScreen(),
      ),
      _Category(
        group: l.settingsGroupApp,
        icon: 'ic_info_outline',
        title: l.termsOfService,
        subtitle: l.termsOfServiceSubtitle,
        screen: const TermsOfServiceScreen(),
      ),
      _Category(
        group: l.settingsGroupApp,
        icon: _aboutIcon,
        title: l.settingsAbout,
        subtitle: _packageInfo == null
            ? '--'
            : '${l.settingsAboutVersion} ${_packageInfo!.version}',
        screen: const AboutSettingsScreen(),
      ),
    ];

    // Two panes only where there is genuinely room. Below this the app's own
    // side rail has already taken its width, and a category pane on top of
    // that leaves the detail pane narrower than the phone it replaced.
    final twoPane = usesWideLayout(context);

    final searchAction = IconButton(
      icon: Icon(_searching ? MdiIcons.close : MdiIcons.magnify),
      tooltip: _searching ? l.filterCancel : l.settingsSearchHint,
      onPressed: _searching ? _endSearch : _startSearch,
    );

    // On a wide window the hub's own bar belongs to the menu column, not to the
    // window: it is built inside that column (below) so its title and search
    // end where the two panes divide, and the line between them can run the
    // full height of the screen. Each category screen keeps its own bar on the
    // other side. A phone has no menu column to cap against, so its single bar
    // stays full width over the list.
    if (twoPane) {
      return Scaffold(body: _buildTwoPane(categories, [searchAction]));
    }

    return Scaffold(
      appBar: SettingsAppBar(title: l.settings, actions: [searchAction]),
      body: CappedContentWidth(child: _buildCategoryList(categories)),
    );
  }

  Widget _buildTwoPane(List<_Category> categories, List<Widget> barActions) {
    final l = AppLocalizations.of(context);
    // Defaults to the first category so the detail pane is never empty: an
    // empty pane on a large screen reads as a failed load rather than as an
    // invitation to pick something.
    final selectable = categories.where((c) => c.hasScreen).toList();
    final index = _selectedIndex ?? _initialCategoryIndex(selectable) ?? 0;
    final current = selectable[index.clamp(0, selectable.length - 1)];

    // A sub-screen in the pane is one the reader can back out of, so the pane
    // owns that step: without this the system's back gesture would take the
    // whole of settings with it and land on whatever was open before it.
    return PopScope(
      canPop: _detail == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeInPane();
      },
      child: Row(
        children: [
          SizedBox(
            width: kSettingsCategoryPaneWidth,
            // Its own fill, so the two columns are two planes instead of one
            // surface split by a line.
            child: ColoredBox(
              color: SettingsSurfaces.sidebar(context),
              child: Column(
                children: [
                  // The hub bar sits over the list it acts on and stops at the
                  // column's edge, which is where the divider is: the search icon
                  // lands on the line rather than out at the far right of the
                  // window, and the pane across the line starts with its own
                  // category screen's bar.
                  SettingsAppBar(title: l.settings, actions: barActions),
                  Expanded(
                    child: _buildCategoryList(
                      categories,
                      selected: current,
                      onSelect: (c) {
                        final i = selectable.indexOf(c);
                        if (i >= 0) {
                          // A category is a screen of its own, so picking one
                          // ends any sub-screen the pane was showing.
                          setState(() {
                            _selectedIndex = i;
                            _detail = null;
                          });
                        }
                      },
                    ),
                  ),
                ],
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
            // settings route -- and what lets one of them open a sub-screen here
            // rather than over the top of it. Its two pane callbacks are method
            // tear-offs, so rebuilding the hub does not invalidate the scope.
            child: SettingsPaneScope(
              onOpenScreen: _openInPane,
              onCloseScreen: _closeInPane,
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
                  // Keyed on what the pane is showing so switching between a
                  // category and a sub-screen rebuilds instead of reusing the
                  // previous one's element tree.
                  key: ValueKey(
                    _detail == null ? 'category:${current.title}' : 'detail',
                  ),
                  child: _detail ?? current.screen!,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(
    List<_Category> categories, {
    _Category? selected,
    ValueChanged<_Category>? onSelect,
  }) {
    final l = AppLocalizations.of(context);
    final needle = _searchQuery.text.trim().toLowerCase();
    // An empty needle is not a filter: opening the field and typing nothing
    // leaves the hub exactly as it was, rather than emptying it.
    final filtering = _searching && needle.isNotEmpty;
    final shown = !filtering
        ? categories
        : categories
            .where(
              (c) =>
                  c.title.toLowerCase().contains(needle) ||
                  c.subtitle.toLowerCase().contains(needle),
            )
            .toList();

    return Column(
      children: [
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchQuery,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l.settingsSearchHint,
                prefixIcon: const Icon(MdiIcons.magnify),
                suffixIcon: IconButton(
                  icon: const Icon(MdiIcons.close),
                  onPressed: _endSearch,
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (filtering && shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Text(
                    l.settingsSearchNoResults,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (var i = 0; i < shown.length; i++) ...[
                // A heading is emitted only where the group changes, so a
                // filtered list still shows the heading for whatever survived
                // the search and never repeats one.
                if (i == 0 || shown[i].group != shown[i - 1].group)
                  _buildGroupHeader(
                    shown[i].group,
                    showDivider: i != 0,
                  ),
                _buildSettingTile(
                  category: shown[i],
                  selected:
                      onSelect != null && identical(shown[i], selected),
                  onTap: () {
                    final c = shown[i];
                    if (c.hasScreen && onSelect != null) {
                      onSelect(c);
                      return;
                    }
                    if (!c.hasScreen) return;
                    // A phone has no category pane, so tapping a row pushes
                    // that category's own screen. [initialCategory] is
                    // deliberately not honoured here: it is about which row
                    // the *hub* opens on, and on a phone the hub is never on
                    // screen by the time a row is tapped.
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => c.screen!),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// A short heading above each run of rows that share a [.._Category.group].
  ///
  /// Like Kotatsu-Redo's Material 3 preference categories, the heading is
  /// separated from the section above it by a full-width hairline. The first
  /// heading in the list has nothing above it to separate, so it omits the
  /// line rather than drawing one just under the app bar.
  Widget _buildGroupHeader(String title, {bool showDivider = true}) {
    final color = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            // Dimmer than the theme's outline so the sections read as one
            // surface rather than as a stack of boxed cards.
            color: color.outlineVariant.withValues(alpha: 0.4),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color.primary,
            ),
          ),
        ),
      ],
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
    final enabled = category.hasScreen;
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
                  child: KotatsuIcon(category.icon, size: 24, color: foreground),
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

/// Opens the sources list the way this window expects it.
///
/// On a wide window that means the settings hub with [ManageSourcesScreen] in
/// its detail pane and the category it hangs off selected beside it, which is
/// how this layout shows a settings sub-screen: the category list stays put as
/// the way back out, and the pane shows the screen the row named. A phone has
/// no pane, so it is a page of its own, as it always was.
///
/// The decision is out here rather than in [SettingsScreen] because it is a
/// question about the window, and [SettingsScreen] is one half of the answer.
void openManageSources(BuildContext context) {
  if (!usesWideLayout(context)) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageSourcesScreen()),
    );
    return;
  }
  final category = AppLocalizations.of(context).settingsMangaSources;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SettingsScreen(
        initialCategory: category,
        initialDetail: const ManageSourcesScreen(),
      ),
    ),
  );
}