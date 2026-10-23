import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/core/notifications/notification_image.dart';
import 'package:yomou/features/reader/services/download_scheduler.dart';

/// A notification's Pause/Cancel button pressed while the app process is not
/// alive. The plugin spawns a bare isolate for this, so everything the
/// handler needs has to be reachable from imports alone: `DownloadScheduler`
/// stops the platform work (best-effort there) and writes the row, which is
/// the one channel the running job's polling loop watches.
@pragma('vm:entry-point')
void downloadNotificationActionHandler(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null) return;
  // The payload is the tap-target JSON (`_encodeProgress`/`_encodeTargetPayload`);
  // the job id rides along so the buttons can name the batch to stop.
  Map? map;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map) map = decoded;
  } catch (_) {
    return;
  }
  final jobId = map?['job']?.toString();
  if (jobId == null || jobId.isEmpty) return;
  final action = response.actionId;
  if (action == DownloadNotifications.pauseActionId) {
    unawaited(DownloadScheduler.pause(jobId));
  } else if (action == DownloadNotifications.cancelActionId) {
    unawaited(DownloadScheduler.cancel(jobId));
  } else if (action == DownloadNotifications.resumeActionId) {
    unawaited(DownloadScheduler.load(jobId).then((job) {
      if (job != null) return DownloadScheduler.resume(job);
    }));
  }
}

/// Notifications for the download job system.
///
/// A running job is a WorkManager foreground service, and that service posts
/// its *own* ongoing notification from the static `ForegroundServiceConfig`
/// it was enqueued with. WorkManager never repaints it — `reportProgress`
/// writes WorkInfo progress data that nothing renders.
///
/// So the ongoing notification is ours to maintain: [progressNotificationId]
/// must be passed as the config's `notificationId`, and every page we
/// re-post under that same id to repaint it in place. The service stays
/// promoted either way, because promotion already happened via
/// `setForegroundAsync`.
class DownloadNotifications {
  const DownloadNotifications._();

  /// Channel used by both WorkManager's foreground service and our updates.
  ///
  /// Must be created by us *before* the first job runs: Android ignores
  /// `createNotificationChannel` for a channel that already exists, so
  /// letting WorkManager create it first would lock in its generic
  /// "Long-running tasks" name and importance.
  static const String channelId = 'downloads';
  static const String channelName = 'Downloads';

  /// Base for ongoing progress notifications. WorkManager needs a unique id
  /// per concurrent foreground service, so this is offset per job.
  static const int _progressIdBase = 482010;

  /// Separate range for terminal (completion/failure) notifications, so they
  /// aren't destroyed by the `stopForeground` that runs when the worker ends.
  static const int _resultIdBase = 482500;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;

  /// The id of the Pause button, wired by the app into `DownloadScheduler`.
  static const String pauseActionId = 'pause';

  /// The id of the Cancel button.
  static const String cancelActionId = 'cancel';

  /// The id of the Resume button on a paused note.
  static const String resumeActionId = 'resume';

  /// The id the foreground service posts under for [jobId]. Passing this to
  /// `ForegroundServiceConfig.notificationId` is what lets [showProgress]
  /// overwrite the service's own notification.
  static int progressNotificationId(String jobId) =>
      _progressIdBase + (jobId.hashCode & 0x1FF);

  static int _resultNotificationId(String jobId) =>
      _resultIdBase + (jobId.hashCode & 0x1FF);

  /// Localisations for a background isolate, which has no `BuildContext`.
  ///
  /// Uses the platform locale; the existing notification code hardcodes
  /// English, so this is a step up but not a guarantee if a user changes
  /// language while a job is queued.
  static AppLocalizations get _l {
    final locale = PlatformDispatcher.instance.locale;
    return lookupAppLocalizations(locale);
  }

