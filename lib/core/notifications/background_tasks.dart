import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/notifications/download_notification.dart';
import 'package:yomou/core/notifications/notification_service.dart';
import 'package:yomou/core/notifications/notification_settings.dart';
import 'package:yomou/core/notifications/update_checker.dart';
import 'package:yomou/core/storage/storage_stats.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/reader/services/chapter_downloader.dart';
import 'package:yomou/features/reader/services/download_job.dart';
import 'package:yomou/features/reader/services/download_scheduler.dart';
import 'package:yomou/features/settings/providers/download_settings_provider.dart';

/// Reverse-DNS identifier submitted to iOS BGTaskScheduler. Must match the
/// `BGTaskSchedulerPermittedIdentifiers` entry in Info.plist and the AppDelegate
/// registration.
const String updateCheckTaskName = 'com.hlomatsi.yomou.updateCheck';

/// Android WorkManager task name (the value the handler receives).
const String _androidTaskName = 'checkUpdates';

/// Top-level entry point for the background isolate. Must stay top-level and
/// annotated so the compiler keeps it when the app is started headless.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == DownloadScheduler.taskName) {
      return runDownloadJob(inputData);
    }
    // The routine cycle runs as a foreground service (see
    // registerUpdateCheckTask), and its note is ours to repaint: a silent
    // "check in progress" line, gone the moment the cycle ends, mirroring
    // the reference's track_worker note.
    final service = NotificationService.instance;
    try {
      await service.init();
      await service.showCheckProgress();
    } catch (_) {}
    try {
      await runUpdateCheck();
    } catch (_) {
      // Never surface a failure to the OS; retrying the whole library scan
      // immediately is not useful.
    }
    // Suggestions ride the same routine cycle (see [runSuggestedDigest]).
    try {
      await runSuggestedDigest();
    } catch (_) {}
    try {
      await service.hideCheckProgress();
    } catch (_) {}
    return true;
  });
}

