import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/storage/storage_stats.dart';
import 'package:yomou/core/utils/relative_time.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/widgets/download_job_card.dart';
import 'package:yomou/features/reader/services/download_job.dart';
import 'package:yomou/features/reader/services/download_scheduler.dart';
import 'package:yomou/features/reader/screens/reader_screen.dart';
import 'package:yomou/features/reader/services/chapter_downloader.dart';
import 'package:yomou/features/settings/screens/downloads_settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:yomou/widgets/m3_components.dart';

/// Every chapter downloaded to local storage, grouped into one card per manga
/// and bucketed by when it was downloaded.
///
/// Kotatsu shows a card per *WorkManager job*; Yomou has no job layer, so a
/// card here is a manga that has finished downloading. There is therefore no
/// queued/in-progress section and no pause/resume — the progress bar instead
/// tracks how much of the downloaded set you've read.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  List<_MangaDownloads> _groups = [];
  List<DownloadJob> _jobs = [];
  bool _loading = true;
  Timer? _jobPoll;

  final Set<String> _expanded = <String>{};
  final Set<String> _selected = <String>{};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _reload();
    // Refresh when a download is added/removed elsewhere.
    ref.listenManual<int>(downloadsRevisionProvider, (prev, next) {
      if (next != prev) _reload();
    });
  }

  @override
  void dispose() {
    _jobPoll?.cancel();
    super.dispose();
  }

  // --- data ---------------------------------------------------------------

  Future<void> _reload() async {
    final rows = await DatabaseHelper.instance.getAllDownloads();
    // Reconciles our rows against WorkManager, so a job killed by a force-stop
    // or a process death is corrected rather than shown as still running.
    final jobs = await DownloadScheduler.reconcile();
    // Rows arrive newest-first, so grouping on first sight keeps each card's
    // chapter list in descending download order and the cards themselves
    // ordered by their most recent chapter.
    final order = <String>[];
    final byManga = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final mangaId = row['mangaId'] as String? ?? '';
      if (mangaId.isEmpty) continue;
      if (!byManga.containsKey(mangaId)) {
        byManga[mangaId] = [];
        order.add(mangaId);
      }
      byManga[mangaId]!.add(row);
    }

    final groups = <_MangaDownloads>[];
    for (final mangaId in order) {
      final chapters = byManga[mangaId]!;
      final first = chapters.first;
      groups.add(
        _MangaDownloads(
          mangaId: mangaId,
          title: first['mangaTitle'] as String? ?? mangaId,
          coverUrl: first['mangaCover'] as String? ?? '',
          sourceId: first['mangaSource'] as String?,
          lastReadChapter:
              (first['mangaLastReadChapter'] as num?)?.toDouble() ?? -1,
          chapters: chapters,
          sizeBytes: await ChapterDownloader.getDownloadSize(mangaId),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _groups = groups;
      _jobs = jobs;
      _loading = false;
      // Drop selections for rows that no longer exist.
      _selected.removeWhere((key) => !groups.any((g) => g.hasChapter(key)));
      if (_selected.isEmpty) _selectionMode = false;
    });
    _syncJobPolling();
  }

  /// Polls only while something is actually in flight, so an idle screen costs
  /// nothing. A finished batch also bumps the downloads revision so saved
  /// chapters appear in the list below.
  void _syncJobPolling() {
    final active = _jobs.any((j) => j.status.isActive);
    if (!active) {
      _jobPoll?.cancel();
      _jobPoll = null;
      return;
    }
    if (_jobPoll != null) return;
    _jobPoll = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (!mounted) return;
      final before = _jobs
          .where((j) => j.status.isActive)
          .map((j) => '${j.jobId}:${j.donePages}:${j.doneChapters}')
          .toSet();
      await _reload();
      final after = _jobs
          .where((j) => j.status.isActive)
          .map((j) => '${j.jobId}:${j.donePages}:${j.doneChapters}')
          .toSet();
      if (before.isNotEmpty && after.isEmpty) {
        // A batch just finished; saved chapters need to be re-read.
        bumpDownloadsRevision(ref);
      }
    });
  }

  // --- selection ----------------------------------------------------------

  void _enterSelection(String key) {
    setState(() {
      _selectionMode = true;
      _selected.add(key);
    });
  }

  void _toggleSelection(String key) {
    setState(() {
      if (!_selected.add(key)) _selected.remove(key);
      if (_selected.isEmpty) _selectionMode = false;
    });
  }

  void _exitSelection() {
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  void _toggleSelectAll() {
    final allKeys = _groups.expand((g) => g.chapterKeys).toList();
    setState(() {
      if (_selected.length == allKeys.length) {
        _selected.clear();
        _selectionMode = false;
      } else {
        _selected
          ..clear()
          ..addAll(allKeys);
        _selectionMode = true;
      }
    });
  }

  // --- actions ------------------------------------------------------------

  Future<void> _removeChapters(Iterable<String> keys) async {
    for (final group in _groups) {
      for (final row in group.chapters) {
        if (!keys.contains(group.keyFor(row))) continue;
        final mangaId = row['mangaId'] as String? ?? '';
        final chapterId = row['chapterId'] as String? ?? '';
        await ChapterDownloader.removeChapterFiles(mangaId, chapterId);
        await DatabaseHelper.instance.removeDownload(mangaId, chapterId);
      }
    }
    bumpDownloadsRevision(ref);
    _exitSelection();
    await _reload();
  }

  Future<void> _confirmRemoveAll() async {
    final l = AppLocalizations.of(context);
    final count = _groups.fold<int>(0, (sum, g) => sum + g.chapters.length);
    final liveJobs = _jobs.where((j) => j.status.isActive).length;
    if (count == 0 && liveJobs == 0) return;
    final confirmed = await _confirm(
      title: l.dlgRemoveAllTitle,
      body: count == 0 ? l.dlgDownloadCancelBody(0, liveJobs) : l.dlgRemoveAllBody,
      confirmLabel: l.remove,
    );
    if (confirmed != true || !mounted) return;
    // Stop in-flight batches first, or a running job would re-add the very
    // chapters this just deleted.
    if (liveJobs > 0) await DownloadScheduler.cancelAll();
    await _removeChapters(_groups.expand((g) => g.chapterKeys));
  }

  Future<void> _confirmRemoveSelected() async {
    final l = AppLocalizations.of(context);
    final count = _selected.length;
    if (count == 0) return;
    final confirmed = await _confirm(
      title: l.dlgRemoveSelectedTitle,
      body: l.dlgRemoveSelectedBody(count),
      confirmLabel: l.remove,
    );
    if (confirmed != true || !mounted) return;
    await _removeChapters(_selected.toList());
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          body,
          style: TextStyle(fontSize: 14, height: 1.4, color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOverflow() async {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final action = await showM3ModalSheet<String>(
      context,
      title: l.downloads,
      children: [
        _SheetRow(
          icon: RemixIcons.delete_bin_6_line,
          label: l.dlgRemoveAll,
          color: cs.error,
          onTap: () => Navigator.pop(context, 'removeAll'),
        ),
        _SheetRow(
          icon: RemixIcons.settings_3_line,
          label: l.dlgSettingsItem,
          subtitle: l.dlgSettingsItemSubtitle,
          color: cs.onSurface,
          onTap: () => Navigator.pop(context, 'settings'),
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'removeAll') {
      await _confirmRemoveAll();
    } else if (action == 'settings') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DownloadsSettingsScreen()),
      );
    }
  }

  /// Opens the reader on [row]'s chapter. The reader is given only the
  /// downloaded chapters so next/previous stays offline and the tray matches
  /// what's actually on the device.
  Future<void> _openChapter(_MangaDownloads group, Map<String, dynamic> row) async {
    final chapters = group.chapters
        .map(
          (r) => Chapter(
            id: r['chapterId'] as String? ?? '',
            title: r['chapterTitle'] as String? ?? '',
            chapterNumber: _fmtNumber(
              (r['chapterNumber'] as num?)?.toDouble() ?? 0,
            ),
            url: '',
          ),
        )
        .toList();
    final index = chapters.indexWhere((c) => c.id == (row['chapterId'] ?? ''));
    if (index < 0) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          allChapters: chapters,
          initialChapterIndex: index,
          mangaId: group.mangaId,
          sourceId: group.sourceId,
          mangaTitle: group.title,
          mangaCoverUrl: group.coverUrl,
          totalChapters: chapters.length,
        ),
      ),
    );
    if (mounted) _reload();
  }

  // --- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _selectionMode
          ? _buildSelectionAppBar(l)
          : SettingsAppBar(
              title: l.downloads,
              actions: [
                IconButton(
                  icon: const Icon(RemixIcons.more_2_fill),
                  tooltip: l.moreOptions,
                  onPressed: _groups.isEmpty && _jobs.isEmpty
                      ? null
                      : _openOverflow,
                ),
              ],
            ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : _groups.isEmpty && !_jobs.any((j) => j.status.isOpen)
          ? EmptyState(
              icon: RemixIcons.download_cloud_line,
              title: l.downloadsEmpty,
              subtitle: l.downloadsEmptySubtitle,
            )
          : _buildList(l),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(AppLocalizations l) {
    final cs = Theme.of(context).colorScheme;
    final all = _groups.expand((g) => g.chapterKeys).toList();
    final allSelected = _selected.length == all.length && all.isNotEmpty;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AppBar(
        leading: IconButton(
          icon: const Icon(RemixIcons.close_line),
          tooltip: l.cancel,
          onPressed: _exitSelection,
        ),
        title: Text(
          l.dlgSelectedCount(_selected.length),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(
              allSelected
                  ? RemixIcons.checkbox_line
                  : RemixIcons.checkbox_multiple_fill,
            ),
            tooltip: allSelected ? l.deselectAll : l.selectAll,
            onPressed: _toggleSelectAll,
          ),
          IconButton(
            icon: const Icon(RemixIcons.delete_bin_6_line),
            color: cs.error,
            tooltip: l.remove,
            onPressed: _selected.isEmpty ? null : _confirmRemoveSelected,
          ),
        ],
      ),
    );
  }

  Widget _buildList(AppLocalizations l) {
    // Flatten into header/card pairs so the whole thing scrolls as one list.
    // Live jobs come first: a download in flight is the reason the user most
    // often opens this screen, and it is time-sensitive in a way the
    // time-grouped history below is not.
    final items = <Widget>[];

    final running = _jobs
        .where((j) => j.status == DownloadJobStatus.running)
        .toList();
    if (running.isNotEmpty) {
      items.add(M3SectionHeader(title: _capitalize(l.dlgInProgress)));
      for (final job in running) {
        items.add(_jobCard(job, l));
      }
    }

    final waiting = _jobs
        .where(
          (j) =>
              j.status == DownloadJobStatus.queued ||
              j.status == DownloadJobStatus.paused,
        )
        .toList();
    if (waiting.isNotEmpty) {
      items.add(M3SectionHeader(title: _capitalize(l.dlgQueued)));
      for (final job in waiting) {
        items.add(_jobCard(job, l));
      }
    }

    final stopped = _jobs
        .where(
          (j) =>
              j.status == DownloadJobStatus.failed ||
              j.status == DownloadJobStatus.cancelled,
        )
        .toList();
    if (stopped.isNotEmpty) {
      items.add(M3SectionHeader(title: _capitalize(l.dlgFailed)));
      for (final job in stopped) {
        items.add(_jobCard(job, l));
      }
    }

    String? prevBucket;
    for (final group in _groups) {
      final bucket = _bucketFor(group.latestAt, l);
      if (bucket.key != prevBucket) {
        items.add(M3SectionHeader(title: bucket.label));
        prevBucket = bucket.key;
      }
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _DownloadCard(
            group: group,
            expanded: _expanded.contains(group.mangaId),
            selectionMode: _selectionMode,
            selected: group.chapterKeys.where(_selected.contains).toSet(),
            onToggleExpand: () => setState(() {
              if (!_expanded.add(group.mangaId)) _expanded.remove(group.mangaId);
            }),
            onLongPressChapter: _enterSelection,
            onToggleChapter: _toggleSelection,
            onTapChapter: (row) {
              final key = group.keyFor(row);
              if (_selectionMode) {
                _toggleSelection(key);
              } else {
                _openChapter(group, row);
              }
            },
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  // --- job controls -------------------------------------------------------

  Widget _jobCard(DownloadJob job, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DownloadJobCard(
        job: job,
        onPause: () => _pauseJob(job),
        onResume: () => _resumeJob(job),
        onCancel: () => _cancelJob(job, l),
        onRemove: () => _removeJob(job),
      ),
    );
  }

  Future<void> _pauseJob(DownloadJob job) async {
    await DownloadScheduler.pause(job.jobId);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _resumeJob(DownloadJob job) async {
    await DownloadScheduler.resume(job);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _cancelJob(DownloadJob job, AppLocalizations l) async {
    final confirmed = await _confirm(
      title: l.dlgDownloadCancelTitle,
      body: l.dlgDownloadCancelBody(job.doneChapters, job.totalChapters),
      confirmLabel: l.dlgDownloadCancel,
    );
    if (confirmed != true) return;
    await DownloadScheduler.cancel(job.jobId);
    if (!mounted) return;
    bumpDownloadsRevision(ref);
    await _reload();
  }

  /// Forgets a finished/failed batch. Only the row goes — chapters that made it
  /// to disk stay downloadable and are already listed below.
  Future<void> _removeJob(DownloadJob job) async {
    await DatabaseHelper.instance.deleteDownloadJob(job.jobId);
    if (!mounted) return;
    await _reload();
  }

  // --- helpers ------------------------------------------------------------

}

/// Time bucket for a card's most recent download. Mirrors Kotatsu's
/// `DateTimeAgo` set, reusing the existing relative-time strings.
///
/// Kotatsu compares whole bucket objects and only emits a header when the
/// bucket changes, so items minutes apart can land in separate groups; the
/// same rule is applied here by comparing [key].
({String key, String label}) _bucketFor(DateTime? time, AppLocalizations l) {
  if (time == null) return (key: 'unknown', label: _capitalize(l.unknown));
  final now = DateTime.now();
  final local = time.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(local.year, local.month, local.day);
  final days = today.difference(that).inDays;

  if (days < 0) {
    // Clock skew or a future timestamp — don't file it under "just now".
    return (
      key: 'abs${local.toIso8601String()}',
      label: _capitalize(_absolute(local, l)),
    );
  }
  if (days == 0) {
    final minutes = now.difference(local).inMinutes;
    if (minutes < 1) {
      return (key: 'justnow', label: _capitalize(l.backupJustNow));
    }
    if (minutes < 60) {
      return (key: 'min$minutes', label: _capitalize(l.backupMinutesAgo(minutes)));
    }
    return (key: 'today', label: _capitalize(l.today));
  }
  if (days == 1) {
    return (key: 'yesterday', label: _capitalize(l.yesterday));
  }
  if (days < 7) {
    return (key: 'day$days', label: _capitalize(l.backupDaysAgo(days)));
  }
  if (days < 30) {
    final weeks = days ~/ 7;
    return (key: 'week$weeks', label: _capitalize(l.backupWeeksAgo(weeks)));
  }
  if (days < 365) {
    final months = days ~/ 30;
    return (key: 'month$months', label: _capitalize(l.backupMonthsAgo(months)));
  }
  final years = days ~/ 365;
  return (key: 'year$years', label: _capitalize(l.backupYearsAgo(years)));
}

/// Section headers elsewhere in the app are title case ("Theme Options"), but
/// the shared time-ago strings are sentence case, so capitalise when used as
/// a header.
String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _absolute(DateTime local, AppLocalizations l) {
  const months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];
  return l.dateLong(months[local.month - 1], local.day, local.year);
}

/// Chapter numbers render without a trailing `.0` when they're whole.
String _fmtNumber(double number) {
  if (number == number.roundToDouble()) return number.toInt().toString();
  return number.toStringAsFixed(1);
}

/// Separator for composite selection keys. Chapter ids are only unique per
/// manga, so keys pair both. A control character can't appear in either id.
const String _keySep = '\u0000';

/// One manga's downloaded chapters, with the on-disk size and how far the user
/// has read into them.
class _MangaDownloads {
  _MangaDownloads({
    required this.mangaId,
    required this.title,
    required this.coverUrl,
    required this.sourceId,
    required this.lastReadChapter,
    required this.chapters,
    required this.sizeBytes,
  });

  final String mangaId;
  final String title;
  final String coverUrl;
  final String? sourceId;

  /// Furthest chapter number the user has read, or -1 when never read.
  final double lastReadChapter;

  /// Chapter rows, most recently downloaded first.
  final List<Map<String, dynamic>> chapters;

  final int sizeBytes;

  /// Chapter ids are only unique per manga, so selection keys are composite.
  List<String> get chapterKeys => chapters.map(keyFor).toList();

  String keyFor(Map<String, dynamic> row) =>
      '${row['mangaId']}$_keySep${row['chapterId']}';

  bool hasChapter(String key) => chapters.any((r) => keyFor(r) == key);

  DateTime? get latestAt {
    final raw = chapters.isEmpty ? null : chapters.first['downloadedAt'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  int get readCount {
    if (lastReadChapter < 0) return 0;
    var count = 0;
    for (final row in chapters) {
      final number = (row['chapterNumber'] as num?)?.toDouble() ?? 0;
      if (number <= lastReadChapter) count++;
    }
    return count;
  }

  double get readFraction =>
      chapters.isEmpty ? 0 : readCount / chapters.length;
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.group,
    required this.expanded,
    required this.selectionMode,
    required this.selected,
    required this.onToggleExpand,
    required this.onLongPressChapter,
    required this.onToggleChapter,
    required this.onTapChapter,
  });

  final _MangaDownloads group;
  final bool expanded;
  final bool selectionMode;

  /// Chapter keys currently selected within this card.
  final Set<String> selected;

  final VoidCallback onToggleExpand;
  final ValueChanged<String> onLongPressChapter;
  final ValueChanged<String> onToggleChapter;
  final ValueChanged<Map<String, dynamic>> onTapChapter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? null : Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPress(
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  _Cover(url: group.coverUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          // A row can outlive its files (cleared externally,
                          // or an interrupted download), so an unknown size is
                          // left out rather than shown as "0 B".
                          group.sizeBytes > 0
                              ? '${l.dlgChapterCount(group.chapters.length)}'
                                    ' · ${formatBytes(group.sizeBytes)}'
                              : l.dlgChapterCount(group.chapters.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          relativeTimeLabel(l, group.latestAt ?? DateTime.now()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      RemixIcons.arrow_down_s_line,
                      color: cs.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _ReadProgress(group: group),
            ),
            _ChapterStrip(
              group: group,
              selectionMode: selectionMode,
              selected: selected,
              onLongPress: onLongPressChapter,
              onToggle: onToggleChapter,
              onTap: onTapChapter,
            ),
          ],
        ],
      ),
    );
  }
}