  /// The paused-state note the reference keeps in the shade once its jobs
  /// stop: the pause bars as glyph, the batch's remaining work behind the
  /// title, and the Resume / Cancel buttons standing in for Restart/Cancel
  /// rows on the pause screen. Not ongoing, so the shade keeps it.
  static Future<void> showPaused({
    required String jobId,
    required String title,
    required int donePages,
    required int totalPages,
    required int doneChapters,
    required int totalChapters,
    String? coverUrl,
    String? mangaId,
    String? sourceId,
    String? error,
  }) async {
    await ensureInitialized();
    final l = _l;
    final body = l.dlgDownloadPartialBody(doneChapters, totalChapters);
    final stalls = error == null || error.isEmpty ? '' : '\n$error';
    final bytes = await NotificationImage.bytesFor(coverUrl);
    try {
      await _plugin.show(
        id: _resultNotificationId(jobId),
        title: l.dlgDownloadPaused,
        body: '$title\n$body$stalls',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: l.dlgDownloadChannelDescription,
            icon: 'ic_stat_paused',
            importance: Importance.low,
            priority: Priority.low,
            // The reference pins the paused note (setOngoing(true)) — the
            // batch is recoverable, so it cannot be swiped away.
            ongoing: true,
            showProgress: totalPages > 0,
            maxProgress: totalPages,
            progress: donePages.clamp(0, totalPages),
            largeIcon: bytes == null ? null : ByteArrayAndroidBitmap(bytes),
            actions: [
              AndroidNotificationAction(resumeActionId, l.dlgDownloadResume),
              AndroidNotificationAction(cancelActionId, l.cancel),
            ],
          ),
          iOS: DarwinNotificationDetails(presentAlert: true),
        ),
        payload: _encodeTargetPayload(
          jobId: jobId,
          mangaId: mangaId,
          title: title,
          coverUrl: coverUrl,
          sourceId: sourceId,
        ),
      );
    } catch (_) {}
  }

  static String _encodeTargetPayload({
    required String jobId,
    String? mangaId,
    String? title,
    String? coverUrl,
    String? sourceId,
  }) => jsonEncode({
    'kind': 'download',
    'id': mangaId ?? '',
    'title': title ?? '',
    'cover': coverUrl ?? '',
    'source': sourceId ?? '',
    'job': jobId,
  });

  static Future<void> ensureInitialized() async {
    if (_initialised) return;
    _initialised = true;
    try {
      const android = AndroidInitializationSettings('ic_stat_notify');
      const ios = IOSInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveBackgroundNotificationResponse:
            downloadNotificationActionHandler,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              channelName,
              description: 'Progress and results for saved chapters',
              importance: Importance.low,
            ),
          );
    } catch (_) {
      // A missing notification must never fail a download.
    }
  }

  /// Repaints the ongoing notification for a running job.
  ///
  /// [donePages]/[totalPages] drive the determinate progress bar. Pass
  /// [indeterminate] while the page count is still being resolved. An
  /// [etaMinutes] of one or more appends the reference's "~n min left" line,
  /// which it computes off a download's own pace.
  static Future<void> showProgress({
    required String jobId,
    required String title,
    required int donePages,
    required int totalPages,
    required int doneChapters,
    required int totalChapters,
    bool indeterminate = false,
    int? etaMinutes,
    String? coverUrl,
    String? mangaId,
    String? sourceId,
  }) async {
    await ensureInitialized();
    final l = _l;
    final progressLine = totalPages > 0
        ? l.dlgDownloadPages(donePages, totalPages)
        : l.dlgDownloadPreparing;
    final chapterLine = l.dlgDownloadChapterOf(
      (doneChapters + 1).clamp(1, totalChapters == 0 ? 1 : totalChapters),
      totalChapters,
    );
    var body = '$chapterLine · $progressLine';
    if (!indeterminate && totalPages > 0 && etaMinutes != null && etaMinutes > 0) {
      body += ' · ${l.dlgDownloadEta(etaMinutes)}';
    }
    final bytes = await NotificationImage.bytesFor(coverUrl);
    final largeIcon = bytes == null ? null : ByteArrayAndroidBitmap(bytes);

    try {
      await _plugin.show(
        id: progressNotificationId(jobId),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: l.dlgDownloadChannelDescription,
            importance: Importance.low,
            priority: Priority.low,
            category: AndroidNotificationCategory.progress,
            ongoing: true,
            onlyAlertOnce: true,
            // A foreground service notification must not be swipeable, or the
            // user can dismiss it while the download is still running.
            autoCancel: false,
            showProgress: !indeterminate && totalPages > 0,
            maxProgress: totalPages,
            progress: donePages.clamp(0, totalPages),
            largeIcon: largeIcon,
            // The reference pins Pause and Cancel on the running note, so a
            // runaway batch is stoppable from the shade without opening the
            // app. The presses land in
            // [downloadNotificationActionHandler] and route through
            // `DownloadScheduler`.
            actions: [
              // Plain wording like the reference's actions, which use
              // android.R.string.cancel rather than a download-specific one.
              AndroidNotificationAction(pauseActionId, l.dlgDownloadPause),
              AndroidNotificationAction(cancelActionId, l.cancel),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentSound: false,
            presentBanner: true,
          ),
        ),
        payload: _encodeProgress(jobId: jobId, mangaId: mangaId),
      );
    } catch (_) {}
  }

  /// Terminal notification: the batch finished, or stopped short. Carries the
  /// full tap target, wired the way the reference routes its final states:
  /// opening it lands on the downloaded series' page.
  static Future<void> showResult({
    required String jobId,
    required String title,
    required bool success,
    required int doneChapters,
    required int totalChapters,
    String? error,
    String? coverUrl,
    String? mangaId,
    String? sourceId,
  }) async {
    await ensureInitialized();
    final l = _l;
    // Drop the ongoing notification first: the service's own id is about to
    // be released, and leaving it behind would strand a stale progress bar.
    await cancel(jobId);

    final body = success
        ? l.dlgDownloadCompleteBody(doneChapters)
        : l.dlgDownloadPartialBody(doneChapters, totalChapters);
    final bytes = await NotificationImage.bytesFor(coverUrl);

    try {
      await _plugin.show(
        id: _resultNotificationId(jobId),
        title: success ? l.dlgDownloadComplete : l.dlgDownloadFailed,
        body: error == null || error.isEmpty ? body : '$body\n$error',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: l.dlgDownloadChannelDescription,
            // The reference's terminal states switch icons: the done check
            // when everything saved, the platform's error glyph otherwise.
            icon: success ? 'ic_stat_done' : 'ic_stat_error',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            ongoing: false,
            autoCancel: true,
            largeIcon: bytes == null ? null : ByteArrayAndroidBitmap(bytes),
          ),
          iOS: DarwinNotificationDetails(presentAlert: true),
        ),
        // Full tap target, so the shade opens the series like the reference's
        // final states do.
        payload: _encodeTargetPayload(
          jobId: jobId,
          mangaId: mangaId,
          title: title,
          coverUrl: coverUrl,
          sourceId: sourceId,
        ),
      );
    } catch (_) {}
  }

  /// Removes the ongoing notification for [jobId].
  static Future<void> cancel(String jobId) async {
    try {
      await _plugin.cancel(id: progressNotificationId(jobId));
      await _plugin.cancel(id: _resultNotificationId(jobId));
    } catch (_) {}
  }

  /// Payload carried by the progress note: a `download` target whose tap
  /// opens the running series (the reference's progress note does the same),
  /// plus the job id the actions need.
  static String _encodeProgress({required String jobId, String? mangaId}) =>
      jsonEncode({
        'kind': 'download',
        'id': mangaId ?? '',
        'job': jobId,
      });
}
