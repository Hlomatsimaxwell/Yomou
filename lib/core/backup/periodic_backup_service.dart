import 'package:yomou/core/backup/backup_schedule.dart';
import 'package:yomou/core/backup/google_drive_config.dart';
import 'package:yomou/core/backup/google_drive_service.dart';
import 'package:yomou/core/backup/kotatsu_backup.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';

enum PeriodicBackupOutcome {
  /// The user has not turned automatic backups on.
  disabled,

  /// Not enough time has passed since the last successful backup.
  notDue,

  /// Another run is already in flight in this process.
  busy,

  /// This build has no OAuth client, so sign-in would fail natively.
  notConfigured,

  /// Nothing stored to restore a session from, or the platform declined.
  notSignedIn,

  /// The library has nothing worth archiving.
  empty,

  uploaded,
  failed,
}

class PeriodicBackupResult {
  const PeriodicBackupResult(this.outcome, {this.fileName, this.error});

  final PeriodicBackupOutcome outcome;
  final String? fileName;
  final String? error;

  bool get uploaded => outcome == PeriodicBackupOutcome.uploaded;
}

/// Runs the automatic backup when the app is opened or resumed.
///
/// There is deliberately no background scheduler here: a headless isolate
/// cannot drive `google_sign_in`'s interactive flow, and iOS gives no interval
/// guarantee anyway. Checking on launch is dull but predictable, and it is the
/// same code path the manual button uses.
class PeriodicBackupService {
  PeriodicBackupService._();

  /// Static so a resume while a run is in flight is a no-op rather than a
  /// second upload of the same archive.
  static bool _running = false;

  static Future<PeriodicBackupResult> maybeRun({
    required CacheSettings settings,
    GoogleDriveService? drive,
    DateTime? now,
  }) async {
    if (!settings.enablePeriodicBackups) {
      return const PeriodicBackupResult(PeriodicBackupOutcome.disabled);
    }

    final at = now ?? DateTime.now();
    if (!isBackupDue(
      lastBackupAt: settings.lastBackupAt,
      frequency: settings.backupFrequency,
      now: at,
    )) {
      return const PeriodicBackupResult(PeriodicBackupOutcome.notDue);
    }

    if (_running) {
      return const PeriodicBackupResult(PeriodicBackupOutcome.busy);
    }
    _running = true;
    try {
      if (!await GoogleDriveConfig.isSignInConfigured()) {
        return const PeriodicBackupResult(PeriodicBackupOutcome.notConfigured);
      }

      final service = drive ?? GoogleDriveService.instance;
      try {
        await service.restoreSession();
      } catch (_) {
        return const PeriodicBackupResult(PeriodicBackupOutcome.notSignedIn);
      }
      if (!service.isSignedIn) {
        return const PeriodicBackupResult(PeriodicBackupOutcome.notSignedIn);
      }

      final favorites = await DatabaseHelper.instance.getFavorites();
      final bookmarks = await DatabaseHelper.instance.getAllBookmarks();
      final progress = await DatabaseHelper.instance.getAllReadingProgress();
      final export = KotatsuBackupCodec.export(
        favorites: favorites,
        bookmarks: bookmarks,
        readingProgress: progress,
      );
      if (export.exported == 0) {
        return const PeriodicBackupResult(PeriodicBackupOutcome.empty);
      }

      final name = 'yomou-${at.millisecondsSinceEpoch}.bk.zip';
      await service.uploadBackup(bytes: export.bytes, name: name);
      if (settings.deleteOldBackups) {
        try {
          await service.pruneBackups(keep: settings.maxNumberOfBackups);
        } catch (_) {
          // Retention is housekeeping; the backup itself already succeeded.
        }
      }
      return PeriodicBackupResult(
        PeriodicBackupOutcome.uploaded,
        fileName: name,
      );
    } catch (e) {
      return PeriodicBackupResult(
        PeriodicBackupOutcome.failed,
        error: e.toString(),
      );
    } finally {
      _running = false;
    }
  }
}