/// Executes one download batch, then reports the result.
///
/// Runs in the headless isolate promoted to a foreground service by
/// WorkManager, so it survives the app being backgrounded. Progress is written
/// to the `download_jobs` row and repainted onto the ongoing notification.
///
/// Cancellation is read back out of the database rather than an in-memory
/// flag: the row is the only state both isolates can agree on. It is sampled
/// once per page, so a cancel can overshoot by a single page — `downloadChapter`
/// deletes the partial directory in that case anyway.
Future<bool> runDownloadJob(Map<String, dynamic>? inputData) async {
  final jobId = inputData?[DownloadScheduler.inputKeyJobId]?.toString();
  if (jobId == null || jobId.isEmpty) return false;

  var job = await DownloadScheduler.load(jobId);
  // Row gone: the job was cancelled from the Downloads screen. Nothing to do,
  // and reporting failure would make WorkManager retry work the user declined.
  if (job == null) return true;
  // Already paused before this run began (paused while queued, or resumed
  // from the note's Resume button): present the paused state instead of
  // exiting silently, since the waits that normally paint it never run.
  if (job.status == DownloadJobStatus.paused) {
    await DownloadNotifications.showPaused(
      jobId: jobId,
      title: job.mangaTitle ?? '',
      coverUrl: job.coverUrl,
      donePages: job.donePages,
      totalPages: job.totalPages,
      doneChapters: job.doneChapters,
      totalChapters: job.totalChapters,
      mangaId: job.mangaId,
      sourceId: job.sourceId,
    );
    return true;
  }
  if (!job.status.isOpen) return true;

  await DownloadNotifications.ensureInitialized();
  await DatabaseHelper.instance.setDownloadJobProgress(
    jobId,
    status: DownloadJobStatus.running.name,
  );
  job = job.copyWith(status: DownloadJobStatus.running);

  var doneChapters = job.doneChapters;
  var donePages = job.donePages;
  var stopped = false;
  String? failure;

  // Repainting the notification and writing the row on every single page would
  // be a lot of platform calls for a 40-page chapter, so coalesce them.
  var lastPaint = DateTime.fromMillisecondsSinceEpoch(0);
  // Reference's ETA: elapsed time over pages done, extended to what remains.
  final jobStart = DateTime.now();
  final jobTitle = job.mangaTitle ?? '';
  final jobCover = job.coverUrl;
  final jobTotalPages = job.totalPages;
  final jobTotalChapters = job.totalChapters;
  final jobMangaId = job.mangaId;
  final jobSourceId = job.sourceId;

  Future<void> repaint(bool force) async {
    final now = DateTime.now();
    if (!force && now.difference(lastPaint).inMilliseconds < 400) return;
    lastPaint = now;
    // Counters only: a Pause or Cancel pressed between pages writes its
    // verdict in status, and this repaint must not overwrite it with
    // `running` — the tail reads the row to decide who owns the batch.
    await DatabaseHelper.instance.touchDownloadJobCounters(
      jobId,
      doneChapters: doneChapters,
      donePages: donePages,
    );
    // Project the batch's own pace forward: seconds per page so far, times
    // the pages that remain, rounded to minutes. The reference computes its
    // "~n min left" the same way, off the download's own throughput.
    int? etaMinutes;
    final elapsed = now.difference(jobStart).inSeconds;
    if (!force && jobTotalPages > 0 && donePages >= 4 && elapsed >= 10) {
      etaMinutes = ((jobTotalPages - donePages) / (donePages / elapsed) / 60)
          .round();
    }
    await DownloadNotifications.showProgress(
      jobId: jobId,
      title: jobTitle,
      coverUrl: jobCover,
      donePages: donePages,
      totalPages: jobTotalPages,
      doneChapters: doneChapters,
      totalChapters: jobTotalChapters,
      indeterminate: jobTotalPages == 0,
      etaMinutes: etaMinutes,
      mangaId: jobMangaId,
      sourceId: jobSourceId,
    );
  }

  for (final chapter in job.remaining) {
    if (await _jobStopped(jobId)) {
      stopped = true;
      break;
    }

    final saved = await ChapterDownloader.downloadChapter(
      mangaId: jobMangaId,
      chapterId: chapter.id,
      pages: chapter.pages,
      headers: job.headers.isEmpty ? null : job.headers,
      networkSourceId: job.sourceId,
      onProgress: (done, total) {
        // A page finished; the stop flag is resampled here so the next
        // `isCancelled` check in the loop sees a fresh value.
        donePages += 1;
        unawaited(_jobStopped(jobId).then((v) => stopped = v));
        unawaited(repaint(false));
      },
      isCancelled: () => stopped,
    );

    if (saved == null || saved.isEmpty) {
      if (stopped) break;
      // Network or write failure for this chapter. Keep whatever landed and
      // record why, rather than silently reporting success.
      failure ??= 'Chapter ${chapter.number} failed';
      break;
    }

    doneChapters += 1;
    final dir = await ChapterDownloader.chapterDir(jobMangaId, chapter.id);
    await DatabaseHelper.instance.addDownload(
      mangaId: jobMangaId,
      chapterId: chapter.id,
      chapterNumber: chapter.number,
      chapterTitle: chapter.title,
      pageCount: saved.length,
      localDir: dir.path,
      pageUrls: jsonEncode(chapter.pages),
    );
    await DatabaseHelper.instance.upsertManga(
      mangaId: jobMangaId,
      title: job.mangaTitle ?? 'Unknown',
      coverUrl: jobCover,
      sourceId: job.sourceId,
    );
    await repaint(true);
  }

  final completed = !stopped && failure == null;

  // Re-read the row: whatever stopped this batch wrote its status from
  // outside (pause or cancel from the note's buttons), and the reading
  // decides what this worker owns afterwards. A paused row must survive as
  // paused — the worker stamping cancelled over it would orphan the batch
  // the Resume button can't bring back — and a cancelled or gone row means
  // the user dismissed the batch, so neither its progress nor its notes are
  // ours to resurrect.
  final row = await DatabaseHelper.instance.getDownloadJobRow(jobId);
  final rowStatus = DownloadJobStatus.parse(row?['status'] as String?);
  if (row == null || rowStatus == DownloadJobStatus.cancelled) {
    await DownloadNotifications.cancel(jobId);
    return true;
  }
  if (rowStatus == DownloadJobStatus.paused) {
    await DatabaseHelper.instance.setDownloadJobProgress(
      jobId,
      status: DownloadJobStatus.paused.name,
      doneChapters: doneChapters,
      donePages: donePages,
    );
    await DownloadNotifications.showPaused(
      jobId: jobId,
      title: jobTitle,
      coverUrl: jobCover,
      donePages: donePages,
      totalPages: jobTotalPages,
      doneChapters: doneChapters,
      totalChapters: jobTotalChapters,
      mangaId: jobMangaId,
      sourceId: jobSourceId,
      error: failure,
    );
    return true;
  }

  final status = failure != null
      ? DownloadJobStatus.failed
      : DownloadJobStatus.completed;

  await DatabaseHelper.instance.setDownloadJobProgress(
    jobId,
    status: status.name,
    doneChapters: doneChapters,
    donePages: donePages,
    error: failure,
  );
  await DownloadNotifications.showResult(
    jobId: jobId,
    title: jobTitle,
    coverUrl: jobCover,
    success: completed,
    doneChapters: doneChapters,
    totalChapters: jobTotalChapters,
    error: failure,
    mangaId: jobMangaId,
    sourceId: jobSourceId,
  );

  // A batch that saved its part and one that stopped are both settled on
  // the row, so the worker always reports success back to WorkManager; the
  // old `!completed` inverted this and made WorkManager re-run finished
  // batches moments later.
  return true;
}

