import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String enabledPrefsKey = 'new_chapter_notifications';
  static const String lastSuggestedSentPrefsKey = 'last_suggested_sent_ms';
  static const String _channelId = 'new_chapters';
  static const String _channelName = 'New chapters';
  static const String _suggestedChannelId = 'suggested_manga';
  static const String _suggestedChannelName = 'Suggested manga';
  static const String _suggestedCategoryId = 'suggested';
  static const int _suggestedNotificationId = 482002;
  static const String payloadFeed = 'feed';
  static const String payloadSuggested = 'suggested';

  static const String _newChapterGroupKey = 'yomou_new_chapters';
  static const int _newChapterSummaryId = 482003;
  static const int _newChapterChildIdBase = 0x100000;

  static const String _readActionId = 'read';
  static const String _moreActionId = 'more';

  int _newChapterChildId(String mangaId) =>
      _newChapterChildIdBase + (mangaId.hashCode & 0xFFFFF);

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
    return prefs.getBool(enabledPrefsKey) ?? false;
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
    String? sourceId,
  }) async {
    final bytes = await _fetchImageBytes(coverUrl);
    final countText = newCount == 1
        ? '1 new chapter'
        : '$newCount new chapters';
    final chapterText = latestChapterTitle.trim();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription:
            'Alerts when manga in your library get new chapters',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        groupKey: _newChapterGroupKey,
        setAsGroupSummary: false,
        groupAlertBehavior: GroupAlertBehavior.summary,
        largeIcon: bytes != null ? ByteArrayAndroidBitmap(bytes) : null,
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
    await init();
    await showNewChapterNotification(
      mangaId: 'preview_one_piece',
      title: 'One Piece',
      coverUrl: 'https://picsum.photos/seed/onepiece/300/420',
      newCount: 3,
      latestChapterTitle: "1128 — Oden's Return",
    );
    await showNewChapterNotification(
      mangaId: 'preview_jujutsu',
      title: 'Jujutsu Kaisen',
      coverUrl: 'https://picsum.photos/seed/jujutsu/300/420',
      newCount: 1,
      latestChapterTitle: 'Chapter 235',
    );
    await showNewChapterNotification(
      mangaId: 'preview_solo_leveling',
      title: 'Solo Leveling',
      coverUrl: 'https://picsum.photos/seed/solo/300/420',
      newCount: 1,
      latestChapterTitle: 'Chapter 176',
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
      channelDescription: 'Recommendations based on what you read',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
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
      id: _suggestedNotificationId,
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

  /// Dev/demo: shows a realistic "suggested manga" card with a cover image for
  /// previewing its look and layout.
  Future<void> showTestSuggested() async {
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
      if (kind != 'newChapter' && kind != 'suggestion') return null;
      final source = map['source'];
      return NotificationTarget(
        kind: kind as String,
        mangaId: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        coverUrl: map['cover']?.toString() ?? '',
        sourceId: source is String && source.isNotEmpty ? source : null,
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
  Future<Uint8List?> _fetchImageBytes(String? url) async {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('local://')) {
      try {
        final file = File(url.substring('local://'.length));
        return await file.readAsBytes();
      } catch (_) {
        return null;
      }
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Where a tapped notification should take the user.
class NotificationTarget {
  const NotificationTarget({
    required this.kind,
    required this.mangaId,
    required this.title,
    required this.coverUrl,
    this.sourceId,
  });

  /// 'newChapter' for library updates, 'suggestion' for recommendations.
  final String kind;

  final String mangaId;
  final String title;
  final String coverUrl;
  final String? sourceId;
}
