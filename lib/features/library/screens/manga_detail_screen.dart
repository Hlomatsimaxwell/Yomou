import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:yomou/widgets/cached_manga_image.dart';
import 'package:yomou/widgets/manga_hero.dart';
import 'package:yomou/widgets/cover_viewer.dart';
import 'package:yomou/widgets/sheet_snap.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/haptics.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/deep_links.dart';
import 'package:yomou/core/share.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/core/widgets/responsive.dart' show usesWideLayout;
import 'package:yomou/features/library/providers/favorites_provider.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/widgets/downloaded_badge.dart';
import 'package:yomou/features/library/widgets/mode_segment_control.dart';
import 'package:yomou/features/library/widgets/chapter_job_indicator.dart';
import 'package:yomou/features/library/widgets/content_unavailable_dialog.dart';
import 'package:yomou/features/library/widgets/download_batch_banner.dart';
import 'package:yomou/features/library/screens/related_manga_screen.dart';
import 'package:yomou/features/library/screens/edit_manga_screen.dart';
import 'package:yomou/features/library/screens/alternatives_screen.dart';
import 'package:yomou/features/reader/screens/reader_screen.dart';
import 'package:yomou/features/reader/services/chapter_downloader.dart';
import 'package:yomou/features/reader/services/download_job.dart';
import 'package:yomou/features/reader/services/download_requests.dart';
import 'package:yomou/features/reader/services/download_scheduler.dart';
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/data/models/manga_details.dart';
import 'package:yomou/data/models/manga_translation.dart';
import 'package:yomou/data/models/bookmark.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/explore/screens/source_search_results_screen.dart';
import 'package:yomou/features/feed/providers/updates_provider.dart';
import 'package:yomou/features/explore/screens/global_search_results_screen.dart';
import 'package:yomou/features/source_management/screens/manga_grid_screen.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/source_icon.dart';
import 'package:yomou/core/diagnostics/diag_log.dart';

/// Height of the art plate at the top of the detail screen.
///
/// A fixed plate rather than a full screen: past it the page is plain
/// background. 420dp is Kotatsu-Redo's number, and it is measured from its own
/// layout rather than guessed.
const double _kBackdropHeight = 420;

/// How much of the art plate shows through.
///
/// The reference holds the cover at a quarter opacity. This is the number that
/// decides how bold the whole header reads.
const double _kBackdropArtOpacity = 0.25;

/// Opacity of the wash painted over the art plate.
///
/// The reference paints its vignette at full strength, which is 1.0 here: the
/// art is only visible in a soft band through the middle and melts into the
/// page at both ends. Lowering it shows the art across the whole plate, at the
/// cost of the plate's bottom edge becoming a visible step rather than a fade.
const double _kBackdropWashOpacity = 0.05;

/// The tray's halfway resting size, between the collapsed bar and full screen.
///
/// The size a tap or a small swipe reaches first. A swipe that carries past it
/// keeps going, so the state is a convenience rather than a toll gate on the
/// way to a full-screen tray.
const double _kTrayHalfSize = 0.5;

/// How much of the collapsed tray's lip is trimmed to shorten it.
///
/// The lip is the one part of the tray that carries nothing, so this is the
/// only place the height can come from: a selection row already fills the
/// bar's own interior, so taking the room from there would push those buttons
/// out of the bar.
const double _kTrayLipTrim = 10;

/// The bottom safe-area inset, raised to at least [kBottomChromeClearance].
///
/// Some gesture-nav skins (notably EMUI) paint a translucent swipe strip over
/// the app without reporting a navigation-bar inset, so MediaQuery
/// padding.bottom stays 0 there and bottom-anchored UI would sit flush under
/// the strip. The floor keeps the tray and chapter lists clear on every
/// device; a device that reports a real inset keeps it, since the higher of
/// the two always wins.
double _bottomClearance(BuildContext context) {
  final inset = MediaQuery.of(context).padding.bottom;
  return inset >= kBottomChromeClearance ? inset : kBottomChromeClearance;
}

/// The line shown under "No chapters available" when the list could not load.
///
/// A failure that carries its own message reports itself. "This source is not
/// supported from here" is only true when there was no source to ask at all,
/// so it is the fallback rather than the first answer. The screen used to test
/// `_source == null` first, which meant a timeout, a parse change or a captcha
/// was reported as a missing source: it named a cause that had never been
/// established and hid the real one, which cost an hour of chasing a resolver
/// that was working.
///
/// [error] wins over [sourceMissing] even when both are true, because a source
/// that resolved and then failed still needs its failure reported.
String mangaDetailChapterFailure({
  required AppLocalizations l,
  required bool sourceMissing,
  String? error,
}) {
  if (error != null && error.isNotEmpty) return error;
  return sourceMissing ? l.sourceNotSupported : l.noChaptersAvailable;
}

/// The label on a chapter row: "Ch.12", or the chapter's own title when it has
/// no number.
///
/// The row reads as a chapter and a date, and the word "Chapter" is the heaviest
/// thing in it -- at list weight, spelled out on every row, it turns a scan down
/// the list into reading. The number is what identifies a chapter, so the list
/// abbreviates and the metadata line underneath carries the rest.
///
/// A chapter the source published without a number (a special, an extra) has
/// only its title to go on, and that is worth more to the reader than "Ch.".
String mangaDetailChapterLabel({
  required AppLocalizations l,
  required String chapterNumber,
  required String title,
}) {
  if (chapterNumber == 'Chapter' || chapterNumber.isEmpty) return title;
  return l.chapterNumShort(chapterNumber);
}

class MangaDetailScreen extends ConsumerStatefulWidget {
  final String mangaId;
  final String title;
  final String imageUrl;
  final String? sourceId;

  /// Open the reader as soon as the chapters are in, instead of waiting to be
  /// asked.
  ///
  /// Set by the browse screen's preview pane, where the user has already
  /// committed to reading this title and came from a grid rather than from
  /// this screen. Pushing the reader directly from there would mean fetching
  /// the chapter list in the pane as well, so the request happens here instead
  /// and only once. Going back from the reader then lands on this screen with
  /// the list already loaded, which is what the user sees next anyway.
  final bool autoStartReader;

  /// The [Hero] tag of the cover that should fly into this screen's cover when
  /// it was reached by tapping a grid cell. Null (e.g. a deep link) means the
  /// header cover simply appears.
  final String? heroTag;