/// True when the job row says stop, or has been deleted outright.
Future<bool> _jobStopped(String jobId) async {
  try {
    final row = await DatabaseHelper.instance.getDownloadJobRow(jobId);
    if (row == null) return true;
    final status = DownloadJobStatus.parse(row['status'] as String?);
    return status == DownloadJobStatus.paused ||
        status == DownloadJobStatus.cancelled ||
        status == DownloadJobStatus.failed;
  } catch (_) {
    // Can't read the row; don't kill an in-flight download over a transient
    // database error.
    return false;
  }
}

/// Checks the whole library for new chapters and posts a notification when
/// anything changed since the last check. Honors the scope/category/NSFW
/// preferences. Callable from the UI isolate too.
Future<void> runUpdateCheck() async {
  final service = NotificationService.instance;
  await service.init();
  if (!await service.isEnabled()) return;

  final prefs = await SharedPreferences.getInstance();
  final scope = await NotificationSettings.lookForUpdates();
  final statuses = await UpdateChecker.checkLibrary(
    disabledSourceIds: disabledSourceIds(sourceRowsFromPrefs(prefs)),
    includeHistory: scope.$2,
    includeFavorites: scope.$1,
    allowedCategories: await NotificationSettings.favoriteCategories(),
    excludeNsfw: !(await NotificationSettings.nsfwAllowed()),
  );

  final lines = <String>[];
  var totalNew = 0;
  var seriesCount = 0;
  for (final status in statuses) {
    if (status.lastNotifiedChapters <= 0) {
      // First time we see this series: record a baseline instead of announcing
      // its entire back catalogue.
      await DatabaseHelper.instance.setLastNotifiedChapters(
        status.mangaId,
        status.liveTotal,
      );
      continue;
    }

    final delta = status.newSinceNotified;
    if (delta > 0) {
      // Commit the baseline before posting so a show() failure can't make us
      // re-announce the same chapters later.
      await DatabaseHelper.instance.setLastNotifiedChapters(
        status.mangaId,
        status.liveTotal,
      );
      await service.showNewChapterNotification(
        mangaId: status.mangaId,
        title: status.title,
        coverUrl: status.coverUrl,
        newCount: delta,
        latestChapterTitle: status.latestChapterTitle,
        sourceId: status.sourceId.isEmpty ? null : status.sourceId,
        nsfw: status.isNsfw,
      );
      totalNew += delta;
      seriesCount += 1;
      lines.add('${status.title} — $delta new');
    }
  }

  if (seriesCount > 0) {
    await service.showNewChaptersGroupSummary(
      seriesCount: seriesCount,
      totalNew: totalNew,
      lines: lines,
    );
  }

  await _logCheck(seriesCount, totalNew, statuses);
  await _autoDownloadNewChapters(statuses);
}

Future<void> _logCheck(
  int seriesCount,
  int totalNew,
  List<LibraryStatus> statuses,
) async {
  final summary = jsonEncode({
    'seriesCount': seriesCount,
    'totalNew': totalNew,
    'scanned': statuses.length,
    'favorite': statuses.where((s) => s.isFavorite).length,
  });
  await DatabaseHelper.instance.addNotificationLog(
    type: 'check',
    summary: summary,
  );
}

/// Minimum pause between two suggested-manga notifications. Surfaced during
/// routine background cycles rather than on a fixed timer, so the app only
/// pings when the user is actually getting updates.
const suggestionDigestInterval = Duration(hours: 8);

