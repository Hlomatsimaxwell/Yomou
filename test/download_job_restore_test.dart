import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/features/reader/services/download_job.dart';
import 'package:yomou/features/reader/services/download_scheduler.dart';

import 'isolated_database.dart';

/// When a detail screen is rebuilt after the user navigated away, it finds the
/// still-running batch by asking [DownloadScheduler.openJobForManga] for the
/// open job for that series. These pin the lookup the restore relies on: the
/// work is global (a `download_jobs` row), so a fresh screen can pick it back up
/// and show the live banner and per-chapter indicators again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedTestDatabase();

  final chapters = [
    {
      'id': 'ch-1',
      'number': 1.0,
      'title': 'Chapter 1',
      'pages': ['https://example.com/1.png'],
    },
    {
      'id': 'ch-2',
      'number': 2.0,
      'title': 'Chapter 2',
      'pages': ['https://example.com/2.png'],
    },
  ];

  Future<void> put(
    String jobId,
    String mangaId,
    DownloadJobStatus status,
  ) =>
      DatabaseHelper.instance.upsertDownloadJob(
        jobId: jobId,
        mangaId: mangaId,
        chapters: chapters,
        status: status.name,
        totalPages: 2,
        doneChapters: 1,
        donePages: 1,
      );

  test('an in-flight batch is found for the manga it belongs to', () async {
    await put('running-job', 'manga-a', DownloadJobStatus.running);

    final job = await DownloadScheduler.openJobForManga('manga-a');
    expect(job, isNotNull);
    expect(job!.jobId, 'running-job');
    expect(job.status, DownloadJobStatus.running);
    expect(job.doneChapters, 1);
    expect(job.chapters.map((c) => c.id), ['ch-1', 'ch-2']);
  });

  test('queued and paused batches are also restorable', () async {
    await put('queued-job', 'manga-b', DownloadJobStatus.queued);
    await put('paused-job', 'manga-c', DownloadJobStatus.paused);

    expect(
      (await DownloadScheduler.openJobForManga('manga-b'))?.status,
      DownloadJobStatus.queued,
    );
    expect(
      (await DownloadScheduler.openJobForManga('manga-c'))?.status,
      DownloadJobStatus.paused,
    );
  });

  test('a batch for another manga is never restored here', () async {
    await put('other-job', 'manga-d', DownloadJobStatus.running);

    expect(await DownloadScheduler.openJobForManga('manga-e'), isNull);
  });

  test('a finished batch is not restored as a live download', () async {
    await put('done-job', 'manga-f', DownloadJobStatus.completed);

    expect(await DownloadScheduler.openJobForManga('manga-f'), isNull);
  });
}
