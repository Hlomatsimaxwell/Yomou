import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/backup/backup_restore.dart';
import 'package:yomou/core/backup/tachiyomi_backup.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/settings/screens/import_results_screen.dart';
import 'package:yomou/features/settings/screens/periodic_backups_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  Future<void> _createBackup() async {
    final history = await DatabaseHelper.instance.getHistory();
    final favorites = await DatabaseHelper.instance.getFavorites();
    final bookmarks = await DatabaseHelper.instance.getAllBookmarks();

    final backup = <String, dynamic>{
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'history': history,
      'favorites': favorites,
      'bookmarks': bookmarks,
    };

    final fileName =
        'yomou-backup-${DateTime.now().millisecondsSinceEpoch}.json';
    final result = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(backup))),
    );

    if (result == null) return;

    final dir = result.replaceAll(RegExp(r'[^/]*$'), '');

    await ref
        .read(cacheSettingsProvider.notifier)
        .setBackupsOutputDirectory(dir);
    await ref
        .read(cacheSettingsProvider.notifier)
        .setLastBackupAt(DateTime.now().millisecondsSinceEpoch);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup saved')),
    );
  }

  Future<void> _restoreBackup() async {
    final l = AppLocalizations.of(context);
    final file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // `.gz` and `.tachibk` are both Tachiyomi backups; `.json` is either
      // format, which is why the file is sniffed rather than chosen here.
      allowedExtensions: ['json', 'tachibk', 'gz'],
      withData: true,
    );

    if (file == null) return;

    try {
      final picked = file.files.single;
      final bytes =
          picked.bytes ?? await File(picked.path!).readAsBytes();

      if (picked.path != null) {
        final dir = picked.path!.replaceAll(RegExp(r'[^/]*$'), '');
        await ref
            .read(cacheSettingsProvider.notifier)
            .setBackupsOutputDirectory(dir);
      }

      final result = await BackupRestore.restore(bytes);
      if (!mounted) return;
      bumpHistoryRevision(ref);
      bumpFavoritesRevision(ref);

      switch (result.format) {
        case BackupFormat.tachiyomi:
          final parsed = result.tachiyomi!;
          if (parsed.mangas.isEmpty && parsed.skipped == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.tachiyomiImportNone)),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImportResultsScreen(result: parsed),
            ),
          );
        case BackupFormat.yomou:
          final restored = result.yomou!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                restored.isEmpty
                    ? l.backupRestoreNone
                    : restored.skippedNewer > 0
                    ? '${l.backupRestoreDone(restored.restored)} · '
                          '${l.backupRestoreKeptNewer(restored.skippedNewer)}'
                    : l.backupRestoreDone(restored.restored),
              ),
            ),
          );
      }
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.tachiyomiImportInvalid)),
      );
    }
  }

  Future<void> _exportTachiyomi() async {
    final l = AppLocalizations.of(context);
    final favorites = await DatabaseHelper.instance.getFavorites();
    final bookmarks = await DatabaseHelper.instance.getAllBookmarks();
    final readingProgress = await DatabaseHelper.instance.getAllReadingProgress();

    final result = TachiyomiBackupCodec.export(
      favorites: favorites,
      bookmarks: bookmarks,
      readingProgress: readingProgress,
    );

    if (result.exported == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.tachiyomiExportNone)),
      );
      return;
    }

    final fileName = 'yomou-${DateTime.now().millisecondsSinceEpoch}.tachibk';
    final saved = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['tachibk'],
      fileName: fileName,
      bytes: result.bytes,
    );

    if (saved == null) return;

    final dir = saved.replaceAll(RegExp(r'[^/]*$'), '');
    await ref
        .read(cacheSettingsProvider.notifier)
        .setBackupsOutputDirectory(dir);
    await ref
        .read(cacheSettingsProvider.notifier)
        .setLastBackupAt(DateTime.now().millisecondsSinceEpoch);

    if (!mounted) return;
    final skipped =
        result.skipped > 0 ? ' (${l.backupSkipped(result.skipped)})' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l.tachiyomiExportDone(result.exported)}$skipped'),
      ),
    );
  }

  Future<void> _importTachiyomi() async {
    final l = AppLocalizations.of(context);
    final file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['tachibk', 'json'],
      withData: true,
    );

    if (file == null) return;

    try {
      final pickedBytes = file.files.single.bytes;
      final bytes = pickedBytes ??
          await File(file.files.single.path!).readAsBytes();

      final parsed = TachiyomiBackupCodec.import(bytes);

      await BackupRestore.applyTachiyomi(parsed);

      if (!mounted) return;
      bumpHistoryRevision(ref);
      bumpFavoritesRevision(ref);
      if (parsed.mangas.isEmpty && parsed.skipped == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.tachiyomiImportNone)),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImportResultsScreen(result: parsed),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.tachiyomiImportInvalid)),
      );
    }
  }

  Future<void> _fixLibrary() async {
    final l = AppLocalizations.of(context);
    final db = DatabaseHelper.instance;
    final invalid = await db.findInvalidLibraryEntries(
      TachiyomiBackupCodec.isInvalidLibraryEntry,
    );
    if (!mounted) return;
    if (invalid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.backupFixLibraryNone)),
      );
      return;
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    final titles = invalid.take(4).map((r) => '• ${r['title']}').toList();
    final more = invalid.length > 4 ? '\n• …' : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: dark ? BorderSide.none : const BorderSide(color: Colors.black12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.backupFixLibraryConfirm(invalid.length),
              style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              '${titles.join('\n')}$more',
              style: TextStyle(
                color: dark ? Colors.white54 : const Color(0xFF49454F),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel, style: TextStyle(color: fg, fontSize: 15)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l.backupFixLibraryRemove,
              style: TextStyle(
                color: dark ? Colors.white : const Color(0xFFB3261E),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final removed = await db.removeLibraryManga(
      invalid.map((r) => r['mangaId'] as String).toList(),
    );
    bumpHistoryRevision(ref);
    bumpFavoritesRevision(ref);
    bumpDownloadsRevision(ref);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.backupFixLibraryDone(removed.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: SettingsAppBar(title: l.backupRestore),
      body: CappedContentWidth(child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _BuildButton(
            icon: RemixIcons.hard_drive_line,
            title: l.createDataBackup,
            subtitle: l.backupSubtitle,
            onTap: _createBackup,
          ),
          _BuildButton(
            icon: RemixIcons.refresh_line,
            title: l.restoreFromBackup,
            subtitle: l.restoreSubtitle,
            onTap: _restoreBackup,
          ),
          const SizedBox(height: 8),
          _BuildButton(
            icon: RemixIcons.upload_2_line,
            title: l.exportTachiyomi,
            subtitle: l.exportTachiyomiSubtitle,
            onTap: _exportTachiyomi,
          ),
          _BuildButton(
            icon: RemixIcons.download_2_line,
            title: l.importTachiyomi,
            subtitle: l.importTachiyomiSubtitle,
            onTap: _importTachiyomi,
          ),
          _BuildButton(
            icon: RemixIcons.scissors_cut_line,
            title: l.backupFixLibrary,
            subtitle: l.backupFixLibrarySubtitle,
            onTap: _fixLibrary,
          ),
          const SizedBox(height: 8),
          _BuildButton(
            icon: RemixIcons.time_line,
            title: l.periodicBackups,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PeriodicBackupsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      )),
    );
  }
}

class _BuildButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _BuildButton({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return ListTile(
      leading: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Icon(icon, size: 26, color: color.onSurfaceVariant),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: color.onSurfaceVariant,
                ),
              ),
            ),
      onTap: onTap,
    );
  }
}