import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/source_management/screens/manga_sources_screen.dart';

/// Center-aligned modal with heavily rounded corners: bold title top-left, a
/// vertical list of thin-line circular radio options, and a single Cancel
/// text button bottom-right (matching the "Sorting order" dialog spec).
Future<String?> showSourceChoiceDialog(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String selected,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final scheme = Theme.of(context).colorScheme;
  final l = AppLocalizations.of(context);

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: dark ? Colors.white : const Color(0xFF1C1B1F),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              for (final option in options) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(dialogContext, option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          option == selected
                              ? RemixIcons.checkbox_circle_fill
                              : RemixIcons.radio_button_line,
                          size: 22,
                          color: option == selected
                              ? scheme.primary
                              : (dark
                                    ? Colors.white38
                                    : const Color(0xFF9E9E9E)),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          option,
                          style: TextStyle(
                            color: dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
                            fontSize: 15,
                            fontWeight: option == selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.primary,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(l.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MangaSourcesSettingsScreen extends ConsumerStatefulWidget {
  const MangaSourcesSettingsScreen({super.key});

  @override
  ConsumerState<MangaSourcesSettingsScreen> createState() =>
      _MangaSourcesSettingsScreenState();
}

class _MangaSourcesSettingsScreenState
    extends ConsumerState<MangaSourcesSettingsScreen> {
  String _sortLabel(String order, AppLocalizations l) => switch (order) {
        'name' => l.sourcesSortOrderName,
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
    final chosen = await showSourceChoiceDialog(
      context,
      title: l.sourcesSortingOrder,
      options: [l.sourcesSortOrderManual, l.sourcesSortOrderName],
      selected: _sortLabel(current, l),
    );
    if (chosen == null) return;
    await ref
        .read(cacheSettingsProvider.notifier)
        .setSourceSortOrder(chosen == l.sourcesSortOrderName ? 'name' : 'manual');
  }

  Future<void> _pickIncognito() async {
    final l = AppLocalizations.of(context);
    final current = ref.read(incognitoModeProvider);
    final chosen = await showSourceChoiceDialog(
      context,
      title: l.sourcesIncognitoNsfw,
      options: [
        l.sourcesIncognitoEnable,
        l.sourcesIncognitoAsk,
        l.sourcesIncognitoDisable,
      ],
      selected: _incognitoLabel(current, l),
    );
    if (chosen == null) return;
    String mode;
    if (chosen == l.sourcesIncognitoEnable) {
      mode = 'enable';
    } else if (chosen == l.sourcesIncognitoDisable) {
      mode = 'disable';
    } else {
      mode = 'ask';
    }
    await ref.read(cacheSettingsProvider.notifier).setIncognitoMode(mode);
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

    final sourceList =
        ref.watch(sourcesProvider).where((s) => s['name'] != 'Mock Source');
    final rows = sourceList.toList();
    final enabledCount = rows.where(isSourceEnabled).length;
    final totalCount = rows.length;

    final divider = dark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE0E0E0);

    Widget sectionDivider() => Divider(
      height: 1,
      thickness: 1,
      color: divider,
    );

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
        title: Text(
          l.settingsMangaSources,
          style: TextStyle(
            color: dark ? Colors.white : const Color(0xFF1C1B1F),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _row(
            icon: RemixIcons.sort_asc,
            title: l.sourcesSortingOrder,
            subtitle: _sortLabel(sortOrder, l),
            trailing: _chevron(),
            onTap: _pickSort,
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.file_list_3_line,
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
            icon: RemixIcons.grid_line,
            title: l.sourcesShowInGrid,
            trailing: Switch(
              value: showInGrid,
              onChanged: (v) =>
                  ref.read(cacheSettingsProvider.notifier).setShowSourcesInGrid(v),
            ),
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.checkbox_circle_line,
            title: l.sourcesEnableAll,
            trailing: Switch(
              value: enableAll,
              onChanged: _toggleEnableAll,
            ),
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.shield_flash_line,
            title: l.disableNsfw,
            trailing: Switch(
              value: enabled,
              onChanged: (v) =>
                  ref.read(cacheSettingsProvider.notifier).setDisableNsfw(v),
            ),
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.refresh_line,
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
            icon: RemixIcons.link,
            title: l.sourcesHandleLinks,
            trailing: Switch(
              value: handleLinks,
              onChanged: (v) =>
                  ref.read(cacheSettingsProvider.notifier).setHandleLinks(v),
            ),
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.eye_off_line,
            title: l.sourcesIncognitoNsfw,
            subtitle: _incognitoLabel(incognitoMode, l),
            trailing: _chevron(),
            onTap: _pickIncognito,
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.database_2_line,
            title: l.sourcesCatalog,
            subtitle: l.sourcesCatalogSubtitle,
            enabled: false,
          ),
        ],
      ),
    );
  }

  Widget _chevron() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Icon(
      RemixIcons.arrow_right_s_line,
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