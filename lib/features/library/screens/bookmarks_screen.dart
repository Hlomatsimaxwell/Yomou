import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Every bookmarked page across all manga, most recent first.
class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  Future<void> _reload() async {
    final rows = await DatabaseHelper.instance.getAllBookmarks();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final pageIndex = (row['pageIndex'] as int?) ?? 0;
    final title = row['chapterTitle'] as String? ?? '';
    final id = row['id'] as int;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final l = AppLocalizations.of(context);
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
          title: Text(
            l.deleteBookmarkTitle,
            style: TextStyle(
              color: dark
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 17,
            ),
          ),
          content: Text(
            title.isEmpty
                ? l.bookmarkPage(pageIndex + 1)
                : l.bookmarkItem(title, pageIndex + 1),
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
                l.delete,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    await DatabaseHelper.instance.deleteBookmark(id);
    _reload();
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
          l.bookmarksTitle,
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
              icon: RemixIcons.bookmark_3_line,
              title: l.bookmarksEmpty,
              subtitle: l.bookmarksEmptySubtitle,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _rows.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final row = _rows[index];
                return _BookmarkTile(row: row, onDelete: _confirmDelete);
              },
            ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _BookmarkTile({required this.row, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l = AppLocalizations.of(context);
    final mangaId = row['mangaId'] as String? ?? '';
    final mangaTitle = row['mangaTitle'] as String? ?? mangaId;
    final mangaCover = row['mangaCover'] as String? ?? '';
    final sourceId = row['mangaSource'] as String?;
    final chapterTitle = row['chapterTitle'] as String? ?? '';
    final pageIndex = (row['pageIndex'] as int?) ?? 0;
    final createdAt = row['createdAt'] as String? ?? '';

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
                    chapterTitle.isEmpty
                        ? l.bookmarkPage(pageIndex + 1)
                        : l.bookmarkItem(chapterTitle, pageIndex + 1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark ? Colors.white70 : const Color(0xFF49454F),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmtDate(createdAt, l),
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
              tooltip: l.deleteBookmarkTooltip,
              onPressed: () => onDelete(row),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String iso, AppLocalizations l) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
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
