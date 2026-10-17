import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:yomou/core/cache/app_cache.dart';
import 'package:yomou/core/widgets/kotatsu_icon.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/settings/providers/storage_usage_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// What the Storage and network pane's "Data removal" row opens.
///
/// Everything the reader can delete lives here rather than on the pane itself:
/// the pane reports how much space each kind of thing takes, and this is where
/// that space can be given back. It follows Kotatsu-Redo, which keeps its
/// clearing actions in `DataCleanupSettingsFragment` behind the same row.
class DataCleanupScreen extends ConsumerStatefulWidget {
  const DataCleanupScreen({super.key});

  @override
  ConsumerState<DataCleanupScreen> createState() => _DataCleanupScreenState();
}

class _DataCleanupScreenState extends ConsumerState<DataCleanupScreen> {
  late Future<String> _usageFuture;

  @override
  void initState() {
    super.initState();
    _usageFuture = AppImageCache.instance.usageLabel();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final settings = ref.watch(cacheSettingsProvider);
    final notifier = ref.read(cacheSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // A sub-screen rather than a category: unlike a category there is
      // something behind it to leave to, so unlike one it keeps its arrow.
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(MdiIcons.arrowLeft),
          // The arrow means "leave this screen", both in a pane -- where it
          // puts the pane back on the category this hangs off -- and on a
          // window that pushed it, where it pops.
          onPressed: () => SettingsPaneScope.closeScreen(context),
        ),
        title: Text(
          l.storageDataRemoval,
          style: SettingsAppBar.titleStyle.copyWith(color: cs.onSurface),
        ),
      ),
      body: CappedContentWidth(child: SettingsRows(child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 8, left: 8, right: 8),
        children: [
          M3SectionHeader(title: l.storageCacheSection, dividerAbove: false),
          _row(
            leading: const Icon(MdiIcons.imageOutline),
            title: l.storageCacheMaxTitle,
            subtitle: Text(l.storageCacheMaxSubtitle(settings.maxCacheObjects)),
            onTap: () => _showMaxCacheSelector(context, l, notifier),
          ),
          _row(
            leading: const KotatsuIcon('ic_timelapse'),
            title: l.storageCacheStaleTitle,
            subtitle: Text(l.storageCacheStaleSubtitle(settings.staleDays)),
            onTap: () => _showStaleSelector(context, l, notifier),
          ),
          _row(
            leading: const KotatsuIcon('ic_images'),
            title: l.storageClearTitle,
            // Read off disk once for this screen, and again only after a
            // clear, so the row does not re-walk the folder on every rebuild.
            subtitle: FutureBuilder<String>(
              future: _usageFuture,
              builder: (context, snapshot) =>
                  Text(l.storageClearSubtitle(snapshot.data ?? l.storageUnknown)),
            ),
            onTap: () => _confirmClearCache(context, l),
          ),
        ],
      ))),
    );
  }

  Widget _row({
    required Widget leading,
    required String title,
    Widget? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      // Colours, sizes and the leading inset come from the theme, the same as
      // the pane this screen hangs off: it is the next row in the same list.
      leading: leading,
      title: Text(title),
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  void _showMaxCacheSelector(
    BuildContext context,
    AppLocalizations l,
    CacheSettingsNotifier notifier,
  ) {
    const options = [100, 200, 400, 800, 1600];
    showM3ModalSheet(
      context,
      title: l.storageCacheMaxTitle,
      children: [
        for (final value in options)
          ListTile(
            title: Text(l.storageCacheMaxSubtitle(value)),
            trailing: ref.read(cacheSettingsProvider).maxCacheObjects == value
                ? Icon(MdiIcons.check,
                    color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () {
              notifier.setMaxCacheObjects(value);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  void _showStaleSelector(
    BuildContext context,
    AppLocalizations l,
    CacheSettingsNotifier notifier,
  ) {
    const options = [7, 14, 30, 60];
    showM3ModalSheet(
      context,
      title: l.storageCacheStaleTitle,
      children: [
        for (final value in options)
          ListTile(
            title: Text(l.storageCacheStaleSubtitle(value)),
            trailing: ref.read(cacheSettingsProvider).staleDays == value
                ? Icon(MdiIcons.check,
                    color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () {
              notifier.setStaleDays(value);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  Future<void> _confirmClearCache(BuildContext context, AppLocalizations l) async {
    final color = Theme.of(context).colorScheme;
    // Taken before the sheet opens: once it is up and dismissed the method is
    // past an await, so [context] cannot be read again after that point.
    final overlay = Overlay.of(context, rootOverlay: true);
    final confirmed = await showM3ModalSheet<bool>(
      context,
      title: l.storageClearConfirmTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
          child: Text(
            l.storageClearConfirmBody,
            style: TextStyle(
              fontSize: 14,
              color: color.onSurfaceVariant,
            ),
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.storageCancel),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: color.error,
                  foregroundColor: color.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.storageClearTitle),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await clearAppCache();
    if (!mounted) return;
    // The pane's usage bar quotes the same folder this just emptied, so it has
    // to be measured again rather than showing the number it settled on.
    ref.invalidate(storageUsageProvider);
    showIosToastOnOverlay(overlay, message: l.storageClearDone);
    _usageFuture = AppImageCache.instance.usageLabel();
    setState(() {});
  }
}
