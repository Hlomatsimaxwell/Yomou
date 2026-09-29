import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/core/notifications/notification_image.dart';

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
  /// [indeterminate] while the page count is still being resolved.
  static Future<void> showProgress({
    required String jobId,
    required String title,
    required int donePages,
    required int totalPages,
    required int doneChapters,
    required int totalChapters,
    bool indeterminate = false,
    String? coverUrl,
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
    final bytes = await NotificationImage.bytesFor(coverUrl);
    final largeIcon = bytes == null ? null : ByteArrayAndroidBitmap(bytes);

    try {
      await _plugin.show(
        id: progressNotificationId(jobId),
        title: title,
        body: '$chapterLine · $progressLine',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: l.dlgDownloadChannelDescription,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            onlyAlertOnce: true,
            // A foreground service notification must not be swipeable, or the
            // user can dismiss it while the download is still running.
            autoCancel: false,
            showProgress: !indeterminate && totalPages > 0,
            maxProgress: totalPages,
            progress: donePages.clamp(0, totalPages),
            largeIcon: largeIcon,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: false,
            presentBanner: true,
          ),
        ),
      );
    } catch (_) {}
  }

  /// Terminal notification: the batch finished, or stopped short.
  static Future<void> showResult({
    required String jobId,
    required String title,
    required bool success,
    required int doneChapters,
    required int totalChapters,
    String? error,
    String? coverUrl,
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
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            ongoing: false,
            autoCancel: true,
            largeIcon: bytes == null ? null : ByteArrayAndroidBitmap(bytes),
          ),
          iOS: DarwinNotificationDetails(presentAlert: true),
        ),
        payload: 'download:$jobId',
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
}
