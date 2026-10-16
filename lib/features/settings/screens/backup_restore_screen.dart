import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/backup/backup_picker.dart';
import 'package:yomou/core/backup/backup_restore.dart';
import 'package:yomou/core/backup/kotatsu_backup.dart';
import 'package:yomou/core/backup/tachiyomi_backup.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/notifications/notification_service.dart';
import 'package:yomou/core/theme/amoled.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/settings/screens/import_results_screen.dart';
import 'package:yomou/features/settings/screens/periodic_backups_screen.dart';
import 'package:yomou/features/settings/widgets/tachiyomi_scan_progress.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/m3_components.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  /// Mirrors the missing-title scan into the notification shade as a
  /// Kotatsu-style ongoing progress bar, so the scan stays visible (and keeps
  /// updating) even after the reader leaves the app.
  void _startScanShadeProgress(
    AppLocalizations l,
    TachiyomiImportResult parsed,
  ) {
    final total = parsed.missingMangas.length;
    if (total == 0) return;
    unawaited(
      NotificationService.instance.showBackupProgress(
        id: NotificationService.importResultNotificationId,
        title: l.importScanTitle,
        body: l.importScanProgress(0, total),
        current: 0,
        total: total,
      ),
    );
  }

  void _updateScanShadeProgress(AppLocalizations l, int done, int total) {
    unawaited(
      NotificationService.instance.showBackupProgress(
        id: NotificationService.importResultNotificationId,
        title: l.importScanTitle,
        body: l.importScanProgress(done, total),
        current: done,
        total: total,
      ),
    );
  }

  void _dismissScanShadeProgress() {
    unawaited(
      NotificationService.instance.cancelBackupProgress(
        id: NotificationService.importResultNotificationId,
      ),
    );
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
      showIosToast(context, message: l.tachiyomiExportNone);
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
    final message = '${l.tachiyomiExportDone(result.exported)}$skipped';
    showIosToast(
      context,
      message: message,
    );
    unawaited(
      NotificationService.instance.showBackupResultNotification(
        id: NotificationService.exportResultNotificationId,
        title: l.backupSaved,
        body: message,
      ),
    );
  }

  Future<void> _exportKotatsu() async {
    final l = AppLocalizations.of(context);
    final favorites = await DatabaseHelper.instance.getFavorites();
    final bookmarks = await DatabaseHelper.instance.getAllBookmarks();
    final readingProgress =
        await DatabaseHelper.instance.getAllReadingProgress();

    final result = KotatsuBackupCodec.export(
      favorites: favorites,
      bookmarks: bookmarks,
      readingProgress: readingProgress,
    );

    if (result.exported == 0) {
      if (!mounted) return;
      showIosToast(context, message: l.kotatsuExportNone);
      return;
    }

    final fileName = 'yomou-${DateTime.now().millisecondsSinceEpoch}.bk.zip';
    final saved = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
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
    final message = '${l.kotatsuExportDone(result.exported)}$skipped';
    showIosToast(
      context,
      message: message,
    );
    unawaited(
      NotificationService.instance.showBackupResultNotification(
        id: NotificationService.exportResultNotificationId,
        title: l.backupSaved,
        body: message,
      ),
    );
  }

  Future<void> _importKotatsu() async {
    final l = AppLocalizations.of(context);
    // Captured before any await: the scan is non-blocking, so the reader may
    // leave this screen while it runs. The navigator and provider container
    // survive the route, so the summary still shows and the library still
    // refreshes whenever the scan finishes.
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    final file = await pickBackupFile(extensions: ['zip']);

    if (file == null) return;

    try {
      final pickedBytes = file.files.single.bytes;
      final bytes = pickedBytes ??
          await File(file.files.single.path!).readAsBytes();

      final parsed = KotatsuBackupCodec.import(bytes);
      if (!mounted) return;
      _startScanShadeProgress(l, parsed);
      final resolved = await scanTachiyomiMissingWithProgress(
        context,
        ref,
        parsed,
        onProgress: (done, total) =>
            _updateScanShadeProgress(l, done, total),
      );
      await BackupRestore.applyTachiyomi(resolved);

      bumpHistoryRevision(container);
      bumpFavoritesRevision(container);
      if (resolved.isEmpty) {
        _dismissScanShadeProgress();
        if (!mounted) return;
        showIosToast(context, message: l.kotatsuImportNone);
        return;
      }
      final message = resolved.skipped > 0
          ? '${l.kotatsuImportDone(resolved.imported)} · '
                '${l.importResultsNotImported(resolved.skipped)}'
          : l.kotatsuImportDone(resolved.imported);
      if (mounted) {
        showIosToast(context, message: message);
      }
      unawaited(
        NotificationService.instance.showBackupResultNotification(
          id: NotificationService.importResultNotificationId,
          title: l.importComplete,
          body: message,
        ),
      );
      navigator.push(
        MaterialPageRoute(
          builder: (context) => ImportResultsScreen(result: resolved),
        ),
      );
    } on FormatException {
      _dismissScanShadeProgress();
      if (!mounted) return;
      showIosToast(context, message: l.kotatsuImportInvalid);
    }
  }

  Future<void> _importTachiyomi() async {
    final l = AppLocalizations.of(context);
    // Captured before any await: the scan is non-blocking, so the reader may
    // leave this screen while it runs. The navigator and provider container
    // survive the route, so the summary still shows and the library still
    // refreshes whenever the scan finishes.
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    final file = await pickBackupFile(extensions: ['tachibk', 'json']);

    if (file == null) return;

    try {
      final pickedBytes = file.files.single.bytes;
      final bytes = pickedBytes ??
          await File(file.files.single.path!).readAsBytes();

      final parsed = TachiyomiBackupCodec.import(bytes);
      if (!mounted) return;
      _startScanShadeProgress(l, parsed);
      // The scan is non-blocking, so this screen may be gone by the time it
      // finishes; the completion UI works off the captured values above.
      final resolved = await scanTachiyomiMissingWithProgress(
        context,
        ref,
        parsed,
        onProgress: (done, total) =>
            _updateScanShadeProgress(l, done, total),
      );
      await BackupRestore.applyTachiyomi(resolved);

      bumpHistoryRevision(container);
      bumpFavoritesRevision(container);
      if (resolved.isEmpty) {
        _dismissScanShadeProgress();
        if (!mounted) return;
        showIosToast(context, message: l.tachiyomiImportNone);
        return;
      }
      final message = importFinishedMessage(l, resolved);
      if (mounted) {
        showIosToast(context, message: message);
      }
      unawaited(
        NotificationService.instance.showBackupResultNotification(
          id: NotificationService.importResultNotificationId,
          title: l.importComplete,
          body: message,
        ),
      );
      navigator.push(
        MaterialPageRoute(
          builder: (context) => ImportResultsScreen(result: resolved),
        ),
      );
    } catch (e) {
      _dismissScanShadeProgress();
      if (!mounted) return;
      showIosToast(context, message: l.tachiyomiImportInvalid);
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
      showIosToast(context, message: l.backupFixLibraryNone);
      return;
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    final titles = invalid.take(4).map((r) => '• ${r['title']}').toList();
    final more = invalid.length > 4 ? '\n• …' : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? amoled(context, 0xFF2C2C2E) : Colors.white,
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
    showIosToast(context, message: l.backupFixLibraryDone(removed.length));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: SettingsAppBar(title: l.backupRestore),
      body: CappedContentWidth(child: ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _AppSectionHeader(title: l.kotatsuSectionTitle),
        _BuildButton(
          icon: RemixIcons.stack_line,
          title: l.exportKotatsu,
          subtitle: l.exportKotatsuSubtitle,
          onTap: _exportKotatsu,
        ),
        _BuildButton(
          icon: RemixIcons.archive_drawer_line,
          title: l.importKotatsu,
          subtitle: l.importKotatsuSubtitle,
          onTap: _importKotatsu,
        ),
        const SizedBox(height: 8),
        _AppSectionHeader(title: l.tachiyomiSectionTitle),
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

class _AppSectionHeader extends StatelessWidget {
  const _AppSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color.primary,
        ),
      ),
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