  const MangaDetailScreen({
    super.key,
    required this.mangaId,
    required this.title,
    required this.imageUrl,
    this.sourceId,
    this.autoStartReader = false,
    this.heroTag,
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

  /// Chapters handed to the download scheduler, still being queued. The
  /// scheduler resolves every page list up front, so this covers the brief
  /// window between tapping "download" and the job existing.
  int _batchQueued = 0;

  /// The live job for this series, polled so the chapter rows can show
  /// real per-chapter progress while the foreground service works.
  DownloadJob? _activeJob;
  Timer? _jobPoll;

  // Real related manga loaded from the source (excluding the current one).
  List<Manga> _relatedManga = [];

  // Real reading progress from the database.
  double _progressPercent = 0;
  double _lastReadChapter = -1;
  int _lastReadPage = 0;

  // Real bookmarks for this manga.
  List<Bookmark> _bookmarks = [];

  // Set when this screen was asked to start reading on arrival, and cleared
  // once it has done so. Guarded rather than fired inline because both inputs
  // the reader needs arrive from separate futures: the chapter list from
  // _loadChapters and the saved page from _loadProgress. Whichever finishes
  // second starts the reader, so neither has to wait on the other.
  bool _autoStartPending = false;
  bool _autoStartDone = false;

  // Captures the DraggableScrollableSheet's scroll controller so we can
  // programmatically scroll the chapter list to the oldest chapter.
  ScrollController? _sheetContentController;

  // The chapter list's scroll controller on a wide layout, where the list is a
  // pane beside the details rather than a tray sliding over them.
  //
  // Both are kept because only one is ever live: [_listScrollController] is
  // what the jump-to-end button and the "can this scroll" check read, so they
  // follow whichever layout is showing instead of each having to know which.
  final ScrollController _widePaneController = ScrollController();
  ScrollController? get _listScrollController =>
      usesWideLayout(context) ? _widePaneController : _sheetContentController;

  // The wide pane owns its controller outright, so it attaches the scroll
  // listener once when it is built. The tray hands us its controller inside
  // DraggableScrollableSheet's builder instead, and that builder can run many
  // times, so the tray's listener is attached there.
  bool _widePaneScrollListening = false;
  bool _trayScrollListening = false;
  bool _trayAtBottom = false;

  // Where the tray bar's drag started. Null whenever no drag is in progress,
  // which is also how the drag callbacks know to ignore a stray update.
  double? _trayDragStartSize;

  // The tray's resting sizes, rebuilt only when the collapsed size changes.
  // Kept as a field because the sheet re-snaps whenever the list it is handed
  // changes, and a fresh list on every build is what let it re-snap mid-drag.
  List<double>? _traySnapSizesCache;
  double? _traySnapSizesCollapsed;
  bool _isLoadingBookmarks = true;

  // Tray shows chapters oldest-first; toggling this shows newest-first.
  bool _reverseOrder = false;

  // Pages grid: page URLs for the preview chapter.
  List<String> _previewPages = [];
  bool _isLoadingPages = false;

  // Local metadata overrides (custom title/cover) loaded from the database, so
  // edits made on the Edit screen are reflected here without re-entering.
  String? _customTitle;
  String? _customCover;

  // Displayed title/cover: prefer the local override, else the passed-in value.
  String get _title =>
      (_customTitle?.isNotEmpty ?? false) ? _customTitle! : widget.title;
  String get _coverUrl => (_customCover?.isNotEmpty ?? false)
      ? _customCover!
      : (_details?.coverUrl.isNotEmpty == true
            ? _details!.coverUrl
            : widget.imageUrl);

  /// The [Hero] tag the header cover carries.
  ///
  /// It is the tag handed in by the grid when this screen was opened from a
  /// cover, or a screen-local fallback for a deep link. Either way there is
  /// always one, so tapping the cover can fly it out into the full-screen
  /// viewer along the same path a grid cell would have used.
  String get _coverHeroTag =>
      widget.heroTag ??
      'manga-cover-detail:${widget.sourceId ?? ''}:${widget.mangaId}';

  @override
  void initState() {
    super.initState();
    _autoStartPending = widget.autoStartReader;
    _loadFavoriteStatus();
    _loadMetadataOverrides();
    _loadChapters();
    _loadProgress();
    _loadBookmarks();

    _sheetController.addListener(() {
      final currentSize = _sheetController.size;
      final isTop = currentSize > 0.8;
      if (isTop != _isExpanded) {
        setState(() => _isExpanded = isTop);
      }

      // Measured against the collapsed size rather than a fixed fraction: the
      // bar costs 72dp plus the safe area, so on a short window the collapsed
      // tray is a taller share of the screen than on a tall one, and a fixed
      // threshold would decide the list was showing while the tray was shut.
      final shouldShowContent = currentSize > _trayCollapsedSize + 0.001;
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
    final num = RegExp(r'(\d+(\.\d+)?)').firstMatch(ch.chapterNumber)?.group(1);
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
      MangaSource? source = sourceOverride;
      if (source == null &&
          widget.sourceId != null &&
          widget.sourceId!.isNotEmpty) {
        source = getSourceBySourceId(widget.sourceId!);
      }
      if (source == null) {
        // No source was passed (e.g. the updates feed before the fix): fall
        // back to the source recorded on this manga's stored row.
        final row = await DatabaseHelper.instance.getManga(widget.mangaId);
        final storedSourceId = row?['sourceId']?.toString() ?? '';
        if (storedSourceId.isNotEmpty) {
          source = getSourceBySourceId(storedSourceId);
        }
      }
      if (source == null) {
        diagSoon(
          'detail: no source for mangaId=${widget.mangaId} '
          'sourceId=${widget.sourceId}',
        );
        setState(() {
          _chapters = [];
          _isLoadingChapters = false;
        });
        // The source is genuinely absent (an import leftover), so no fetch is
        // going to succeed: offer the Alternatives search up front instead of
        // a dead-end failure line. Only this case gets the dialog -- a source
        // that resolved and then failed reports its own error.
        _promptFindOnOtherSources();
        return;
      }
      diagSoon('detail: source ${source.id} for ${widget.mangaId}');
      // Non-null snapshot: `source` above is reassigned, so closures below
      // would not be able to see it as non-null.
      final src = source;
      // Sources backed by a single shared WebView cannot serve both requests at
      // once, and the chapter listing is by far the larger of the two. Racing
      // them made the header wait on a 640 KB response, which the UI gave up on
      // and reported as a failure. Details are small and quick, so they go
      // first and the chapter fetch starts once the header is already on screen.
      final detailsFuture = SourceCache.mangaDetails(
        sourceId: src.id,
        mangaId: widget.mangaId,
        forceRefresh: forceRefresh,
        fetch: () => src.getMangaDetails(widget.mangaId),
      );
      final chaptersFuture = detailsFuture.then(
        (_) => SourceCache.chapters(
          sourceId: src.id,
          mangaId: widget.mangaId,
          forceRefresh: forceRefresh,
          fetch: () => src.getChapters(widget.mangaId),
        ),
      );
      // The chapter fetch is chained off the details fetch, so a details
      // failure rejects it as well. When that happens nothing awaits this
      // future - the `await detailsFuture` below throws first and the catch
      // at the end of this method reports it - and an error with no listener
      // is handed to the VM, which paints a red error screen over an
      // otherwise working page. Claiming the error here keeps it on the path
      // that reports it; the `await chaptersFuture` further down still
      // throws normally.
      chaptersFuture.then<void>((_) {}, onError: (Object _) {});
      if (mounted) {
        setState(() {
          _source = src;
          _sourceName = src.name;
        });
      }
      final details = await detailsFuture;
      if (details != null && mounted) {
        setState(() => _details = details);
        // Cache tags in the database for the suggestions engine.
        if (details.tags.isNotEmpty) {
          DatabaseHelper.instance.saveMangaTags(widget.mangaId, details.tags);
        }
      }
      final chapters = await chaptersFuture;
      if (mounted) {
        setState(() {
          _chapters = _sortChaptersNewestFirst(chapters);
          _isLoadingChapters = false;
        });
        _maybeAutoStartReader();
      }
      if (chapters.isNotEmpty && mounted) {
        _loadPreviewPages();
      }
      // Opening the detail counts as seeing however many chapters exist now:
      // the updates feed keeps this manga (and its count) but drops its dot.
      if (chapters.isNotEmpty) {
        await DatabaseHelper.instance.markMangaSeen(
          widget.mangaId,
          chapters.length,
        );
        if (mounted) ref.invalidate(updatesProvider);
      }
      _loadRelatedManga(src);
      _loadTotalChapters(src);
      _loadDownloadSize();
    } catch (e) {
      if (mounted) {
        setState(() {
          _chapterError = e.toString();
          _isLoadingChapters = false;
        });
        _maybeAutoStartReader();
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

  // Total size of the pages this manga has on disk, for the card's "On Device"
  // row. Queried after the chapters load rather than computed up front: it
  // walks the file tree, and there is no reason to hold up the list for it.
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
    _maybeAutoStartReader();
  }

  /// Start the reader once both of its inputs have arrived.
  ///
  /// Progress is the one that gates it, not the chapters: opening the reader
  /// at a page belonging to a chapter that has not loaded yet would land on a
  /// page the reader cannot show, whereas waiting for chapters while progress
  /// is still loading just means resuming from page one of the right chapter.
  /// If the chapter fetch fails there is nothing to open, so the request is
  /// dropped rather than retried in a loop -- the screen is still there, and
  /// the user can refresh it by hand.
  void _maybeAutoStartReader() {
    if (!_autoStartPending || _autoStartDone) return;
    if (_isLoadingChapters) return;
    if (_chapters.isEmpty) {
      _autoStartPending = false;
      return;
    }
    _autoStartPending = false;
    _autoStartDone = true;
    // Deferred out of the setState that loading progress just ran inside, so
    // the reader is pushed once this frame has been built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openReader();
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
          .take(8)
          .toList();

      final scored = <(int, Manga)>[];

      // Rows that already carry their tags get ranked straight off the listing.
      // This used to open one detail request per candidate, which is eight
      // requests through a WebView queue that runs them one at a time - and the
      // detail the user actually navigated to competes for the same queue, so
      // it could sit behind all eight. On MangaBall this path costs nothing.
      final tagged = <Manga>[];
      final untagged = <Manga>[];
      for (final m in candidates) {
        (m.tags.isEmpty ? untagged : tagged).add(m);
      }

      void score(Manga m, List<String> tags) {
        final matches = tags
            .map((t) => t.toLowerCase())
            .where(myTags.contains)
            .length;
        if (matches > 0) scored.add((matches, m));
        // Cache tags for suggestions engine.
        if (tags.isNotEmpty) {
          DatabaseHelper.instance.saveMangaTags(m.id, tags);
        }
      }

      for (final m in tagged) {
        score(m, m.tags);
      }

      // Sources that don't tag their listing rows still need the details, one at
      // a time. The queue is serial anyway, so asking for all of them at once
      // bought no concurrency - it only meant a navigate-away could not stop the
      // rest, and they kept the queue busy for as many seconds as there were
      // candidates.
      for (final m in untagged) {
        if (!mounted) return;
        try {
          final details = await SourceCache.mangaDetails(
            sourceId: source.id,
            mangaId: m.id,
            fetch: () => source.getMangaDetails(m.id),
          );
          if (details == null || details.tags.isEmpty) continue;
          score(m, details.tags);
        } catch (_) {
          // A candidate that fails to load simply does not rank.
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

  // Load any custom title/cover saved for this manga (from the Edit screen).
  Future<void> _loadMetadataOverrides() async {
    final row = await DatabaseHelper.instance.getManga(widget.mangaId);
    if (!mounted) return;
    setState(() {
      _customTitle = (row?['title'] as String?)?.trim();
      _customCover = (row?['coverUrl'] as String?)?.trim();
    });
  }

  // Toggle favorite status in the database and refresh the favorites tab.
  Future<void> _toggleFavorite() async {
    appHaptic(ref, AppHaptic.light);
    final newValue = !_isFavorite;
    await DatabaseHelper.instance.setFavorite(
      mangaId: widget.mangaId,
      title: _title,
      coverUrl: _coverUrl,
      sourceId: widget.sourceId,
      isFavorite: newValue,
    );
    if (!mounted) return;
    setState(() {
      _isFavorite = newValue;
    });
    bumpFavoritesRevision(ref);
  }

  /// Where [chapterId] sits in the live job's queue, if the series has one.
  ///
  /// The job row only carries aggregate page counts, so per-chapter state is
  /// derived from queue position: everything before the cursor is on disk, the
  /// chapter at the cursor is in flight, and the rest are still pending. That
  /// is honest — a per-chapter page fraction would be a guess.
  ChapterJobState _jobChapterState(String chapterId) {
    final job = _activeJob;
    if (job == null || !job.status.isOpen) return ChapterJobState.none;
    final index = job.chapters.indexWhere((c) => c.id == chapterId);
    if (index < 0) return ChapterJobState.none;
    if (index < job.doneChapters) return ChapterJobState.saved;
    if (index == job.doneChapters) {
      return job.status == DownloadJobStatus.running
          ? ChapterJobState.active
          : ChapterJobState.pending;
    }
    return ChapterJobState.pending;
  }

  /// Pauses a running batch, or resumes a paused one. Both are the same
  /// affordance because WorkManager has no pause: pausing cancels the platform
  /// work and keeps the row, resuming re-registers it.
  Future<void> _toggleJobPause() async {
    final job = _activeJob;
    if (job == null) return;
    if (job.status == DownloadJobStatus.paused) {
      await DownloadScheduler.resume(job);
    } else {
      await DownloadScheduler.pause(job.jobId);
    }
    if (!mounted) return;
    final reloaded = await DownloadScheduler.load(job.jobId);
    if (!mounted) return;
    setState(() => _activeJob = reloaded);
    _watchJob(job.jobId);
  }

  /// Stops a batch for good. Chapters already saved stay on disk.
  Future<void> _cancelJob() async {
    final job = _activeJob;
    if (job == null) return;
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.dlgDownloadCancelTitle),
        content: Text(
          l.dlgDownloadCancelBody(job.doneChapters, job.totalChapters),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(dialogContext).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.dlgDownloadCancel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await DownloadScheduler.cancel(job.jobId);
    if (!mounted) return;
    _jobPoll?.cancel();
    setState(() => _activeJob = null);
    bumpDownloadsRevision(ref);
  }

  @override
  void dispose() {
    _jobPoll?.cancel();
    _sheetController.dispose();
    _widePaneController.dispose();
    super.dispose();
  }

  void _animateSheetTo(double targetSize) {
    _sheetController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  /// The lip the collapsed tray keeps under its bar.
  ///
  /// The safe-area floor less [_kTrayLipTrim]. Trimming the lip shortens the
  /// tray without touching the bar's interior, so nothing inside the bar moves
  /// relative to the bar -- the whole thing simply sits [_kTrayLipTrim] lower.
  double get _trayBottomLip => _bottomClearance(context) - _kTrayLipTrim;

  /// The collapsed tray, as a fraction of the screen: the tray bar plus its
  /// lip, so collapsing never clips the bar's own gesture-area lip. On a
  /// phone-height screen this lands just above the old 8% peek; on a taller
  /// window the bar costs less of the height, so the ratio shrinks back
  /// toward it.
  double get _trayCollapsedSize {
    final height = MediaQuery.sizeOf(context).height;
    return ((72 + _trayBottomLip) / height).clamp(0.08, 0.5);
  }

  // Scroll the chapter list to the chapter you were last reading (or the
  // first chapter for a fresh manga).
  void _scrollToResumeChapter() {
    final sc = _listScrollController;
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

  // True when the tray list is long enough to be worth jumping around in.
  bool get _trayCanScroll {
    final sc = _listScrollController;
    return sc?.hasClients == true && sc!.position.maxScrollExtent > 40;
  }

  // Track which way the chapter list is being read, for the jump button.
  //
  // The button follows the gesture instead of waiting for an end to be reached:
  // the arrow points the way the list is being read, so it is the down arrow
  // while the reader is working towards the last chapter and the up arrow as
  // soon as they turn back -- sitting four chapters from the end should not be
  // the point at which the arrow changes its mind, and a slow drag should turn
  // it as surely as a flick.
  //
  // The ends still pin it, because from them there is only one way left to go:
  // at the top the button can only offer the last chapter, and at the end it can
  // only offer the first. Without that, over-scrolling at an end would leave the
  // arrow pointing at the end the list is already sitting on.
  void _onTrayContentScroll() {
    final sc = _listScrollController;
    if (sc == null || !sc.hasClients) return;
    final pos = sc.position;

    final bool atBottom;
    if (pos.maxScrollExtent <= 0 || pos.extentAfter <= 8) {
      atBottom = true;
    } else if (pos.pixels <= 8) {
      atBottom = false;
    } else if (pos.userScrollDirection == ScrollDirection.reverse) {
      atBottom = false;
    } else if (pos.userScrollDirection == ScrollDirection.forward) {
      atBottom = true;
    } else {
      // Nothing has moved the list yet, so leave the button as it was.
      atBottom = _trayAtBottom;
    }

    if (atBottom != _trayAtBottom) {
      setState(() => _trayAtBottom = atBottom);
    }
  }

  // Jump the chapter list to its very top (chapter 1).
  void _jumpTrayToTop() {
    final sc = _listScrollController;
    if (sc == null || !sc.hasClients) return;
    sc.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  // Jump the chapter list to its last loaded chapter.
  void _jumpTrayToBottom() {
    final sc = _listScrollController;
    if (sc == null || !sc.hasClients) return;
    sc.animateTo(
      sc.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  /// Where the tray comes to rest: the collapsed bar, halfway, full screen.
  ///
  /// The sheet is given these, and the bar's own drag snaps against the same
  /// list, so the two cannot drift apart. Halfway is what a tap or a small
  /// swipe reaches first; a swipe that carries past it opens the rest of the
  /// way rather than dropping back to it, which is what [sheetNextStop] is for.
  List<double> get _traySnapSizes {
    final collapsed = _trayCollapsedSize;
    // Built once per collapsed size rather than once per build: the sheet is
    // handed this list, and it re-snaps whenever the list changes. A fresh
    // list on every build is what made it re-snap mid-drag.
    if (_traySnapSizesCache == null || _traySnapSizesCollapsed != collapsed) {
      _traySnapSizesCache = [
        collapsed,
        // The sheet asserts its snap sizes are strictly ascending, and the
        // collapsed size is clamped at 0.5 -- so on a window short enough for
        // the bar to reach that, the half stop is simply left out.
        if (_kTrayHalfSize > collapsed + 0.01) _kTrayHalfSize,
        1.0,
      ];
      _traySnapSizesCollapsed = collapsed;
    }
    return _traySnapSizesCache!;
  }

  // The tray bar doubles as the tray's drag handle.
  //
  // A [DraggableScrollableSheet] only sees drags that arrive through the
  // scrollable it hands out, so the bar on its own can only ask the sheet to
  // grow. Dragging it up moves the sheet; dragging it down -- the thing a
  // full-screen tray most needs, and the thing a bar invites -- used to fall
  // through to the chapter list and scroll that instead, leaving the tray stuck
  // open until the list was scrolled all the way back to the top. Kotatsu drags
  // its sheet by its header bar for the same reason; this is the Flutter
  // equivalent, and it works from wherever the list happens to be.
  void _onTrayBarDragStart(DragStartDetails details) {
    if (!_sheetController.isAttached) return;
    _trayDragStartSize = _sheetController.size;
  }

  void _onTrayBarDragUpdate(DragUpdateDetails details) {
    final start = _trayDragStartSize;
    if (start == null || !_sheetController.isAttached) return;
    // The sheet measures itself in fractions of its own container, so the drag
    // is converted through that height rather than the window's: they stop
    // being the same number as soon as anything else takes a slice of the
    // screen.
    final height = _sheetController.sizeToPixels(1.0);
    if (height <= 0) return;
    _sheetController.jumpTo(
      (start - details.delta.dy / height).clamp(_traySnapSizes.first, 1.0),
    );
  }

  void _onTrayBarDragEnd(DragEndDetails details) {
    final start = _trayDragStartSize;
    _trayDragStartSize = null;
    if (start == null || !_sheetController.isAttached) return;
    _animateSheetTo(
      sheetSnapTarget(
        size: _sheetController.size,
        velocity: details.velocity.pixelsPerSecond.dy,
        stops: _traySnapSizes,
      ),
    );
  }

  // Collapse the sheet back to its small bar.
  void _dismissSheet() {
    _animateSheetTo(_trayCollapsedSize);
  }

  // Navigate to Reader Screen
  void _openReader({int? chapterIndex}) {
    if (_chapters.isEmpty) return;
    final indexToOpen = chapterIndex ?? _resumeChapterIndex;
    // The saved page position belongs to the resume chapter only. Tapping a
    // specific chapter in the list always starts it from page one.
    final initialPage = chapterIndex == null ? _lastReadPage : 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          allChapters: _chapters,
          initialChapterIndex: indexToOpen,
          initialPageIndex: initialPage,
          mangaId: widget.mangaId,
          sourceId: _source?.id,
          mangaTitle: _title,
          mangaCoverUrl: _coverUrl,
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
                      showIosToast(
                        context,
                        message: AppLocalizations.of(
                          context,
                        ).searchEverywhereBusy(tagName),
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
                          AppLocalizations.of(
                            context,
                          ).searchOnSource(_sourceName ?? ''),
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
    if (usesWideLayout(context)) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(child: _buildWideLayout(context)),
      );
    }
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
                  padding: EdgeInsets.only(
                    bottom: 90 + _bottomClearance(context),
                  ),
                  // The art plate is the first layer of the scroll content, not
                  // a backdrop pinned to the screen. That is the whole point:
                  // it rides up and off with the header as you scroll, instead
                  // of staying put behind the page. It paints below the header,
                  // so it never takes a tap.
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: _kBackdropHeight,
                        child: _buildImmersiveBackdrop(),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopAppBar(),
                          // The header carries its own top margin now; the nav
                          // row sits directly on it.
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
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox.expand(
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _trayCollapsedSize,
              minChildSize: _trayCollapsedSize,
              maxChildSize: 1.0,
              snap: true,
              // The same list the bar's drag snaps against, so there is one set
              // of resting sizes rather than two that can drift apart. It is
              // cached rather than built inline here: a fresh list on every
              // build reads as changed `snapSizes` to the sheet, which then
              // re-snaps -- and it used to do that mid-drag, which is part of
              // why a swipe up could stop short of full screen.
              snapSizes: _traySnapSizes,
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
                          delegate: _buildSheetHeaderDelegate(),
                        ),
                        if (_batchQueued > 0 || _activeJob != null)
                          SliverToBoxAdapter(
                            child: DownloadBatchBanner(
                              job: _activeJob,
                              pendingCount: _batchQueued,
                              onPause: _toggleJobPause,
                              onCancel: _cancelJob,
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

          // Floating jump button shown on top of the tray when it is full
          // screen. Lifted clear of the safe-area lip rather than parked on
          // its edge: down there it read as part of the phone's own chrome
          // instead of a control on the list. The earlier 90dp placement is
          // the ceiling to avoid -- that floated in the middle of the last
          // chapters rather than over them.
          if (_showSheetContent && _trayCanScroll && !_selectionMode)
            Positioned(
              right: 14,
              bottom: 64 + _bottomClearance(context),
              child: IgnorePointer(
                ignoring: !_isExpanded,
                child: AnimatedOpacity(
                  opacity: _isExpanded ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _TrayJumpButton(
                    atBottom: _trayAtBottom,
                    onTap: _trayAtBottom ? _jumpTrayToTop : _jumpTrayToBottom,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the chapter-list header for whichever layout is showing.
  ///
  /// [docked] is the wide layout, where the list is a pane rather than a tray.
  /// The differences are all consequences of there being no sheet: no drag
  /// handle, no expand chevron, no bottom safe-area padding to clear, and an
  /// order toggle that is always present rather than only at full screen --
  /// there is no "collapsed" state for it to be hiding in. Tapping the bar to
  /// cycle the sheet is meaningless when there is no sheet, so it is inert.
  _SheetHeaderDelegate _buildSheetHeaderDelegate({bool docked = false}) {
    return _SheetHeaderDelegate(
      docked: docked,
      isExpanded: docked || _isExpanded,
      activeTab: _activeTab,
      accent: ref.watch(accentProvider),
      topPadding: docked ? 0 : MediaQuery.of(context).padding.top,
      bottomPadding: docked ? 0 : _trayBottomLip,
      unreadCount: _unreadCount,
      showContinueButton: _activeTab == 0 && _chapters.isNotEmpty,
      hasRead: _lastReadChapter >= 0,
      continueChapterNumber:
          _lastReadChapter >= 0 &&
              _resumeChapterIndex >= 0 &&
              _resumeChapterIndex < _chapters.length
          ? _chapters[_resumeChapterIndex].chapterNumber
          : null,
      isSelectionMode: _selectionMode,
      selectedCount: _selectedIds.length,
      isAllSelected:
          _selectedIds.length == _chapters.length && _chapters.isNotEmpty,
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
        if (docked) return;
        // One stop per tap, so each tap is a step that can be seen: bar to
        // halfway, halfway to full screen, and around again from there. The
        // same walk the bar's own drag does, and the reason a tap no longer
        // skips past the halfway state on its way up.
        final current = _sheetController.size;
        final next = sheetNextStop(size: current, stops: _traySnapSizes);
        _animateSheetTo(next);
        if (next > current) _scrollToResumeChapter();
      },
      onBarDragStart: docked ? null : _onTrayBarDragStart,
      onBarDragUpdate: docked ? null : _onTrayBarDragUpdate,
      onBarDragEnd: docked ? null : _onTrayBarDragEnd,
      onOverflow: () => _showOverflowMenu(context),
      onTabSelected: (index) {
        setState(() => _activeTab = index);
        if (docked) return;
        // Picking a tab is a request to see that tab, so a shut tray opens to
        // the halfway state -- far enough to read the list, not so far that it
        // covers the page for someone who only wanted a glance.
        if (_sheetController.size < 0.2) {
          _animateSheetTo(_kTrayHalfSize);
        }
      },
    );
  }

  /// Master-detail layout for tablets and desktop windows.
  ///
  /// The phone layout stacks everything in one column and puts the chapter
  /// list in a tray that slides up over it, which works because a phone has one
  /// sensible way to use the height. A wide window has both, and stacking them
  /// just makes a tall narrow column with a lot of space beside it. So the
  /// details and the chapter list each get a column and their own scroll
  /// position: reading a chapter list no longer loses the reader's place in
  /// the description, and vice versa.
  ///
  /// The tray does not exist here. There is nothing to drag and nothing to
  /// expand, so the header drops its handle and chevron and keeps the tabs,
  /// Continue pill, order toggle and selection mode that lived in the tray.
  Widget _buildWideLayout(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            // Distinct from the tray: the bottom inset here is only the safe
            // area, because there is no bar to clear.
            padding: EdgeInsets.only(bottom: 24 + _bottomClearance(context)),
            // The same art plate the phone layout scrolls its header over. It
            // rides up and off with the content rather than staying pinned
            // behind the pane, and it is what the details card is translucent
            // over -- without it that card sits on a flat page and reads as a
            // plain filled block, which is what it used to be.
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _kBackdropHeight,
                  child: _buildImmersiveBackdrop(),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopAppBar(),
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
              ],
            ),
          ),
        ),
        // A hairline rather than a wide divider: it has to read as a pane
        // boundary without pulling attention from the covers.
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: dark ? Colors.white12 : Colors.black12,
        ),
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              CustomScrollView(
                controller: _buildWidePaneController(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _buildSheetHeaderDelegate(docked: true),
                  ),
                  if (_batchQueued > 0 || _activeJob != null)
                    SliverToBoxAdapter(
                      child: DownloadBatchBanner(
                        job: _activeJob,
                        pendingCount: _batchQueued,
                        onPause: _toggleJobPause,
                        onCancel: _cancelJob,
                      ),
                    ),
                  if (_activeTab == 0)
                    _buildChapterListSliver()
                  else if (_activeTab == 1)
                    _buildPagesGridSliver()
                  else
                    _buildBookmarksSliver(),
                ],
              ),

              // Live whenever the list is actually long enough to need it. The
              // tray version also fades this in only at full screen; a pane has
              // the full height from the start, so there is no state to wait
              // for -- but the length check still applies, or a three-chapter
              // manga would show a button that cannot do anything. Sat at 16dp
              // it read as pinned to the pane's bottom edge alongside the safe
              // area; lifted to 40 it floats over the last rows instead.
              if (_trayCanScroll && !_selectionMode)
                Positioned(
                  right: 14,
                  bottom: 40 + _bottomClearance(context),
                  child: _TrayJumpButton(
                    atBottom: _trayAtBottom,
                    onTap: _trayAtBottom ? _jumpTrayToTop : _jumpTrayToBottom,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The wide pane's scroll controller, with the at-bottom listener attached
  /// the first time it is asked for.
  ///
  /// Attached here rather than at construction because the pane is built
  /// inside [build]: a controller with a listener that is never used, or one
  /// whose listener outlives the layout it was for, both cost more than this
  /// one line of bookkeeping.
  ScrollController _buildWidePaneController() {
    if (!_widePaneScrollListening) {
      _widePaneScrollListening = true;
      _widePaneController.addListener(_onTrayContentScroll);
    }
    return _widePaneController;
  }

  Widget _buildChapterListSliver() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
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
                mangaDetailChapterFailure(
                  l: AppLocalizations.of(context),
                  sourceMissing: _source == null,
                  error: _chapterError,
                ),
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
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + _bottomClearance(context)),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final originalIndex = _reverseOrder
              ? _chapters.length - 1 - index
              : index;
          final ch = _chapters[originalIndex];
          final isRead =
              _lastReadChapter >= 0 && (originalIndex + 1) <= _lastReadChapter;
          final isCurrent = originalIndex == _currentDisplayIndex;
          final downloaded = downloadedChapterIds.contains(ch.id);
          final isSelected = _selectedIds.contains(ch.id);
          // The label's base colour, before the read step. Near-black in light,
          // white in dark: the row is built on the gap between this and the
          // metadata under it, so it has to be as strong as the surface allows.
          final titleBase = dark ? Colors.white : scheme.onSurface;

          return ListTile(
            key: ValueKey(ch.id),
            // A chapter row is a title with one line of metadata under it, and
            // this list is the screen's main body of information -- so give the
            // pair room rather than compressing it. `dense` would shrink the
            // text along with the box, which is the opposite of what this
            // wants.
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                Expanded(
                  child: Text(
                    mangaDetailChapterLabel(
                      l: AppLocalizations.of(context),
                      chapterNumber: ch.chapterNumber,
                      title: ch.title,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent
                          ? Colors.green
                          : (isRead
                                ? titleBase.withValues(alpha: 0.75)
                                : titleBase),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
              style: TextStyle(
                // The row's supporting line, and it has to stay clearly under
                // the chapter number: the number is the only thing the eye
                // should land on, so this is deliberately a step down in both
                // weight and colour. Not *lighter* than this, though -- at
                // 10.5px a very faint grey stops being quiet and starts being
                // unreadable, which is a different thing, and the reference's
                // ghosted date gets away with its low contrast by being set
                // several points larger. Around 45% of the title's colour is
                // about as quiet as this can go and still read as a date.
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.45),
                fontSize: 10.5,
              ),
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
                else if (_jobChapterState(ch.id) != ChapterJobState.none)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: ChapterJobIndicator(
                        state: _jobChapterState(ch.id),
                        isDark: dark,
                      ),
                    ),
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
    final dt = DateTime.tryParse(iso)?.toLocal() ?? _parseRawChapterDate(iso);
    if (dt == null) return '';
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final days = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (days == 0) return l.chapterDateToday;
    if (days == 1) return l.chapterDateYesterday;
    if (days < 7) return l.chapterDaysAgo(days);
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
    for (final m in RegExp(
      r'^([A-Za-z]{3})-(\d{1,2})-(\d{4})$',
    ).allMatches(s)) {
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
        ..addAll(_chapters.sublist(minIndex, maxIndex + 1).map((c) => c.id));
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
      final isRead = _lastReadChapter >= 0 && (i + 1) <= _lastReadChapter;
      if (!isRead) return false;
    }
    return true;
  }

  bool get _isSelectedDownloaded {
    final downloadedIds = ref
        .read(downloadedChaptersForMangaProvider(widget.mangaId))
        .valueOrNull;
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

    final targetChapterNumbers = selectedIndices.map((i) => i + 1).toList();
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
      title: _title,
      coverUrl: _coverUrl,
      sourceId: widget.sourceId,
      lastReadChapter: newThreshold,
      lastTrayTotalChapters: _resolvedTotalChapters,
    );
    _exitSelection();
  }

  Future<void> _downloadSelectedChapters() async {
    final chapters = _chapters
        .where((c) => _selectedIds.contains(c.id))
        .toList();
    _exitSelection();
    await _downloadChapters(chapters);
  }

  Future<void> _downloadChapters(List<Chapter> chapters) async {
    final source = _source;
    if (source == null || chapters.isEmpty) return;
    if (!mounted) return;

    setState(() => _batchQueued = chapters.length);

    final result = await DownloadRequests.enqueue(
      context: context,
      ref: ref,
      source: source,
      mangaId: widget.mangaId,
      mangaTitle: _title,
      coverUrl: _coverUrl,
      chapters: chapters,
    );
    if (!mounted) return;

    setState(() => _batchQueued = 0);
    final l = AppLocalizations.of(context);
    if (result.blocked) {
      showIosToast(context, message: l.dlsCellularBlocked);
      return;
    }
    if (result.isEmpty) {
      showIosToast(
        context,
        message: result.alreadyDownloaded > 0 && result.unavailable == 0
            ? l.dlgAlreadyDownloaded
            : l.dlgDownloadNothingQueued,
      );
      return;
    }

    // The batch now runs in a foreground service, so this screen doesn't drive
    // it. It only mirrors progress while visible; the authoritative view is the
    // notification, and the Downloads screen tracks the same job.
    _watchJob(result.jobId);
    showIosToast(context, message: l.dlgQueuedDownload(result.queued));
  }

  /// Polls the job row so the banner and per-chapter rings stay live while this
  /// screen is on top. Stops itself once the job reaches a terminal state.
  void _watchJob(String? jobId) {
    _jobPoll?.cancel();
    if (jobId == null) return;
    _jobPoll = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      final job = await DownloadScheduler.load(jobId);
      if (!mounted) {
        _jobPoll?.cancel();
        return;
      }
      if (job == null || !job.status.isOpen) {
        _jobPoll?.cancel();
        setState(() {
          _activeJob = null;
          _downloadingChapters.clear();
        });
        bumpDownloadsRevision(ref);
        return;
      }
      setState(() => _activeJob = job);
    });
  }

  // Chapters not yet read (oldest-first based on read position), capped at
  // [count]. Falls back to the newest [count] chapters when everything is read.
  List<Chapter> _buildUnreadChapters(int count) {
    final unread = <Chapter>[];
    for (var i = 0; i < _chapters.length; i++) {
      final isRead = _lastReadChapter >= 0 && (i + 1) <= _lastReadChapter;
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
    showIosToast(
      context,
      message: AppLocalizations.of(context).deletedSelectedDownloads,
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
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + _bottomClearance(context)),
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
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + _bottomClearance(context)),
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
                  alignment: Alignment.center,
                  child: Icon(
                    RemixIcons.image_2_line,
                    color: dark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ),
            title: Text(
              AppLocalizations.of(
                context,
              ).mangaDetailBookmarkItem(bm.chapterTitle, bm.pageIndex + 1),
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

  /// Takes no context on purpose: the build method already has the State's
  /// own [context] to hand, and using it here is what makes the `mounted`
  /// guard in the refresh handler below the correct one rather than a
  /// lookalike for some other element's context.
  Widget _buildTopAppBar() {
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
            icon: Icon(RemixIcons.share_line, color: iconColor),
            onPressed: () => _showShareSheet(context),
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
    final textColor = dark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

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
                _title,
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
              ctx,
              RemixIcons.earth_line,
              l.findSimilar,
              'similar',
            ),
            _buildOverflowRow(
              ctx,
              RemixIcons.git_branch_line,
              l.alternatives,
              'alternatives',
            ),
            _buildOverflowRow(
              ctx,
              RemixIcons.globe_line,
              l.openInBrowser,
              'web',
            ),
            _buildOverflowRow(
              ctx,
              RemixIcons.external_link_line,
              l.createShortcut,
              'shortcut',
            ),
            _buildOverflowRow(
              ctx,
              RemixIcons.swap_line,
              l.replaceSource,
              'replace',
            ),
            _buildOverflowRow(
              ctx,
              RemixIcons.arrow_up_down_line,
              l.detailReverseOrder,
              'reverse',
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'edit':
        await _openEditMetadata(context);
      case 'similar':
        _openSimilarSearch();
      case 'alternatives':
        _openAlternativesSearch();
      case 'web':
        await _openInBrowser();
      case 'shortcut':
        _createShortcut();
      case 'replace':
        _openAlternativesSearch();
      case 'reverse':
        setState(() => _reverseOrder = !_reverseOrder);
    }
  }

  /// The share entry (the icon next to "open in web browser"): a Kotatsu-style
  /// sheet with two rows — the manga's page on the source's website, and the
  /// https link that opens the manga back inside Yomou. Each row hands its
  /// link to the Android system share sheet, so it can be sent to WhatsApp,
  /// email, or anywhere else in one tap.
  Future<void> _showShareSheet(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final source = _source;
    if (source == null) return;
    // The same page "Open in web browser" opens: the API's canonical URL when
    // it reported one (Asura Scans' public_url), else the source's best link
    // for this manga id.
    final knownPage = _details?.publicUrl ?? '';
    final siteUrl = knownPage.isNotEmpty
        ? knownPage
        : source.websiteMangaUrl(widget.mangaId);
    final yomouLink = buildYomouShareLink(
      sourceId: source.id,
      mangaId: widget.mangaId,
      title: _title,
      websiteUrl: siteUrl,
    );

    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final textColor = dark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    showModalBottomSheet<void>(
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
            ListTile(
              leading: Icon(RemixIcons.link, color: scheme.primary),
              title: Text(
                l.shareLinkInYomou,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              onTap: () async {
                await shareText(yomouLink);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(RemixIcons.globe_line, color: scheme.primary),
              title: Text(
                l.shareLinkOnSource(source.name),
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              onTap: () async {
                await shareText(siteUrl);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
        : (_details?.title.isNotEmpty == true ? _details!.title : _title);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlobalSearchResultsScreen(searchQuery: query),
      ),
    );
  }

  /// Kotatsu-style "Content unavailable" sheet for a manga whose source is
  /// not installed. "Find on other sources" hands off to the Alternatives
  /// search; Close or dismissing leaves the failure line on screen.
  Future<void> _promptFindOnOtherSources() async {
    if (!mounted) return;
    final go = await showContentUnavailableDialog(context, imageUrl: _coverUrl);
    if (go == true && mounted) {
      _openAlternativesSearch();
    }
  }

  void _openAlternativesSearch() {
    String? language;
    if (_source != null) {
      final rows = ref.read(sourcesProvider);
      for (final row in rows) {
        if (row['name'] == _source!.name) {
          language = row['language']?.toString();
          break;
        }
      }
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlternativesScreen(
          mangaId: widget.mangaId,
          title: _title,
          imageUrl: _coverUrl,
          currentSourceId: widget.sourceId ?? _source?.id,
          currentSourceName: _source?.name,
          currentSourceLanguage: language,
          originalTotal: _realTotalChapters > 0
              ? _realTotalChapters
              : _chapters.length,
        ),
      ),
    );
  }

  Future<void> _openInBrowser() async {
    final l = AppLocalizations.of(context);
    final source = _source;
    if (source == null) {
      _showMessage(l.urlUnavailable);
      return;
    }
    // When the source's API reported a canonical page (Asura Scans'
    // `public_url`, which carries the site's volatile slug hash), open that;
    // otherwise let the source build its best link for the manga id.
    final knownPage = _details?.publicUrl ?? '';
    final url = knownPage.isNotEmpty
        ? knownPage
        : source.websiteMangaUrl(widget.mangaId);
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) _showMessage(l.urlUnavailable);
    } catch (_) {
      _showMessage(l.urlUnavailable);
    }
  }

  void _createShortcut() {
    _showMessage(AppLocalizations.of(context).shortcutCreated);
  }

  Future<void> _openEditMetadata(BuildContext context) async {
    final edited = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditMangaScreen(
          mangaId: widget.mangaId,
          title: _title,
          imageUrl: _coverUrl,
          sourceId: widget.sourceId,
        ),
      ),
    );
    if (edited == true && context.mounted) {
      await _loadMetadataOverrides();
      if (!context.mounted) return;
      setState(() {});
      bumpFavoritesRevision(ref);
      bumpHistoryRevision(ref);
      _showMessage(AppLocalizations.of(context).metadataSaved);
    }
  }

  Future<void> _showSaveMangaDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).colorScheme.primary;
    final chapterTotal = _chapters.length;

    final config =
        await showDialog<({String target, int count, bool startNow})>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              var target = 'all';
              var firstCount = 5;
              var unreadCount = 5;
              var startNow = true;
              var destIndex = 0;
              var formatIndex = 0;

              final counts = [
                1,
                2,
                3,
                5,
                10,
                15,
                20,
                30,
                50,
                100,
              ].where((c) => c <= chapterTotal).toList();
              final countChoices = counts.isEmpty
                  ? const [5, 10, 20, 30, 50]
                  : counts;
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
                            color: dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
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
                            color: dark
                                ? Colors.white70
                                : const Color(0xFF49454F),
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
                        dropdownColor: dark
                            ? const Color(0xFF2E2E33)
                            : Colors.white,
                        items: [
                          for (var i = 0; i < options.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                options[i],
                                style: TextStyle(
                                  color: dark
                                      ? Colors.white
                                      : const Color(0xFF1C1B1F),
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
                            Icon(
                              RemixIcons.information_line,
                              size: 18,
                              color: dark
                                  ? Colors.white54
                                  : const Color(0xFF49454F),
                            ),
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
                            color: dark
                                ? Colors.white54
                                : const Color(0xFF6B6B6B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Theme(
                        data: Theme.of(
                          ctx,
                        ).copyWith(dividerColor: Colors.transparent),
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
                            labeledPicker(
                              l.destinationDirectory,
                              destIndex,
                              destOptions,
                              (v) {
                                setDialogState(() => destIndex = v);
                              },
                            ),
                            labeledPicker(
                              l.preferredFormat,
                              formatIndex,
                              formatOptions,
                              (v) {
                                setDialogState(() => formatIndex = v);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                actionsAlignment: MainAxisAlignment.end,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(foregroundColor: accent),
                    child: Text(
                      l.cancel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  FilledButton(
                    onPressed: chapterTotal == 0
                        ? null
                        : () => Navigator.pop(ctx, (
                            target: target,
                            count: target == 'first' ? firstCount : unreadCount,
                            startNow: startNow,
                          )),
                    style: FilledButton.styleFrom(
                      foregroundColor: dark
                          ? const Color(0xFF1C1B1F)
                          : Colors.white,
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
      showIosToast(context, message: l.downloadsQueued);
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
      showIosToast(context, message: l.downloadNotReady);
      return;
    }
    await _downloadChapters(targets);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showIosToast(context, message: message);
  }

  /// The art plate behind the header, rebuilt from Kotatsu-Redo.
  ///
  /// Three things in the reference are easy to get wrong, and all three were:
  ///
  /// * It is a **plate, not a backdrop**. 420dp tall at the top of the content;
  ///   below it the page is plain background.
  /// * The cover is held at **25% opacity** and blurred by only 16. That low
  ///   opacity is what lets the info card stay opaque and still read as though
  ///   it were translucent -- there is simply very little art under it.
  /// * The wash is a **symmetric vignette**, not a fade to the bottom:
  ///   surface, half, clear, clear, half, surface. At full strength the art is
  ///   only visible in a soft band through the middle and dissolves back into
  ///   the page at both ends.
  ///
  /// The two strengths are named constants above, because they are the dials
  /// for the whole look and the pair chosen here is not the reference's: the
  /// vignette is dialled right down so the art carries across the plate, which
  /// keeps more of the cover reading behind the header at the cost of a step at
  /// the plate's bottom edge. It is painted in the page's own background colour,
  /// so whatever is left of the vignette lands on the real background in either
  /// theme. Nothing here is interactive.
  Widget _buildImmersiveBackdrop() {
    final cover = _coverUrl;
    if (cover.isEmpty) return const SizedBox.shrink();

    // The vignette is painted in the real page colour, so it lands on the
    // background exactly rather than on an approximation of it.
    final surface = Theme.of(context).scaffoldBackgroundColor;

    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // How much of the art shows through. The reference holds it at a
            // quarter.
            Opacity(
              opacity: _kBackdropArtOpacity,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: SizedBox.expand(
                  child: CachedMangaImage(imageUrl: cover, fit: BoxFit.cover),
                ),
              ),
            ),
            // The wash over the art. At full strength it is the reference's
            // vignette; dialled down, the art shows right across the plate and
            // the plate's bottom edge becomes a visible step instead of a fade.
            Opacity(
              opacity: _kBackdropWashOpacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // Six evenly spaced stops, matching GradientDrawable's
                    // ramp: opaque surface top and bottom, clear through the
                    // middle.
                    colors: [
                      surface,
                      surface.withValues(alpha: 0.5),
                      surface.withValues(alpha: 0.0),
                      surface.withValues(alpha: 0.0),
                      surface.withValues(alpha: 0.5),
                      surface,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    // Read from this section's own constraints rather than the window: on a wide
    // layout it lives in one pane of a split, and the window is not what it was
    // given.
    return Padding(
      // The reference gives both the cover and the title a 16dp top margin, so
      // the header sits clear of the nav row instead of tucked under it.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _buildHeaderRow(mangaDetailCoverWidth(constraints.maxWidth)),
      ),
    );
  }

  /// The cover and the title block beside it, laid out against the same
  /// [coverWidth] the caller resolved.
  Widget _buildHeaderRow(double coverWidth) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final coverHeight = mangaDetailCoverHeight(coverWidth);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            GestureDetector(
              // Deliberate: expanding the art is worth a tap back, matching
              // the feel of the cover flight that landed here.
              onTap: () {
                appHaptic(ref, AppHaptic.selection);
                showCoverViewer(
                  context,
                  imageUrl: _coverUrl,
                  title: widget.title,
                  heroTag: _coverHeroTag,
                );
              },
              child: MangaCoverHero(
                tag: _coverHeroTag,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: dark ? null : Border.all(color: Colors.black12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedMangaImage(
                      imageUrl: _coverUrl,
                      width: coverWidth,
                      height: coverHeight,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            // Grows with the cover, but more slowly than it does. Left at a
            // flat 24 the badge is the same absolute size as on a 140px grid
            // cell and reads as a speck on a 203px plate; scaled in step it
            // would grow into a 50px blob, because the badge is a quarter of a
            // grid cell and a header cover is not a grid cell. The floor is the
            // size a phone has always got.
            DownloadedMangaBadge(
              mangaId: widget.mangaId,
              size: (coverWidth * 0.13).clamp(24.0, 32.0),
              iconSize: (coverWidth * 0.076).clamp(14.0, 19.0),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                maxLines: 3,
                style: TextStyle(
                  color: dark
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  // TitleLarge, the size the reference uses for the title.
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
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
                  : _buildFavoriteButton(),
            ],
          ),
        ),
      ],
    );
  }

  /// The favourite control: the tonal chip from the reference, split in two.
  ///
  /// Kotatsu-Redo styles this as a dropdown chip -- `primaryContainer` fill,
  /// on-colour content, no stroke, 40dp tall. That is where the "soft light-grey
  /// pill" in the screenshot comes from: it is a tone derived from the user's
  /// accent, which lands near grey for a neutral accent, not a hand-picked grey.
  ///
  /// The one deliberate departure is the split. The reference's chip opens the
  /// favourite-category menu; Yomou has no favourite categories, so the left
  /// half keeps the one-tap toggle and the chevron half opens the options sheet,
  /// which is the "more options" the chevron promises.
  Widget _buildFavoriteButton() {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // A very light fill rather than an outline. The outline gave the pill a hard
    // edge of its own, which read as heavier than the cover sitting next to it;
    // a tint this faint keeps the shape and the tap target without drawing a box
    // on the page. Favourited takes a wash of the accent instead of a wash of
    // ink: the heart already says the work is saved, and a solid pill next to
    // the cover pulls the eye off the art, which is the thing on this screen
    // worth looking at.
    final favorited = _isFavorite;
    final fg = favorited ? scheme.primary : scheme.onSurface;
    final heartColor = fg;
    final fill = favorited
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.onSurface.withValues(alpha: 0.05);

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _toggleFavorite,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isFavorite
                        ? RemixIcons.heart_3_fill
                        : RemixIcons.heart_3_line,
                    color: heartColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isFavorite ? l.favorited : l.favorite,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          InkWell(
            onTap: () => _showOverflowMenu(context),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Icon(
                RemixIcons.arrow_down_s_line,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // The shadow sits on the outer box, not the frosted one: a blur inside
        // the clip would be cut off at the rounded edge and the card would stop
        // floating. This is the "soft shadow" half of the effect -- the blur is
        // the other half.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.30 : 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // Frosted glass, which is three things and not one: a blur of whatever is
      // behind the pane, a translucent fill over that blur, and a hairline edge
      // to give the sheet a boundary the fill alone cannot. An opaque card here
      // read as paper laid on the screen -- it had no relationship to the art
      // plate behind it, which is the thing the pane is built around. The blur
      // has to sample the plate, which is why it is a `BackdropFilter` inside
      // the pane's stack rather than a translucent colour on its own.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            // More room at the sides than above and below: the card is the
            // widest block in the pane and its label and value columns were
            // running right up to the edges, which is what made it read as
            // cramped rather than spacious.
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: (dark ? const Color(0xFF1E1E22) : Colors.white).withValues(
                alpha: 0.80,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (dark ? Colors.white : Colors.black).withValues(
                  alpha: 0.06,
                ),
              ),
            ),
            child: Column(
              children: [
                _buildCardRow(
                  l.detailSource,
                  _sourceName ?? l.unknown,
                  leading: _buildSourceIcon(),
                  // Only when the source still resolves: an unknown name falls
                  // back to MangaDex in [getSourceByName], which would open the
                  // wrong catalogue rather than nothing.
                  onTap:
                      ref
                          .watch(sourcesProvider)
                          .any((row) => row['name'] == (_sourceName ?? ''))
                      ? _openSourceCatalogue
                      : null,
                ),
                // Author only earns a row when there is one. An empty author
                // is the common case on scraped sources, and a row whose value
                // is "Unknown" is noise -- the card is meant to be facts, and
                // this is the one field that is regularly absent.
                if (!(_details?.author.isEmpty ?? true))
                  _buildCardRow(l.detailAuthor, _details!.author),
                _buildTranslationRow(),
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
                      style: TextStyle(
                        color: _detailLabelColor(dark),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _lastReadChapter >= 0
                              ? (_progressPercent / 100).clamp(0.0, 1.0)
                              : 0,
                          backgroundColor: dark
                              ? Colors.white12
                              : Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ref.watch(accentProvider),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _lastReadChapter >= 0
                          ? '${_progressPercent.round()}%'
                          : '0%',
                      style: TextStyle(
                        color: _detailValueColor(dark),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // The language of the translation currently open: reported by the details
  // lookup, else the source's own catalogue language.
  String _currentLanguageCode() {
    final fromDetails = _details?.language ?? '';
    if (fromDetails.isNotEmpty) return fromDetails;
    final source = getSourceBySourceId(widget.sourceId ?? '');
    return source?.languageCode ?? 'en';
  }

  // Every translation of this work, with the current one guaranteed present so
  // the picker can mark it.
  List<MangaTranslation> _translationsFor(String current) {
    final list = <MangaTranslation>[...?_details?.translations];
    final currentId = _details?.id ?? '';
    if (currentId.isNotEmpty && !list.any((t) => t.mangaId == currentId)) {
      list.insert(
        0,
        MangaTranslation(
          language: current,
          mangaId: currentId,
          title: _details?.title ?? widget.title,
        ),
      );
    }
    list.sort((a, b) => a.language.compareTo(b.language));
    return list;
  }

  // The "Translation" row, directly under the author. Tappable when the source
  // publishes the work in more than one language; each translation is a
  // distinct manga, so reading progress is tracked separately per language.
  Widget _buildTranslationRow() {
    final l = AppLocalizations.of(context);
    final current = _currentLanguageCode();
    final all = _translationsFor(current);
    final tappable = all.length > 1;
    return _buildCardRow(
      l.detailTranslation,
      MangaLanguage.label(current),
      // A flag, because the value is a language: it is the one row where the
      // icon says more than the label does.
      icon: RemixIcons.flag_line,
      onTap: tappable ? () => _showTranslationPicker(all, current) : null,
    );
  }

  void _showTranslationPicker(List<MangaTranslation> all, String current) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // A title can offer a dozen languages, and this is one row per language
      // in a non-scrolling column. Without this the sheet is capped at about
      // 9/16 of the viewport, which on a phone in landscape is ~200dp against
      // a column that wants several times that -- the same overflow the
      // history menu had.
      isScrollControlled: true,
      builder: (sheetContext) {
        final dark = Theme.of(sheetContext).brightness == Brightness.dark;
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                // A gap below the full height, so a long list still leaves a
                // strip of scrim to tap and dismiss the sheet.
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight - kSheetOutsideGap,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        AppLocalizations.of(sheetContext).detailTranslation,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: dark ? Colors.white : null,
                        ),
                      ),
                    ),
                    for (final t in all)
                      ListTile(
                        dense: true,
                        title: Text(MangaLanguage.label(t.language)),
                        trailing: t.language == current
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: ref.watch(accentProvider),
                              )
                            : null,
                        onTap: t.language == current
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _openTranslation(t);
                              },
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Each translation is a separate manga entry (its own history, favourites and
  // progress), so we open a fresh detail screen for it.
  void _openTranslation(MangaTranslation translation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDetailScreen(
          mangaId: translation.mangaId,
          title: translation.title.isNotEmpty
              ? translation.title
              : (_details?.title ?? widget.title),
          imageUrl: _details?.coverUrl ?? widget.imageUrl,
          sourceId: widget.sourceId,
        ),
      ),
    );
  }


  /// Opens the catalogue of the source this manga came from -- the same screen
  /// Explore pushes when a source is tapped. Only offered when the name still
  /// resolves to a real source; [getSourceByName] silently falls back to
  /// MangaDex, so a manga whose source was removed would otherwise open the
  /// wrong catalogue.
  void _openSourceCatalogue() {
    final name = _sourceName;
    if (name == null || name.isEmpty) return;
    final known = ref.read(sourcesProvider).any((row) => row['name'] == name);
    if (!known) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MangaGridScreen(sourceName: name)),
    );
  }

  // Small favicon tile (20×20) for the source row, using the shared brand
  // tile: real logo when available, otherwise a gradient brand-tile fallback.
  Widget _buildSourceIcon() {
    final name = _sourceName ?? '';
    final source = getSourceBySourceId(widget.sourceId ?? '');
    return SourceIcon(name: name, iconUrl: source?.iconUrl ?? '', size: 20);
  }

  /// Human-readable byte counts for the "On Device" row.
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// The muted colour of a metadata label ("Source", "Author", ...).
  ///
  /// Kept clearly lighter than the value beside it, and it has gone lighter on
  /// every pass: at #8A8A8E the label held almost as much weight as the value,
  /// so a column of them read as a block of text rather than a list of facts
  /// and made the left pane feel heavy. The label is a caption; the value is
  /// the content. Slightly darker than the chapter rows' metadata on purpose --
  /// this text is 14px next to a value, that one is 10.5px next to a heading.
  Color _detailLabelColor(bool dark) =>
      dark ? Colors.white38 : const Color(0xFFB4B4B9);

  /// The charcoal colour of a metadata value.
  Color _detailValueColor(bool dark) =>
      dark ? Colors.white : const Color(0xFF1C1B1F);

  Widget _buildCardRow(
    String label,
    String value, {
    IconData? icon,
    Widget? leading,
    VoidCallback? onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = _detailValueColor(dark);
    final labelColor = _detailLabelColor(dark);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: labelColor, fontSize: 14),
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
                  Icon(icon, size: 16, color: valueColor),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
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
    // Collapse only when the user asked for it: the appearance setting is the
    // whole reason this section has two states, and ignoring it left the
    // settings screen with a switch that did nothing.
    final collapseByDefault = settings.collapseDescription && hasDescription;

    return LayoutBuilder(
      builder: (context, constraints) {
        // "More" earns its place by being needed. A description that already
        // fits in the collapsed three lines has nothing to reveal, and a
        // permanent More button on a short blurb reads as decoration.
        final canShowToggle =
            collapseByDefault &&
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
                        () => _descriptionExpanded = !_descriptionExpanded,
                      ),
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
                        () => _descriptionExpanded = !_descriptionExpanded,
                      )
                    : null,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Text(
                    description,
                    maxLines: collapseByDefault && !_descriptionExpanded
                        ? 3
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

  /// Whether [text] runs past [maxLines] at the width it is about to be given.
  ///
  /// The description used to be clamped and let go without ever asking if it
  /// needed it, which is how a three-line blurb ended up with a More button
  /// leading nowhere. Measured with the same metrics the Text renders at.
  bool _exceedsLineLimit(String text, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
      maxLines: 3,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: tags.map((tag) {
          return GestureDetector(
            onTap: () => _showTagSearchDialog(tag),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.transparent,
                border: Border.all(
                  color: dark ? Colors.white30 : Colors.black38,
                ),
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
                        color: dark ? const Color(0xFF2C2C2E) : Colors.white,
                        alignment: Alignment.center,
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
  /// The list is a pane in a two-pane layout, not a tray sliding over the
  /// details, so there is no handle to drag and no chevron to expand.
  final bool docked;

  final bool isExpanded;
  final int activeTab;

  /// The accent the user picked in appearance settings. The Continue pill is
  /// built in this delegate rather than on the screen, so the color has to
  /// travel with it.
  final Color accent;
  final double topPadding;
  final double bottomPadding;
  final int unreadCount;
  final bool showContinueButton;
  final bool hasRead;
  final String? continueChapterNumber;
  final bool isSelectionMode;
  final int selectedCount;
  final bool isAllSelected;
  final bool hasSelectionGap;
  final VoidCallback onContinuePressed;
  final VoidCallback onBarTap;

  /// The tray bar is the tray's drag handle; these are absent on the docked
  /// pane, which has no extent to drag.
  final GestureDragStartCallback? onBarDragStart;
  final GestureDragUpdateCallback? onBarDragUpdate;
  final GestureDragEndCallback? onBarDragEnd;
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
  final VoidCallback onOverflow;

  _SheetHeaderDelegate({
    this.docked = false,
    required this.isExpanded,
    required this.activeTab,
    required this.accent,
    required this.topPadding,
    this.bottomPadding = 0,
    this.unreadCount = 0,
    this.showContinueButton = false,
    this.hasRead = false,
    this.continueChapterNumber,
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.isAllSelected = false,
    this.hasSelectionGap = false,
    required this.onContinuePressed,
    required this.onBarTap,
    this.onBarDragStart,
    this.onBarDragUpdate,
    this.onBarDragEnd,
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
    required this.onOverflow,
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
      onTap: isSelectionMode || docked ? null : onBarTap,
      // The bar is the tray's handle. `down` rather than the default `start`
      // so the sheet does not jump by the touch slop the moment the drag is
      // recognised.
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: isSelectionMode ? null : onBarDragStart,
      onVerticalDragUpdate: isSelectionMode ? null : onBarDragUpdate,
      onVerticalDragEnd: isSelectionMode ? null : onBarDragEnd,
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
          // A docked pane sits inside the page's SafeArea already, so it adds
          // no top or bottom inset of its own -- only the tray has to clear
          // the status bar and the bar below it.
          top: docked ? 6 : (isExpanded ? (topPadding + 6) : 6),
          bottom: docked ? 6 : (isExpanded ? 6 : (6 + bottomPadding)),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A grab handle on a pane that cannot be dragged is a control that
            // lies, so it only exists in the tray.
            if (!docked) ...[
              const _SheetDragHandle(),
              const SizedBox(height: 6),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelectionMode
                  ? _buildSelectionHeader(context, dark: dark, scheme: scheme)
                  : _buildDefaultHeader(context, dark: dark, scheme: scheme),
            ),
          ],
        ),
      ),
    );
  }

  // Default header: the pane's mode control and its primary action, or -- in
  // the tray -- the icon row that is all a phone sheet has room for.
  Widget _buildDefaultHeader(
    BuildContext context, {
    required bool dark,
    required ColorScheme scheme,
  }) {
    // A docked pane has the width for a labelled control and the height for a
    // real header, so it gets one. Everything below this is the tray, where
    // three bare icons are what fits between a drag handle and the screen edge.
    if (docked) {
      return Row(
        key: const ValueKey('defaultTrayHeader'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // The control is sized to its content and pinned left rather than
          // stretched across whatever is left of the row. Stretched it ran
          // right up against Continue, which made the whole header read as one
          // crowded bar; capping it is what creates the gap that lets the two
          // sides breathe.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: _buildModeSegments(),
              ),
            ),
          ),
          const SizedBox(width: 24),
          if (showContinueButton) ...[
            _buildPrimaryButton(context: context, dark: dark, scheme: scheme),
            const SizedBox(width: 8),
          ],
          _buildTabIcon(
            Icons.more_vert,
            false,
            dark: dark,
            scheme: scheme,
            onTap: onOverflow,
          ),
        ],
      );
    }

    return Row(
      key: const ValueKey('defaultTrayHeader'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Chapter list tab (shows unread count when there are unread chapters).
        _buildTabIcon(
          Icons.format_list_bulleted,
          activeTab == 0,
          dark: dark,
          scheme: scheme,
          onTap: () => onTabSelected(0),
          badge: unreadCount > 0 ? _buildBadge(unreadCount) : null,
        ),
        const SizedBox(width: 2),
        _buildTabIcon(
          Icons.grid_view,
          activeTab == 1,
          dark: dark,
          scheme: scheme,
          onTap: () => onTabSelected(1),
        ),
        const SizedBox(width: 2),
        _buildTabIcon(
          Icons.bookmark_border,
          activeTab == 2,
          dark: dark,
          scheme: scheme,
          onTap: () => onTabSelected(2),
        ),
        const Spacer(),
        // Fullscreen: the Continue pill gives way to the search and overflow
        // icons in the tray's trailing corner. The docked pane never reaches
        // here -- it returns above with a header of its own.
        if (isExpanded) ...[
          _buildTabIcon(
            Icons.more_vert,
            false,
            dark: dark,
            scheme: scheme,
            onTap: onOverflow,
          ),
          const SizedBox(width: 6),
          _buildExpandButton(dark: dark, scheme: scheme),
        ] else ...[
          // Continue/Read action, only for the chapter list tab.
          if (showContinueButton) ...[
            _buildPrimaryButton(context: context, dark: dark, scheme: scheme),
            const SizedBox(width: 2),
            _buildTabIcon(
              Icons.more_vert,
              false,
              dark: dark,
              scheme: scheme,
              onTap: onOverflow,
            ),
            const SizedBox(width: 6),
          ] else ...[
            _buildTabIcon(
              Icons.more_vert,
              false,
              dark: dark,
              scheme: scheme,
              onTap: onOverflow,
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
            icon: Icon(
              RemixIcons.checkbox_multiple_blank_line,
              color: iconColor,
            ),
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

  /// The pane's mode control. The component itself lives in
  /// `widgets/mode_segment_control.dart`: it is the one piece of this header
  /// that is worth building and testing on its own, and it is what the phone
  /// tray's icon tabs are *not*.
  Widget _buildModeSegments() {
    return ModeSegmentControl(
      activeTab: activeTab,
      onTabSelected: onTabSelected,
      unreadCount: unreadCount,
      badge: unreadCount > 0 ? _buildBadge(unreadCount) : null,
    );
  }

  // A single consistent, tappable tab icon with a square active highlight --
  // the tray's own idiom, for the phone sheet.
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
              borderRadius: BorderRadius.circular(9),
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
          if (badge != null) Positioned(top: -5, right: -5, child: badge),
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
  Widget _buildExpandButton({required bool dark, required ColorScheme scheme}) {
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
          isExpanded
              ? RemixIcons.arrow_down_s_line
              : RemixIcons.arrow_up_s_line,
          color: dark ? Colors.white : scheme.onSurface,
          size: 16,
        ),
      ),
    );
  }

  // Primary Read/Continue action pill that lives on the tray. Split-pill:
  // the left part holds the label ("Continue · 3"), the right part is a small
  // dropdown section separated by a thin vertical line.
  Widget _buildPrimaryButton({
    required BuildContext context,
    required bool dark,
    required ColorScheme scheme,
  }) {
    final l = AppLocalizations.of(context);
    final label = (hasRead)
        ? '${l.continueAction} · ${continueChapterNumber ?? ''}'.trim()
        : l.readAction;
    // The pill wears the accent the user picked, with the dropdown half a step
    // darker and a lighter hairline between them -- the relationship the fixed
    // blues had. The label takes whichever of black or white reads on that
    // accent: a green or monochrome pill cannot carry white.
    final leftColor = accent;
    final rightColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.18),
      accent,
    );
    final onAccent =
        ThemeData.estimateBrightnessForColor(leftColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Container(
      // The shadow belongs to the whole pill, not to either half: put on one
      // half it would cast onto the other. The tinted glow is what stops the
      // accent from reading as a flat swatch of colour stuck on the bar, and it
      // is why the pill now has the weight of the primary action.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onContinuePressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: leftColor,
              child: Row(
                children: [
                  Icon(RemixIcons.arrow_right_line, color: onAccent, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: onAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onContinuePressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: rightColor,
                border: Border(
                  left: BorderSide(
                    color: Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.35),
                      accent,
                    ),
                    width: 0.5,
                  ),
                ),
              ),
              child: Icon(
                RemixIcons.arrow_down_s_line,
                color: onAccent,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 72 + (isExpanded ? topPadding : bottomPadding);

  @override
  double get minExtent => 72 + (isExpanded ? topPadding : bottomPadding);

  @override
  bool shouldRebuild(covariant _SheetHeaderDelegate oldDelegate) {
    return oldDelegate.isExpanded != isExpanded ||
        oldDelegate.activeTab != activeTab ||
        oldDelegate.accent != accent ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.bottomPadding != bottomPadding ||
        oldDelegate.unreadCount != unreadCount ||
        oldDelegate.showContinueButton != showContinueButton ||
        oldDelegate.hasRead != hasRead ||
        oldDelegate.continueChapterNumber != continueChapterNumber ||
        oldDelegate.isSelectionMode != isSelectionMode ||
        oldDelegate.selectedCount != selectedCount ||
        oldDelegate.isAllSelectedRead != isAllSelectedRead ||
        oldDelegate.hasDownloaded != hasDownloaded;
  }
}

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

/// Share of its column the detail header's cover takes.
///
/// The cover used to be a fixed 125x175, which is exactly right on a phone --
/// the column is 328px there, so it filled the space as intended -- and wrong
/// everywhere wider. On a wide layout the header sits in the left pane of a 5:6
/// split, which is around 534px on a 1325px window, so the fixed cover left a
/// fifth of the column empty on a desktop while the title block beside it kept
/// growing. That is the whole of the "the art is too small on a desktop" report.
///
/// The share is picked so a phone still lands on a smaller number: 328 * 0.32 is
/// ~105px (minimum clamps to 110), giving a smaller footprint relative to card.
const double _detailCoverShareOfColumn = 0.32;

/// Smallest the cover gets, which is what a phone column resolves to.
const double _detailCoverMinWidth = 110;

/// Where the cover stops growing.
///
/// Past a 200px plate it stops being a thumbnail beside the title and becomes
/// the subject of the screen, and the title and metadata are pushed into a
/// column too narrow to hold a synopsis.
const double _detailCoverMaxWidth = 200;

/// The shape the fixed cover had, so growing it does not also reshape it.
const double _detailCoverAspect = 175 / 125;

/// Width of the detail header's cover in a column [columnWidth] wide.
///
/// Public so the numbers can be pinned by a test. The screen reads the database
/// and the network as it opens, so a widget test cannot pump it, and the entire
/// change is this arithmetic.
double mangaDetailCoverWidth(double columnWidth) =>
    (columnWidth * _detailCoverShareOfColumn).clamp(
      _detailCoverMinWidth,
      _detailCoverMaxWidth,
    );

/// Height that goes with [mangaDetailCoverWidth], holding the 125:175 the
/// fixed cover had.
double mangaDetailCoverHeight(double coverWidth) =>
    coverWidth * _detailCoverAspect;