/// Opportunistically suggests a manga the user hasn't read yet, based on their
/// top genres. Tasks no work until enough time has passed since the last
/// suggestion, and stays quiet until there is actually reading history: a
/// fresh install only has `getPopularManga` to fall back on, so without that
/// guard the suggestion card would fire the moment the first routine cycle
/// ran after enabling notifications.
Future<void> runSuggestedDigest() async {
  final service = NotificationService.instance;
  await service.init();
  if (!await service.isEnabled()) return;

  final prefs = await SharedPreferences.getInstance();
  final lastMs =
      prefs.getInt(NotificationService.lastSuggestedSentPrefsKey) ?? 0;
  if (DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastMs)) <
      suggestionDigestInterval) {
    return;
  }

  final sourceRows = sourceRowsFromPrefs(prefs);
  final sources = resolveActiveSources(sourceRows);
  if (sources.isEmpty) return;

  final topTags = await DatabaseHelper.instance.getUserTopTags(limit: 5);
  final allowedCategories = await NotificationSettings.favoriteCategories();
  final excludeNsfw = !(await NotificationSettings.nsfwAllowed());

  final libraryIds = <String>{};
  final libraryRows = [
    ...await DatabaseHelper.instance.getHistory(),
    ...await DatabaseHelper.instance.getFavorites(),
  ];
  for (final row in libraryRows) {
    final id = row['mangaId']?.toString();
    if (id != null && id.isNotEmpty) libraryIds.add(id);
  }
  // The popular-source fallback below is for readers nothing in the taste
  // model yet covers, not for an empty device: without any history there is
  // nothing to suggest around, so hold off (the reference's suggestions are
  // history-driven the same way).
  if (libraryIds.isEmpty) return;

  final candidates = <Manga>[];
  for (final source in sources) {
    if (candidates.length >= 3) break;
    try {
      final pool = topTags.isNotEmpty
          ? await source
                .searchMangaByTags(topTags)
                .timeout(const Duration(seconds: 10), onTimeout: () => const [])
          : await source
                .getPopularManga(page: 1)
                .timeout(const Duration(seconds: 10), onTimeout: () => []);
      for (final manga in pool) {
        if (manga.id.isNotEmpty && !libraryIds.contains(manga.id)) {
          candidates.add(manga);
        }
        if (candidates.length >= 3) break;
      }
    } catch (_) {}
  }
  if (candidates.isEmpty) return;

  // Pick the first candidate whose details pass the filters (NSFW/categories),
  // so preferences gate recommendations too.
  for (final candidate in candidates) {
    final detailsSource = sources.firstWhere(
      (s) => s.id == candidate.sourceId,
      orElse: () => sources.first,
    );
    final details = await detailsSource
        .getMangaDetails(candidate.id)
        .then((value) => value, onError: (_) => null);
    if (details == null || details.id.isEmpty) continue;
    if (excludeNsfw && NotificationSettings.tagsAreNsfw(details.tags)) {
      continue;
    }
    if (allowedCategories.isNotEmpty &&
        details.tags.toSet().intersection(allowedCategories).isEmpty) {
      continue;
    }

    await service.showSuggestedManga(
      SuggestedMangaNotification(
        mangaTitle: details.title,
        genres: details.tags,
        chapterCount: details.totalChapters,
        synopsis: details.description,
        coverUrl: details.coverUrl,
        mangaId: candidate.id,
        sourceId: candidate.sourceId,
      ),
    );
    await DatabaseHelper.instance.addNotificationLog(
      type: 'suggestion',
      summary: jsonEncode({
        'title': details.title,
        'coverUrl': details.coverUrl,
      }),
    );
    await prefs.setInt(
      NotificationService.lastSuggestedSentPrefsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    return;
  }
}

