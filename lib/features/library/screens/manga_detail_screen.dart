import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:remixicon/remixicon.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/screens/related_manga_screen.dart';
import 'package:yomou/features/reader/screens/reader_screen.dart';
import 'package:yomou/features/reader/services/chapter_downloader.dart';
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/data/models/manga_details.dart';
import 'package:yomou/data/models/bookmark.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/explore/screens/source_search_results_screen.dart';
import 'package:yomou/features/explore/screens/global_search_results_screen.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

class MangaDetailScreen extends ConsumerStatefulWidget {
  final String mangaId;
  final String title;
  final String imageUrl;
  final String? sourceId;

  const MangaDetailScreen({
    super.key,
    required this.mangaId,
    required this.title,
    required this.imageUrl,
    this.sourceId,
  });

  @override
  ConsumerState<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends ConsumerState<MangaDetailScreen> {
  int _activeTab = 0; // 0: Chapter List, 1: Pages Grid, 2: Bookmarks

  // Chapter multi-selection state (chapter ids currently selected).
  final Set<String> _selectedIds = <String>{};
  bool _selectionMode = false;

  // Favorite state & persistence (backed by the manga database table).
  bool _isFavorite = false;
  bool _isLoadingPreferences = true;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isExpanded = false;
  bool _showSheetContent = false;

  // Description expand/collapse state (independent of the app bar shrink).
  bool _descriptionExpanded = false;

  String? _sourceName;

  List<Chapter> _chapters = [];
  bool _isLoadingChapters = true;
  String? _chapterError;
  MangaSource? _source;

  MangaDetails? _details;

  // The source's authoritative chapter count (-1 until loaded).
  int _realTotalChapters = -1;

  // Total size of downloaded pages on disk (bytes).
  int _downloadSize = 0;

  // Per-chapter download progress: {chapterId: (done, total)}.
  final Map<String, ({int done, int total})> _downloadingChapters = {};

  // Real related manga loaded from the source (excluding the current one).
  List<Manga> _relatedManga = [];

  // Real reading progress from the database.
  double _progressPercent = 0;
  double _lastReadChapter = -1;
  int _lastReadPage = 0;

  // Real bookmarks for this manga.
  List<Bookmark> _bookmarks = [];

  // Captures the DraggableScrollableSheet's scroll controller so we can
  // programmatically scroll the chapter list to the oldest chapter.
  ScrollController? _sheetContentController;
  bool _trayScrollListening = false;
  bool _trayAtBottom = false;
  bool _isLoadingBookmarks = true;

  // Tray shows chapters oldest-first; toggling this shows newest-first.
  bool _reverseOrder = false;

  // Pages grid: page URLs for the preview chapter.
  List<String> _previewPages = [];
  bool _isLoadingPages = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
    _loadChapters();
    _loadProgress();
    _loadBookmarks();

    _sheetController.addListener(() {
      final currentSize = _sheetController.size;
      final isTop = currentSize > 0.8;
      if (isTop != _isExpanded) {
        setState(() => _isExpanded = isTop);
      }

      final shouldShowContent = currentSize > 0.12;
      if (shouldShowContent != _showSheetContent) {
        setState(() => _showSheetContent = shouldShowContent);
      }
    });
  }

  // Chapters are sorted oldest-first so the first chapter is at the top of
  // the tray and the latest chapter is reached by scrolling down.
  List<Chapter> _sortChaptersNewestFirst(List<Chapter> chapters) {
    final sorted = [...chapters];
    sorted.sort((a, b) => (_chapterNum(a) - _chapterNum(b)).toInt());
    return sorted;
  }

  double _chapterNum(Chapter ch) {
    final num = RegExp(r'(\d+(\.\d+)?)')
        .firstMatch(ch.chapterNumber)
        ?.group(1);
    return num != null ? double.tryParse(num) ?? 0 : 0;
  }

  Future<void> _loadChapters({
    bool forceRefresh = false,
    MangaSource? sourceOverride,
  }) async {
    setState(() {
      _isLoadingChapters = true;
      _chapterError = null;
    });
    try {
      final source = sourceOverride ??
          (widget.sourceId != null ? getSourceBySourceId(widget.sourceId!) : null);
      if (source == null) {
        setState(() {
          _chapters = [];
          _isLoadingChapters = false;
        });
        return;
      }
      final chapters = await SourceCache.chapters(
        sourceId: source.id,
        mangaId: widget.mangaId,
        forceRefresh: forceRefresh,
        fetch: () => source.getChapters(widget.mangaId),
      );
      if (mounted) {
        setState(() {
          _source = source;
          _sourceName = source.name;
          _chapters = _sortChaptersNewestFirst(chapters);
          _isLoadingChapters = false;
        });
      }

      // Fetch real manga details + preview pages (best-effort, don't block UI).
      final details = await SourceCache.mangaDetails(
        sourceId: source.id,
        mangaId: widget.mangaId,
        forceRefresh: forceRefresh,
        fetch: () => source.getMangaDetails(widget.mangaId),
      );
      if (details != null && mounted) {
        setState(() => _details = details);
        // Cache tags in the database for the suggestions engine.
        if (details.tags.isNotEmpty) {
          DatabaseHelper.instance.saveMangaTags(widget.mangaId, details.tags);
        }
      }
      if (chapters.isNotEmpty && mounted) {
        _loadPreviewPages();
      }
      _loadRelatedManga(source);
      _loadTotalChapters(source);
      _loadDownloadSize();
    } catch (e) {
      if (mounted) {
        setState(() {
          _chapterError = e.toString();
          _isLoadingChapters = false;
        });
      }
    }
  }

  // Load the source's authoritative chapter count (best-effort).
  Future<void> _loadTotalChapters(MangaSource source) async {
    try {
      final total = await source.getTotalChapters(widget.mangaId);
      if (total > 0 && mounted) {
        setState(() => _realTotalChapters = total);
      }
    } catch (e) {
      _realTotalChapters = -1;
    }
  }

  Future<void> _loadDownloadSize() async {
    final size = await ChapterDownloader.getDownloadSize(widget.mangaId);
    if (mounted) setState(() => _downloadSize = size);
  }

  // Load the real saved reading progress for this manga from the database.
  Future<void> _loadProgress() async {
    final row = await DatabaseHelper.instance.getManga(widget.mangaId);
    if (!mounted) return;
    setState(() {
      _lastReadChapter = row?['lastReadChapter'] is num
          ? (row!['lastReadChapter'] as num).toDouble()
          : -1;
      _lastReadPage = (row?['lastReadPage'] as int?) ?? 0;
      final total = (row?['totalChapters'] as int? ?? 0);
      if (_lastReadChapter >= 0 && total > 0) {
        final clamped = _lastReadChapter.clamp(0, total.toDouble());
        _progressPercent = (clamped / total) * 100;
      }
    });
  }

  // Load saved bookmarks for this manga.
  Future<void> _loadBookmarks() async {
    final rows = await DatabaseHelper.instance.getBookmarks(widget.mangaId);
    if (!mounted) return;
    setState(() {
      _bookmarks = rows.map(Bookmark.fromMap).toList();
      _isLoadingBookmarks = false;
    });
  }

