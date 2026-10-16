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
    final dark = Theme.of(context).brightness == Brightness.dark;
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

    Widget sectionDivider() => const SizedBox(height: 6);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        // Same rule as SettingsAppBar: no back arrow when this screen is the
        // detail pane of a two-pane settings layout, because there is nothing
        // behind it to go back to.
        leading: SettingsPaneScope.of(context)
            ? const SizedBox.shrink()
            : IconButton(
                icon: Icon(
                  MdiIcons.arrowLeft,
                  color: dark ? Colors.white : const Color(0xFF1C1B1F),
                ),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          l.settingsMangaSources,
          style: TextStyle(
            color: dark ? Colors.white : const Color(0xFF1C1B1F),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: CappedContentWidth(child: ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _row(
          icon: MdiIcons.sortAscending,
          title: l.sourcesSortingOrder,
          subtitle: _sortLabel(sortOrder, l),
          trailing: _chevron(),
          onTap: _pickSort,
        ),
        sectionDivider(),
        _row(
          icon: MdiIcons.newspaperVariantOutline,
          title: l.sourcesManage,
          subtitle: l.settingsMangaSourcesSubtitle(enabledCount, totalCount),
          trailing: _chevron(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageSourcesScreen(),
              ),
            );
          },
        ),
        sectionDivider(),
        _row(
          icon: MdiIcons.viewGridOutline,
          title: l.sourcesShowInGrid,
          trailing: Switch(
            value: showInGrid,
            onChanged: (v) =>
                ref.read(cacheSettingsProvider.notifier).setShowSourcesInGrid(v),
          ),
        ),
        sectionDivider(),
        _row(
          icon: MdiIcons.checkboxBlankCircleOutline,
          title: l.sourcesEnableAll,
          trailing: Switch(
            value: enableAll,
            onChanged: _toggleEnableAll,
          ),
        ),
        sectionDivider(),
        _row(
          icon: MdiIcons.shieldOutline,
          title: l.disableNsfw,
          trailing: Switch(
            value: enabled,
            onChanged: (v) =>
                ref.read(cacheSettingsProvider.notifier).setDisableNsfw(v),
          ),
        ),
        sectionDivider(),
        _row(
          icon: MdiIcons.refresh,
          title: l.sourcesChooseMirror,
          trailing: Switch(
            value: chooseMirror,
            onChanged: (v) => ref
                .read(cacheSettingsProvider.notifier)
                .setChooseMirrorAutomatically(v),
          ),
        ),
        sectionDivider(),
        _row(
          icon: MdiIcons.linkVariant,
          title: l.sourcesHandleLinks,
          trailing: Switch(
            value: handleLinks,
            onChanged: (v) =>
                ref.read(cacheSettingsProvider.notifier).setHandleLinks(v),
          ),
        ),
        sectionDivider(),
        _row(
          icon: MdiIcons.eyeOffOutline,
          title: l.sourcesIncognitoNsfw,
          subtitle: _incognitoLabel(incognitoMode, l),
          trailing: _chevron(),
          onTap: _pickIncognito,
        ),
        sectionDivider(),
        _row(
          icon: MdiIcons.databaseOutline,
          title: l.sourcesCatalog,
          subtitle: l.sourcesCatalogSubtitle,
          enabled: false,
        ),
      ],
    )),
    );
  }

  Widget _chevron() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Icon(
      MdiIcons.chevronRight,
      size: 20,
      color: dark ? Colors.white30 : Colors.black26,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final charcoal = dark ? Colors.white : const Color(0xFF1C1B1F);
    final muted = dark ? Colors.white54 : const Color(0xFF9E9E9E);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 4,
        ),
        leading: Icon(icon, size: 24, color: enabled ? charcoal : muted),
        title: Text(
          title,
          style: TextStyle(
            color: charcoal,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: muted,
                    fontSize: 13,
                  ),
                ),
              ),
        trailing: trailing,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}