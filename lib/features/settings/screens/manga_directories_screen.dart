import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/backup/saf_directory_picker.dart';
import 'package:yomou/core/storage/storage_stats.dart';
import 'package:yomou/features/settings/providers/download_settings_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

/// One row on the Local manga directories screen: a real storage location the
/// app reads/writes downloads to. Built-in roots carry their id only — the
/// display title is resolved at build time so locale changes are picked up.
/// Custom entries are SAF tree URIs whose path may fail to resolve.
class _Location {
  const _Location({
    required this.id,
    this.path = '',
    this.customTitle,
    this.writable = true,
  });

  final String id;
  final String path;

  /// Display name for user-added folders (null for the built-in roots).
  final String? customTitle;

  /// Whether Yomou can write here — probed on load so the card can warn.
  final bool writable;

  bool get isCustom => customTitle != null;
}

/// Settings > Downloads > Local manga directories.
///
/// Lists every location Yomou stores reading material in with real capacity
/// stats (free/used via `StatFs`), marks the current default, flags folders
/// Yomou can't write to, and lets the user add folders picked through the
/// system storage access framework or remove the ones they added.
///
/// Like Kotatsu, this screen only *manages* locations. Picking the folder
/// chapters download to is done from the "Downloads folder" row above it.
class MangaDirectoriesScreen extends ConsumerStatefulWidget {
  const MangaDirectoriesScreen({super.key});

  @override
  ConsumerState<MangaDirectoriesScreen> createState() =>
      _MangaDirectoriesScreenState();
}

class _MangaDirectoriesScreenState extends ConsumerState<MangaDirectoriesScreen> {
  List<_Location> _locations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Resolves the locations on disk. Runs from [initState], so it must not
  /// touch `context`/localizations — titles are resolved in [build] instead.
  Future<void> _load() async {
    final settings = ref.read(downloadSettingsProvider);
    final list = <_Location>[];

    final support = await getApplicationSupportDirectory();
    final chapters = p.join(support.path, 'chapters');
    list.add(_Location(
      id: kFolderChapters,
      path: chapters,
      writable: await isDirWritable(chapters),
    ));

    final public = await getPublicDownloadsPath();
    if (public != null) {
      list.add(_Location(
        id: kFolderPublic,
        path: public,
        writable: await isDirWritable(public),
      ));
    }

    final docs = await getApplicationDocumentsDirectory();
    list.add(_Location(
      id: kFolderDocuments,
      path: docs.path,
      writable: await isDirWritable(docs.path),
    ));

    for (final d in settings.customDirs) {
      final id = '$kFolderCustomPrefix${d.uri}';
      // Tree URIs are resolved to real paths so the card can show the folder,
      // read its capacity and probe it; stays empty when unresolvable.
      final path = await resolveDownloadLocationPath(id) ?? '';
      list.add(_Location(
        id: id,
        path: path,
        customTitle: d.title,
        writable: await isDirWritable(path),
      ));
    }
    if (!mounted) return;
    setState(() {
      _locations = list;
      _loading = false;
    });
  }

  Future<void> _showAddSheet() async {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final picked = await showM3ModalSheet<String>(
      context,
      title: l.dlsAddSheetTitle,
      children: [
        ListTile(
          leading: Icon(RemixIcons.folder_add_line, color: cs.primary),
          title: Text(l.dlsAddCustom),
          subtitle: Text(l.dlsAddCustomSubtitle),
          onTap: () => Navigator.pop(context, 'pick'),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel, style: TextStyle(color: cs.primary)),
            ),
          ],
        ),
      ),
    );
    if (picked != 'pick' || !mounted) return;

    final uri = await pickBackupDirectory();
    if (uri == null || !mounted) return;
    final settings = ref.read(downloadSettingsProvider);
    final title = l.dlsCustomName(settings.customDirs.length + 1);
    await ref
        .read(downloadSettingsProvider.notifier)
        .addCustomDir(uri, title);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.dlsDirAdded(title))),
    );
    await _load();
  }

  Future<void> _removeCustom(_Location loc) async {
    if (!loc.id.startsWith(kFolderCustomPrefix)) return;
    await ref
        .read(downloadSettingsProvider.notifier)
        .removeCustomDir(loc.id.substring(kFolderCustomPrefix.length));
    if (!mounted) return;
    await _load();
  }

  /// Display title for a location, localized for the built-in roots.
  String _titleFor(AppLocalizations l, _Location loc) {
    if (loc.customTitle != null) return loc.customTitle!;
    switch (loc.id) {
      case kFolderChapters:
        return l.dlsChaptersName;
      case kFolderPublic:
        return l.dlsPublicName;
      case kFolderDocuments:
        return l.dlsDocumentsName;
      default:
        return l.dlsCustomName(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final settings = ref.watch(downloadSettingsProvider);

    return Scaffold(
      appBar: SettingsAppBar(title: l.dlsDirsTitle),
      body: Stack(
        children: [
          Positioned.fill(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      MediaQuery.paddingOf(context).bottom + 120,
                    ),
                    children: [
                      for (final loc in _locations)
                        _StorageCard(
                          title: _titleFor(l, loc),
                          location: loc,
                          selected: settings.downloadsFolder == loc.id,
                          onRemove: loc.isCustom
                              ? () => _removeCustom(loc)
                              : null,
                        ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              RemixIcons.information_line,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l.dlsWarning,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          Positioned(
            right: 20,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: _AddPill(
              label: l.dlsAdd,
              onTap: _showAddSheet,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating accent pill button used to add a directory.
class _AddPill extends StatelessWidget {
  const _AddPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary,
      borderRadius: BorderRadius.circular(999),
      elevation: 4,
      shadowColor: Colors.black45,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(RemixIcons.add_line, size: 20, color: cs.onPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card for one location: title, mono path, capacity bar with "X available",
/// the default-directory pill, a write-permission warning when applicable and
/// a remove action for user-added folders.
class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.title,
    required this.location,
    required this.selected,
    this.onRemove,
  });

  /// Localized display title, resolved by the parent at build time.
  final String title;
  final _Location location;

  /// Whether this is the folder chapters currently download to.
  final bool selected;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  RemixIcons.hard_drive_2_line,
                  size: 22,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onRemove != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: l.remove,
                            icon: Icon(
                              RemixIcons.delete_bin_line,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            // Never remove the folder downloads currently
                            // write to — switch the default first.
                            onPressed: selected ? null : onRemove,
                          ),
                        ],
                      ],
                    ),
                    if (selected)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l.dlsDefaultMarker,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    if (location.path.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        location.path,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: cs.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _CapacityStat(path: location.path),
                    if (!location.writable)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              RemixIcons.alert_line,
                              size: 14,
                              color: cs.error,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l.dlsNoWritePermission,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: cs.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

/// Free-space row: a thin bar + "X available", or a muted dash when the
/// location isn't a real path (e.g. a SAF tree URI).
class _CapacityStat extends StatelessWidget {
  const _CapacityStat({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    if (path.isEmpty) {
      return Text(
        l.dlsNoStats,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      );
    }
    return FutureBuilder<StorageStats?>(
      future: getStorageStats(path),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        if (stats == null) {
          return Text(
            l.dlsNoStats,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: stats.usedFraction,
                minHeight: 4,
                color: cs.primary,
                backgroundColor: cs.primary.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.dlsAvailable(_formatBytes(stats.freeBytes)),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}