import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/core/notifications/notification_image.dart';

/// A manga suggestion ready to be shown as a notification.
class SuggestedMangaNotification {
  const SuggestedMangaNotification({
    required this.mangaTitle,
    required this.genres,
    required this.chapterCount,
    required this.synopsis,
    this.coverUrl,
    this.mangaId,
    this.sourceId,
  });

  /// Display name of the recommended manga.
  final String mangaTitle;

  /// Genre tags, comma-joined in the metadata subtext (e.g. "Comedy, Romance").
  final List<String> genres;

  /// Current chapter count shown after the genres.
  final int chapterCount;

  /// Multi-line plot synopsis shown as the notification body.
  final String synopsis;

  /// Optional cover art URL used as the trailing thumbnail.
  final String? coverUrl;

  /// Source-specific id of the recommended manga (for tap routing).
  final String? mangaId;

  /// The source the recommendation came from (for tap routing).
  final String? sourceId;

  /// Second content line: "Comedy, Romance, Schoollife, Webtoons • 28 chapters".
  String get metadataLine {
    final b = StringBuffer();
    if (genres.isNotEmpty) b.write(genres.join(', '));
    if (chapterCount > 0) {
      if (b.isNotEmpty) b.write(' • ');
      b.write(chapterCount == 1 ? '1 chapter' : '$chapterCount chapters');
    }
    return b.toString();
  }
}

