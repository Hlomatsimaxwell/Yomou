import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:workmanager/workmanager.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/notifications/download_notification.dart';
import 'package:yomou/features/reader/services/download_job.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Registers chapter downloads as WorkManager jobs and keeps our database
/// rows reconciled with the platform's view of them.
///
/// WorkManager is the source of truth for *whether a job is alive*
/// (`getWorkInfo` is served by WorkManager itself on Android); the
/// `download_jobs` table is the source of truth for *what the job is*
/// (chapter list, page counts, progress).
///
/// Pausing is cancel-plus-remember rather than a platform pause — WorkManager
/// has no pause. The row survives as [DownloadJobStatus.paused] with its
/// completed chapters intact, and [resume] re-registers the same [jobId].
class DownloadScheduler {
  const DownloadScheduler._();

  /// Task name the background dispatcher receives for download jobs.
  static const String taskName = 'yomou.downloadJob';

  /// Tag applied to every job, so the whole set can be cancelled or audited.
  static const String tag = 'yomou_download_job';

  /// A batch's chapter list can be tens of kilobytes, and WorkManager caps
  /// `inputData` at 10KB, so the job id is the only thing that crosses into
  /// the worker.
  static const String inputKeyJobId = 'jobId';

  /// Set once at app startup with the same dispatcher handed to
  /// `Workmanager().initialize`, so an enqueue can initialise the plugin if the
  /// app hasn't already done so. When null, initialization is assumed to have
  /// happened during startup.
  static void Function()? _dispatcher;
  static bool _workmanagerReady = false;

  static void attachDispatcher(void Function() dispatcher) {
    _dispatcher = dispatcher;
  }

  static Future<void> ensureInitialized() async {
    if (_workmanagerReady) return;
    final dispatcher = _dispatcher;
    if (dispatcher == null) return;
    _workmanagerReady = true;
    try {
      await Workmanager().initialize(dispatcher);
    } catch (_) {
      // Already initialised. A genuinely broken plugin surfaces at enqueue.
    }
  }

