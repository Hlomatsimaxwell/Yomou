import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/notifications/notification_service.dart';
import 'package:yomou/core/notifications/notification_settings.dart';
import 'package:yomou/core/notifications/update_checker.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/reader/services/chapter_downloader.dart';

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
    return true;
  });
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
/// suggestion. No-op on a fresh install (no reading taste yet).
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
Future<void> registerUpdateCheckTask() async {
  await Workmanager().initialize(callbackDispatcher);
  final interval = NotificationSettings.intervalFor(
    await NotificationSettings.frequency(),
  );
  if (interval == null) {
    await Workmanager().cancelByUniqueName(updateCheckTaskName);
    return;
  }

  final wifiOnly = await NotificationSettings.isWifiOnly();
  await Workmanager().registerPeriodicTask(
    updateCheckTaskName,
    _androidTaskName,
    frequency: interval,
    constraints: Constraints(
      networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
}

/// Cancels the scheduled periodic check (used when the user disables
/// notifications).
Future<void> cancelUpdateCheckTask() async {
  try {
    await Workmanager().cancelByUniqueName(updateCheckTaskName);
  } catch (_) {}
}
