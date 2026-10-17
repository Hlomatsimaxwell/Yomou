import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/widgets/kotatsu_icon.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/settings/providers/reader_settings_provider.dart';
import 'package:yomou/features/settings/providers/storage_usage_provider.dart';
import 'package:yomou/features/settings/screens/data_cleanup_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';
import 'package:yomou/widgets/storage_usage_bar.dart';

/// The Storage and network pane, in the shape Kotatsu-Redo's
/// `pref_network_storage.xml` gives it: how much space the app is using, where
/// some of that space can be given back, and what it is allowed to download
/// ahead of you.
///
/// The inspo's last four rows are missing on purpose. A proxy, DNS over HTTPS,
/// an image proxy and a switch apiece for certificates and connectivity checks
/// are network features this app has no implementation of, so a row naming them
/// would be a row that cannot do anything. They belong on this screen once they
/// are built, not before.
class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() =>
      _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
  /// The policy behind "Preload pages" is the reader's own, so it is named
  /// the same way here as it is there and the two screens cannot disagree.
  String _preloadLabel(AppLocalizations l, String id) => switch (id) {
        kPreloadWifiOnly => l.rsetPreloadWifiOnly,
        kPreloadNever => l.rsetPreloadNever,
        _ => l.rsetPreloadAlways,
      };

  Future<void> _pickPreload() async {
    final l = AppLocalizations.of(context);
    final current = ref.read(readerSettingsProvider).preload;
    final chosen = await showM3OptionSheet<String>(
      context,
      title: l.rsetPreload,
      options: [
        (kPreloadAlways, l.rsetPreloadAlways),
        (kPreloadWifiOnly, l.rsetPreloadWifiOnly),
        (kPreloadNever, l.rsetPreloadNever),
      ],
      selected: current,
    );
    if (chosen == null) return;
    await ref.read(readerSettingsProvider.notifier).setPreload(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final cache = ref.watch(cacheSettingsProvider);
    final cacheNotifier = ref.read(cacheSettingsProvider.notifier);
    final reader = ref.watch(readerSettingsProvider);
    // Null while the figures are still being measured, and stays null if a
    // measurement cannot be taken at all -- off a device the bar is drawn
    // empty rather than as an error across the top of a settings screen.
    final usage =
        ref.watch(storageUsageProvider).value ??
        const StorageUsage(
          savedManga: 0,
          pagesCache: 0,
          otherCache: 0,
          available: 0,
        );

    return Scaffold(
      appBar: SettingsAppBar(title: l.settingsStorage),
      body: CappedContentWidth(child: SettingsRows(child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 8, left: 8, right: 8),
        children: [
          M3SectionHeader(title: l.storageUsageTitle, dividerAbove: false),
          StorageUsageBar(segments: [
            // The three filled wedges, in the reference's own colours rather
            // than the scheme's: see StorageUsageBar's own note.
            StorageUsageSegment(
              label: l.storageSavedManga,
              bytes: usage.savedManga,
              color: StorageUsageBar.savedMangaColor,
            ),
            StorageUsageSegment(
              label: l.storagePagesCache,
              bytes: usage.pagesCache,
              color: StorageUsageBar.pagesCacheColor,
            ),
            StorageUsageSegment(
              label: l.storageOtherCache,
              bytes: usage.otherCache,
              color: StorageUsageBar.otherCacheColor,
            ),
            // The container colour the track itself is painted in, so this
            // reads as the bar's unfilled remainder rather than as a fourth
            // thing competing with the other three.
            StorageUsageSegment(
              label: l.storageAvailable,
              bytes: usage.available,
              color: cs.secondaryContainer,
            ),
          ]),
          _row(
            leading: const KotatsuIcon('ic_clear_all'),
            title: l.storageDataRemoval,
            // A sub-screen of this pane rather than a page over the top of it,
            // the same as Manage sources: the reader keeps the pane they came
            // from, and the app's own navigation beside it.
            onTap: () => SettingsPaneScope.openScreen(
              context,
              const DataCleanupScreen(),
            ),
          ),
          const Divider(height: 40, thickness: 1),
          _row(
            leading: const KotatsuIcon('ic_download'),
            title: l.storageContentPreloading,
            subtitle: l.storagePreloadSubtitle,
            trailing: Switch(
              value: cache.precacheNextChapter,
              onChanged: (_) => cacheNotifier.togglePrecacheNextChapter(),
            ),
          ),
          _row(
            leading: const KotatsuIcon('ic_book_page'),
            title: l.rsetPreload,
            subtitle: _preloadLabel(l, reader.preload),
            onTap: _pickPreload,
          ),
        ],
      ))),
    );
  }

  Widget _row({
    required Widget leading,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      // Colours, sizes and the leading inset all come from the theme, so this
      // pane's rows read as the same list as the one beside it. The glyph is
      // the inspo's own wherever the ported set carries it.
      leading: leading,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