  /// Stable job id for a batch, so resuming reuses the same WorkManager unique
  /// name and the same database row.
  ///
  /// Uses FNV-1a rather than [Object.hash]/[String.hashCode]: those aren't
  /// guaranteed stable across VM restarts or SDK versions, and a changed hash
  /// would orphan the row and orphan the work.
  static String jobIdFor(String mangaId, List<String> chapterIds) {
    final material = '$mangaId|${chapterIds.join(",")}';
    var hash = 0x811c9dc5;
    for (final unit in material.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'dl_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  /// Enqueues (or re-enqueues) a batch and returns its job id.
  ///
  /// [allowMetered] should be false when the user declined mobile data; the
  /// job then carries an unmetered network constraint so it cannot start on
  /// cellular even if the user backgrounds the app. Passing true when the
  /// user has cellular downloads switched off entirely would defeat the
  /// setting, so callers must resolve it first.
  static Future<String> enqueue({
    required String mangaId,
    required List<DownloadJobChapter> chapters,
    String? mangaTitle,
    String? coverUrl,
    String? sourceId,
    Map<String, String>? headers,
    int doneChapters = 0,
    int donePages = 0,
    bool allowMetered = true,
  }) async {
    if (chapters.isEmpty) {
      throw ArgumentError('Cannot enqueue an empty download batch');
    }
    await ensureInitialized();

    final jobId = jobIdFor(
      mangaId,
      chapters.map((c) => c.id).toList(),
    );
    final totalPages = chapters.fold<int>(0, (sum, c) => sum + c.pages.length);

    await DatabaseHelper.instance.upsertDownloadJob(
      jobId: jobId,
      mangaId: mangaId,
      mangaTitle: mangaTitle,
      coverUrl: coverUrl,
      sourceId: sourceId,
      headers: headers,
      chapters: [for (final c in chapters) c.toJson()],
      totalPages: totalPages,
      doneChapters: doneChapters,
      donePages: donePages,
      status: DownloadJobStatus.queued.name,
    );

    final l = _preparingLabel();
    await Workmanager().registerOneOffTask(
      jobId,
      taskName,
      // Only the id crosses into the worker: a batch's page URLs blow past
      // WorkManager's 10KB Data limit, so the payload stays in the database.
      inputData: {inputKeyJobId: jobId},
      constraints: Constraints(
        networkType: allowMetered ? NetworkType.connected : NetworkType.unmetered,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      tag: tag,
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationId: DownloadNotifications.progressNotificationId(jobId),
        notificationChannelId: DownloadNotifications.channelId,
        notificationChannelName: DownloadNotifications.channelName,
        notificationTitle: mangaTitle ?? '',
        notificationText: l,
        foregroundServiceType: ForegroundServiceType.dataSync,
      ),
    );
    return jobId;
  }

  /// Stops a job for good and forgets it. Already-downloaded chapters stay.
  static Future<void> cancel(String jobId) async {
    await _stopPlatform(jobId);
    await DatabaseHelper.instance.deleteDownloadJob(jobId);
  }

  /// Stops a job but keeps the row and its progress so it can be resumed.
  static Future<void> pause(String jobId) async {
    await _stopPlatform(jobId);
    await DatabaseHelper.instance.setDownloadJobProgress(
      jobId,
      status: DownloadJobStatus.paused.name,
    );
  }

  /// Re-registers a paused job. The row is reused, so progress carries over.
  static Future<void> resume(DownloadJob job) async {
    final remaining = job.remaining;
    if (remaining.isEmpty) {
      await DatabaseHelper.instance.setDownloadJobProgress(
        job.jobId,
        status: DownloadJobStatus.completed.name,
      );
      return;
    }
    await DatabaseHelper.instance.setDownloadJobProgress(
      job.jobId,
      status: DownloadJobStatus.queued.name,
    );
    await enqueue(
      mangaId: job.mangaId,
      mangaTitle: job.mangaTitle,
      coverUrl: job.coverUrl,
      sourceId: job.sourceId,
      headers: job.headers,
      chapters: job.chapters,
      doneChapters: job.doneChapters,
      donePages: job.donePages,
      // Resuming is an explicit user action, so the constraint stays open;
      // the cellular policy was already resolved when the job was created.
      allowMetered: true,
    );
  }

  static Future<void> cancelAll() async {
    try {
      await Workmanager().cancelByTag(tag);
    } catch (_) {}
    final rows = await DatabaseHelper.instance.getDownloadJobRows();
    for (final row in rows) {
      await DatabaseHelper.instance.deleteDownloadJob(row['jobId'].toString());
    }
  }

  static Future<void> _stopPlatform(String jobId) async {
    try {
      await Workmanager().cancelByUniqueName(jobId);
    } catch (_) {}
    await DownloadNotifications.cancel(jobId);
  }

  /// Reconciles stored rows with WorkManager.
  ///
  /// A row the platform has never heard of is left alone (it may be a paused
  /// job, which is intentionally not registered). A row the platform knows is
  /// finished, failed or cancelled has its status corrected — the worker
  /// normally writes this itself, but a force-stop or process kill can land
  /// between the two.
  static Future<List<DownloadJob>> reconcile() async {
    final rows = await DatabaseHelper.instance.getDownloadJobRows();
    final jobs = <DownloadJob>[];
    for (final row in rows) {
      var job = _decode(row);
      if (job.status.isActive) {
        final info = await _workInfo(job.jobId);
        if (info == null) {
          // Never registered, or already pruned by WorkManager. A queued job in
          // that state is dead; a running one may simply be mid-registration.
          if (job.status == DownloadJobStatus.queued) {
            job = job.copyWith(
              status: DownloadJobStatus.failed,
              error: 'Job was never picked up',
            );
            await DatabaseHelper.instance.setDownloadJobProgress(
              job.jobId,
              status: job.status.name,
              error: job.error,
            );
          }
        } else {
          final next = switch (info.state) {
            WorkState.running => DownloadJobStatus.running,
            WorkState.scheduled => DownloadJobStatus.queued,
            WorkState.succeeded => DownloadJobStatus.completed,
            WorkState.failed => DownloadJobStatus.failed,
            // A job we paused is cancelled on the platform on purpose, so a
            // cancelled WorkInfo paired with a paused row stays paused.
            WorkState.cancelled => job.status == DownloadJobStatus.paused
                ? DownloadJobStatus.paused
                : DownloadJobStatus.cancelled,
          };
          if (next != job.status) {
            job = job.copyWith(status: next);
            await DatabaseHelper.instance.setDownloadJobProgress(
              job.jobId,
              status: next.name,
            );
          }
        }
      }
      jobs.add(job);
    }
    return jobs;
  }

  /// Jobs the user can currently act on, newest first.
  static Future<List<DownloadJob>> openJobs() async {
    final jobs = await reconcile();
    return jobs.where((j) => j.status.isOpen).toList();
  }

  /// The most recent job for [mangaId], if it is still open. Used to merge a
  /// fresh download into the batch already downloading that series instead of
  /// starting a competing job.
  static Future<DownloadJob?> openJobForManga(String mangaId) async {
    final rows = await DatabaseHelper.instance.getDownloadJobRows(
      statuses: [
        DownloadJobStatus.queued.name,
        DownloadJobStatus.running.name,
        DownloadJobStatus.paused.name,
      ],
    );
    for (final row in rows) {
      if (row['mangaId'] == mangaId) return _decode(row);
    }
    return null;
  }

  static Future<DownloadJob?> load(String jobId) async {
    final row = await DatabaseHelper.instance.getDownloadJobRow(jobId);
    return row == null ? null : _decode(row);
  }

  static Future<WorkInfo?> _workInfo(String jobId) async {
    try {
      return await Workmanager().getWorkInfo(jobId);
    } catch (_) {
      return null;
    }
  }

  static DownloadJob _decode(Map<String, dynamic> row) {
    List<DownloadJobChapter> chapters;
    try {
      chapters = [
        for (final raw
            in (jsonDecode(row['chapters'] as String? ?? '[]') as List))
          DownloadJobChapter.fromJson(raw as Map<String, dynamic>),
      ];
    } catch (_) {
      chapters = const [];
    }
    Map<String, String> headers;
    try {
      headers = {
        for (final e in (jsonDecode(row['headers'] as String? ?? '{}')
            as Map)
          .entries)
          e.key.toString(): e.value.toString(),
      };
    } catch (_) {
      headers = const {};
    }

    return DownloadJob(
      jobId: row['jobId']?.toString() ?? '',
      mangaId: row['mangaId']?.toString() ?? '',
      mangaTitle: row['mangaTitle'] as String?,
      coverUrl: row['coverUrl'] as String?,
      sourceId: row['sourceId'] as String?,
      headers: headers,
      chapters: chapters,
      totalPages: (row['totalPages'] as num?)?.toInt() ?? 0,
      doneChapters: (row['doneChapters'] as num?)?.toInt() ?? 0,
      donePages: (row['donePages'] as num?)?.toInt() ?? 0,
      status: DownloadJobStatus.parse(row['status'] as String?),
      error: row['error'] as String?,
      createdAt: DateTime.tryParse(row['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// Strings needed at enqueue time, before any notification exists. Only the
  /// placeholder body matters; the worker repaints the text as it goes.
  static String _preparingLabel() {
    try {
      return lookupAppLocalizations(
        PlatformDispatcher.instance.locale,
      ).dlgDownloadPreparing;
    } catch (_) {
      return 'Preparing download…';
    }
  }
}