  // Load the first chapter's page URLs to populate the Pages Grid tab.
  Future<void> _loadPreviewPages() async {
    if (_chapters.isEmpty || _isLoadingPages) return;
    setState(() => _isLoadingPages = true);
    try {
      final source = getSourceBySourceId(widget.sourceId ?? '');
      final pages = source == null
          ? <String>[]
          : await SourceCache.pageUrls(
              sourceId: source.id,
              chapterId: _chapters.first.id,
              fetch: () => source.getPageUrls(_chapters.first.id),
            );
      if (mounted) {
        setState(() {
          _previewPages = pages;
          _isLoadingPages = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPages = false);
    }
  }

  // Load manga with similar tags from the same source (excluding current).
  Future<void> _loadRelatedManga(MangaSource source) async {
    try {
      final myTags = (_details?.tags ?? const <String>[])
          .map((t) => t.toLowerCase())
          .toSet();

      final popular = await SourceCache.mangaList(
        sourceId: source.id,
        kind: 'popular',
        page: 1,
        fetch: () => source.getPopularManga(page: 1),
      );
      final candidates = popular
          .where((m) => m.id != widget.mangaId)
          .take(16)
          .toList();

      // Fetch each candidate's tags in parallel and rank by overlap.
      final scored = <(int, Manga)>[];
      final results = await Future.wait(
        candidates.map((m) async {
          try {
            final details = await SourceCache.mangaDetails(
              sourceId: source.id,
              mangaId: m.id,
              fetch: () => source.getMangaDetails(m.id),
            );
            return (m, details);
          } catch (_) {
            return (m, null);
          }
        }),
      );
      for (final (m, d) in results) {
        if (d == null) continue;
        final matches = (d.tags)
            .map((t) => t.toLowerCase())
            .where(myTags.contains)
            .length;
        if (matches > 0) scored.add((matches, m));
        // Cache tags for suggestions engine.
        if (d.tags.isNotEmpty) {
          DatabaseHelper.instance.saveMangaTags(m.id, d.tags);
        }
      }

      // Sort by tag overlap desc, then by title for stability.
      scored.sort((a, b) {
        final byTags = b.$1.compareTo(a.$1);
        return byTags != 0 ? byTags : a.$2.title.compareTo(b.$2.title);
      });

      final related = scored.take(6).map((s) => s.$2).toList();
      if (mounted) {
        setState(() => _relatedManga = related);
      }
    } catch (e) {
      // Ignore; the section simply shows nothing on failure.
    }
  }

  // Load the saved favorite status from the database.
  Future<void> _loadFavoriteStatus() async {
    final isFav = await DatabaseHelper.instance.getIsFavorite(widget.mangaId);
    if (!mounted) return;
    setState(() {
      _isFavorite = isFav;
      _isLoadingPreferences = false;
    });
  }

  // Toggle favorite status in the database and refresh the favorites tab.
  Future<void> _toggleFavorite() async {
    final newValue = !_isFavorite;
    await DatabaseHelper.instance.setFavorite(
      mangaId: widget.mangaId,
      title: widget.title,
      coverUrl: widget.imageUrl,
      sourceId: widget.sourceId,
      isFavorite: newValue,
    );
    if (!mounted) return;
    setState(() {
      _isFavorite = newValue;
    });
    bumpFavoritesRevision(ref);
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _animateSheetTo(double targetSize) {
    _sheetController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  // Scroll the chapter list to the chapter you were last reading (or the
  // first chapter for a fresh manga).
  void _scrollToResumeChapter() {
    final sc = _sheetContentController;
    if (sc == null) return;
    final fraction = _chapters.length <= 1
        ? 1.0
        : (_resumeChapterIndex / (_chapters.length - 1)).clamp(0.0, 1.0);
    void animate() {
      if (sc.hasClients) {
        sc.animateTo(
          sc.position.maxScrollExtent * fraction,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    }

    if (sc.hasClients) {
      animate();
    } else {
      // Retry on the next frame once the list is laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) => animate());
    }
  }

  // True when the tray list is scrolled to its last chapter.
  bool get _trayCanScroll =>
      _sheetContentController?.hasClients == true &&
      _sheetContentController!.position.maxScrollExtent > 40;

  // Track whether the tray list has scrolled to its last chapter.
  void _onTrayContentScroll() {
    final sc = _sheetContentController;
    if (sc == null || !sc.hasClients) return;
    final pos = sc.position;
    final atBottom =
        pos.maxScrollExtent <= 0 ||
        pos.pixels >= pos.maxScrollExtent - 400;
    if (atBottom != _trayAtBottom) {
      setState(() => _trayAtBottom = atBottom);
    }
  }

  // Jump the full-screen tray list to its very top (chapter 1).
  void _jumpTrayToTop() {
    final sc = _sheetContentController;
    if (sc == null || !sc.hasClients) return;
    sc.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  // Jump the full-screen tray list to its last loaded chapter.
  void _jumpTrayToBottom() {
    final sc = _sheetContentController;
    if (sc == null || !sc.hasClients) return;
    sc.animateTo(
      sc.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  // Collapse the sheet back to its small bar.
  void _dismissSheet() {
    _animateSheetTo(0.08);
  }

  // Navigate to Reader Screen
  void _openReader({int? chapterIndex}) {
    if (_chapters.isEmpty) return;
    final indexToOpen = chapterIndex ?? _resumeChapterIndex;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          allChapters: _chapters,
          initialChapterIndex: indexToOpen,
          initialPageIndex: _lastReadPage,
          mangaId: widget.mangaId,
          sourceId: _source?.id,
          mangaTitle: widget.title,
          mangaCoverUrl: widget.imageUrl,
          totalChapters: _resolvedTotalChapters,
        ),
      ),
    ).then((_) {
      // Reload real progress/bookmarks after returning from the reader.
      _loadProgress();
      _loadBookmarks();
    });
  }

  // The source's authoritative chapter count, falling back to the detail info
  // and finally to the loaded list length.
  int get _resolvedTotalChapters {
    if (_realTotalChapters > 0) return _realTotalChapters;
    if ((_details?.totalChapters ?? 0) > 0) return _details!.totalChapters;
    return _chapters.length;
  }

  // Number of chapters not yet read (based on last-read position).
  int get _unreadCount {
    if (_chapters.isEmpty) return 0;
    if (_lastReadChapter <= 0) return _chapters.length;
    final total = _resolvedTotalChapters;
    if (total <= 0) return 0;
    return (total - _lastReadChapter.round())
        .clamp(0, _chapters.length)
        .toInt();
  }

  // Index of the chapter to resume from, based on last-read position.
  // Fresh manga (no progress) opens the very first (oldest) chapter.
  int get _resumeChapterIndex {
    if (_chapters.isEmpty) return 0;
    if (_lastReadChapter <= 0) return 0;

    // Chapters are ordered oldest-first, so the resume chapter index is the
    // last-read chapter's 0-based position (read "10 chapters" -> index 9).
    final lastReadInt = _lastReadChapter.round();
    final byPosition = lastReadInt - 1;
    if (byPosition >= 0 && byPosition < _chapters.length) {
      return byPosition;
    }

    // Fallback: match by the chapter's name number.
    for (var i = 0; i < _chapters.length; i++) {
      final numParsed = double.tryParse(
        RegExp(
              r'(\d+(\.\d+)?)',
            ).firstMatch(_chapters[i].chapterNumber)?.group(1) ??
            '',
      );
      if (numParsed != null && numParsed.round() == lastReadInt) {
        return i;
      }
    }
    return _chapters.length - 1;
  }

  // Tag Search Options Dialog
  void _showTagSearchDialog(String tagName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final textColor = dark
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface;
        return Dialog(
          backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      RemixIcons.price_tag_3_line,
                      color: textColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tagName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AppPress(
                  onTap: () {
                    Navigator.pop(context);
                    final source = _source;
                    if (source == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context).searchEverywhereBusy(tagName),
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SourceSearchResultsScreen(
                          source: source,
                          query: tagName,
                          genre: tagName,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)
                              .searchOnSource(_sourceName ?? ''),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AppPress(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GlobalSearchResultsScreen(searchQuery: tagName),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(context).searchEverywhere,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalizations.of(context).close,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // Tapping the content background dismisses the open sheet.
                if (_sheetController.size > 0.12) _dismissSheet();
              },
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopAppBar(context),
                      _buildHeaderSection(),
                      const SizedBox(height: 16),
                      _buildSourceCard(),
                      const SizedBox(height: 16),
                      _buildDescriptionSection(),
                      const SizedBox(height: 12),
                      _buildTagChips(),
                      const SizedBox(height: 20),
                      _buildRelatedMangaSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox.expand(
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.08,
              minChildSize: 0.08,
              maxChildSize: 1.0,
              snap: true,
              snapSizes: const [0.08, 0.5, 1.0],
              builder: (context, scrollController) {
                _sheetContentController = scrollController;
                if (!_trayScrollListening) {
                  _trayScrollListening = true;
                  scrollController.addListener(_onTrayContentScroll);
                }
                final dark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1E1E20) : Colors.white,
                    borderRadius: _isExpanded
                        ? BorderRadius.zero
                        : const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black87,
                        blurRadius: 20,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: _isExpanded
                        ? BorderRadius.zero
                        : const BorderRadius.vertical(top: Radius.circular(28)),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SheetHeaderDelegate(
                            isExpanded: _isExpanded,
                            activeTab: _activeTab,
                            topPadding: MediaQuery.of(context).padding.top,
                            unreadCount: _unreadCount,
                            showContinueButton:
                                _activeTab == 0 && _chapters.isNotEmpty,
                            hasRead: _lastReadChapter >= 0,
                            isSelectionMode: _selectionMode,
                            selectedCount: _selectedIds.length,
                            isAllSelected: _selectedIds.length == _chapters.length &&
                                _chapters.isNotEmpty,
                            hasSelectionGap: _hasSelectionGap,
                            onContinuePressed: _openReader,
                            onExitSelection: _exitSelection,
                            onSelectRange: _selectChapterRange,
                            onSelectAll: _selectAllChapters,
                            onDeselectAll: _deselectAllChapters,
                            onToggleSelectedRead: _toggleSelectedRead,
                            isAllSelectedRead: _isAllSelectedRead,
                            hasDownloaded: _isSelectedDownloaded,
                            onRemoveDownloads: _deleteSelectedDownloads,
                            onDownload: _downloadSelectedChapters,
                            onBarTap: () {
                              final current = _sheetController.size;
                              if (current < 0.2) {
                                _animateSheetTo(0.5);
                                _scrollToResumeChapter();
                              } else if (current > 0.6) {
                                // Fullscreen: collapse back to the half state.
                                _animateSheetTo(0.5);
                              } else {
                                _animateSheetTo(0.08);
                              }
                            },
                            reverseOrder: _reverseOrder,
                            onToggleOrder: () =>
                                setState(() => _reverseOrder = !_reverseOrder),
                            onTabSelected: (index) {
                              setState(() => _activeTab = index);
                              if (_sheetController.size < 0.2) {
                                _animateSheetTo(0.5);
                              }
                            },
                          ),
                        ),
                        if (_showSheetContent) ...[
                          if (_activeTab == 0)
                            _buildChapterListSliver()
                          else if (_activeTab == 1)
                            _buildPagesGridSliver()
                          else
                            _buildBookmarksSliver(),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Floating jump button shown on top of the tray when it is full screen.
          if (_showSheetContent && _trayCanScroll && !_selectionMode)
            Positioned(
              right: 14,
              bottom: 90,
              child: IgnorePointer(
                ignoring: !_isExpanded,
                child: AnimatedOpacity(
                  opacity: _isExpanded ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _TrayJumpButton(
                    atBottom: _trayAtBottom,
                    onTap:
                        _trayAtBottom ? _jumpTrayToTop : _jumpTrayToBottom,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChapterListSliver() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final downloadedChapterIds =
        ref
            .watch(downloadedChaptersForMangaProvider(widget.mangaId))
            .valueOrNull ??
        const <String>{};

    if (_isLoadingChapters) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: CircularProgressIndicator(
              color: dark
                  ? Colors.white54
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (_chapterError != null || _source == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
          child: Column(
            children: [
              Text(
                AppLocalizations.of(context).noChaptersAvailable,
                style: TextStyle(
                  color: dark ? Colors.white70 : const Color(0xFF49454F),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _source == null
                    ? AppLocalizations.of(context).sourceNotSupported
                    : _chapterError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final originalIndex =
              _reverseOrder ? _chapters.length - 1 - index : index;
          final ch = _chapters[originalIndex];
          final isRead =
              _lastReadChapter >= 0 &&
              (originalIndex + 1) <= _lastReadChapter;
          final isCurrent = originalIndex == _currentDisplayIndex;
          final downloaded = downloadedChapterIds.contains(ch.id);
          final isSelected = _selectedIds.contains(ch.id);

          return ListTile(
            key: ValueKey(ch.id),
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            shape: isSelected
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: dark ? Colors.white : const Color(0xFF334155),
                      width: 1.5,
                    ),
                  )
                : null,
            tileColor: isSelected
                ? (dark ? const Color(0xFF2C2C2C) : const Color(0xFFE2E8F0))
                : null,
            title: Row(
              children: [
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      RemixIcons.play_fill,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                Expanded(
                  child: Text(
                    ch.chapterNumber == 'Chapter'
                        ? ch.title
                        : AppLocalizations.of(context).chapterNum(ch.chapterNumber),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isRead ? Colors.grey : (dark ? Colors.white : onSurface),
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              () {
                final metadata = _chapterMetadataSubtitle(ch);
                if (metadata.isNotEmpty) return metadata;
                final l = AppLocalizations.of(context);
                if (isRead && downloaded) {
                  return l.chapterStatusReadDownloaded;
                }
                if (isRead) return l.chapterStatusRead;
                if (downloaded) return l.chapterStatusDownloaded;
                return '';
              }(),
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (downloaded)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      RemixIcons.sd_card_line,
                      color: dark ? Colors.white70 : const Color(0xFF49454F),
                      size: 18,
                    ),
                  ),
                if (isSelected)
                  Icon(
                    RemixIcons.checkbox_circle_fill,
                    color: dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                    size: 18,
                  )
                else if (_downloadingChapters.containsKey(ch.id))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: _downloadingChapters[ch.id]!.total > 0
                            ? (_downloadingChapters[ch.id]!.done /
                                    _downloadingChapters[ch.id]!.total)
                                .clamp(0.0, 1.0)
                            : null,
                        strokeWidth: 2.5,
                        color: dark
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                        backgroundColor: dark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                  )
                else if (!_selectionMode && isRead)
                  Icon(
                    RemixIcons.checkbox_circle_line,
                    color: dark ? Colors.white70 : const Color(0xFF49454F),
                    size: 18,
                  ),
              ],
            ),
            onTap: () {
              if (_selectionMode) {
                _toggleSelection(ch.id);
              } else {
                _openReader(chapterIndex: originalIndex);
              }
            },
            onLongPress: () => _enterSelection(ch.id),
          );
        }, childCount: _chapters.length),
      ),
    );
  }

  // The chapter index shown as "current" (green play icon). Uses the last-read
  // position from the DB when available; no icon when nothing has been read.
  int get _currentDisplayIndex {
    if (_lastReadChapter <= 0) return -1;
    // Chapters are ordered oldest-first; the "current" chapter is the last
    // one read (read "10 chapters" -> index 9).
    final index = _lastReadChapter.round() - 1;
    return (index >= 0 && index < _chapters.length) ? index : -1;
  }

  // Formats an ISO chapter date as relative text for recent entries and a
  // human-readable date (e.g. "Aug 22, 2026") for older ones.
  String _formatChapterDate(String iso) {
    final dt =
        DateTime.tryParse(iso)?.toLocal() ?? _parseRawChapterDate(iso);
    if (dt == null) return '';
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final days = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (days == 0) return l.chapterDateToday;
    if (days == 1) return l.chapterDateYesterday;
    if (days < 7) return l.chapterDaysAgo(days);
    final months = [
      l.jan, l.feb, l.mar, l.apr, l.may, l.jun,
      l.jul, l.aug, l.sep, l.oct, l.nov, l.dec,
    ];
    return l.dateLong(months[dt.month - 1], dt.day, dt.year);
  }

  // Some sources return a human-readable string ("Sep 10, 2026") or the
  // MangaKatana style ("Sep-05-2026") instead of ISO 8601.
  DateTime? _parseRawChapterDate(String raw) {
    final s = raw.trim();
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    DateTime? from(int? mo, int? day, int? year) {
      if (mo == null || day == null || year == null) return null;
      return DateTime(year, mo, day);
    }

    // "Sep 10, 2026" / "Sep 10,2026" / "Sep 10 2026"
    for (final m in RegExp(
      r'^([A-Za-z]{3})[.]?[ ](\d{1,2}),?\s*(\d{4})$',
    ).allMatches(s)) {
      final d = from(
        months[m.group(1)!.toLowerCase()],
        int.tryParse(m.group(2)!),
        int.tryParse(m.group(3)!),
      );
      if (d != null) return d;
    }

    // "Sep-05-2026"
    for (final m in RegExp(r'^([A-Za-z]{3})-(\d{1,2})-(\d{4})$').allMatches(s)) {
      final d = from(
        months[m.group(1)!.toLowerCase()],
        int.tryParse(m.group(2)!),
        int.tryParse(m.group(3)!),
      );
      if (d != null) return d;
    }
    return null;
  }

  // Secondary line on each chapter tile: "#2 · Aug 27, 2026" style metadata.
  String _chapterMetadataSubtitle(Chapter ch) {
    final number = ch.chapterNumber.trim();
    final date = (ch.releaseDate?.isNotEmpty ?? false)
        ? _formatChapterDate(ch.releaseDate!)
        : '';
    final parts = <String>[
      if (number.isNotEmpty && number != 'Chapter') '#$number',
      if (date.isNotEmpty) date,
    ];
    return parts.join(' · ');
  }

  void _enterSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
    // Jump the tray to full height so the selection actions stay visible.
    _animateSheetTo(1.0);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedIds.add(id)) {
        _selectedIds.remove(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _exitSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  // Adds every chapter between the min and max indices of the current
  // selection, then keeps just that contiguous range selected.
  void _selectChapterRange() {
    if (_chapters.isEmpty || _selectedIds.isEmpty) return;
    final indices = <int>[
      for (var i = 0; i < _chapters.length; i++)
        if (_selectedIds.contains(_chapters[i].id)) i,
    ];
    final minIndex = indices.reduce((a, b) => a < b ? a : b);
    final maxIndex = indices.reduce((a, b) => a > b ? a : b);
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(
          _chapters
              .sublist(minIndex, maxIndex + 1)
              .map((c) => c.id),
        );
    });
  }

  // True when there are non-selected chapters between the extremes of the
  // current selection (i.e. a range fill would actually select something).
  bool get _hasSelectionGap {
    if (_selectedIds.length < 2) return false;
    final indices = <int>[
      for (var i = 0; i < _chapters.length; i++)
        if (_selectedIds.contains(_chapters[i].id)) i,
    ];
    if (indices.length < 2) return false;
    final minIndex = indices.reduce((a, b) => a < b ? a : b);
    final maxIndex = indices.reduce((a, b) => a > b ? a : b);
    return (maxIndex - minIndex + 1) > indices.length;
  }

  // Selects every chapter in the list.
  void _selectAllChapters() {
    if (_chapters.isEmpty) return;
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(_chapters.map((c) => c.id));
    });
  }

  // Clears the selection and exits selection mode.
  void _deselectAllChapters() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  // True when every selected chapter is in the "read" range.
  bool get _isAllSelectedRead {
    if (_selectedIds.isEmpty) return false;
    for (var i = 0; i < _chapters.length; i++) {
      if (!_selectedIds.contains(_chapters[i].id)) continue;
      final isRead =
          _lastReadChapter >= 0 &&
          (i + 1) <= _lastReadChapter;
      if (!isRead) return false;
    }
    return true;
  }

  bool get _isSelectedDownloaded {
    final downloadedIds =
        ref.read(downloadedChaptersForMangaProvider(widget.mangaId)).valueOrNull;
    if (downloadedIds == null) return false;
    return _selectedIds.any(downloadedIds.contains);
  }

void _toggleSelectedRead() {
    // Batch read/unread toggle — flips the last-read threshold so all
    // selected chapters fall on the opposite side. Newest chapter = highest
    // number; a chapter index i is read when it maps to a chapter number
    // <= _lastReadChapter.
    final selectedIndices = <int>[
      for (var i = 0; i < _chapters.length; i++)
        if (_selectedIds.contains(_chapters[i].id)) i,
    ];
    if (selectedIndices.isEmpty) return;

    final targetChapterNumbers = selectedIndices
        .map((i) => i + 1)
        .toList();
    final double newThreshold = _isAllSelectedRead
        // Mark unread: drop threshold below the lowest (oldest) selected.
        ? (targetChapterNumbers.reduce((a, b) => a < b ? a : b) - 1).toDouble()
        // Mark read: raise threshold to cover the highest (oldest) selected.
        : targetChapterNumbers.reduce((a, b) => a > b ? a : b).toDouble();

    setState(() {
      _lastReadChapter = newThreshold;
      _progressPercent = (_lastReadChapter / _resolvedTotalChapters) * 100;
    });
    DatabaseHelper.instance.saveMangaProgress(
      mangaId: widget.mangaId,
      title: widget.title,
      coverUrl: widget.imageUrl,
      sourceId: widget.sourceId,
      lastReadChapter: newThreshold,
      lastTrayTotalChapters: _resolvedTotalChapters,
    );
    _exitSelection();
  }

  Future<void> _downloadSelectedChapters() async {
    final chapters =
        _chapters.where((c) => _selectedIds.contains(c.id)).toList();
    _exitSelection();
    await _downloadChapters(chapters);
  }

  Future<void> _downloadChapters(List<Chapter> chapters) async {
    final source = _source;
    if (source == null) return;
    var success = 0;
    for (final ch in chapters) {
      try {
        setState(() {
          _downloadingChapters[ch.id] = const (done: 0, total: 0);
        });
        final pages = await source.getPageUrls(ch.id);
        if (pages.isEmpty) {
          setState(() => _downloadingChapters.remove(ch.id));
          continue;
        }
        setState(() {
          _downloadingChapters[ch.id] = (done: 0, total: pages.length);
        });
        final saved = await ChapterDownloader.downloadChapter(
          mangaId: widget.mangaId,
          chapterId: ch.id,
          pages: pages,
          headers: source.headers,
          onProgress: (done, total) {
            if (mounted) {
              setState(() {
                _downloadingChapters[ch.id] = (done: done, total: total);
              });
            }
          },
        );
        if (saved == null || saved.isEmpty) continue;
        final dir = await ChapterDownloader.chapterDir(
          widget.mangaId,
          ch.id,
        );
        await DatabaseHelper.instance.addDownload(
          mangaId: widget.mangaId,
          chapterId: ch.id,
          chapterNumber: double.tryParse(ch.chapterNumber) ?? 0,
          chapterTitle: ch.title,
          pageCount: saved.length,
          localDir: dir.path,
          pageUrls: jsonEncode(pages),
        );
        success++;
      } catch (_) {
        // skip failed chapter, continue with the rest
      }
      if (mounted) {
        setState(() => _downloadingChapters.remove(ch.id));
      }
    }
    if (!mounted) return;
    bumpDownloadsRevision(ref);
    await DatabaseHelper.instance.upsertManga(
      mangaId: widget.mangaId,
      title: widget.title,
      coverUrl: widget.imageUrl,
      sourceId: widget.sourceId,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).downloadedChaptersCount(success),
        ),
      ),
    );
  }

  // Chapters not yet read (oldest-first based on read position), capped at
  // [count]. Falls back to the newest [count] chapters when everything is read.
  List<Chapter> _buildUnreadChapters(int count) {
    final unread = <Chapter>[];
    for (var i = 0; i < _chapters.length; i++) {
      final isRead = _lastReadChapter >= 0 &&
          (i + 1) <= _lastReadChapter;
      if (!isRead) {
        unread.add(_chapters[i]);
        if (unread.length == count) break;
      }
    }
    return unread.isNotEmpty ? unread : _chapters.take(count).toList();
  }

  Future<void> _deleteSelectedDownloads() async {
    final selected = _selectedIds.toList();
    _exitSelection();
    for (final ch in _chapters) {
      if (!selected.contains(ch.id)) continue;
      await ChapterDownloader.removeChapterFiles(widget.mangaId, ch.id);
      await DatabaseHelper.instance.removeDownload(widget.mangaId, ch.id);
    }
    if (!mounted) return;
    bumpDownloadsRevision(ref);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).deletedSelectedDownloads,
        ),
      ),
    );
  }

  Widget _buildPagesGridSliver() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoadingPages) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: CircularProgressIndicator(
              color: dark
                  ? Colors.white54
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (_previewPages.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
          child: Center(
            child: Text(
              _chapters.isEmpty
                  ? AppLocalizations.of(context).pagesHintStartReading
                  : AppLocalizations.of(context).pagesUnavailable,
              style: TextStyle(
                color: dark ? Colors.white54 : Colors.black54,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedMangaImage(
              imageUrl: _previewPages[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: dark ? const Color(0xFF2C2C2E) : Colors.white,
                child: Center(
                  child: CircularProgressIndicator(
                    color: dark ? Colors.white24 : Colors.black12,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: dark ? const Color(0xFF2C2C2E) : Colors.white,
                child: Center(
                  child: Icon(
                    RemixIcons.image_2_line,
                    color: dark ? Colors.white38 : Colors.black38,
                    size: 24,
                  ),
                ),
              ),
            ),
          );
        }, childCount: _previewPages.length),
      ),
    );
  }

  Widget _buildBookmarksSliver() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (_isLoadingBookmarks) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: CircularProgressIndicator(
              color: dark
                  ? Colors.white54
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (_bookmarks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: EmptyState(
            icon: RemixIcons.bookmark_3_line,
            title: AppLocalizations.of(context).bookmarksEmpty,
            subtitle: AppLocalizations.of(context).mangaDetailBookmarksEmpty,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final bm = _bookmarks[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedMangaImage(
                imageUrl: bm.pageUrl,
                width: 48,
                height: 64,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 48,
                  height: 64,
                  color: dark ? const Color(0xFF2C2C2E) : Colors.white,
                  child: Icon(
                    RemixIcons.image_2_line,
                    color: dark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ),
            title: Text(
              AppLocalizations.of(context)
                  .mangaDetailBookmarkItem(bm.chapterTitle, bm.pageIndex + 1),
              style: TextStyle(
                color: dark ? Colors.white : onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: bm.note != null && bm.note!.isNotEmpty
                ? Text(
                    bm.note!,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  )
                : Text(
                    AppLocalizations.of(context).noNote,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
            trailing: IconButton(
              icon: Icon(
                RemixIcons.delete_bin_6_line,
                color: dark ? Colors.white54 : Colors.black54,
              ),
              onPressed: () async {
                await DatabaseHelper.instance.deleteBookmark(bm.id);
                await _loadBookmarks();
              },
            ),
          );
        }, childCount: _bookmarks.length),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = dark ? Colors.white : const Color(0xFF1C1B1F);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(RemixIcons.arrow_left_line, color: iconColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(RemixIcons.refresh_line, color: iconColor),
            onPressed: () => _loadChapters(forceRefresh: true),
          ),
          IconButton(
            icon: Icon(RemixIcons.share_line, color: iconColor),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(RemixIcons.download_line, color: iconColor),
            onPressed: () => _showSaveMangaDialog(context),
          ),
          IconButton(
            icon: Icon(RemixIcons.more_2_line, color: iconColor),
            onPressed: () => _showOverflowMenu(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showOverflowMenu(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final textColor =
        dark ? Colors.white : Theme.of(context).colorScheme.onSurface;

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildOverflowRow(ctx, RemixIcons.edit_2_line, l.mangaEdit, 'edit'),
            _buildOverflowRow(
                ctx, RemixIcons.earth_line, l.findSimilar, 'similar'),
            _buildOverflowRow(
                ctx, RemixIcons.git_branch_line, l.alternatives, 'alternatives'),
            _buildOverflowRow(ctx, RemixIcons.globe_line, l.openInBrowser, 'web'),
            _buildOverflowRow(
                ctx, RemixIcons.external_link_line, l.createShortcut, 'shortcut'),
            _buildOverflowRow(
                ctx, RemixIcons.swap_line, l.replaceSource, 'replace'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'edit':
        _showEditMetadataSheet(context);
      case 'similar':
        _openSimilarSearch();
      case 'alternatives':
        _openAlternativesSearch();
      case 'web':
        await _openInBrowser();
      case 'shortcut':
        _createShortcut();
      case 'replace':
        await _showReplaceSourceSheet(context);
    }
  }

  Widget _buildOverflowRow(
    BuildContext ctx,
    IconData icon,
    String label,
    String value,
  ) {
    final textColor = Theme.of(ctx).brightness == Brightness.dark
        ? Colors.white
        : Theme.of(ctx).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: Theme.of(ctx).colorScheme.primary),
      title: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  void _openSimilarSearch() {
    final tags = _details?.tags ?? const <String>[];
    final query = tags.isNotEmpty
        ? tags.join(' ')
        : (_details?.title.isNotEmpty == true ? _details!.title : widget.title);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GlobalSearchResultsScreen(searchQuery: query),
      ),
    );
  }

  void _openAlternativesSearch() {
    final query = _details?.title.isNotEmpty == true
        ? _details!.title
        : widget.title;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GlobalSearchResultsScreen(searchQuery: query),
      ),
    );
  }

  Future<void> _openInBrowser() async {
    final l = AppLocalizations.of(context);
    final base = _source?.baseUrl ?? '';
    if (base.isEmpty) {
      _showMessage(l.urlUnavailable);
      return;
    }
    final uri = Uri.parse(base);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) _showMessage(l.urlUnavailable);
    } catch (_) {
      _showMessage(l.urlUnavailable);
    }
  }

  void _createShortcut() {
    _showMessage(AppLocalizations.of(context).shortcutCreated);
  }

  Future<void> _showEditMetadataSheet(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        dark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final details = _details;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: dark ? const Color(0xFF2E2E33) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dark ? Colors.white38 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.mangaEdit,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildEditRow(
                  ctx, l.editMangaTitle, widget.title, RemixIcons.edit_2_line),
              _buildEditRow(
                  ctx, l.editMangaCover, widget.imageUrl, RemixIcons.image_2_line),
              _buildEditRow(
                  ctx,
                  l.editMangaTags,
                  (details?.tags ?? const <String>[]).join(', '),
                  RemixIcons.price_tag_3_line),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      l.cancel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showMessage(l.metadataSaved);
                    },
                    child: Text(l.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditRow(
      BuildContext ctx, String label, String value, IconData icon) {
    final subtitleColor = Theme.of(ctx).brightness == Brightness.dark
        ? Colors.white70
        : const Color(0xFF49454F);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(ctx).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: subtitleColor, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurface,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReplaceSourceSheet(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        dark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final sources = ref.read(sourcesProvider);
    if (sources.isEmpty) {
      _showMessage(l.noSourceToReplace);
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: dark ? const Color(0xFF2E2E33) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: dark ? Colors.white38 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                l.replaceSource,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final source in sources)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      leading: Icon(
                        RemixIcons.stack_line,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                      title: Text(
                        source['name']?.toString() ?? '',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: source['name'] == _source?.name
                          ? Icon(
                              RemixIcons.check_line,
                              color: Theme.of(ctx).colorScheme.primary,
                            )
                          : null,
                      onTap: () =>
                          Navigator.pop(ctx, source['name']?.toString()),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final replacement = getSourceByName(selected);
    await DatabaseHelper.instance.updateMangaSource(
      mangaId: widget.mangaId,
      sourceId: replacement.id,
    );
    if (!mounted) return;
    bumpFavoritesRevision(ref);
    _loadChapters(sourceOverride: replacement);
    _showMessage(l.replaceSourceDone(selected));
  }

  Future<void> _showSaveMangaDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        dark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).colorScheme.primary;
    final chapterTotal = _chapters.length;

    final config = await showDialog<
        ({String target, int count, bool startNow})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          var target = 'all';
          var firstCount = 5;
          var unreadCount = 5;
          var startNow = true;
          var destIndex = 0;
          var formatIndex = 0;

          final counts = [1, 2, 3, 5, 10, 15, 20, 30, 50, 100]
              .where((c) => c <= chapterTotal)
              .toList();
          final countChoices =
              counts.isEmpty ? const [5, 10, 20, 30, 50] : counts;
          if (!countChoices.contains(firstCount)) {
            firstCount = countChoices.last;
          }
          if (!countChoices.contains(unreadCount)) {
            unreadCount = countChoices.last;
          }

          final destOptions = [
            l.destInternalStorage,
            l.destAppFiles,
            l.destCacheFolder,
          ];
          final formatOptions = [
            l.formatAutomatic,
            l.formatCbz,
            l.formatImages,
          ];

          Widget countPicker(int value, void Function(int) onChanged) {
            return DropdownButton<int>(
              value: value,
              isDense: true,
              underline: const SizedBox(),
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              dropdownColor: dark ? const Color(0xFF2E2E33) : Colors.white,
              items: [
                for (final n in countChoices)
                  DropdownMenuItem(
                    value: n,
                    child: Text(
                      '$n',
                      style: TextStyle(
                        color: dark ? Colors.white : const Color(0xFF1C1B1F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            );
          }

          Widget labeledPicker(
            String label,
            int index,
            List<String> options,
            void Function(int) onChanged,
          ) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: dark ? Colors.white70 : const Color(0xFF49454F),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  DropdownButton<int>(
                    value: index,
                    isDense: true,
                    underline: const SizedBox(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    dropdownColor:
                        dark ? const Color(0xFF2E2E33) : Colors.white,
                    items: [
                      for (var i = 0; i < options.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            options[i],
                            style: TextStyle(
                              color:
                                  dark ? Colors.white : const Color(0xFF1C1B1F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) onChanged(v);
                    },
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: dark ? const Color(0xFF2E2E33) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              l.saveManga,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioGroup<String>(
                    groupValue: target,
                    onChanged: (v) {
                      if (v != null) setDialogState(() => target = v);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RadioListTile<String>(
                          value: 'all',
                          activeColor: accent,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l.downloadWholeManga(chapterTotal),
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        RadioListTile<String>(
                          value: 'first',
                          activeColor: accent,
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l.downloadFirstChapters(firstCount),
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              countPicker(firstCount, (v) {
                                setDialogState(() => firstCount = v);
                                target = 'first';
                              }),
                            ],
                          ),
                        ),
                        RadioListTile<String>(
                          value: 'unread',
                          activeColor: accent,
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l.downloadNextUnread(unreadCount),
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              countPicker(unreadCount, (v) {
                                setDialogState(() => unreadCount = v);
                                target = 'unread';
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.06)
                          : accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(RemixIcons.information_line,
                            size: 18,
                            color:
                                dark ? Colors.white54 : const Color(0xFF49454F)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.downloadHint,
                            style: TextStyle(
                              color: dark
                                  ? Colors.white70
                                  : const Color(0xFF49454F),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    value: startNow,
                    onChanged: (v) => setDialogState(() => startNow = v),
                    activeThumbColor: accent,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l.startDownload,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      l.startDownloadQueueHint,
                      style: TextStyle(
                        color:
                            dark ? Colors.white54 : const Color(0xFF6B6B6B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Divider(height: 16, color: Colors.white24),
                  Theme(
                    data: Theme.of(ctx).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      iconColor: textColor,
                      collapsedIconColor: textColor,
                      textColor: textColor,
                      collapsedTextColor: textColor,
                      title: Text(
                        l.moreOptions,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        labeledPicker(l.destinationDirectory, destIndex,
                            destOptions, (v) {
                          setDialogState(() => destIndex = v);
                        }),
                        labeledPicker(l.preferredFormat, formatIndex,
                            formatOptions, (v) {
                          setDialogState(() => formatIndex = v);
                        }),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding:
                const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                ),
                child: Text(
                  l.cancel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton(
                onPressed: chapterTotal == 0
                    ? null
                    : () => Navigator.pop(
                          ctx,
                          (target: target, count: target == 'first'
                              ? firstCount
                              : unreadCount, startNow: startNow),
                        ),
                style: FilledButton.styleFrom(
                  foregroundColor: dark ? const Color(0xFF1C1B1F) : Colors.white,
                  backgroundColor: accent,
                ),
                child: Text(
                  l.download,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (config == null || !context.mounted) return;
    if (!config.startNow) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.downloadsQueued)),
      );
      return;
    }
    final List<Chapter> targets;
    switch (config.target) {
      case 'first':
        targets = _chapters.take(config.count).toList();
      case 'unread':
        targets = _buildUnreadChapters(config.count);
      default:
        targets = _chapters.toList();
    }
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.downloadNotReady)),
      );
      return;
    }
    await _downloadChapters(targets);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildHeaderSection() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: dark ? null : Border.all(color: Colors.black12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedMangaImage(
                    imageUrl: widget.imageUrl,
                    width: 125,
                    height: 175,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              DownloadedMangaBadge(mangaId: widget.mangaId),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 3,
                  style: TextStyle(
                    color: dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _isLoadingPreferences
                    ? SizedBox(
                        height: 36,
                        width: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: dark
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : GestureDetector(
                        onTap: _toggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: dark
                                ? (_isFavorite
                                      ? const Color(0xFF3A3A3C)
                                      : const Color(0xFF1E1E22))
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: dark
                                  ? (_isFavorite
                                        ? Colors.white70
                                        : Colors.white24)
                                  : (_isFavorite
                                        ? Colors.redAccent
                                        : Colors.black12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isFavorite
                                    ? RemixIcons.heart_3_fill
                                    : RemixIcons.heart_3_line,
                                color: _isFavorite
                                    ? Colors.redAccent
                                    : (dark
                                          ? Colors.white
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSurface),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isFavorite
                                    ? AppLocalizations.of(context).favorited
                                    : AppLocalizations.of(context).favorite,
                                style: TextStyle(
                                  color: dark
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    // Prefer the API-declared chapter count; fall back to the fetched list.
    final totalChapters = _resolvedTotalChapters;
    final chaptersText = _lastReadChapter >= 0
        ? l.chapterOfTotal(_lastReadChapter.floor(), totalChapters)
        : l.chaptersCount(totalChapters);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: dark ? null : Border.all(color: Colors.black12),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          _buildCardRow(
            l.detailSource,
            _details?.sourceId == 'mock'
                ? l.mockSource
                : (_sourceName ?? l.unknown),
            leading: _buildSourceIcon(),
          ),
          _buildCardRow(
            l.detailAuthor,
            _details?.author.isEmpty ?? true ? l.unknown : _details!.author,
          ),
          _buildCardRow(
            l.detailYear,
            _details?.year.isEmpty ?? true ? '—' : _details!.year,
          ),
          if ((_details?.status.isEmpty ?? true) == false)
            _buildCardRow(l.detailState, _details!.status),
          _buildCardRow(l.detailChapters, chaptersText),
          if (_downloadSize > 0)
            _buildCardRow(l.detailOnDevice, _formatBytes(_downloadSize)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                l.detailProgress,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _lastReadChapter >= 0
                        ? (_progressPercent / 100).clamp(0.0, 1.0)
                        : 0,
                    backgroundColor: dark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      dark
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _lastReadChapter >= 0 ? '${_progressPercent.round()}%' : '0%',
                style: TextStyle(
                  color: dark
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Small favicon tile (20×20) for the source row, matching the explore
  // screen fallback: first-letter on a deterministic hue when no icon.
  Widget _buildSourceIcon() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = _sourceName ?? '';
    final source = getSourceBySourceId(widget.sourceId ?? '');
    final iconUrl = source?.iconUrl ?? '';
    final fallbackLetter = name.isEmpty ? '?' : name[0];

    int hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    final bg = HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.35, 0.35)
        .toColor();

    Widget fallback() => Center(
      child: Text(
        fallbackLetter,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: dark ? Colors.white : const Color(0xFF1C1B1F),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ColoredBox(
        color: bg,
        child: SizedBox(
          width: 20,
          height: 20,
          child: iconUrl.isNotEmpty
              ? Image.network(
                  iconUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback(),
                )
              : fallback(),
        ),
      ),
    );
  }

  Widget _buildCardRow(
    String label,
    String value, {
    IconData? icon,
    Widget? leading,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading,
                  const SizedBox(width: 6),
                ] else if (icon != null) ...[
                  Icon(icon, size: 16, color: dark ? Colors.white : onSurface),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: dark ? Colors.white : onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    final settings = ref.watch(appearanceSettingsProvider);
    final hasDescription = !(_details?.description.isEmpty ?? true);
    final description = hasDescription
        ? _details!.description
        : AppLocalizations.of(context).noDescription;
    final collapseByDefault = settings.collapseDescription && hasDescription;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canShowToggle = collapseByDefault &&
            _exceedsLineLimit(description, constraints.maxWidth - 32);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.description,
                    style: TextStyle(
                      color: dark
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (canShowToggle)
                    GestureDetector(
                      onTap: () => setState(
                          () => _descriptionExpanded = !_descriptionExpanded),
                      child: Text(
                        _descriptionExpanded ? l.showLess : l.showMore,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: canShowToggle
                    ? () => setState(
                        () => _descriptionExpanded = !_descriptionExpanded)
                    : null,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Text(
                    description,
                    maxLines: collapseByDefault && !_descriptionExpanded
                        ? 4
                        : null,
                    overflow: collapseByDefault && !_descriptionExpanded
                        ? TextOverflow.ellipsis
                        : TextOverflow.visible,
                    style: TextStyle(
                      color: dark ? Colors.white70 : const Color(0xFF49454F),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _exceedsLineLimit(String text, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
      maxLines: 4,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  Widget _buildTagChips() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tags = (_details?.tags.isNotEmpty ?? false)
        ? _details!.tags
        : const <String>[];
    if (tags.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tags.map((tag) {
          return GestureDetector(
            onTap: () => _showTagSearchDialog(tag),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: dark ? Colors.transparent : const Color(0xFFE2E8F0),
                border: dark ? Border.all(color: Colors.white30) : null,
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: dark ? Colors.white : const Color(0xFF334155),
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRelatedMangaSection() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (_relatedManga.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).relatedManga,
                style: TextStyle(
                  color: dark ? Colors.white : onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RelatedMangaScreen(
                        title: AppLocalizations.of(context).relatedManga,
                        relatedManga: _relatedManga,
                      ),
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.of(context).showAll,
                  style: TextStyle(
                    color: dark ? Colors.white : onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _relatedManga.map((m) {
              return _buildRelatedCard(m);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedCard(Manga manga) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MangaDetailScreen(
              mangaId: manga.id,
              title: manga.title,
              imageUrl: manga.coverUrl,
              sourceId: manga.sourceId,
            ),
          ),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: dark ? null : Border.all(color: Colors.black12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedMangaImage(
                      imageUrl: manga.coverUrl,
                      height: 120,
                      width: 100,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        height: 120,
                        width: 100,
                        color: dark
                            ? const Color(0xFF2C2C2E)
                            : Colors.white,
                        child: Icon(
                          RemixIcons.book_open_line,
                          color: dark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  ),
                ),
                DownloadedMangaBadge(mangaId: manga.id, size: 20, iconSize: 12),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              manga.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark ? Colors.white : onSurface,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isExpanded;
  final int activeTab;
  final double topPadding;
  final int unreadCount;
  final bool showContinueButton;
  final bool hasRead;
  final bool isSelectionMode;
  final int selectedCount;
  final bool isAllSelected;
  final bool hasSelectionGap;
  final VoidCallback onContinuePressed;
  final VoidCallback onBarTap;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onExitSelection;
  final VoidCallback onSelectRange;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback onToggleSelectedRead;
  final bool isAllSelectedRead;
  final bool hasDownloaded;
  final VoidCallback onRemoveDownloads;
  final VoidCallback onDownload;
  final bool reverseOrder;
  final VoidCallback onToggleOrder;

  _SheetHeaderDelegate({
    required this.isExpanded,
    required this.activeTab,
    required this.topPadding,
    this.unreadCount = 0,
    this.showContinueButton = false,
    this.hasRead = false,
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.isAllSelected = false,
    this.hasSelectionGap = false,
    required this.onContinuePressed,
    required this.onBarTap,
    required this.onTabSelected,
    required this.onExitSelection,
    required this.onSelectRange,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onToggleSelectedRead,
    this.isAllSelectedRead = false,
    this.hasDownloaded = false,
    required this.onRemoveDownloads,
    required this.onDownload,
    this.reverseOrder = false,
    required this.onToggleOrder,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isSelectionMode ? null : onBarTap,
      child: Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E1E20) : Colors.white,
          border: dark
              ? null
              : const Border(bottom: BorderSide(color: Colors.black12)),
        ),
        padding: EdgeInsets.only(
          left: 10,
          right: 10,
          top: isExpanded ? (topPadding + 6) : 6,
          bottom: 6,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetDragHandle(),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelectionMode
                  ? _buildSelectionHeader(
                      context,
                      dark: dark,
                      scheme: scheme,
                    )
                  : _buildDefaultHeader(
                      context,
                      dark: dark,
                      scheme: scheme,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Default tray: tab icons, primary Continue/Read pill, and tray controls.
  Widget _buildDefaultHeader(
    BuildContext context, {
    required bool dark,
    required ColorScheme scheme,
  }) {
    return Row(
      key: const ValueKey('defaultTrayHeader'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Chapter list tab (shows unread count when there are unread chapters).
        _buildTabIcon(
          RemixIcons.list_unordered,
          activeTab == 0,
          dark: dark,
          scheme: scheme,
          onTap: () => onTabSelected(0),
          badge: unreadCount > 0 ? _buildBadge(unreadCount) : null,
        ),
        const SizedBox(width: 2),
        _buildTabIcon(
          RemixIcons.grid_line,
          activeTab == 1,
          dark: dark,
          scheme: scheme,
          onTap: () => onTabSelected(1),
        ),
        const SizedBox(width: 2),
        _buildTabIcon(
          activeTab == 2
              ? RemixIcons.bookmark_2_fill
              : RemixIcons.bookmark_2_line,
          activeTab == 2,
          dark: dark,
          scheme: scheme,
          onTap: () => onTabSelected(2),
        ),
        const Spacer(),
        // Fullscreen: Continue pill and chevron are replaced by the
        // search and overflow menu icons in the tray's trailing corner.
        if (isExpanded) ...[
          _buildTabIcon(
            RemixIcons.search_line,
            false,
            dark: dark,
            scheme: scheme,
            onTap: () {},
          ),
          const SizedBox(width: 2),
          _buildTabIcon(
            RemixIcons.arrow_up_down_line,
            reverseOrder,
            dark: dark,
            scheme: scheme,
            onTap: onToggleOrder,
          ),
          const SizedBox(width: 6),
          _buildExpandButton(dark: dark, scheme: scheme),
        ] else ...[
          // Continue/Read action, only for the chapter list tab.
          if (showContinueButton) ...[
            _buildPrimaryButton(
              context: context,
              dark: dark,
              scheme: scheme,
            ),
            const SizedBox(width: 6),
          ],
          _buildExpandButton(dark: dark, scheme: scheme),
        ],
      ],
    );
  }

  // Selection mode header: close, count, range, mark-read and download.
  Widget _buildSelectionHeader(
    BuildContext context, {
    required bool dark,
    required ColorScheme scheme,
  }) {
    final iconColor = dark ? Colors.white : const Color(0xFF1C1B1F);
    return Row(
      key: const ValueKey('selectionTrayHeader'),
      children: [
        IconButton(
          icon: Icon(RemixIcons.close_line, color: iconColor),
          onPressed: onExitSelection,
        ),
        const SizedBox(width: 4),
        Text(
          '$selectedCount',
          style: TextStyle(
            color: iconColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (isAllSelected)
          IconButton(
            icon: Icon(RemixIcons.checkbox_multiple_blank_line, color: iconColor),
            tooltip: AppLocalizations.of(context).deselectAll,
            onPressed: onDeselectAll,
          )
        else ...[
          if (hasSelectionGap)
            IconButton(
              icon: Icon(RemixIcons.list_unordered, color: iconColor),
              tooltip: AppLocalizations.of(context).selectRange,
              onPressed: onSelectRange,
            ),
          IconButton(
            icon: Icon(RemixIcons.checkbox_multiple_line, color: iconColor),
            tooltip: AppLocalizations.of(context).selectAll,
            onPressed: onSelectAll,
          ),
        ],
        IconButton(
          icon: Icon(
            isAllSelectedRead ? RemixIcons.eye_off_line : RemixIcons.eye_line,
            color: iconColor,
          ),
          tooltip: AppLocalizations.of(context).toggleRead,
          onPressed: onToggleSelectedRead,
        ),
        if (hasDownloaded)
          IconButton(
            icon: Icon(RemixIcons.delete_bin_6_line, color: iconColor),
            tooltip: AppLocalizations.of(context).removeDownloadTooltip,
            onPressed: onRemoveDownloads,
          )
        else
          IconButton(
            icon: Icon(RemixIcons.download_line, color: iconColor),
            tooltip: AppLocalizations.of(context).detailDownload,
            onPressed: onDownload,
          ),
      ],
    );
  }

  // A single consistent, tappable tab icon with a circular active highlight.
  Widget _buildTabIcon(
    IconData icon,
    bool active, {
    required bool dark,
    required ColorScheme scheme,
    VoidCallback? onTap,
    Widget? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: active
                  ? (dark ? const Color(0xFF2C2C2E) : Colors.black12)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active
                  ? (dark ? Colors.white : scheme.onSurface)
                  : Colors.grey,
              size: 18,
            ),
          ),
          // Badge sits on the button's top-right corner, clear of the icon.
          if (badge != null)
            Positioned(top: -5, right: -5, child: badge),
        ],
      ),
    );
  }

  // Compact unread-count badge that hugs the icon's top-right corner.
  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.all(3),
      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Subtle chevron that expands the tray.
  Widget _buildExpandButton({
    required bool dark,
    required ColorScheme scheme,
  }) {
    return GestureDetector(
      onTap: onBarTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: dark ? null : Border.all(color: Colors.black12),
        ),
        child: Icon(
          isExpanded ? RemixIcons.arrow_down_s_line : RemixIcons.arrow_up_s_line,
          color: dark ? Colors.white : scheme.onSurface,
          size: 16,
        ),
      ),
    );
  }

  // Primary Read/Continue action pill that lives on the tray.
  Widget _buildPrimaryButton({
    required BuildContext context,
    required bool dark,
    required ColorScheme scheme,
  }) {
    final l = AppLocalizations.of(context);
    final label = hasRead ? l.continueAction : l.readAction;
    return GestureDetector(
      onTap: onContinuePressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(14),
          border: dark ? Border.all(color: Colors.white12, width: 1) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: scheme.onPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 72 + (isExpanded ? topPadding : 0);

  @override
  double get minExtent => 72 + (isExpanded ? topPadding : 0);

  @override
  bool shouldRebuild(covariant _SheetHeaderDelegate oldDelegate) {
    return oldDelegate.isExpanded != isExpanded ||
        oldDelegate.activeTab != activeTab ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.unreadCount != unreadCount ||
        oldDelegate.showContinueButton != showContinueButton ||
        oldDelegate.hasRead != hasRead ||
        oldDelegate.isSelectionMode != isSelectionMode ||
        oldDelegate.selectedCount != selectedCount ||
        oldDelegate.isAllSelectedRead != isAllSelectedRead ||
        oldDelegate.hasDownloaded != hasDownloaded ||
        oldDelegate.reverseOrder != reverseOrder;
  }
}

// Floating circular button shown on the right edge of the full-screen tray.
class _TrayJumpButton extends StatelessWidget {
  final bool atBottom;
  final VoidCallback onTap;

  const _TrayJumpButton({required this.atBottom, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    return Material(
      color: dark ? const Color(0xF22A2A2C) : Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(
            atBottom ? RemixIcons.arrow_up_line : RemixIcons.arrow_down_line,
            size: 22,
            color: fg,
          ),
        ),
      ),
    );
  }
}