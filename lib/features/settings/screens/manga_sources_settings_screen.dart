import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/data/providers/source_sort.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/source_management/screens/manga_sources_screen.dart';
import 'package:yomou/widgets/m3_components.dart';

class MangaSourcesSettingsScreen extends ConsumerStatefulWidget {
  const MangaSourcesSettingsScreen({super.key});

  @override
  ConsumerState<MangaSourcesSettingsScreen> createState() =>
      _MangaSourcesSettingsScreenState();
}

class _MangaSourcesSettingsScreenState
    extends ConsumerState<MangaSourcesSettingsScreen> {
  String _sortLabel(String order, AppLocalizations l) => switch (order) {
        SourceSortOrder.name => l.sourcesSortOrderName,
        SourceSortOrder.popular => l.sourcesSortOrderPopular,
        SourceSortOrder.lastUsed => l.sourcesSortOrderLastUsed,
        SourceSortOrder.popularReliable => l.sourcesSortOrderPopularReliable,
        _ => l.sourcesSortOrderManual,
      };

  String _incognitoLabel(String mode, AppLocalizations l) => switch (mode) {
        'enable' => l.sourcesIncognitoEnable,
        'disable' => l.sourcesIncognitoDisable,
        _ => l.sourcesIncognitoAsk,
      };

  Future<void> _pickSort() async {
    final l = AppLocalizations.of(context);
    final current = ref.read(sourceSortOrderProvider);
    final chosen = await showM3OptionSheet<String>(
      context,
      title: l.sourcesSortingOrder,
      options: [
        for (final order in SourceSortOrder.values)
          (order, _sortLabel(order, l)),
      ],
      selected: current,
    );
    if (chosen == null) return;
    await ref.read(cacheSettingsProvider.notifier).setSourceSortOrder(chosen);
  }

  Future<void> _pickIncognito() async {
    final l = AppLocalizations.of(context);
    final current = ref.read(incognitoModeProvider);
    final chosen = await showM3OptionSheet<String>(
      context,
      title: l.sourcesIncognitoNsfw,
      options: [
        ('enable', l.sourcesIncognitoEnable),
        ('ask', l.sourcesIncognitoAsk),
        ('disable', l.sourcesIncognitoDisable),
      ],
      selected: current,
    );
    if (chosen == null) return;
    await ref.read(cacheSettingsProvider.notifier).setIncognitoMode(chosen);
  }

  Future<void> _toggleEnableAll(bool enable) async {
    final notifier = ref.read(cacheSettingsProvider.notifier);
    await notifier.setEnableAllSources(enable);
    if (enable) {
      ref.read(sourcesProvider.notifier).enableAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final enabled = ref.watch(disableNsfwProvider);
    final sortOrder = ref.watch(sourceSortOrderProvider);
    final showInGrid = ref.watch(showSourcesInGridProvider);
    final enableAll = ref.watch(enableAllSourcesProvider);
    final chooseMirror = ref.watch(chooseMirrorAutomaticallyProvider);
    final handleLinks = ref.watch(handleLinksProvider);
    final incognitoMode = ref.watch(incognitoModeProvider);

    final rows = ref.watch(sourcesProvider).toList();
    final enabledCount = rows.where(isSourceEnabled).length;
    final totalCount = rows.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SettingsAppBar(title: l.settingsMangaSources, contentMargin: 24),
      // The pane's own rhythm: [SettingsRows] holds every row to the same
      // height and the same trailing edge as the other settings panes, and the
      // 8 of list padding is what puts this pane's rows on the same 24px guide
      // as its title (16 that a row insets itself by, plus this 8).
      body: CappedContentWidth(child: SettingsRows(child: ListView(
      // 12 above the first row, then 8 at the sides and the bottom: the pane's
      // title sits in the app bar above this, and 12 is the gap it keeps to the
      // first thing under it.
      padding: const EdgeInsets.only(top: 12, bottom: 8, left: 8, right: 8),
      children: [
        _row(
          icon: MdiIcons.sortAscending,
          title: l.sourcesSortingOrder,
          subtitle: _sortLabel(sortOrder, l),
          onTap: _pickSort,
        ),
        _row(
          icon: MdiIcons.viewGridOutline,
          title: l.sourcesShowInGrid,
          trailing: Switch(
            value: showInGrid,
            onChanged: (v) =>
                ref.read(cacheSettingsProvider.notifier).setShowSourcesInGrid(v),
          ),
        ),
        _row(
          icon: MdiIcons.newspaperVariantOutline,
          title: l.sourcesManage,
          subtitle: l.settingsMangaSourcesSubtitle(enabledCount, totalCount),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageSourcesScreen(),
              ),
            );
          },
        ),
        // Everything about which sources are on and what they show, then the
        // two that only change how a source is reached. The rule carries the
        // same 8 of air a section header gives its own, so a group break doesn't
        // read as a line the row above it is sitting on.
        const Divider(height: 40, thickness: 1),
        _row(
          icon: MdiIcons.checkboxBlankCircleOutline,
          title: l.sourcesEnableAll,
          subtitle: l.sourcesEnableAllSubtitle,
          trailing: Switch(
            value: enableAll,
            onChanged: _toggleEnableAll,
          ),
        ),
        _row(
          icon: MdiIcons.databaseOutline,
          title: l.sourcesCatalog,
          subtitle: l.sourcesCatalogSubtitle,
          enabled: false,
        ),
        _row(
          icon: MdiIcons.shieldOutline,
          title: l.disableNsfw,
          subtitle: l.disableNsfwSubtitle,
          trailing: Switch(
            value: enabled,
            onChanged: (v) =>
                ref.read(cacheSettingsProvider.notifier).setDisableNsfw(v),
          ),
        ),
        _row(
          icon: MdiIcons.eyeOffOutline,
          title: l.sourcesIncognitoNsfw,
          subtitle: _incognitoLabel(incognitoMode, l),
          onTap: _pickIncognito,
        ),
        const Divider(height: 40, thickness: 1),
        _row(
          icon: MdiIcons.refresh,
          title: l.sourcesChooseMirror,
          subtitle: l.sourcesChooseMirrorSubtitle,
          trailing: Switch(
            value: chooseMirror,
            onChanged: (v) => ref
                .read(cacheSettingsProvider.notifier)
                .setChooseMirrorAutomatically(v),
          ),
        ),
        _row(
          icon: MdiIcons.linkVariant,
          title: l.sourcesHandleLinks,
          subtitle: l.sourcesHandleLinksSubtitle,
          trailing: Switch(
            value: handleLinks,
            onChanged: (v) =>
                ref.read(cacheSettingsProvider.notifier).setHandleLinks(v),
          ),
        ),
      ],
    ))),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: ListTile(
        // Colours, sizes and the leading inset all come from the theme now:
        // this pane's rows have to read as the same list as the appearance
        // pane's, which leaves them to the theme rather than restating the
        // scheme's own values.
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: trailing,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}