import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/notifications/download_notification.dart';
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/features/downloads/services/metered_network_gate.dart';
import 'package:yomou/features/reader/services/chapter_downloader.dart';
import 'package:yomou/features/reader/services/download_job.dart';
import 'package:yomou/features/reader/services/download_scheduler.dart';

/// Outcome of handing a set of chapters to the download scheduler.
class DownloadRequestResult {
  const DownloadRequestResult({
    required this.queued,
    required this.alreadyDownloaded,
    required this.unavailable,
    required this.blocked,
    this.jobId,
  });

  /// Chapters handed to the scheduler.
  final int queued;

  /// Chapters already on disk, skipped.
  final int alreadyDownloaded;

  /// Chapters the source returned no pages for.
  final int unavailable;

  /// True when the cellular prompt refused the whole batch.
  final bool blocked;

  final String? jobId;

  bool get isEmpty => queued == 0;
}

/// Bridges the UI's "download these chapters" intent to a queued download job.
///
/// Resolves the cellular policy, skips chapters already on disk, resolves each
/// chapter's page list up front (the worker must not have to talk to the
/// source), then hands the batch to [DownloadScheduler] as a single job.
class DownloadRequests {
  const DownloadRequests._();

  static Future<DownloadRequestResult> enqueue({
    required BuildContext context,
    required WidgetRef ref,
    required MangaSource source,
    required String mangaId,
    required List<Chapter> chapters,
    String? mangaTitle,
    String? coverUrl,
  }) async {
    // The cellular prompt needs a mounted context, and can be dismissed.
    final verdict = await askAboutMeteredDownload(context, ref);
    if (verdict == null || !verdict.allowed) {
      return const DownloadRequestResult(
        queued: 0,
        alreadyDownloaded: 0,
        unavailable: 0,
        blocked: true,
      );
    }

    final already = await DatabaseHelper.instance.getDownloadedChapterIds(
      mangaId,
    );

    final resolvable = <DownloadJobChapter>[];
    var skipped = 0;
    var unavailable = 0;
    for (final chapter in chapters) {
      if (already.contains(chapter.id) ||
          await ChapterDownloader.isDownloaded(mangaId, chapter.id)) {
        skipped++;
        continue;
      }
      final pages = await _pagesFor(source, chapter.id);
      if (pages == null || pages.isEmpty) {
        unavailable++;
        continue;
      }
      resolvable.add(
        DownloadJobChapter(
          id: chapter.id,
          number: double.tryParse(chapter.chapterNumber) ?? 0,
          title: chapter.title,
          pages: pages,
        ),
      );
    }

    if (resolvable.isEmpty) {
      return DownloadRequestResult(
        queued: 0,
        alreadyDownloaded: skipped,
        unavailable: unavailable,
        blocked: false,
      );
    }

    final jobId = await DownloadScheduler.enqueue(
      mangaId: mangaId,
      mangaTitle: mangaTitle,
      coverUrl: coverUrl,
      sourceId: source.id,
      headers: source.headers,
      chapters: resolvable,
      // A refusal at the prompt means the job must not be able to start on
      // cellular later either, so the constraint has to carry that decision.
      allowMetered: verdict.allowed,
    );

    // Paint the ongoing notification immediately so the batch is visible even
    // before WorkManager promotes its worker.
    await DownloadNotifications.showProgress(
      jobId: jobId,
      title: mangaTitle ?? '',
      coverUrl: coverUrl,
      donePages: 0,
      totalPages: resolvable.fold<int>(0, (sum, c) => sum + c.pages.length),
      doneChapters: 0,
      totalChapters: resolvable.length,
    );

    return DownloadRequestResult(
      queued: resolvable.length,
      alreadyDownloaded: skipped,
      unavailable: unavailable,
      blocked: false,
      jobId: jobId,
    );
  }

  /// Page list for a chapter, or null when the source can't be reached.
  static Future<List<String>?> _pagesFor(
    MangaSource source,
    String chapterId,
  ) async {
    try {
      return await source.getPageUrls(chapterId);
    } catch (_) {
      return null;
    }
  }
}
