import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/reader/services/chapter_downloader.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// All chapters downloaded to local storage across every manga.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
    // Refresh when a download is added/removed elsewhere.
    ref.listenManual<int>(downloadsRevisionProvider, (prev, next) {
      if (next != prev) _reload();
    });
  }

  Future<void> _reload() async {
    final rows = await DatabaseHelper.instance.getAllDownloads();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _confirmRemove(Map<String, dynamic> row) async {
    final mangaId = row['mangaId'] as String? ?? '';
    final chapterId = row['chapterId'] as String? ?? '';
    final title =
        row['chapterTitle'] as String? ??
        AppLocalizations.of(context).chapterNum(_formatChapterNumber(((row['chapterNumber'] as num?) ?? 0).toDouble()));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final l = AppLocalizations.of(context);
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
          title: Text(
            l.removeDownloadTitle,
            style: TextStyle(
              color: dark
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 17,
            ),
          ),
          content: Text(
            l.removeDownloadContent(title),
            style: TextStyle(
              color: dark ? Colors.white70 : const Color(0xFF49454F),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                l.cancel,
                style: TextStyle(
                  color: dark ? Colors.white70 : const Color(0xFF49454F),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                l.remove,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    await ChapterDownloader.removeChapterFiles(mangaId, chapterId);
    await DatabaseHelper.instance.removeDownload(mangaId, chapterId);
    bumpDownloadsRevision(ref);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          l.downloads,
          style: TextStyle(
            color: dark ? Colors.white : const Color(0xFF1C1B1F),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: dark
                    ? Colors.white38
                    : Theme.of(context).colorScheme.primary,
              ),
            )
          : _rows.isEmpty
          ? EmptyState(
              icon: RemixIcons.download_cloud_line,
              title: l.downloadsEmpty,
              subtitle: l.downloadsEmptySubtitle,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _rows.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = _rows[index];
                return _DownloadTile(row: row, onDelete: _confirmRemove);
              },
            ),
    );
  }

  String _formatChapterNumber(double number) {
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(number == number.truncateToDouble() ? 0 : 1);
  }
}

class _DownloadTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _DownloadTile({required this.row, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l = AppLocalizations.of(context);
    final mangaId = row['mangaId'] as String? ?? '';
    final mangaTitle = row['mangaTitle'] as String? ?? mangaId;
    final mangaCover = row['mangaCover'] as String? ?? '';
    final sourceId = row['mangaSource'] as String?;
    final title = row['chapterTitle'] as String? ?? '';
    final chapterNumber = ((row['chapterNumber'] as num?) ?? 0).toDouble();
    final pageCount = (row['pageCount'] as int?) ?? 0;
    final downloadedAt = row['downloadedAt'] as String? ?? '';

    return AppPress(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MangaDetailScreen(
              mangaId: mangaId,
              title: mangaTitle,
              imageUrl: mangaCover,
              sourceId: sourceId,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: dark
                  ? CachedMangaImage(
                      imageUrl: mangaCover,
                      width: 48,
                      height: 64,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        width: 48,
                        height: 64,
                        color: const Color(0xFF2C2C2E),
                        alignment: Alignment.center,
                        child: const Icon(
                          RemixIcons.book_open_line,
                          color: Colors.white38,
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: CachedMangaImage(
                        imageUrl: mangaCover,
                        width: 48,
                        height: 64,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          width: 48,
                          height: 64,
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(
                            RemixIcons.book_open_line,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mangaTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark ? Colors.white : onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title.isEmpty ? l.chapterNum(_fmtNum(chapterNumber)) : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark ? Colors.white70 : const Color(0xFF49454F),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l.downloadsPagesDate(pageCount, _fmtDate(downloadedAt, l)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark ? Colors.white38 : Colors.black38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                RemixIcons.delete_bin_6_line,
                color: dark ? Colors.white38 : Colors.black38,
                size: 20,
              ),
              tooltip: l.removeDownloadTooltip,
              onPressed: () => onDelete(row),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(double number) {
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(1);
  }

  String _fmtDate(String iso, AppLocalizations l) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return l.today;
    if (diff == 1) return l.yesterday;
    final months = [
      l.jan,
      l.feb,
      l.mar,
      l.apr,
      l.may,
      l.jun,
      l.jul,
      l.aug,
      l.sep,
      l.oct,
      l.nov,
      l.dec,
    ];
    return l.dateLong(months[local.month - 1], local.day, local.year);
  }
}