/// Downloads newly released chapters for series that already have downloaded
/// chapters ("Manga with downloaded chapters") or were read recently
/// ("Recently read manga"), per the auto-download preference. Never for the
/// default "Never". Bounded so a single background cycle stays small.
Future<void> _autoDownloadNewChapters(List<LibraryStatus> statuses) async {
  final mode = await NotificationSettings.autoDownload();
  if (mode == AutoDownload.never) return;

  final Set<String> targetIds;
  try {
    targetIds = switch (mode) {
      AutoDownload.downloaded =>
        await DatabaseHelper.instance.getMangaIdsWithDownloads(),
      AutoDownload.recentlyRead =>
        await DatabaseHelper.instance.getRecentlyReadMangaIds(
          const Duration(days: 30),
        ),
      AutoDownload.never => <String>{},
    };
  } catch (_) {
    return;
  }
  if (targetIds.isEmpty) return;

  // Background work can't show the cellular prompt, so "Ask every time" is
  // treated as "don't" on mobile data — spending data without consent is the
  // one outcome that must never happen silently.
  try {
    final policy = (await loadDownloadSettings()).cellularNetwork;
    if (policy == kNetworkDeny) return;
    if (policy == kNetworkAsk && await isActiveNetworkMetered()) return;
  } catch (_) {
    // Can't determine the network state — fall through to the preference.
  }

  const seriesBudget = 2;
  const chaptersPerSeries = 3;

  var usedSeries = 0;
  for (final status in statuses) {
    if (usedSeries >= seriesBudget) break;
    final newChapters = status.newSinceRead;
    if (newChapters <= 0 || !targetIds.contains(status.mangaId)) continue;

    final source =
        getSourceBySourceId(status.sourceId) ?? getSourceByName('MangaDex');
    try {
      final chapters = await source.getChapters(status.mangaId);
      final alreadyDown = await DatabaseHelper.instance.getDownloadedChapterIds(
        status.mangaId,
      );
      // Down to the newest unread chapters only.
      var remainingNew = newChapters > 0 ? newChapters : chapters.length;
      var usedChapters = 0;
      for (final chapter in chapters) {
        if (usedChapters >= chaptersPerSeries) break;
        if (usedChapters >= remainingNew) break;
        if (alreadyDown.contains(chapter.id)) continue;
        final pages = await source.getPageUrls(chapter.id);
        if (pages.isEmpty) continue;
        final headers = source.headers;
        final saved = await ChapterDownloader.downloadChapter(
          mangaId: status.mangaId,
          chapterId: chapter.id,
          pages: pages,
          headers: headers,
        );
        if (saved == null || saved.isEmpty) continue;
        final dir = await ChapterDownloader.chapterDir(
          status.mangaId,
          chapter.id,
        );
        await DatabaseHelper.instance.addDownload(
          mangaId: status.mangaId,
          chapterId: chapter.id,
          chapterNumber: double.tryParse(chapter.chapterNumber) ?? 0,
          chapterTitle: chapter.title,
          pageCount: saved.length,
          localDir: dir.path,
          pageUrls: jsonEncode(pages),
        );
        await DatabaseHelper.instance.upsertManga(
          mangaId: status.mangaId,
          title: status.title,
          coverUrl: status.coverUrl,
          sourceId: status.sourceId,
          totalChapters: status.liveTotal,
        );
        usedChapters++;
      }
      if (usedChapters > 0) {
        usedSeries++;
      }
    } catch (_) {
      // skip failed series, try the next
    }
  }
}

/// Schedules the periodic library check according to the current frequency and
/// Wi-Fi preferences. Manual mode cancels any scheduled work. Safe to call on
/// every launch / whenever a related setting changes.
/// Registers the background entry point with the platform.
///
/// Split out from [registerUpdateCheckTask] because the two features are
/// independent: downloads must still be schedulable when the user has turned
/// new-chapter notifications off, and update checks must not be registered
/// twice. Safe to call more than once.
Future<void> ensureWorkManagerInitialized() async {
  if (_workManagerInitialized) return;
  _workManagerInitialized = true;
  // Let the scheduler initialise the plugin on demand if a download is
  // enqueued before this has run.
  DownloadScheduler.attachDispatcher(callbackDispatcher);
  try {
    await Workmanager().initialize(callbackDispatcher);
  } catch (_) {
    // Already registered, or the platform is unavailable. Enqueueing surfaces
    // a real failure if the plugin is genuinely broken.
  }
}

bool _workManagerInitialized = false;

Future<void> registerUpdateCheckTask() async {
  // WorkManager is the Android scheduler; on any other platform there is
  // nothing to register and initializing it throws.
  if (!Platform.isAndroid) return;
  await ensureWorkManagerInitialized();
  final interval = NotificationSettings.intervalFor(
    await NotificationSettings.frequency(),
  );
  if (interval == null) {
    await Workmanager().cancelByUniqueName(updateCheckTaskName);
    return;
  }

  final wifiOnly = await NotificationSettings.isWifiOnly();
  // The check runs the way the reference's tracker worker does: inside a
  // foreground service carrying its own silent progress note. The channel is
  // created first, so the config name lands on the reference's wording.
  await NotificationService.instance.ensureCheckChannel();
  try {
    await Workmanager().registerPeriodicTask(
      updateCheckTaskName,
      _androidTaskName,
      frequency: interval,
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationId: NotificationService.checkNoteId,
        notificationChannelId: 'check_worker',
        notificationChannelName: 'Check for new chapters',
        notificationTitle: 'Check for new chapters',
        notificationText: 'Checking in the background…',
        foregroundServiceType: ForegroundServiceType.dataSync,
      ),
    );
  } catch (e) {
    // Don't crash the app on iOS if BGTaskScheduler registration fails.
    rethrow;
  }
}

/// Cancels the scheduled periodic check (used when the user disables
/// notifications).
Future<void> cancelUpdateCheckTask() async {
  try {
    await Workmanager().cancelByUniqueName(updateCheckTaskName);
  } catch (_) {}
}