/// Read progress across the downloaded chapters.
///
/// Kotatsu puts a byte-progress bar here for a running download. Yomou has no
/// job layer, so the bar shows how much of what's on disk has been read —
/// which is the same visual slot with an honest meaning.
class _ReadProgress extends StatelessWidget {
  const _ReadProgress({required this.group});

  final _MangaDownloads group;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final fraction = group.readFraction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.dlgReadProgress(group.readCount, group.chapters.length),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ),
            Text(
              '${(fraction * 100).round()}%',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: cs.onSurface.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
      ],
    );
  }
}

class _ChapterStrip extends StatelessWidget {
  const _ChapterStrip({
    required this.group,
    required this.selectionMode,
    required this.selected,
    required this.onLongPress,
    required this.onToggle,
    required this.onTap,
  });

  final _MangaDownloads group;
  final bool selectionMode;
  final Set<String> selected;
  final ValueChanged<String> onLongPress;
  final ValueChanged<String> onToggle;
  final ValueChanged<Map<String, dynamic>> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: isDark
          ? cs.onSurface.withValues(alpha: 0.05)
          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final row in group.chapters)
            Builder(
              builder: (context) {
                final key = group.keyFor(row);
                final isSelected = selected.contains(key);
                final number = (row['chapterNumber'] as num?)?.toDouble() ?? 0;
                final title = (row['chapterTitle'] as String?) ?? '';
                final isRead = group.lastReadChapter >= 0 && number <= group.lastReadChapter;
                final label = title.isEmpty
                    ? l.chapterNum(_fmtNumber(number))
                    : title;

                return Semantics(
                  // The read tick is colour-only otherwise, so state it for
                  // screen readers.
                  label: isRead ? '$label, ${l.dlgRead}' : label,
                  selected: selectionMode ? isSelected : null,
                  child: AppPress(
                    onTap: () => onTap(row),
                    onLongPress: () => onLongPress(key),
                    pressedScale: 1.0,
                    child: Container(
                      color: isSelected
                          ? cs.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isRead
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _fmtNumber(number),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isRead
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurface, fontSize: 13),
                            ),
                          ),
                          if (selectionMode)
                            Icon(
                              isSelected
                                  ? RemixIcons.checkbox_fill
                                  : RemixIcons.checkbox_blank_line,
                              color: isSelected
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                              size: 19,
                            )
                          else if (isRead)
                            Icon(
                              RemixIcons.checkbox_circle_fill,
                              color: cs.primary,
                              size: 17,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedMangaImage(
        imageUrl: url,
        width: 52,
        height: 70,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          width: 52,
          height: 70,
          color: isDark ? const Color(0xFF2C2C2E) : Colors.black12,
          alignment: Alignment.center,
          child: Icon(
            RemixIcons.book_open_line,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPress(
      onTap: onTap,
      pressedScale: 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