/// Wraps local notifications for "new chapters in your library" alerts.
///
/// There is no server, so these are locally generated: a background task (or
/// the app itself) checks the sources and calls [showNewChapters]. The service
/// is safe to use from the background isolate workmanager spawns.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// Whether OS notifications are a feature on this platform.
  ///
  /// The alert types here are built on the mobile plugins and nothing schedules
  /// the periodic checks on desktop, so every entry point below is inert off
  /// Android/iOS rather than failing there: `initialize` rejects a settings
  /// object without Linux settings, and a switch that cannot do its job is
  /// worse than no switch.
  static bool get supported => Platform.isAndroid || Platform.isIOS;

  static const String enabledPrefsKey = 'new_chapter_notifications';
  static const String lastSuggestedSentPrefsKey = 'last_suggested_sent_ms';
  static const String _channelId = 'new_chapters';
  static const String _channelName = 'New chapters';
  /// The reference's alert glyph for its new-chapter channel (its
  /// ic_stat_book_plus open-book-plus mark). Status-bar icons are tiny, so
  /// the shared plain-ligature icon reads as noise next to the reference's.
  static const String _newChapterIcon = 'ic_stat_new_chapters';
  static const String _suggestedChannelId = 'suggested_manga';
  static const String _suggestedChannelName = 'Suggested manga';
  /// The reference's badge glyph for its suggestions channel
  /// (ic_stat_suggestion).
  static const String _suggestedIcon = 'ic_stat_suggestion';
  static const String _suggestedCategoryId = 'suggested';
  static const int _suggestedNotificationIdBase = 482002;
  static const String _suggestionGroupKey = 'yomou_suggestions';
  static const String _doneIcon = 'ic_stat_done';
  static const String _errorIcon = 'ic_stat_error';
  /// The reference posts a silent progress note from its tracker worker
  /// while a check runs (its track_worker channel, IMPORTANCE_LOW). Yomou's
  /// periodic task mirrors it, so this channel exists before the task posts.
  static const String _checkChannelId = 'check_worker';
  static const String _checkChannelName = 'Check for new chapters';
  static const String _checkChannelDescription =
      'Progress of background checks for new chapters';
  static const int _checkNoteId = 482020;
  static const String payloadFeed = 'feed';
  static const String payloadSuggested = 'suggested';

  static const String _backupChannelId = 'backup_restore';
  static const String _backupChannelName = 'Backup & restore';
  static const String _backupChannelDescription =
      'Results of backup, export and import';
  static const int _exportResultNotificationId = 484010;
  static const int _importResultNotificationId = 484011;

  static const String _newChapterGroupKey = 'yomou_new_chapters';
  static const int _newChapterSummaryId = 482003;
  static const int _newChapterChildIdBase = 0x100000;

  /// The id the periodic check's progress note posts under. Passed to
  /// WorkManager's foreground config so the service and the repaint share it,
  /// the way the download jobs manage their own note.
  static int get checkNoteId => _checkNoteId;

  static const String _readActionId = 'read';
  static const String _moreActionId = 'more';

  static String get readActionId => _readActionId;
  static String get moreActionId => _moreActionId;

  /// Notification ids for the backup/restore result notifications.
  static int get exportResultNotificationId => _exportResultNotificationId;
  static int get importResultNotificationId => _importResultNotificationId;

  int _newChapterChildId(String mangaId) =>
      _newChapterChildIdBase + (mangaId.hashCode & 0xFFFFF);

  int _suggestedId(String mangaId) =>
      _suggestedNotificationIdBase + (mangaId.hashCode & 0x3FFFF);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  void Function(NotificationResponse response)? _onSelect;

  /// Initializes the plugin (once) and registers [onSelect] for taps/actions
  /// while the app is running. Call before showing notifications.
  Future<void> init({
    void Function(NotificationResponse response)? onSelect,
  }) async {
    if (onSelect != null) _onSelect = onSelect;
    if (!supported) return;
    if (_initialized) return;
    _initialized = true;

    const android = AndroidInitializationSettings('ic_stat_notify');
    final ios = IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      // iOS shows actions only via long-press/expansion; register the "READ"
      // and "MORE" actions for the suggested category here.
      notificationCategories: [
        DarwinNotificationCategory(
          _suggestedCategoryId,
          actions: [
            DarwinNotificationAction.plain(_readActionId, 'READ'),
            DarwinNotificationAction.plain(_moreActionId, 'MORE'),
          ],
        ),
      ],
    );
    final settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _onSelect?.call(response);
      },
    );
  }

  /// Payload of the notification that launched the app, if any.
  Future<String?> launchPayload() async {
    if (!supported) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details?.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Default on: new-chapter notifications are part of the setup a new reader
    // gets, and the welcome flow asks for the OS permission right away. The
    // switch is turned off only if that permission is refused (or by the reader
    // in settings), so the value stored here still wins once set.
    return prefs.getBool(enabledPrefsKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledPrefsKey, value);
  }

  /// Requests the OS notification permission (Android 13+ / iOS). Returns true
  /// on platforms that have no permission prompt.
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final impl = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        // Null means the platform (pre-Android 13) has nothing to ask.
        return await impl?.requestNotificationsPermission() ?? true;
      }
      if (Platform.isIOS) {
        final impl = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await impl?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (_) {}
    return true;
  }

  /// First notification type: one "new chapter" notification per series.
  ///
  /// Notifications are fired individually and grouped by the OS so it stacks
  /// them into its own summary view:
  /// - Android: shared [AndroidNotificationDetails.groupKey] (the OS collapses
  ///   them on the lock screen/shade).
  /// - iOS: a shared `threadIdentifier` (UNUserNotificationCenter groups them).
  ///
  /// Layout (spec):
  /// - Header: app glyph left, "Yomou • now" (system-controlled).
  /// - Two-column: left text (bold title, "1 new chapter", grey chapter label
  ///   in the second text line), right small square cover thumbnail
  ///   (Android large icon; iOS attachment).
  /// - Tap routes to the series (see [NotificationTarget]).
  Future<void> showNewChapterNotification({
    required String mangaId,
    required String title,
    required String coverUrl,
    required int newCount,
    required String latestChapterTitle,
    required bool nsfw,
    String? sourceId,
  }) async {
    if (!supported) return;

    final bytes = await _fetchImageBytes(coverUrl);
    final countText = newCount == 1
        ? '1 new chapter'
        : '$newCount new chapters';
    final chapterText = latestChapterTitle.trim();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        icon: _newChapterIcon,
        channelDescription:
            'Alerts when manga in your library get new chapters',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        groupKey: _newChapterGroupKey,
        setAsGroupSummary: false,
        groupAlertBehavior: GroupAlertBehavior.summary,
        largeIcon: bytes != null ? ByteArrayAndroidBitmap(bytes) : null,
        // The reference hides its NSFW posts from the lock screen entirely
        // (VISIBILITY_SECRET in TrackerNotificationHelper); everything else
        // shows in full.
        visibility: nsfw ? NotificationVisibility.secret : null,
      ),
      iOS: DarwinNotificationDetails(
        subtitle: countText,
        threadIdentifier: _newChapterGroupKey,
        attachments: await _darwinAttachment(bytes, mangaId),
      ),
    );

    await _plugin.show(
      id: _newChapterChildId(mangaId),
      title: title,
      body: chapterText.isEmpty ? countText : '$countText\n$chapterText',
      notificationDetails: details,
      payload: _encodeTarget(
        kind: 'newChapter',
        mangaId: mangaId,
        title: title,
        coverUrl: coverUrl,
        sourceId: sourceId,
      ),
    );
  }

  /// Posts the OS group summary for a batch of new chapters (Android only).
  /// iOS groups children purely via `threadIdentifier`, no summary needed.
  Future<void> showNewChaptersGroupSummary({
    required int seriesCount,
    required int totalNew,
    List<String> lines = const [],
  }) async {
    if (!Platform.isAndroid) return;

    final title = '$totalNew new chapter${totalNew == 1 ? '' : 's'}';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        icon: _newChapterIcon,
        channelDescription:
            'Alerts when manga in your library get new chapters',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        groupKey: _newChapterGroupKey,
        setAsGroupSummary: true,
        groupAlertBehavior: GroupAlertBehavior.all,
        styleInformation: lines.isEmpty
            ? null
            : InboxStyleInformation(
                lines,
                contentTitle: title,
                summaryText: '$seriesCount series updated',
              ),
      ),
    );

    await _plugin.show(
      id: _newChapterSummaryId,
      title: title,
      body: '$seriesCount series updated',
      notificationDetails: details,
      payload: payloadFeed,
    );
  }

  /// Dev/demo: fires three per-series notifications plus their OS group
  /// summary so the stacked shade view can be previewed.
  Future<void> showTestNewChapters() async {
    if (!supported) return;

    await init();
    await showNewChapterNotification(
      mangaId: 'preview_one_piece',
      title: 'One Piece',
      coverUrl: 'https://picsum.photos/seed/onepiece/300/420',
      newCount: 3,
      latestChapterTitle: "1128 — Oden's Return",
      nsfw: false,
    );
    await showNewChapterNotification(
      mangaId: 'preview_jujutsu',
      title: 'Jujutsu Kaisen',
      coverUrl: 'https://picsum.photos/seed/jujutsu/300/420',
      newCount: 1,
      latestChapterTitle: 'Chapter 235',
      nsfw: false,
    );
    await showNewChapterNotification(
      mangaId: 'preview_solo_leveling',
      title: 'Solo Leveling',
      coverUrl: 'https://picsum.photos/seed/solo/300/420',
      newCount: 1,
      latestChapterTitle: 'Chapter 176',
      nsfw: false,
    );
    await showNewChaptersGroupSummary(
      seriesCount: 3,
      totalNew: 5,
      lines: const [
        'One Piece — 3 new',
        'Jujutsu Kaisen — 1 new',
        'Solo Leveling — 1 new',
      ],
    );
  }

  /// Second notification type: a single "suggestion" card with cover thumbnail
  /// and READ/MORE actions.
  ///
  /// Layout (spec):
  /// - Header: app glyph left, "Yomou • now" (Android small icon / iOS bundle
  ///   name are platform-controlled).
  /// - Title: "Suggestion: <Title>" (system bold).
  /// - Subtext: "Comedy, Romance, Schoollife, Webtoons • 28 chapters".
  /// - Body: multi-line synopsis (the manga's description).
  /// - Media: small square cover thumbnail beside the text block. Android =
  ///   large icon (collapsed); iOS = attachment thumbnail.
  /// - Footer: READ / MORE. Android renders inline text buttons (expanded);
  ///   iOS requires long-press/expansion via the registered category.
  Future<void> showSuggestedManga(SuggestedMangaNotification manga) async {
    if (!supported) return;

    final title = 'Suggestion: ${manga.mangaTitle}';
    final bytes = await _fetchImageBytes(manga.coverUrl);
    final text = manga.metadataLine.isNotEmpty
        ? '${manga.metadataLine}\n${manga.synopsis}'
        : manga.synopsis;

    List<DarwinNotificationAttachment>? iosAttachments;
    if (bytes != null) {
      final file = File(
        '${Directory.systemTemp.path}/yomou_suggested_${manga.mangaTitle.hashCode}.jpg',
      );
      try {
        await file.writeAsBytes(bytes, flush: true);
        iosAttachments = [DarwinNotificationAttachment(file.path)];
      } catch (_) {}
    }

    final android = AndroidNotificationDetails(
      _suggestedChannelId,
      _suggestedChannelName,
      icon: _suggestedIcon,
      channelDescription: 'Recommendations based on what you read',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      // The reference's suggestions carry CATEGORY_RECOMMENDATION.
      category: AndroidNotificationCategory.recommendation,
      // An id per manga, the way the reference hashes theirs: two suggestions
      // stack instead of the next digest replacing the last card.
      groupKey: _suggestionGroupKey,
      largeIcon: bytes != null ? ByteArrayAndroidBitmap(bytes) : null,
      // Compact, text-first card: no big banner. The cover stays a small
      // thumbnail in the collapsed view; expanding shows the full description.
      styleInformation: BigTextStyleInformation(
        manga.synopsis,
        contentTitle: title,
        summaryText: manga.metadataLine,
      ),
      actions: const [
        AndroidNotificationAction(_readActionId, 'READ'),
        AndroidNotificationAction(_moreActionId, 'MORE'),
      ],
    );

    final ios = DarwinNotificationDetails(
      subtitle: manga.metadataLine.isEmpty ? null : manga.metadataLine,
      categoryIdentifier: _suggestedCategoryId,
      attachments: iosAttachments,
    );

    await _plugin.show(
      // Stable per manga, so a later digest of the same series updates that
      // card in place while a different one stacks alongside it.
      id: _suggestedId(manga.mangaId ?? manga.mangaTitle),
      title: title,
      body: text,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: _encodeTarget(
        kind: 'suggestion',
        mangaId: manga.mangaId ?? manga.mangaTitle,
        title: manga.mangaTitle,
        coverUrl: manga.coverUrl ?? '',
        sourceId: manga.sourceId,
      ),
    );
  }

  /// Posts a single final "export/import finished" notification on a silent
  /// high-priority channel, mirroring the result notification Kotatsu shows
  /// after a backup or restore finishes.
  ///
  /// Import runs can outlive the screen that started them (the missing-title
  /// scan is non-blocking), so this is posted without needing a context or an
  /// active route. Failures are swallowed: a notification is a nice-to-have,
  /// and the in-app toast still reports the result.
  Future<void> showBackupResultNotification({
    required int id,
    required String title,
    required String body,
    bool success = true,
  }) async {
    if (!supported) return;

    try {
      await init();
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _backupChannelId,
            _backupChannelName,
            // The reference's result posts carry the done check on success
            // and the platform's error glyph on failure.
            icon: success ? _doneIcon : _errorIcon,
            channelDescription: _backupChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: false,
            enableVibration: false,
            category: AndroidNotificationCategory.status,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  /// Shows (or updates, by [id]) the Kotatsu-style ongoing progress
  /// notification that mirrors a running import scan in the shade. Calling it
  /// again with the same [id] replaces the previous one; [total] of zero (or a
  /// negative [current]) renders an indeterminate bar. Posting the final result
  /// with [showBackupResultNotification] on the same [id] swaps this out.
  Future<void> showBackupProgress({
    required int id,
    required String title,
    required String body,
    required int current,
    required int total,
  }) async {
    if (!supported) return;

    try {
      await init();
      final indeterminate = total <= 0 || current < 0;
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _backupChannelId,
            _backupChannelName,
            channelDescription: _backupChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: false,
            enableVibration: false,
            category: AndroidNotificationCategory.status,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showProgress: true,
            maxProgress: total < 1 ? 1 : total,
            progress: current < 0 ? 0 : current.clamp(0, total),
            indeterminate: indeterminate,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  /// Removes the ongoing progress notification so nothing lingers when an
  /// import finishes without posting a result (e.g. nothing was importable).
  Future<void> cancelBackupProgress({required int id}) async {
    if (!supported) return;

    try {
      await init();
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  /// Creates the check-progress channel up front, so the periodic task's
  /// foreground config name lands on a channel with the reference's wording
  /// rather than WorkManager's generic "Long-running tasks".
  Future<void> ensureCheckChannel() async {
    if (!Platform.isAndroid) return;
    try {
      await init();
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              _checkChannelId,
              _checkChannelName,
              description: _checkChannelDescription,
              importance: Importance.low,
            ),
          );
    } catch (_) {}
  }

  /// The silent "Checking for new chapters" note the reference's tracker
  /// worker pins while it scans (its `track_worker` channel, IMPORTANCE_LOW):
  /// an ongoing line under the running check, gone as soon as the check ends.
  /// The id matches the foreground config so this repaints the service's own
  /// notification in place, the way the download jobs manage theirs.
  Future<void> showCheckProgress() async {
    if (!Platform.isAndroid) return;
    try {
      await ensureCheckChannel();
      await _plugin.show(
        id: _checkNoteId,
        title: _checkChannelName,
        body: 'Checking in the background…',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _checkChannelId,
            _checkChannelName,
            channelDescription: _checkChannelDescription,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            showProgress: true,
            maxProgress: 1,
            indeterminate: true,
          ),
        ),
      );
    } catch (_) {}
  }

  /// Drops the check progress note after the routine cycle finishes.
  Future<void> hideCheckProgress() async {
    if (!Platform.isAndroid) return;
    try {
      await _plugin.cancel(id: _checkNoteId);
    } catch (_) {}
  }

  /// Dev/demo: shows a realistic "suggested manga" card with a cover image for
  /// previewing its look and layout.
  Future<void> showTestSuggested() async {
    if (!supported) return;

    await init();
    await showSuggestedManga(
      SuggestedMangaNotification(
        mangaTitle: 'One Punch Man',
        genres: const ['Action', 'Comedy', 'Sci-Fi', 'Schoollife'],
        chapterCount: 187,
        synopsis:
            'In this action-comedy, nothing about a young man named Saitama '
            'screams hero — his lifeless expression, bald head and unimpressive '
            'figure suggest otherwise. So why does he hog the spotlight? '
            'Because he is so powerful that nobody can stand against him, '
            'winning every fight with a single punch.',
        coverUrl: 'https://picsum.photos/seed/onepunchman/300/420',
      ),
    );
  }

  /// Decodes a notification payload into a navigation target, or null when the
  /// payload isn't a manga deep link (e.g. the plain "feed" payload).
  static NotificationTarget? decodeTarget(String? payload) {
    if (payload == null ||
        payload == payloadFeed ||
        payload == payloadSuggested) {
      return null;
    }
    try {
      final map = jsonDecode(payload);
      if (map is! Map) return null;
      final kind = map['kind'];
      if (kind != 'newChapter' && kind != 'suggestion' && kind != 'download') {
        return null;
      }
      final source = map['source'];
      return NotificationTarget(
        kind: kind as String,
        mangaId: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        coverUrl: map['cover']?.toString() ?? '',
        sourceId: source is String && source.isNotEmpty ? source : null,
        jobId: map['job']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static String _encodeTarget({
    required String kind,
    required String mangaId,
    required String title,
    required String coverUrl,
    String? sourceId,
  }) {
    return jsonEncode({
      'kind': kind,
      'id': mangaId,
      'title': title,
      'cover': coverUrl,
      'source': sourceId ?? '',
    });
  }

  /// Turns image bytes into an iOS attachment (writes a temp file). Returns
  /// null when there is nothing to attach.
  Future<List<DarwinNotificationAttachment>?> _darwinAttachment(
    Uint8List? bytes,
    String name,
  ) async {
    if (bytes == null) return null;
    final file = File('${Directory.systemTemp.path}/yomou_$name.jpg');
    try {
      await file.writeAsBytes(bytes, flush: true);
      return [DarwinNotificationAttachment(file.path)];
    } catch (_) {
      return null;
    }
  }

  /// Best-effort download of an image (or read of a `local://` file), used to
  /// attach cover art to notifications. Returns null when unavailable.
  /// Delegates to the shared fetcher so every notification decodes covers the
  /// same way.
  Future<Uint8List?> _fetchImageBytes(String? url) =>
      NotificationImage.bytesFor(url);
}

/// Where a tapped notification should take the user.
class NotificationTarget {
  const NotificationTarget({
    required this.kind,
    required this.mangaId,
    required this.title,
    required this.coverUrl,
    this.sourceId,
    this.jobId = '',
  });

  /// 'newChapter' for library updates, 'suggestion' for recommendations,
  /// 'download' for a finished download batch.
  final String kind;

  final String mangaId;
  final String title;
  final String coverUrl;
  final String? sourceId;

  /// The WorkManager job id on download targets, for the pause/cancel actions.
  final String jobId;
}
