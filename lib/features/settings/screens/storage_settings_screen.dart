import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/cache/app_cache.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() =>
      _StorageSettingsScreenState();
}
class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
  late Future<String> _usageFuture;

  @override
  void initState() {
    super.initState();
    _usageFuture = _usageLabel();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(cacheSettingsProvider);
    final notifier = ref.read(cacheSettingsProvider.notifier);

    return Scaffold(
      appBar: SettingsAppBar(title: l.settingsStorage),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          M3SectionHeader(title: l.storageCacheSection),
          ListTile(
            title: Text(l.storageCacheMaxTitle),
            subtitle: Text(l.storageCacheMaxSubtitle(settings.maxCacheObjects)),
            trailing: Icon(
              RemixIcons.arrow_right_s_line,
              color: Theme.of(context).colorScheme.outline,
            ),
            onTap: () => _showMaxCacheSelector(context, l, notifier),
          ),
          ListTile(
            title: Text(l.storageCacheStaleTitle),
            subtitle: Text(l.storageCacheStaleSubtitle(settings.staleDays)),
            trailing: Icon(
              RemixIcons.arrow_right_s_line,
              color: Theme.of(context).colorScheme.outline,
            ),
            onTap: () => _showStaleSelector(context, l, notifier),
          ),
          SwitchListTile(
            title: Text(l.storagePreloadTitle),
            subtitle: Text(l.storagePreloadSubtitle),
            value: settings.precacheNextChapter,
            onChanged: (_) => notifier.togglePrecacheNextChapter(),
          ),
          const Divider(),
          FutureBuilder<String>(
            future: _usageFuture,
            builder: (context, snapshot) => ListTile(
              leading: Icon(
                RemixIcons.delete_bin_line,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l.storageClearTitle),
              subtitle: Text(
                l.storageClearSubtitle(snapshot.data ?? l.storageUnknown),
              ),
              onTap: () => _confirmClearCache(context, l),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<String> _usageLabel() {
    return AppImageCache.instance.usageLabel();
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
                ? Icon(RemixIcons.check_line,
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
                ? Icon(RemixIcons.check_line,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.storageClearConfirmTitle),
        content: Text(l.storageClearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.storageCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.storageClearTitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await clearAppCache();
    if (!mounted) return;
    _usageFuture = _usageLabel();
    setState(() {});
    messenger.showSnackBar(
      SnackBar(content: Text(l.storageClearDone)),
    );
  }
}