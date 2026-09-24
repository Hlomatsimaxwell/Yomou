import 'package:remixicon/remixicon.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/widgets/safe_image.dart';
import 'package:yomou/core/cache/app_cache.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/source_cache.dart';
import '../../../core/widgets/ios/ios_sheet.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/core/widgets/empty_state.dart';
import 'package:yomou/features/settings/screens/settings_screen.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import '../services/chapter_downloader.dart';

// Reading modes (Kotatsu-style).
enum ReadingMode { standard, rightToLeft, vertical, webtoon }

class ReaderScreen extends ConsumerStatefulWidget {
  final List<Chapter> allChapters;
  final int initialChapterIndex;
  final int initialPageIndex;
  final String mangaId;
  final String? sourceId;
  final String? mangaTitle;
  final String? mangaCoverUrl;
  final int totalChapters;

  const ReaderScreen({
    super.key,
    required this.allChapters,
    required this.initialChapterIndex,
    this.initialPageIndex = 0,
    required this.mangaId,
    this.sourceId,
    this.mangaTitle,
    this.mangaCoverUrl,
    this.totalChapters = 0,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  PageController _pageController = PageController();
  final List<String> _pages = [];
  final List<int> _loadedChapterIndices = [];

  int _currentChapterIndex = 0;
  bool _isLoadingNextChapter = false;
  bool _isLoadingPreviousChapter = false;
  int _lastPageIndex = -1;
  bool _hasMoreChapters = true;
  // While true, the "scrolled back to page 0 of a chapter" triggers won't
  // auto-load/prepend the adjacent chapter. Set after an explicit chapter
  // switch (which lands at page 1) and cleared once the reader actually moves
  // forward, so a fresh landing is never misread as a backward swipe.
  bool _suppressAdjacentAutoLoad = true;
  // Bumped on every explicit chapter switch so the progress-track widget can
  // reset its thumb to page 1 even when jumpTo() no-ops (no listener fires).
  int _trackSession = 0;
  // Tracks scroll direction (backing up vs. advancing) inside the vertical
  // ticker, since ScrollPosition exposes no direct velocity getter.
  double _lastScrollPixels = 0;
  bool _showControls = true;
  Timer? _statusTimer;
  String _clockText = '';
  int _batteryLevel = -1;

  void _startStatusTicker() {
    _updateStatusBadges();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _updateStatusBadges();
    });
  }

  Future<void> _updateStatusBadges() async {
    final clock = DateFormat('HH:mm').format(DateTime.now());
    var battery = _batteryLevel;
    try {
      battery = await Battery().batteryLevel;
    } catch (_) {
      // Emulator / unsupported platform: keep the previous value.
    }
    if (!mounted) return;
    if (clock == _clockText && battery == _batteryLevel) return;
    setState(() {
      _clockText = clock;
      _batteryLevel = battery;
    });
  }

  // Kotatsu-style top info bar (shown while the system UI + controls are
  // hidden): live clock and battery percentage.
  void _applySystemUiMode() {
    // Kotatsu behavior: while the controls are hidden the entire system UI is
    // immersive (nothing drawn by the OS), so the reader renders its own slim
    // status bar at the top edge. Tapping the controls restores the native
    // system status bar / navigation bars.
    //
    // System overlays are explicitly transparent in both states so the manga
    // canvas and background draw all the way to the absolute top edge of the
    // glass — there's never a reserved black strip where the status bar was.
    SystemChrome.setEnabledSystemUIMode(
      _showControls ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // Chapter transition toast (Kotatsu-style chapter/page pill).
  double _toastOpacity = 0;
  int _toastShownChapter = -1;
  Timer? _toastTimer;
  Timer? _scrollStopTimer;
  bool _isSaving = false;
  Timer? _autoSaveTimer;
  // Guards the debounced autosave: only fire when the page actually moved.
  int _autoSavedPage = -1;
  int _autoSavedChapter = -1;
  bool _needsRestore = false;
  int? _pendingJumpPage;
  final Set<String> _bookmarkedKeys = {};

  // Set to false to render pages without the zoom wrapper (A/B diagnostic).
  static const bool _zoomEnabled = false;

  // Per-page double-tap zoom state.
  final Map<int, TransformationController> _zoomControllers = {};
  final Map<int, bool> _zoomed = {};
  final Map<int, Offset> _zoomFocal = {};
  int? _zoomSeenPageCount;
  late final AnimationController _zoomAnimController;
  VoidCallback? _zoomAnimListener;

  Size? _lastViewportSize; // page box size in horizontal mode

  String _bookmarkKey(String chapterId, int pageIndex) =>
      '$chapterId:$pageIndex';

  bool get _isCurrentPageBookmarked {
    if (_currentChapterIndex < 0) return false;
    return _bookmarkedKeys.contains(
      _bookmarkKey(
        widget.allChapters[_currentChapterIndex].id,
        _currentPageIndex,
      ),
    );
  }

  ReadingMode _readingMode = ReadingMode.vertical;

  // Settings state.
  bool _useTwoPagesLayout = false;
  bool _rotateScreen = false;
  Timer? _autoScrollTimer;

  // Color correction.
  double _brightness = 100;
  double _contrast = 100;
  double _sepia = 0;

  // Chapter downloads.
  final Set<String> _downloadedChapters = {};
  final Map<String, _ChapterDownloadTask> _activeDownloads = {};

  // Chapter tray selection mode.
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;
  double _lastReadChapter = -1;

  // Per-page bookkeeping: pages belong to a chapter index, and each page may
  // have a local file path when its chapter has been downloaded.
  final List<int> _pagesChapters = [];
  final List<String?> _pageFiles = [];

  // Bumped per page to force a reload after the user taps "Retry" on a failed
  // page (the new value becomes part of the image widget's key).
  final Map<int, int> _pageRetryTokens = {};

  // Proactive preloading: keeps the last 8 network URLs we asked the cache
  // manager to fetch so we don't schedule duplicate downloads, and remembers
  // which page the preload window was centered on (so chapter loads and scroll
  // ticks don't spam the cache).
  final Set<String> _prefetchScheduled = {};
  int _prefetchAnchorPage = -1;
  bool _isPrecachingNextChapter = false;
  Map<String, String>? _activeRequestHeaders;

  // Refresh callback for the open chapter tray sheet.
  bool _trayOpen = false;
  VoidCallback? _trayRefresh;
  final DraggableScrollableController _trayExtentController =
      DraggableScrollableController();

  void _refreshTray() {
    if (_trayOpen) _trayRefresh?.call();
  }

  bool get _isHorizontal =>
      _readingMode == ReadingMode.standard ||
      _readingMode == ReadingMode.rightToLeft;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialChapterIndex;
    _needsRestore = widget.initialPageIndex > 0;
    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _loadPrefs();
    _loadBookmarks();
    _loadProgress();
    _loadDownloads().then((_) => _loadChapter(_currentChapterIndex));

    _scrollController.addListener(_handleScrollTicker);
    WidgetsBinding.instance.addObserver(this);
    _startStatusTicker();
    _sessionStopwatch.start();
    // Crash safety: while the reader is open, periodically persist the current
    // position so a forced kill (force-stop, crash, OOM) doesn't lose the read.
    // The debounce logic in _autosaveProgress skips no-op ticks.
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _autosaveProgress(),
    );
  }

  // --- PERSISTED READER SETTINGS ---

  // Reader settings are stored per manga so changing them for one title never
  // affects another.
  String _prefKey(String suffix) => '${widget.mangaId}_$suffix';

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_prefKey('reader_mode'));
    final mode = ReadingMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => ReadingMode.vertical,
    );
    final rotateScreen =
        prefs.getBool(_prefKey('reader_rotate_screen')) ?? false;

    if (!mounted) return;
    setState(() {
      _readingMode = mode;
      _useTwoPagesLayout = prefs.getBool(_prefKey('reader_two_pages')) ?? false;
      _rotateScreen = rotateScreen;
      _brightness = prefs.getDouble(_prefKey('reader_brightness')) ?? 100;
      _contrast = prefs.getDouble(_prefKey('reader_contrast')) ?? 100;
      _sepia = prefs.getDouble(_prefKey('reader_sepia')) ?? 0;
    });

    if (_useTwoPagesLayout) {
      _recreatePageController();
    }

    if (rotateScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _saveReaderMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey('reader_mode'), _readingMode.name);
  }

  void _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _saveColorCorrection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefKey('reader_brightness'), _brightness);
    await prefs.setDouble(_prefKey('reader_contrast'), _contrast);
    await prefs.setDouble(_prefKey('reader_sepia'), _sepia);
  }

  void _recreatePageController() {
    _pageController.dispose();
    _pageController = PageController(
      viewportFraction: _useTwoPagesLayout ? 0.5 : 1.0,
    );
  }

  @override
  void dispose() {
    _flushSessionTime();
    _sessionStopwatch.stop();
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    // The immersive overlay on every exit path restores the normal system UI.
    _restoreSystemUi();
    _autoSaveTimer?.cancel();
    _scrollController.dispose();
    _pageController.dispose();
    _trayExtentController.dispose();
    for (final controller in _zoomControllers.values) {
      controller.dispose();
    }
    _toastTimer?.cancel();
    _scrollStopTimer?.cancel();
    _autoScrollTimer?.cancel();
    _zoomAnimController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    _applySystemUiMode();
  }

  /// Kotatsu-style left-hand status text: "Ch. 26/205 Pg. 3/16 12%".
  String _immersiveStatusText(int chapterIndex, String chapterLabel) {
    final page = _currentPageIndex;
    final totalPages = _pages.length;
    final progress = widget.totalChapters > 0
        ? (((chapterIndex + 1) / widget.totalChapters) * 100).round()
        : (totalPages > 0 ? (((page + 1) / totalPages) * 100).round() : 0);
    final ch = chapterLabel.isNotEmpty ? chapterLabel : '${chapterIndex + 1}';
    return 'Ch. $ch/${widget.totalChapters} Pg. ${page + 1}/$totalPages $progress%';
  }

  int get _currentPageIndex {
    if (_pages.isEmpty) return 0;
    if (_isHorizontal && _pageController.positions.length == 1) {
      return _pageController.page?.round().clamp(0, _pages.length - 1) ?? 0;
    } else if (!_isHorizontal && _scrollController.hasClients) {
      const perPage = 600.0;
      return (_scrollController.offset / perPage).floor().clamp(
        0,
        _pages.length - 1,
      );
    }
    return 0;
  }

  /// The chapter the reader is currently showing, accounting for chapters
  /// prepended/appended by the adjacent-chapter loaders. Falls back to the
  /// newest loaded chapter while pages are still loading.
  int get _readChapterIndex {
    if (_pagesChapters.isEmpty) return _currentChapterIndex;
    final ci = _pagesChapters[_currentPageIndex];
    if (ci < 0 || ci >= widget.allChapters.length) return _currentChapterIndex;
    return ci;
  }

  void _jumpToPage(int pageIndex) {
    if (_pages.isEmpty) return;
    final idx = pageIndex.clamp(0, _pages.length - 1);
    if (_isHorizontal) {
      if (_pageController.hasClients) _pageController.jumpToPage(idx);
    } else {
      if (_scrollController.hasClients) {
        final extent = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo((idx * 600.0).clamp(0.0, extent));
      }
    }
    setState(() {});
  }

  Widget _buildProgressTrack() {
    // Show the slider against the chapter under the reader, not the whole
    // concatenated list (which grows when adjacent chapters are loaded).
    final chapterIndex = _readChapterIndex;
    int chapterStart = 0;
    var chapterCount = _pages.length;
    if (_pagesChapters.isNotEmpty) {
      var start = -1;
      var end = -1;
      for (var i = 0; i < _pagesChapters.length; i++) {
        if (_pagesChapters[i] == chapterIndex) {
          if (start == -1) start = i;
          end = i;
        }
      }
      if (start != -1) {
        chapterStart = start;
        chapterCount = end - start + 1;
      }
    }
    return _ReaderProgressTrack(
      session: _trackSession,
      totalPages: _pages.length,
      chapterStart: chapterStart,
      chapterPageCount: chapterCount,
      isHorizontal: _isHorizontal,
      scrollController: _scrollController,
      pageController: _pageController,
      onSeek: _jumpToPage,
    );
  }

  void _restorePosition() {
    if (!_needsRestore || _pages.isEmpty) return;
    _needsRestore = false;
    _jumpToPage(widget.initialPageIndex);
  }

  void _setReadingMode(ReadingMode mode) {
    if (mode == _readingMode) return;
    final approxPage = _currentPageIndex;
    if (_autoScrollTimer != null) {
      _autoScrollTimer!.cancel();
      _autoScrollTimer = null;
    }
    final oldController = _pageController;
    setState(() {
      _readingMode = mode;
      // Each mode gets a freshly initialized controller so the old pager's
      // scroll position never lingers on the new layout.
      _pageController = PageController(
        viewportFraction: _useTwoPagesLayout ? 0.5 : 1.0,
      );
    });
    // The old PageView unmounts during the rebuild above; only now is it safe
    // to release its controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (oldController != _pageController) oldController.dispose();
    });
    _saveReaderMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpToPage(approxPage);
    });
  }

  // --- SETTINGS ACTIONS ---

  void _toggleTwoPages(bool value) {
    if (value == _useTwoPagesLayout) return;
    final lastApprox = _currentPageIndex;
    final oldController = _pageController;
    setState(() {
      _useTwoPagesLayout = value;
      _pageController = PageController(viewportFraction: value ? 0.5 : 1.0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (oldController != _pageController) oldController.dispose();
      if (!mounted || !_pageController.hasClients || _pages.isEmpty) return;
      _pageController.jumpToPage(lastApprox.clamp(0, _pages.length - 1));
    });
    _saveBool(_prefKey('reader_two_pages'), value);
  }

  void _toggleRotateScreen(bool value) {
    setState(() => _rotateScreen = value);
    if (value) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    _saveBool(_prefKey('reader_rotate_screen'), value);
  }

  void _showColorCorrectionDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          final l = AppLocalizations.of(context);
          return AlertDialog(
            backgroundColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              l.colorCorrection,
              style: TextStyle(
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterSlider(
                  l.filterBrightness,
                  _brightness,
                  (v) => setDialogState(() => _brightness = v),
                ),
                _buildFilterSlider(
                  l.filterContrast,
                  _contrast,
                  (v) => setDialogState(() => _contrast = v),
                ),
                _buildFilterSlider(
                  l.filterSepia,
                  _sepia,
                  (v) => setDialogState(() => _sepia = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    _brightness = 100;
                    _contrast = 100;
                    _sepia = 0;
                  });
                  if (mounted) setState(() {});
                  _saveColorCorrection();
                },
                child: Text(
                  l.reset,
                  style: TextStyle(
                    color: dark ? Colors.white70 : const Color(0xFF49454F),
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {});
                  _saveColorCorrection();
                  Navigator.pop(context);
                },
                child: Text(
                  l.done,
                  style: TextStyle(
                    color: dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: dark ? Colors.white70 : const Color(0xFF49454F),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: dark
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
              inactiveTrackColor: dark ? Colors.white12 : Colors.black12,
              thumbColor: dark
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayColor: dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.12),
            ),
            child: Slider(min: 0, max: 200, value: value, onChanged: onChanged),
          ),
        ),
      ],
    );
  }

  Future<void> _saveCurrentPage() async {
    if (_pages.isEmpty) return;
    final pageIndex = _currentPageIndex.clamp(0, _pages.length - 1);
    final url = _pages[pageIndex];

    try {
      final readerSource = widget.sourceId != null
          ? getSourceBySourceId(widget.sourceId!)
          : null;
      final headers =
          readerSource?.headers ?? ref.read(currentSourceProvider).headers;
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      Directory directory;
      try {
        directory =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      } catch (_) {
        directory = await getApplicationDocumentsDirectory();
      }

      final ext = _imageExtension(url, response.headers['content-type']);
      final file = File('${directory.path}/page_${pageIndex + 1}.$ext');
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).readerPageSavedTo(file.path),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).readerFailedToSavePage),
          ),
        );
      }
    }
  }

  String _imageExtension(String url, String? contentType) {
    if (contentType != null) {
      if (contentType.contains('png')) return 'png';
      if (contentType.contains('jpeg')) return 'jpg';
      if (contentType.contains('webp')) return 'webp';
      if (contentType.contains('gif')) return 'gif';
    }
    final dotIndex = url.lastIndexOf('.');
    if (dotIndex != -1) {
      final ext = url.substring(dotIndex + 1).split('?').first.toLowerCase();
      if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext)) return ext;
    }
    return 'png';
  }

  // --- CHAPTER NAVIGATION ---

  void _changeChapterExplicitly(int newIndex) {
    setState(() {
      _currentChapterIndex = newIndex;
      _pages.clear();
      _pagesChapters.clear();
      _pageFiles.clear();
      _loadedChapterIndices.clear();
      _pageRetryTokens.clear();
      _hasMoreChapters = true;
      _lastPageIndex = -1;
      _prefetchScheduled.clear();
    });
    // Explicit chapter navigation always starts at the first page: the
    // "resume at last page" restore applies only to the first chapter opened
    // from the detail screen. (Bookmarks set [_pendingJumpPage] first.)
    // Landing at page 1 must never be misread as "scrolled back a chapter".
    _needsRestore = false;
    _suppressAdjacentAutoLoad = true;
    _trackSession += 1;
    _pendingJumpPage ??= 0;
    _loadChapter(_currentChapterIndex);
  }

  void _showChapterList() {
    final currentIndex = _currentChapterIndex;
    var listView = 'list';
    var didJump = false;

    MangaSource? source;
    if (widget.sourceId != null) {
      source = getSourceBySourceId(widget.sourceId!);
    }
    source ??= ref.read(currentSourceProvider);
    final headers = source?.headers;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SizedBox.expand(
          child: DraggableScrollableSheet(
            controller: _trayExtentController,
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 1.0,
            snap: true,
            snapSizes: const [0.3, 0.5, 1.0],
            builder: (context, sheetController) {
              return StatefulBuilder(
                builder: (context, setSheetState) {
                  final dark = Theme.of(context).brightness == Brightness.dark;
                  _trayOpen = true;
                  _trayRefresh = () => setSheetState(() {});
                  if (!didJump) {
                    // Force the tray back to the mid (0.5) extent on a fresh
                    // open: the [DraggableScrollableController] is persistent
                    // and would otherwise inherit the size left over from a
                    // previous long-press fullscreen.
                    _trayExtentController.animateTo(
                      0.5,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                    _jumpToCurrentInSheet(sheetController, currentIndex, 72, 0);
                    didJump = true;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF1E1E20) : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 5,
                              margin: const EdgeInsets.only(top: 12, bottom: 8),
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xFF6E6E73)
                                    : Colors.black26,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          _buildChapterSheetHeader(listView, setSheetState),
                          Expanded(
                            child: switch (listView) {
                              'grid' => _buildPageGridView(
                                sheetController,
                                currentIndex,
                                headers,
                              ),
                              'bookmark' => _buildBookmarksView(
                                sheetController,
                                headers,
                                onRefresh: () => setSheetState(() {}),
                              ),
                              'download' => _buildDownloadsView(
                                sheetController,
                              ),
                              _ => _buildChapterListView(
                                sheetController,
                                currentIndex,
                              ),
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    ).then((_) {
      _trayOpen = false;
      _trayRefresh = null;
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  // Retries until the sheet's scroll controller is attached, then centers the
  // active chapter.
  void _jumpToCurrentInSheet(
    ScrollController controller,
    int index,
    double itemExtent,
    int attempt,
  ) {
    if (attempt > 6) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!controller.hasClients) {
        _jumpToCurrentInSheet(controller, index, itemExtent, attempt + 1);
        return;
      }
      final viewDim = controller.position.viewportDimension;
      final target = (index * itemExtent - viewDim / 2).clamp(
        0.0,
        controller.position.maxScrollExtent,
      );
      controller.jumpTo(target);
    });
  }

  Widget _buildChapterSheetHeader(String listView, StateSetter setSheetState) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = dark ? Colors.white : const Color(0xFF1C1B1F);
    final selectedCount = _selectedIds.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _selectionMode
            ? Row(
                key: const ValueKey('selectionTrayHeader'),
                children: [
                  IconButton(
                    icon: Icon(RemixIcons.close_line, color: iconColor),
                    onPressed: _exitSelection,
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
                  if (_isAllSelectedInTray)
                    IconButton(
                      icon: Icon(
                        RemixIcons.checkbox_multiple_blank_line,
                        color: iconColor,
                      ),
                      tooltip: AppLocalizations.of(context).deselectAll,
                      onPressed: _deselectAllChapters,
                    )
                  else ...[
                    if (_hasSelectionGap)
                      IconButton(
                        icon: Icon(RemixIcons.list_unordered, color: iconColor),
                        tooltip: AppLocalizations.of(context).selectRange,
                        onPressed: _selectChapterRange,
                      ),
                    IconButton(
                      icon: Icon(
                        RemixIcons.checkbox_multiple_line,
                        color: iconColor,
                      ),
                      tooltip: AppLocalizations.of(context).selectAll,
                      onPressed: _selectAllChapters,
                    ),
                  ],
                  IconButton(
                    icon: Icon(
                      _isAllSelectedRead
                          ? RemixIcons.eye_off_line
                          : RemixIcons.eye_line,
                      color: iconColor,
                    ),
                    tooltip: AppLocalizations.of(context).toggleRead,
                    onPressed: _toggleSelectedRead,
                  ),
                  if (_isSelectedDownloaded)
                    IconButton(
                      icon: Icon(
                        RemixIcons.delete_bin_6_line,
                        color: iconColor,
                      ),
                      tooltip: AppLocalizations.of(
                        context,
                      ).removeDownloadTooltip,
                      onPressed: _deleteSelectedDownloads,
                    )
                  else
                    IconButton(
                      icon: Icon(RemixIcons.download_line, color: iconColor),
                      tooltip: AppLocalizations.of(context).detailDownload,
                      onPressed: _downloadSelectedChapters,
                    ),
                ],
              )
            : Row(
                key: const ValueKey('trayHeader'),
                children: [
                  _buildTrayViewIcon(
                    icon: RemixIcons.list_unordered,
                    active: listView == 'list',
                    dark: dark,
                    onTap: () => setSheetState(() => listView = 'list'),
                  ),
                  _buildTrayViewIcon(
                    icon: RemixIcons.grid_line,
                    active: listView == 'grid',
                    dark: dark,
                    onTap: () => setSheetState(() => listView = 'grid'),
                  ),
                  _buildTrayViewIcon(
                    icon: RemixIcons.bookmark_2_line,
                    active: listView == 'bookmark',
                    dark: dark,
                    onTap: () => setSheetState(() => listView = 'bookmark'),
                  ),
                ],
              ),
      ),
    );
  }

  // A single clean, thin icon to switch the tray's view (list/grid/bookmark),
  // tinted when active, grey otherwise. No heavy background.
  Widget _buildTrayViewIcon({
    required IconData icon,
    required bool active,
    required bool dark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          color: active
              ? (dark ? Colors.white : const Color(0xFF1C1B1F))
              : Colors.grey,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildChapterListView(ScrollController controller, int currentIndex) {
    return ListView.builder(
      controller: controller,
      itemExtent: 72,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: widget.allChapters.length,
      itemBuilder: (context, index) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final chapter = widget.allChapters[index];
        final isCurrent = index == currentIndex;
        final isSelected = _selectedIds.contains(chapter.id);
        final isRead = _lastReadChapter >= 0 && (index + 1) <= _lastReadChapter;

        return ListTile(
          key: ValueKey(chapter.id),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 2,
          ),
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
              Icon(
                RemixIcons.play_fill,
                color: isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  chapter.title.isEmpty
                      ? AppLocalizations.of(
                          context,
                        ).chapterNum(chapter.chapterNumber)
                      : chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isRead && !isCurrent
                        ? Colors.grey
                        : (dark ? Colors.white70 : const Color(0xFF49454F)),
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            _chapterSubtitle(chapter, AppLocalizations.of(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          trailing: isSelected
              ? Icon(
                  RemixIcons.check_fill,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                )
              : null,
          onTap: () {
            if (_selectionMode) {
              _toggleSelection(chapter.id);
            } else {
              Navigator.pop(context);
              _changeChapterExplicitly(index);
            }
          },
          onLongPress: () => _enterSelection(chapter.id),
        );
      },
    );
  }

  Widget _buildPageGridView(
    ScrollController controller,
    int currentIndex,
    Map<String, String>? headers,
  ) {
    if (_pages.isEmpty) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Text(
          AppLocalizations.of(context).readerPagesLoading,
          style: TextStyle(
            color: dark ? Colors.white54 : Colors.black54,
            fontSize: 14,
          ),
        ),
      );
    }

    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        return _buildPageThumbCard(
          imageUrl: _pages[index],
          badgeText: '${index + 1}',
          headers: headers,
          localPath: _pageFiles[index],
          onTap: () => _openPage(index),
        );
      },
    );
  }

  void _openPage(int pageIndex) {
    Navigator.pop(context);
    _jumpToPage(pageIndex);
  }

  Widget _buildBookmarksView(
    ScrollController controller,
    Map<String, String>? headers, {
    required VoidCallback onRefresh,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getBookmarks(widget.mangaId),
      builder: (context, snapshot) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        if (snapshot.hasError) {
          return Center(
            child: Text(
              AppLocalizations.of(context).readerFailedToLoadBookmarks,
              style: TextStyle(
                color: dark ? Colors.white54 : Colors.black54,
                fontSize: 14,
              ),
            ),
          );
        }
        final bookmarks = snapshot.data ?? const [];
        if (bookmarks.isEmpty) {
          return EmptyState(
            icon: RemixIcons.bookmark_3_line,
            title: AppLocalizations.of(context).bookmarksEmpty,
            subtitle: AppLocalizations.of(context).readerBookmarksHint,
          );
        }

        // Group bookmarks by chapter.
        final grouped = <String, List<Map<String, dynamic>>>{};
        String titleFor(Map<String, dynamic> bm) =>
            bm['chapterTitle'] as String? ?? '';
        for (final bm in bookmarks) {
          final key = (bm['chapterId'] as String?) ?? titleFor(bm);
          grouped.putIfAbsent(key, () => []).add(bm);
        }

        final totalPages = _pages.isEmpty ? 0 : _pages.length;

        return SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: grouped.entries.map((entry) {
              final isCurrentChapter =
                  entry.key == widget.allChapters[_currentChapterIndex].id;
              final chapterNum = entry.value.first['chapterTitle'] ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Text(
                      AppLocalizations.of(context).chapterNum(chapterNum),
                      style: TextStyle(
                        color: dark
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: entry.value.length,
                    itemBuilder: (context, index) {
                      final bm = entry.value[index];
                      final pageIndex = (bm['pageIndex'] as int?) ?? 0;
                      final percent = isCurrentChapter && totalPages > 1
                          ? ((pageIndex / totalPages) * 100).round()
                          : null;
                      return _buildPageThumbCard(
                        imageUrl: bm['pageUrl'] as String? ?? '',
                        badgeText: percent != null
                            ? '$percent%'
                            : '${pageIndex + 1}',
                        headers: headers,
                        onTap: () => _openBookmark(bm),
                        onLongPress: () => _removeBookmark(bm, onRefresh),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildDownloadsView(ScrollController controller) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getDownloads(widget.mangaId),
      builder: (context, snapshot) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context).readerNoDownloads,
              style: TextStyle(
                color: dark ? Colors.white54 : Colors.black54,
                fontSize: 14,
              ),
            ),
          );
        }
        return ListView.builder(
          controller: controller,
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final chapterId = row['chapterId'] as String? ?? '';
            final title = row['chapterTitle'] as String? ?? '';
            final chapterNumber = ((row['chapterNumber'] as num?) ?? 0)
                .toDouble();
            final pageCount = (row['pageCount'] as int?) ?? 0;
            final downloadedAt = row['downloadedAt'] as String? ?? '';
            return ListTile(
              dense: true,
              leading: Icon(
                RemixIcons.checkbox_circle_line,
                color: _activeGreen,
                size: 22,
              ),
              title: Text(
                title.isEmpty
                    ? AppLocalizations.of(
                        context,
                      ).chapterNum(_formatChapterNumber(chapterNumber))
                    : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dark ? Colors.white70 : const Color(0xFF49454F),
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                AppLocalizations.of(context).readerDownloadedChapterDate(
                  pageCount,
                  _formatChapterDate(
                    downloadedAt,
                    AppLocalizations.of(context),
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dark ? Colors.white38 : Colors.black38,
                  fontSize: 11,
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  RemixIcons.delete_bin_6_line,
                  color: dark ? Colors.white38 : Colors.black38,
                  size: 20,
                ),
                tooltip: AppLocalizations.of(context).removeDownloadTooltip,
                onPressed: () => _confirmRemoveDownload(chapterId, title),
              ),
              onTap: () {
                Navigator.pop(context);
                final matched = widget.allChapters.indexWhere(
                  (c) => c.id == chapterId,
                );
                if (matched != -1) {
                  _pendingJumpPage = 0;
                  _changeChapterExplicitly(matched);
                }
              },
            );
          },
        );
      },
    );
  }

  String _formatChapterNumber(double number) {
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(
      number == number.truncateToDouble() ? 0 : _decimalPlaces(number),
    );
  }

  int _decimalPlaces(double number) {
    final s = number.toString();
    final dot = s.indexOf('.');
    return dot == -1 ? 0 : s.length - dot - 1;
  }

  Widget _buildPageThumbCard({
    required String imageUrl,
    required String badgeText,
    required Map<String, String>? headers,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    String? localPath,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: localPath != null && File(localPath).existsSync()
                  ? SafeFileImage(
                      file: File(localPath),
                      fit: BoxFit.cover,
                      errorWidget: (context, path, error) {
                        final dark =
                            Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          color: dark ? const Color(0xFF2C2C2E) : Colors.white,
                          child: Icon(
                            RemixIcons.book_open_line,
                            color: dark ? Colors.white38 : Colors.black38,
                            size: 20,
                          ),
                        );
                      },
                    )
                  : SafeNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      httpHeaders: headers,
                      errorWidget: (context, url, error) {
                        final dark =
                            Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          color: dark ? const Color(0xFF2C2C2E) : Colors.white,
                          child: Icon(
                            RemixIcons.book_open_line,
                            color: dark ? Colors.white38 : Colors.black38,
                            size: 20,
                          ),
                        );
                      },
                    ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeBookmark(
    Map<String, dynamic> bookmark,
    VoidCallback onRefresh,
  ) async {
    final id = bookmark['id'] as int?;
    if (id == null) return;

    final pageIndex = (bookmark['pageIndex'] as int?) ?? 0;
    final chapterTitle = bookmark['chapterTitle'] ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final l = AppLocalizations.of(context);
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
          title: Text(
            l.readerRemoveBookmarkTitle,
            style: TextStyle(
              color: dark
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: Text(
            l.readerBookmarkLine(chapterTitle, pageIndex + 1),
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
              child: Text(l.remove, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    await DatabaseHelper.instance.deleteBookmark(id);
    final key = _bookmarkKey(bookmark['chapterId'] as String? ?? '', pageIndex);
    if (mounted) {
      setState(() => _bookmarkedKeys.remove(key));
    }
    onRefresh();
  }

  void _openBookmark(Map<String, dynamic> bookmark) {
    final chapterId = bookmark['chapterId'] as String?;
    final pageIndex = (bookmark['pageIndex'] as int?) ?? 0;
    final index = chapterId == null
        ? -1
        : widget.allChapters.indexWhere((c) => c.id == chapterId);

    Navigator.pop(context);
    if (index != -1) {
      _pendingJumpPage = pageIndex;
      _changeChapterExplicitly(index);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).readerChapterNotFound),
        ),
      );
    }
  }

  String _chapterSubtitle(Chapter chapter, AppLocalizations l) {
    final num = chapter.chapterNumber.isNotEmpty
        ? '#${chapter.chapterNumber}'
        : '';
    final date = _formatChapterDate(chapter.releaseDate, l);
    return [num, date].where((p) => p.isNotEmpty).join(' • ');
  }

  String _formatChapterDate(String? raw, AppLocalizations l) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // --- SETTINGS SHEET ---

  void _showSettingsSheet() {
    showIosSheet<void>(
      context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            final l = AppLocalizations.of(context);
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top actions.
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        leading: Icon(
                          RemixIcons.save_2_line,
                          color: dark ? Colors.white : const Color(0xFF1C1B1F),
                          size: 22,
                        ),
                        title: Text(
                          l.readerSavePage,
                          style: TextStyle(
                            color: dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
                            fontSize: 15,
                          ),
                        ),
                        onTap: _saveCurrentPage,
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        leading: Icon(
                          _isCurrentPageBookmarked
                              ? RemixIcons.bookmark_2_fill
                              : RemixIcons.bookmark_3_line,
                          color: _isCurrentPageBookmarked
                              ? _activeGreen
                              : dark
                              ? Colors.white
                              : const Color(0xFF1C1B1F),
                          size: 22,
                        ),
                        title: Text(
                          _isCurrentPageBookmarked
                              ? l.readerRemoveBookmark
                              : l.readerAddBookmark,
                          style: TextStyle(
                            color: _isCurrentPageBookmarked
                                ? _activeGreen
                                : dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
                            fontSize: 15,
                          ),
                        ),
                        onTap: () async {
                          await _toggleBookmark();
                          if (context.mounted) setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 8),

                      // Read mode.
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          l.readerSectionReadingMode,
                          style: TextStyle(
                            color: dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildReadModeSelector(
                        afterChange: () => setSheetState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.readerRememberedNote,
                        style: TextStyle(
                          color: dark ? Colors.white38 : Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Toggles.
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        activeTrackColor: _activeGreen,
                        activeThumbColor: Colors.white,
                        inactiveTrackColor: dark
                            ? Colors.white24
                            : Colors.black26,
                        inactiveThumbColor: dark ? Colors.white : Colors.white,
                        dense: true,
                        title: Text(
                          l.readerTwoPagesLandscape,
                          style: TextStyle(
                            color: dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
                            fontSize: 15,
                          ),
                        ),
                        value: _useTwoPagesLayout,
                        onChanged: (value) {
                          _toggleTwoPages(value);
                          setSheetState(() {});
                        },
                      ),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        activeTrackColor: _activeGreen,
                        activeThumbColor: Colors.white,
                        inactiveTrackColor: dark
                            ? Colors.white24
                            : Colors.black26,
                        inactiveThumbColor: dark ? Colors.white : Colors.white,
                        dense: true,
                        title: Text(
                          l.readerRotateScreen,
                          style: TextStyle(
                            color: dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
                            fontSize: 15,
                          ),
                        ),
                        value: _rotateScreen,
                        onChanged: (value) {
                          _toggleRotateScreen(value);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 8),

                      // Plain list items.
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        leading: Icon(
                          RemixIcons.timer_line,
                          color: dark ? Colors.white : const Color(0xFF1C1B1F),
                          size: 22,
                        ),
                        title: Text(
                          l.readerAutoScroll,
                          style: TextStyle(
                            color: dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
                            fontSize: 15,
                          ),
                        ),
                        onTap: () {},
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        leading: Icon(
                          RemixIcons.contrast_2_line,
                          color: dark ? Colors.white : const Color(0xFF1C1B1F),
                          size: 22,
                        ),
                        title: Text(
                          l.colorCorrection,
                          style: TextStyle(
                            color: dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
                            fontSize: 15,
                          ),
                        ),
                        onTap: _showColorCorrectionDialog,
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        leading: Icon(
                          RemixIcons.settings_4_line,
                          color: dark ? Colors.white : const Color(0xFF1C1B1F),
                          size: 22,
                        ),
                        title: Text(
                          l.settings,
                          style: TextStyle(
                            color: dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
                            fontSize: 15,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReadModeSelector({VoidCallback? afterChange}) {
    final l = AppLocalizations.of(context);
    final modes = [
      (ReadingMode.standard, RemixIcons.crop_line, l.readerModeStandard),
      (ReadingMode.rightToLeft, RemixIcons.swap_line, l.readerModeRTL),
      (ReadingMode.vertical, RemixIcons.rectangle_line, l.readerModeVertical),
      (ReadingMode.webtoon, RemixIcons.list_view, l.readerModeWebtoon),
    ];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = dark ? const Color(0xFF5B8DEF) : Colors.blue.shade100;
    final selectedFg = dark ? Colors.white : Colors.blue.shade900;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: modes.map((mode) {
          final isSelected = _readingMode == mode.$1;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _setReadingMode(mode.$1);
                afterChange?.call();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      mode.$2,
                      size: 16,
                      color: isSelected
                          ? selectedFg
                          : dark
                          ? Colors.white70
                          : Colors.black,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        mode.$3,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? selectedFg
                              : dark
                              ? Colors.white70
                              : Colors.black,
                          fontSize: 12.5,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Active/current accent — resolved from the active color scheme preset.
  Color get _activeGreen => Theme.of(context).colorScheme.primary;

  Future<void> _loadChapter(int chapterIndex) async {
    if (_loadedChapterIndices.contains(chapterIndex)) return;

    final chapter = widget.allChapters[chapterIndex];
    MangaSource? source;
    if (widget.sourceId != null) {
      source = getSourceBySourceId(widget.sourceId!);
    }
    source ??= ref.read(currentSourceProvider);

    if (source == null) return;
    final src = source;

    try {
      final List<String> newPages;
      if (_downloadedChapters.contains(chapter.id)) {
        // Offline-first: use the page URLs persisted when the chapter was
        // downloaded so no network is needed to open it.
        final download = await DatabaseHelper.instance.getDownload(
          widget.mangaId,
          chapter.id,
        );
        final stored = download?['pageUrls'];
        final storedList = stored is String && stored.isNotEmpty
            ? (jsonDecode(stored) as List).cast<String>()
            : null;
        if (storedList != null && storedList.isNotEmpty) {
          newPages = storedList;
        } else {
          // Legacy download (pre page-URL caching) -> network fallback.
          newPages = await SourceCache.pageUrls(
            sourceId: src.id,
            chapterId: chapter.id,
            fetch: () => src.getPageUrls(chapter.id),
          );
        }
      } else {
        newPages = await SourceCache.pageUrls(
          sourceId: src.id,
          chapterId: chapter.id,
          fetch: () => src.getPageUrls(chapter.id),
        );
      }
      if (!mounted) return;

      List<String?>? locals;
      if (_downloadedChapters.contains(chapter.id)) {
        locals = await ChapterDownloader.localPathsForChapter(
          mangaId: widget.mangaId,
          chapterId: chapter.id,
          pages: newPages,
        );
        if (!mounted) return;
      }

      setState(() {
        _pages.addAll(newPages);
        _pagesChapters.addAll(newPages.map((_) => chapterIndex));
        if (locals != null) {
          _pageFiles.addAll(locals);
        } else {
          _pageFiles.addAll(newPages.map((_) => null));
        }
        _loadedChapterIndices.add(chapterIndex);
      });
      // New pages entered the list; let the next tick re-center the preload
      // window on the reader's actual position.
      _prefetchAnchorPage = -1;
      if (_needsRestore) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
      } else if (_pendingJumpPage != null) {
        final target = _pendingJumpPage!;
        _pendingJumpPage = null;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _jumpToPage(target),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _prefetchNearbyPages();
          _maybeShowToast();
        }
      });
    } catch (e) {
      debugPrint('Error loading chapter: $e');
    }
  }

  Future<void> _loadNextChapter() async {
    final nextIndex = _currentChapterIndex + 1;
    if (nextIndex >= widget.allChapters.length) {
      setState(() => _hasMoreChapters = false);
      return;
    }
    setState(() => _isLoadingNextChapter = true);
    _currentChapterIndex = nextIndex;
    await _loadChapter(_currentChapterIndex);
    if (mounted) {
      setState(() => _isLoadingNextChapter = false);
    }
  }

  /// Loads the chapter before the frontmost loaded one and PREPENDS its pages
  /// to the list, then shifts the view back to what the reader was showing.
  /// `_currentChapterIndex` stays unchanged (it tracks the newest loaded
  /// chapter, which forward-navigation and progress-saving depend on).
  Future<void> _loadPreviousChapter() async {
    if (_isLoadingPreviousChapter) return;
    final frontChapter = _pagesChapters.isNotEmpty
        ? _pagesChapters.first
        : _currentChapterIndex;
    final prevIndex = frontChapter - 1;
    if (prevIndex < 0 || prevIndex >= widget.allChapters.length) return;
    if (_loadedChapterIndices.contains(prevIndex)) return;
    _isLoadingPreviousChapter = true;

    final chapter = widget.allChapters[prevIndex];
    MangaSource? source;
    if (widget.sourceId != null) {
      source = getSourceBySourceId(widget.sourceId!);
    }
    source ??= ref.read(currentSourceProvider);
    if (source == null) {
      _isLoadingPreviousChapter = false;
      return;
    }
    final src = source;

    try {
      final List<String> newPages;
      if (_downloadedChapters.contains(chapter.id)) {
        final download = await DatabaseHelper.instance.getDownload(
          widget.mangaId,
          chapter.id,
        );
        final stored = download?['pageUrls'];
        final storedList = stored is String && stored.isNotEmpty
            ? (jsonDecode(stored) as List).cast<String>()
            : null;
        if (storedList != null && storedList.isNotEmpty) {
          newPages = storedList;
        } else {
          newPages = await SourceCache.pageUrls(
            sourceId: src.id,
            chapterId: chapter.id,
            fetch: () => src.getPageUrls(chapter.id),
          );
        }
      } else {
        newPages = await SourceCache.pageUrls(
          sourceId: src.id,
          chapterId: chapter.id,
          fetch: () => src.getPageUrls(chapter.id),
        );
      }
      if (!mounted) return;

      List<String?>? locals;
      if (_downloadedChapters.contains(chapter.id)) {
        locals = await ChapterDownloader.localPathsForChapter(
          mangaId: widget.mangaId,
          chapterId: chapter.id,
          pages: newPages,
        );
        if (!mounted) return;
      }

      final wasAt = _currentPageIndex;
      final inserted = newPages.length;

      setState(() {
        _pages.insertAll(0, newPages);
        _pagesChapters.insertAll(0, List.filled(inserted, prevIndex));
        _pageFiles.insertAll(0, locals ?? List.filled(inserted, null));
        _loadedChapterIndices.add(prevIndex);
      });
      _prefetchAnchorPage = -1;

      // The page under the reader moved forward by [inserted] slots; keep the
      // view on it. Vertical mode estimates page height at 600 (matches the
      // jump-to-page math used elsewhere).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_isHorizontal) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(wasAt + inserted);
          }
        } else if (_scrollController.hasClients) {
          _scrollController.jumpTo((wasAt + inserted) * 600.0);
        }
        if (mounted) _maybeShowToast();
      });
    } catch (e) {
      debugPrint('Error loading previous chapter: $e');
    } finally {
      _isLoadingPreviousChapter = false;
    }
  }

  // --- CHAPTER TRANSITION TOAST ---

  Future<void> _prefetchNearbyPages({int lookahead = 6}) async {
    if (_pages.isEmpty) return;
    final current = _currentPageIndex;
    // Re-center the window only when the anchor actually moved, otherwise a
    // busy scroll ticker would re-schedule the same downloads repeatedly.
    if (current == _prefetchAnchorPage) return;
    _prefetchAnchorPage = current;

    final start = (current - 2).clamp(0, _pages.length - 1);
    final end = (current + lookahead).clamp(0, _pages.length - 1);
    // Snapshot the URLs to prefetch up front: the loop below awaits downloads,
    // and switching chapters mid-loop clears _pages, which would otherwise make
    // _pages[i] throw a RangeError on the next iteration.
    final targets = <String>[];
    for (var i = start; i <= end && i < _pages.length; i++) {
      final ref = _pages[i];
      if (!ref.startsWith('http')) continue;
      if (_prefetchScheduled.contains(ref)) continue;
      targets.add(ref);
    }
    _prefetchScheduled.addAll(targets);
    for (final ref in targets) {
      try {
        await AppImageCache.instance.manager.getSingleFile(
          ref,
          headers: _activeRequestHeaders,
        );
      } catch (_) {
        // Swallow: download failures are surfaced by the image widget itself.
      }
    }
  }

  /// Gently warms the chapter AFTER the one the reader is currently finishing,
  /// so advancing to it feels instant. Only runs when the reader is on the
  /// last few pages of an in-memory chapter, the next chapter exists, and the
  /// user enabled "Pre-cache next chapter" in Storage settings.
  void _precacheNextChapterPages() {
    if (_isPrecachingNextChapter) return;
    if (_pages.isEmpty ||
        _pagesChapters.isEmpty ||
        _currentPageIndex >= _pages.length) {
      return;
    }
    if (!ref.read(cacheSettingsProvider).precacheNextChapter) return;

    final currentChapter = _pagesChapters[_currentPageIndex];
    // Walk to the last page that belongs to this same chapter.
    var lastPageOfChapter = _currentPageIndex;
    for (var i = _currentPageIndex + 1; i < _pagesChapters.length; i++) {
      if (_pagesChapters[i] != currentChapter) break;
      lastPageOfChapter = i;
    }
    // Only engage within the final ~2 pages of the chapter.
    if (lastPageOfChapter - _currentPageIndex > 2) return;

    final nextIndex = currentChapter + 1;
    if (nextIndex >= widget.allChapters.length) return;
    if (_loadedChapterIndices.contains(nextIndex)) return;

    _precacheChapterPages(nextIndex);
  }

  Future<void> _precacheChapterPages(int chapterIndex) async {
    if (_isPrecachingNextChapter) return;
    final chapter = widget.allChapters[chapterIndex];
    // Chapters stored locally are read from disk instantly — nothing to warm.
    if (_downloadedChapters.contains(chapter.id)) return;
    _isPrecachingNextChapter = true;
    try {
      MangaSource? source;
      if (widget.sourceId != null) {
        source = getSourceBySourceId(widget.sourceId!);
      }
      source ??= ref.read(currentSourceProvider);
      if (source == null) return;
      final src = source;

      final pages = await SourceCache.pageUrls(
        sourceId: src.id,
        chapterId: chapter.id,
        fetch: () => src.getPageUrls(chapter.id),
      );
      if (!mounted) return;

      // Warm the first handful of pages of the next chapter into the disk
      // cache so the chapter boundary reads like a normal page turn.
      final limit = pages.length < 6 ? pages.length : 6;
      for (var i = 0; i < limit; i++) {
        final url = pages[i];
        if (!url.startsWith('http')) continue;
        try {
          await AppImageCache.instance.manager.getSingleFile(
            url,
            headers: _activeRequestHeaders,
          );
        } catch (_) {
          // Swallow: the page widget surfaces any real failure when reached.
        }
      }
    } catch (e) {
      debugPrint('Error pre-caching chapter ${chapterIndex + 1}: $e');
    } finally {
      _isPrecachingNextChapter = false;
    }
  }

  void _handleScrollTicker() {
    final pos = _scrollController.position;
    // Warm the on-disk cache for pages a little ahead while scrolling.
    _prefetchNearbyPages();
    // When the reader reaches the last few pages of a chapter, silently warm
    // the NEXT chapter's pages too so chapter transitions are instant.
    _precacheNextChapterPages();
    // Once the reader moves off the landing page, re-arm the adjacent-chapter
    // loaders so real backward swipes still work.
    if (_suppressAdjacentAutoLoad && pos.pixels > 800) {
      _suppressAdjacentAutoLoad = false;
    }
    // Load the previous chapter only on a real backward pull at the very top
    // (scrolled below zero, moving further back). Floating within the first
    // 800px must NOT trigger it: that's what used to prepend a whole chapter
    // and shift the view under the reader "by itself".
    final movingBack = pos.pixels < _lastScrollPixels;
    _lastScrollPixels = pos.pixels;
    if (!_suppressAdjacentAutoLoad &&
        pos.pixels < 0 &&
        movingBack &&
        !_isLoadingPreviousChapter) {
      _loadPreviousChapter();
    }
    if (pos.pixels >= pos.maxScrollExtent - 800 &&
        !_isLoadingNextChapter &&
        _hasMoreChapters) {
      _loadNextChapter();
    }
    _maybeShowToast();
    _scrollStopTimer?.cancel();
    _scrollStopTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _toastOpacity <= 0) return;
      _scheduleToastDismiss(delay: const Duration(milliseconds: 1000));
    });
  }

  void _maybeShowToast() {
    if (_pages.isEmpty || _pagesChapters.isEmpty) return;
    final ci = _pagesChapters[_currentPageIndex];
    if (ci == _toastShownChapter || ci < 0 || ci >= widget.allChapters.length) {
      return;
    }
    _toastShownChapter = ci;
    _toastTimer?.cancel();
    _setToastOpacity(1);
    _scheduleToastDismiss();
  }

  void _setToastOpacity(double value) {
    if (_toastOpacity == value) return;
    setState(() => _toastOpacity = value);
  }

  void _scheduleToastDismiss({
    Duration delay = const Duration(milliseconds: 4000),
  }) {
    _toastTimer?.cancel();
    _toastTimer = Timer(delay, () {
      if (mounted) _setToastOpacity(0);
    });
  }

  Widget? _buildChapterToast() {
    final chi = _toastShownChapter;
    if (chi < 0 || chi >= widget.allChapters.length) return null;
    final ch = widget.allChapters[chi];
    final label = ch.chapterNumber == 'Chapter'
        ? ch.title
        : AppLocalizations.of(context).chapterNum(ch.chapterNumber);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 110,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _toastOpacity,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: Center(child: _ChapterPageToast(label: label)),
        ),
      ),
    );
  }

  Future<void> _autosaveProgress() async {
    if (_pages.isEmpty || _loadedChapterIndices.isEmpty) return;
    final page = _currentPageIndex;
    final chapter = _readChapterIndex;
    if (page == _autoSavedPage && chapter == _autoSavedChapter) return;
    _autoSavedPage = page;
    _autoSavedChapter = chapter;
    await _saveCascadingReadProgress();
  }

  // Persist progress when the app is backgrounded or about to be killed, so a
  // force-stop / OOM right after leaving the reader doesn't lose the position.
  @override
  // Tracks reading time while the reader is open so the statistics charts get
  // honest per-manga minutes. Flushed to the `reading_time` table on lifecycle
  // pauses and on dispose; a process kill loses at most one session.
  final Stopwatch _sessionStopwatch = Stopwatch();
  int _flushedSessionSeconds = 0;

  Future<void> _flushSessionTime() async {
    if (!_sessionStopwatch.isRunning) return;
    final elapsed = _sessionStopwatch.elapsed.inSeconds;
    final pending = elapsed - _flushedSessionSeconds;
    if (pending < 45) return;
    final minutes = pending ~/ 60;
    if (minutes <= 0) return;
    _flushedSessionSeconds += minutes * 60;
    await DatabaseHelper.instance.addReadingTime(widget.mangaId, minutes);
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _autosaveProgress();
      _flushSessionTime();
    }
    // Returning to a backgrounded immersive reader re-hides the system bars.
    if (state == AppLifecycleState.resumed && !_showControls) {
      _applySystemUiMode();
    }
  }

  Future<void> _saveCascadingReadProgress() async {
    if (_loadedChapterIndices.isEmpty || _isSaving) return;
    _isSaving = true;

    final currentChapter = widget.allChapters[_currentChapterIndex];
    final currentIndex = _currentChapterIndex;

    // `lastReadChapter` is a threshold counted from the oldest chapter:
    // reading the chapter at index `i` means the first `i + 1` chapters are
    // read. (Previously this was computed as `totalChapters - i`, which made
    // reading the first chapter mark every chapter as read.)
    final position = (currentIndex + 1).toDouble();

    await DatabaseHelper.instance.markChapterAsRead(
      widget.mangaId,
      currentChapter.id,
      position,
    );

    await DatabaseHelper.instance.saveMangaProgress(
      mangaId: widget.mangaId,
      title: widget.mangaTitle ?? 'Unknown',
      coverUrl: widget.mangaCoverUrl,
      sourceId: widget.sourceId,
      totalChapters: widget.totalChapters,
      lastReadChapter: position,
      lastReadPage: _pages.isEmpty ? 0 : _currentPageIndex,
    );

    bumpHistoryRevision(ref);
    _isSaving = false;
  }

  // --- CHAPTER DOWNLOADS ---

  Future<void> _loadProgress() async {
    final row = await DatabaseHelper.instance.getManga(widget.mangaId);
    if (!mounted) return;
    setState(() {
      _lastReadChapter = row?['lastReadChapter'] is num
          ? (row!['lastReadChapter'] as num).toDouble()
          : -1;
    });
  }

  Future<void> _loadDownloads() async {
    final rows = await DatabaseHelper.instance.getDownloads(widget.mangaId);
    final ids = <String>{};
    for (final row in rows) {
      final chapterId = row['chapterId'] as String? ?? '';
      if (chapterId.isEmpty) continue;
      if (await ChapterDownloader.isDownloaded(widget.mangaId, chapterId)) {
        ids.add(chapterId);
      }
    }
    if (!mounted) return;
    setState(() {
      _downloadedChapters
        ..clear()
        ..addAll(ids);
    });
  }

  Future<bool> _downloadChapter(Chapter chapter, {bool notify = true}) async {
    MangaSource? source;
    if (widget.sourceId != null) {
      source = getSourceBySourceId(widget.sourceId!);
    }
    source ??= ref.read(currentSourceProvider);
    if (source == null) return false;
    final src = source;

    final List<String> pages;
    try {
      pages = await SourceCache.pageUrls(
        sourceId: src.id,
        chapterId: chapter.id,
        fetch: () => src.getPageUrls(chapter.id),
      );
    } catch (e) {
      if (notify && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).readerFailedLoadChapterPages,
            ),
          ),
        );
      }
      return false;
    }
    if (!mounted) return false;

    final task = _ChapterDownloadTask()..total = pages.length;
    setState(() => _activeDownloads[chapter.id] = task);
    _refreshTray();

    final saved = await ChapterDownloader.downloadChapter(
      mangaId: widget.mangaId,
      chapterId: chapter.id,
      pages: pages,
      headers: source.headers,
      isCancelled: () => task.cancelled,
      onProgress: (done, total) {
        task
          ..done = done
          ..total = total;
        if (mounted) setState(() {});
        _refreshTray();
      },
    );
    if (!mounted) return false;

    if (saved == null) {
      setState(() => _activeDownloads.remove(chapter.id));
      _refreshTray();
      if (notify && !task.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).readerFailedDownloadChapter,
            ),
          ),
        );
      }
      return false;
    }

    final dir = await ChapterDownloader.chapterDir(widget.mangaId, chapter.id);
    await DatabaseHelper.instance.addDownload(
      mangaId: widget.mangaId,
      chapterId: chapter.id,
      chapterNumber: double.tryParse(chapter.chapterNumber) ?? 0,
      chapterTitle: chapter.title,
      pageCount: saved.length,
      localDir: dir.path,
      pageUrls: jsonEncode(pages),
    );
    await DatabaseHelper.instance.upsertManga(
      mangaId: widget.mangaId,
      title: widget.mangaTitle ?? 'Unknown',
      coverUrl: widget.mangaCoverUrl,
      sourceId: widget.sourceId,
    );
    if (!mounted) return false;

    setState(() {
      _activeDownloads.remove(chapter.id);
      _downloadedChapters.add(chapter.id);
    });
    bumpDownloadsRevision(ref);
    _refreshTray();

    final index = widget.allChapters.indexWhere((c) => c.id == chapter.id);
    if (index != -1) _refreshLoadedChapterFiles(index);

    if (notify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).readerDownloadedChapter(chapter.title),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return true;
  }

  Future<void> _confirmRemoveDownload(String chapterId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final l = AppLocalizations.of(context);
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF2C2C2E) : Colors.white,
          title: Text(
            l.readerRemoveDownloadTitle,
            style: TextStyle(
              color: dark
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: Text(
            title.isEmpty ? l.readerThisChapter : title,
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
              child: Text(l.remove, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    await ChapterDownloader.removeChapterFiles(widget.mangaId, chapterId);
    await DatabaseHelper.instance.removeDownload(widget.mangaId, chapterId);
    if (!mounted) return;

    setState(() => _downloadedChapters.remove(chapterId));
    bumpDownloadsRevision(ref);
    _refreshTray();

    final index = widget.allChapters.indexWhere((c) => c.id == chapterId);
    if (index != -1) _refreshLoadedChapterFiles(index);
  }

  // --- CHAPTER TRAY SELECTION MODE ---

  void _enterSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
    // Jump the tray to full height so the selection actions stay visible.
    _trayExtentController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _refreshTray();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedIds.add(id)) {
        _selectedIds.remove(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
    _refreshTray();
  }

  void _exitSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
    _refreshTray();
  }

  // Adds every chapter between the min and max indices of the current
  // selection, then keeps just that contiguous range selected.
  void _selectChapterRange() {
    final chapters = widget.allChapters;
    if (chapters.isEmpty || _selectedIds.isEmpty) return;
    final indices = <int>[
      for (var i = 0; i < chapters.length; i++)
        if (_selectedIds.contains(chapters[i].id)) i,
    ];
    final minIndex = indices.reduce((a, b) => a < b ? a : b);
    final maxIndex = indices.reduce((a, b) => a > b ? a : b);
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(chapters.sublist(minIndex, maxIndex + 1).map((c) => c.id));
    });
    _refreshTray();
  }

  // True when every chapter in the tray is selected.
  bool get _isAllSelectedInTray =>
      widget.allChapters.isNotEmpty &&
      _selectedIds.length == widget.allChapters.length;

  // True when there are non-selected chapters between the extremes of the
  // current selection (i.e. a range fill would actually select something).
  bool get _hasSelectionGap {
    final chapters = widget.allChapters;
    if (_selectedIds.length < 2 || chapters.isEmpty) return false;
    final indices = <int>[
      for (var i = 0; i < chapters.length; i++)
        if (_selectedIds.contains(chapters[i].id)) i,
    ];
    if (indices.length < 2) return false;
    final minIndex = indices.reduce((a, b) => a < b ? a : b);
    final maxIndex = indices.reduce((a, b) => a > b ? a : b);
    return (maxIndex - minIndex + 1) > indices.length;
  }

  // Selects every chapter in the tray.
  void _selectAllChapters() {
    final chapters = widget.allChapters;
    if (chapters.isEmpty) return;
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(chapters.map((c) => c.id));
    });
    _refreshTray();
  }

  // Clears the selection and exits selection mode.
  void _deselectAllChapters() {
    _exitSelection();
  }

  // True when every selected chapter is in the "read" range.
  bool get _isAllSelectedRead {
    if (_selectedIds.isEmpty) return false;
    for (var i = 0; i < widget.allChapters.length; i++) {
      if (!_selectedIds.contains(widget.allChapters[i].id)) continue;
      final isRead = _lastReadChapter >= 0 && (i + 1) <= _lastReadChapter;
      if (!isRead) return false;
    }
    return true;
  }

  bool get _isSelectedDownloaded {
    return _selectedIds.any(_downloadedChapters.contains);
  }

  void _toggleSelectedRead() {
    // Batch read/unread toggle — flips the last-read threshold so all
    // selected chapters fall on the opposite side.
    final selectedIndices = <int>[
      for (var i = 0; i < widget.allChapters.length; i++)
        if (_selectedIds.contains(widget.allChapters[i].id)) i,
    ];
    if (selectedIndices.isEmpty) return;

    final targetChapterNumbers = selectedIndices.map((i) => i + 1).toList();
    final double newThreshold = _isAllSelectedRead
        ? (targetChapterNumbers.reduce((a, b) => a < b ? a : b) - 1).toDouble()
        : targetChapterNumbers.reduce((a, b) => a > b ? a : b).toDouble();

    setState(() => _lastReadChapter = newThreshold);
    DatabaseHelper.instance.saveMangaProgress(
      mangaId: widget.mangaId,
      title: widget.mangaTitle ?? 'Unknown',
      coverUrl: widget.mangaCoverUrl,
      sourceId: widget.sourceId,
      totalChapters: widget.totalChapters,
      lastTrayTotalChapters: widget.totalChapters,
      lastReadChapter: newThreshold,
    );
    _exitSelection();
  }

  Future<void> _downloadSelectedChapters() async {
    final chapters = widget.allChapters
        .where((c) => _selectedIds.contains(c.id))
        .toList();
    _exitSelection();
    var success = 0;
    for (final ch in chapters) {
      final ok = await _downloadChapter(ch, notify: false);
      if (ok) success++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).downloadedChaptersCount(success),
        ),
      ),
    );
  }

  Future<void> _deleteSelectedDownloads() async {
    final selected = _selectedIds.toList();
    _exitSelection();
    for (final ch in widget.allChapters) {
      if (!selected.contains(ch.id)) continue;
      await ChapterDownloader.removeChapterFiles(widget.mangaId, ch.id);
      await DatabaseHelper.instance.removeDownload(widget.mangaId, ch.id);
    }
    if (!mounted) return;
    setState(() {
      for (final id in selected) {
        _downloadedChapters.remove(id);
      }
    });
    bumpDownloadsRevision(ref);
    _refreshTray();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).deletedSelectedDownloads),
      ),
    );
  }

  // Point already-loaded pages of a chapter at their local files (or back at
  // the network when the download was removed).
  Future<void> _refreshLoadedChapterFiles(int chapterIndex) async {
    final start = _pagesChapters.indexOf(chapterIndex);
    if (start == -1) return;
    final end = _pagesChapters.lastIndexOf(chapterIndex);
    final chapter = widget.allChapters[chapterIndex];

    List<String>? locals;
    if (_downloadedChapters.contains(chapter.id)) {
      locals = await ChapterDownloader.localPathsForChapter(
        mangaId: widget.mangaId,
        chapterId: chapter.id,
        pages: _pages.sublist(start, end + 1),
      );
    }
    if (!mounted) return;
    setState(() {
      for (var i = start; i <= end; i++) {
        _pageFiles[i] = locals != null ? locals[i - start] : null;
      }
    });
  }

  Future<void> _loadBookmarks() async {
    final rows = await DatabaseHelper.instance.getBookmarks(widget.mangaId);
    if (!mounted) return;
    setState(() {
      _bookmarkedKeys
        ..clear()
        ..addAll(
          rows.map(
            (r) => _bookmarkKey(
              r['chapterId'] as String? ?? '',
              (r['pageIndex'] as int?) ?? 0,
            ),
          ),
        );
    });
  }

  Future<void> _toggleBookmark() async {
    if (_pages.isEmpty || _currentChapterIndex < 0) return;

    final pageIndex = _currentPageIndex.clamp(0, _pages.length - 1);

    final chapter = widget.allChapters[_currentChapterIndex];
    final pageUrl = _pages[pageIndex];
    final note = AppLocalizations.of(
      context,
    ).readerSavedFromChapter(chapter.title);

    final existing = await DatabaseHelper.instance.findBookmarkId(
      mangaId: widget.mangaId,
      chapterId: chapter.id,
      pageIndex: pageIndex,
    );
    if (existing != null) {
      await DatabaseHelper.instance.deleteBookmark(existing);
      if (mounted) {
        setState(() {
          _bookmarkedKeys.remove(_bookmarkKey(chapter.id, pageIndex));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).readerBookmarkRemovedNice(chapter.title, pageIndex + 1),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    await DatabaseHelper.instance.addBookmark(
      mangaId: widget.mangaId,
      chapterId: chapter.id,
      chapterTitle: chapter.title,
      pageIndex: pageIndex,
      pageUrl: pageUrl,
      note: note,
    );
    if (mounted) {
      setState(() {
        _bookmarkedKeys.add(_bookmarkKey(chapter.id, pageIndex));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).readerBookmarked(chapter.title, pageIndex + 1),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- COLOR CORRECTION FILTER ---

  List<double> _buildColorMatrix() {
    final contrast = _contrast / 100;
    final brightness = (_brightness - 100) * 255 / 100;
    final s = _sepia / 100;

    const sepia = [
      [0.393, 0.769, 0.189, 0.0, 0.0],
      [0.349, 0.686, 0.168, 0.0, 0.0],
      [0.272, 0.534, 0.131, 0.0, 0.0],
      [0.0, 0.0, 0.0, 1.0, 0.0],
    ];

    double m(int row, int col) {
      final identity = row == col ? 1.0 : 0.0;
      return identity * (1 - s) + sepia[row][col] * s;
    }

    return [
      m(0, 0) * contrast,
      m(0, 1) * contrast,
      m(0, 2) * contrast,
      0,
      brightness,
      m(1, 0) * contrast,
      m(1, 1) * contrast,
      m(1, 2) * contrast,
      0,
      brightness,
      m(2, 0) * contrast,
      m(2, 1) * contrast,
      m(2, 2) * contrast,
      0,
      brightness,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  Widget _applyColorFilter(Widget child) {
    if (_brightness == 100 && _contrast == 100 && _sepia == 0) {
      return child;
    }
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_buildColorMatrix()),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final readChapterIndex = _readChapterIndex;
    final currentChapter = widget.allChapters[readChapterIndex];
    final chLabel = currentChapter.chapterNumber.isNotEmpty
        ? currentChapter.chapterNumber
        : '${readChapterIndex + 1}';
    final activeSource = ref.watch(currentSourceProvider);
    final Map<String, String>? activeHeaders = activeSource.headers;

    final readerSource = widget.sourceId != null
        ? getSourceBySourceId(widget.sourceId!)
        : null;
    final headers = readerSource?.headers ?? activeHeaders;
    _activeRequestHeaders = headers;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveCascadingReadProgress();
        if (context.mounted) Navigator.of(context).pop(result);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          onLongPress: _showSettingsSheet,
          child: Stack(
            children: [
              // --- VIEWPORT AREA ---
              _pages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _isHorizontal
                  ? _buildHorizontalReader(headers)
                  : _buildVerticalReader(headers),

              // --- TOP APP BAR OVERLAY (same capsule theming as the bottom bar) ---
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                // Fully off-screen when hidden: the capsule is taller than a
                // fixed 100px once the notch/safe-area inset and 48px content
                // are accounted for, so hide by (safe area + full card height)
                // or its bottom lip stays visible on notched phones.
                top: _showControls
                    ? 0
                    : -(MediaQuery.of(context).padding.top + 96),
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xF228282A) : Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: dark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            RemixIcons.arrow_left_line,
                            color: dark
                                ? Colors.white
                                : const Color(0xFF1C1B1F),
                          ),
                          onPressed: () async {
                            await _saveCascadingReadProgress();
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.mangaTitle ?? currentChapter.title,
                                style: TextStyle(
                                  color: dark
                                      ? Colors.white
                                      : const Color(0xFF1C1B1F),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).readerChapterShort(chLabel),
                                style: TextStyle(
                                  color: dark
                                      ? Colors.white54
                                      : const Color(0xFF49454F),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- PAGE THUMBNAIL STRIP (removed) ---

              // --- KOTATSU-STYLE TOP STATUS BAR (immersive mode) ---
              // Rendered only while the reader controls are hidden. The native
              // system status bar is hidden by SystemChrome, so this replaces it
              // entirely: a full-width row inside the SafeArea (clear of notches
              // / punch-holes) with the reading progress on the left and the
              // battery + clock on the right. No card surface, no elevation,
              // no back button, and it never intercepts taps toggling controls.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: !_showControls
                      ? SafeArea(
                          key: const ValueKey('immersiveStatusBar'),
                          top: true,
                          left: false,
                          right: false,
                          minimum: const EdgeInsets.only(top: 0),
                          child: Transform.translate(
                            offset: const Offset(0, -3),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _immersiveStatusText(
                                        readChapterIndex,
                                        chLabel,
                                      ),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 1.5,
                                            offset: Offset(0, 0),
                                          ),
                                          Shadow(
                                            color: Colors.black87,
                                            blurRadius: 5,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_batteryLevel >= 0) ...[
                                        Icon(
                                          _batteryLevel > 20
                                              ? RemixIcons.battery_2_fill
                                              : RemixIcons.battery_low_fill,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_batteryLevel%',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black,
                                                blurRadius: 1.5,
                                                offset: Offset(0, 0),
                                              ),
                                              Shadow(
                                                color: Colors.black87,
                                                blurRadius: 5,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      Text(
                                        _clockText,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 1.5,
                                              offset: Offset(0, 0),
                                            ),
                                            Shadow(
                                              color: Colors.black87,
                                              blurRadius: 5,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('noStatusBar'),
                          width: 0,
                          height: 0,
                        ),
                ),
              ),

              // --- BOTTOM CAPSULE BAR ---
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                bottom: _showControls ? 16 : -100,
                left: 16,
                right: 16,
                child: Builder(
                  builder: (context) {
                    final dark =
                        Theme.of(context).brightness == Brightness.dark;
                    final iconColor = dark
                        ? Colors.white
                        : const Color(0xFF1C1B1F);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xF228282A) : Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: dark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: AppLocalizations.of(
                              context,
                            ).readerPreviousChapter,
                            icon: Icon(
                              RemixIcons.skip_back_line,
                              color: iconColor,
                              size: 28,
                            ),
                            onPressed: _currentChapterIndex > 0
                                ? () => _changeChapterExplicitly(
                                    _currentChapterIndex - 1,
                                  )
                                : null,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: _buildProgressTrack(),
                            ),
                          ),
                          IconButton(
                            tooltip: AppLocalizations.of(
                              context,
                            ).readerNextChapter,
                            icon: Icon(
                              RemixIcons.skip_forward_line,
                              color: iconColor,
                              size: 28,
                            ),
                            onPressed:
                                _currentChapterIndex <
                                    widget.allChapters.length - 1
                                ? () => _changeChapterExplicitly(
                                    _currentChapterIndex + 1,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 1,
                            height: 26,
                            color: dark ? Colors.white24 : Colors.black12,
                          ),
                          IconButton(
                            tooltip: AppLocalizations.of(
                              context,
                            ).detailChapters,
                            icon: Icon(
                              RemixIcons.list_unordered,
                              color: iconColor,
                              size: 24,
                            ),
                            onPressed: _showChapterList,
                          ),
                          IconButton(
                            tooltip: AppLocalizations.of(context).settings,
                            icon: Icon(
                              RemixIcons.more_2_line,
                              color: iconColor,
                              size: 24,
                            ),
                            onPressed: _showSettingsSheet,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // --- CHAPTER TRANSITION TOAST ---
              if (_toastShownChapter >= 0) _buildChapterToast()!,
            ],
          ),
        ),
      ),
    );
  }

  // --- VERTICAL READER BUILDER (Vertical / Webtoon) ---
  Widget _buildVerticalReader(Map<String, String>? headers) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        itemCount: _pages.length + 1,
        itemBuilder: (context, index) {
          if (index < _pages.length) {
            return _buildPageImage(
              _pages[index],
              headers,
              index: index,
              localPath: _pageFiles[index],
            );
          }
          return _buildLoadingIndicator();
        },
      ),
    );
  }

  // --- HORIZONTAL READER BUILDER (Standard / Right-to-left) ---
  Widget _buildHorizontalReader(Map<String, String>? headers) {
    final isRtl = _readingMode == ReadingMode.rightToLeft;

    Widget pageView = PageView.builder(
      key: ValueKey('pager-${_readingMode.name}-$_useTwoPagesLayout'),
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (index) {
        _maybeShowToast();
        // Warm the on-disk cache for pages ahead of where the reader sits.
        _prefetchNearbyPages();
        // Once the reader moves off the landing page, re-arm the adjacent
        // chapter loaders so real backward swipes still work.
        if (_suppressAdjacentAutoLoad && index > 0) {
          _suppressAdjacentAutoLoad = false;
        }
        // Swiping back into page 0 -> load the previous chapter so the pager
        // can keep going backward across the chapter boundary.
        if (!_suppressAdjacentAutoLoad && _lastPageIndex > 0 && index == 0) {
          _loadPreviousChapter();
        }
        _lastPageIndex = index;
      },
      // Mangayomi-style: while the current page is zoomed, give the page
      // gesture ownership (swipe is disabled until the user zooms back out).
      physics: (_zoomed[_currentPageIndex] ?? false)
          ? const NeverScrollableScrollPhysics()
          : null,
      itemBuilder: (context, index) {
        final page = _buildPageImage(
          _pages[index],
          headers,
          index: index,
          localPath: _pageFiles[index],
        );
        // Un-mirror each page when the reader itself is mirrored for RTL.
        return isRtl ? Transform.scale(scaleX: -1, child: page) : page;
      },
    );

    // Mirror the whole viewport so swiping goes right-to-left naturally.
    if (isRtl) {
      pageView = Transform.scale(scaleX: -1, child: pageView);
    }
    return pageView;
  }

  // --- REUSABLE IMAGE WIDGET ---
  Widget _buildPageImage(
    String url,
    Map<String, String>? headers, {
    required int index,
    String? localPath,
  }) {
    // Changing the key (via retry token) recreates the image widget, which
    // re-triggers the network request.
    final key = ValueKey('$url#${_pageRetryTokens[index] ?? 0}');
    final Widget image;
    if (localPath != null && File(localPath).existsSync()) {
      image = SafeFileImage(
        key: key,
        file: File(localPath),
        fit: BoxFit.fitWidth,
        gaplessPlayback: true,
        errorWidget: (context, path, error) =>
            _buildPageError(index: index, localPath: localPath),
      );
    } else {
      image = SafeNetworkImage(
        key: key,
        imageUrl: url,
        fit: BoxFit.fitWidth,
        httpHeaders: headers,
        placeholder: (context, url) => SizedBox(
          height: MediaQuery.sizeOf(context).height,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white24),
          ),
        ),
        errorWidget: (context, url, error) => _buildPageError(index: index),
      );
    }
    return _buildZoomablePage(index: index, child: _applyColorFilter(image));
  }

  // --- DOUBLE-TAP ZOOM WRAPPER (Mangayomi-style, no pinch) ---
  Widget _buildZoomablePage({required int index, required Widget child}) {
    _maybeResetZoomState();
    // A/B kill-switch: rendering the page image directly (no zoom layer)
    // isolates the wrapper from page-load/source issues.
    if (!_zoomEnabled) return child;
    // Keep a single controller per page alive from first build so the double
    // tap always operates on the SAME matrix that is displayed. The page is
    // drawn with a plain Transform of that matrix (identity when idle), so
    // rendering is identical to the zoom-off path.
    final controller = _zoomControllers.putIfAbsent(
      index,
      TransformationController.new,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (details) => _zoomFocal[index] = details.localPosition,
      onDoubleTap: () => _togglePageZoom(index),
      // Single tap still toggles the reader chrome; Flutter disambiguates it
      // from the double-tap above (single tap fires only after the double-tap
      // window elapses).
      onTap: _toggleControls,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _lastViewportSize = constraints.biggest;
          return ValueListenableBuilder<Matrix4>(
            valueListenable: controller,
            builder: (context, value, _) =>
                Transform(transform: value, child: child),
          );
        },
      ),
    );
  }

  Matrix4 _zoomClampTranslation(Matrix4 matrix) {
    if (!_isHorizontal) return matrix.clone();
    final size = _lastViewportSize;
    final s = matrix.getMaxScaleOnAxis();
    if (s <= 1.0) return Matrix4.identity();
    if (size == null || size.width <= 0 || size.height <= 0)
      return matrix.clone();
    final t = matrix.getTranslation();
    final dx = t.x.clamp(-(s - 1) * size.width, 0.0).toDouble();
    final dy = t.y.clamp(-(s - 1) * size.height, 0.0).toDouble();
    if (dx == t.x && dy == t.y) return matrix.clone();
    return matrix.clone()..setTranslationRaw(dx, dy, t.z);
  }

  void _maybeResetZoomState() {
    if (_zoomSeenPageCount != _pages.length) {
      _zoomSeenPageCount = _pages.length;
      final oldControllers = _zoomControllers.values.toList();
      _zoomControllers.clear();
      _zoomed.clear();
      _zoomFocal.clear();
      // Dispose outside of the build phase: _maybeResetZoomState runs from
      // _buildZoomablePage while a frame builds, and disposing an attached
      // controller fires its notifier listener during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in oldControllers) {
          controller.dispose();
        }
      });
    }
  }

  void _togglePageZoom(int index) {
    if (!mounted) return;
    final controller = _zoomControllers.putIfAbsent(
      index,
      TransformationController.new,
    );
    // The tap focal is reported in the *viewport* (widget) coordinate space,
    // but the matrix operates on the *child* space. Map it to child
    // coordinates under the current transform so the zoom anchor stays where
    // the finger is when the page is already zoomed.
    final viewportFocal = _zoomFocal[index] ?? Offset.zero;
    final childFocal = MatrixUtils.transformPoint(
      Matrix4.inverted(controller.value),
      viewportFocal,
    );
    final currentScale = controller.value.getMaxScaleOnAxis();
    // Mangayomi-style: toggle between fit and a fixed 2.5x zoom on the tap.
    final target = currentScale > 1.5 ? 1.0 : 2.5;

    setState(() => _zoomed[index] = target > 1.5);

    _zoomAnimController.stop();
    if (_zoomAnimListener != null) {
      _zoomAnimController.removeListener(_zoomAnimListener!);
      _zoomAnimListener = null;
    }
    _zoomAnimController.value = 0.0;

    // Animate scale while keeping the tapped point fixed under the finger.
    void updateZoomMatrix() {
      if (!mounted) return;
      final t = Curves.easeInOutCubic.transform(_zoomAnimController.value);
      final scale = currentScale + (target - currentScale) * t;
      final tx = viewportFocal.dx - scale * childFocal.dx;
      final ty = viewportFocal.dy - scale * childFocal.dy;
      controller.value = Matrix4.identity()
        ..translateByDouble(tx, ty, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
      controller.value = _zoomClampTranslation(controller.value);
    }

    _zoomAnimListener = updateZoomMatrix;
    _zoomAnimController.addListener(updateZoomMatrix);
    _zoomAnimController.forward();
  }

  Future<void> _retryPage(int index, String? localPath) async {
    if (index < 0 || index >= _pages.length) return;

    // Drop any cached (possibly corrupt/partial) download so the retry starts
    // from a fresh request. Local files are re-read from disk instead.
    if (localPath == null) {
      try {
        await AppImageCache.instance.manager.removeFile(_pages[index]);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _pageRetryTokens[index] = (_pageRetryTokens[index] ?? 0) + 1;
    });
  }

  Widget _buildPageError({required int index, String? localPath}) {
    return Container(
      height: 200,
      color: const Color(0xFF1E1E20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(RemixIcons.image_2_line, color: Colors.white54, size: 32),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).readerFailedLoadPage,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _retryPage(index, localPath),
            icon: const Icon(RemixIcons.refresh_line, size: 18),
            label: Text(AppLocalizations.of(context).retry),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // --- LOADING INDICATOR WIDGET ---
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: _hasMoreChapters
          ? Column(
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).readerLoadingNextChapter,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            )
          : Text(
              AppLocalizations.of(context).readerReachedLatestChapter,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
    );
  }
}

class _ReaderProgressTrack extends StatefulWidget {
  const _ReaderProgressTrack({
    required this.session,
    required this.totalPages,
    required this.chapterStart,
    required this.chapterPageCount,
    required this.isHorizontal,
    required this.scrollController,
    required this.pageController,
    required this.onSeek,
  });

  final int session;
  final int totalPages;
  final int chapterStart;
  final int chapterPageCount;
  final bool isHorizontal;
  final ScrollController scrollController;
  final PageController pageController;
  final ValueChanged<int> onSeek;

  @override
  State<_ReaderProgressTrack> createState() => _ReaderProgressTrackState();
}

class _ReaderProgressTrackState extends State<_ReaderProgressTrack> {
  int _currentIndex = 0;
  int _lastSession = -1;

  @override
  void initState() {
    super.initState();
    _lastSession = widget.session;
    widget.scrollController.addListener(_onMoved);
    widget.pageController.addListener(_onMoved);
  }

  @override
  void didUpdateWidget(_ReaderProgressTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An explicit chapter switch resets the thumb to page 1 even when the
    // controller listener never fires (jumpTo to the same offset no-ops).
    if (widget.session != _lastSession) {
      _lastSession = widget.session;
      _currentIndex = widget.chapterStart;
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onMoved);
      widget.scrollController.addListener(_onMoved);
    }
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController.removeListener(_onMoved);
      widget.pageController.addListener(_onMoved);
    }
    if (oldWidget.chapterStart != widget.chapterStart) {
      _currentIndex = widget.chapterStart;
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onMoved);
    widget.pageController.removeListener(_onMoved);
    super.dispose();
  }

  void _onMoved() {
    if (widget.totalPages <= 0) return;
    final int idx;
    if (widget.isHorizontal) {
      if (!widget.pageController.hasClients) return;
      final page = widget.pageController.page;
      if (page == null) return;
      idx = page.round();
    } else {
      if (!widget.scrollController.hasClients) return;
      const perPage = 600.0;
      idx = (widget.scrollController.offset / perPage).floor();
    }
    // Absolute page index within the concatenated list.
    final absolute = idx.clamp(0, widget.totalPages - 1);
    if (absolute != _currentIndex) setState(() => _currentIndex = absolute);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final relativeMax = widget.chapterPageCount > 1
        ? widget.chapterPageCount - 1
        : 0;
    final relative = (_currentIndex - widget.chapterStart).clamp(
      0,
      relativeMax,
    );
    final accent = dark ? Colors.white : Theme.of(context).colorScheme.primary;
    final dim = dark ? Colors.white70 : const Color(0xFF49454F);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DottedPageSlider(
          min: 0,
          max: relativeMax.toDouble(),
          value: relative.toDouble(),
          accent: accent,
          dotColor: dim,
          // Seek live while dragging (updates the reader as the thumb moves).
          onChangeStart: (v) => widget.onSeek(widget.chapterStart + v.round()),
          onChanged: (v) => widget.onSeek(widget.chapterStart + v.round()),
        ),
      ],
    );
  }
}

/// Custom pill slider whose track is a row of evenly spaced dots instead of a
/// solid line. The active span glows with the accent color; the thumb is a
/// solid, larger handle that stays visually distinct from the dot track.
class _DottedPageSlider extends StatefulWidget {
  const _DottedPageSlider({
    required this.min,
    required this.max,
    required this.value,
    required this.accent,
    required this.dotColor,
    required this.onChanged,
    required this.onChangeStart,
  });

  final double min;
  final double max;
  final double value;
  final Color accent;
  final Color dotColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;

  @override
  State<_DottedPageSlider> createState() => _DottedPageSliderState();
}

class _DottedPageSliderState extends State<_DottedPageSlider> {
  double _fraction(double dx, double width) {
    const thumbInset = 15.0;
    final usable = (width - thumbInset * 2).clamp(0.0, double.infinity);
    if (usable <= 0) return 0;
    return ((dx - thumbInset) / usable).clamp(0.0, 1.0);
  }

  double _valueAt(double dx, double width) {
    final frac = _fraction(dx, width);
    return widget.min + frac * (widget.max - widget.min);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const height = 34.0;
        // Single-page chapters can't move; keep the track static.
        final enabled = widget.max > widget.min;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled
              ? (d) {
                  widget.onChangeStart(
                    _valueAt(d.localPosition.dx, constraints.maxWidth),
                  );
                  widget.onChanged(
                    _valueAt(d.localPosition.dx, constraints.maxWidth),
                  );
                }
              : null,
          onHorizontalDragStart: enabled
              ? (d) {
                  widget.onChangeStart(
                    _valueAt(d.localPosition.dx, constraints.maxWidth),
                  );
                }
              : null,
          onHorizontalDragUpdate: enabled
              ? (d) {
                  widget.onChanged(
                    _valueAt(d.localPosition.dx, constraints.maxWidth),
                  );
                }
              : null,
          child: CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _DottedTrackPainter(
              progress: enabled
                  ? ((widget.value - widget.min) / (widget.max - widget.min))
                        .clamp(0.0, 1.0)
                  : 1.0,
              accent: widget.accent,
              dotColor: widget.dotColor,
            ),
          ),
        );
      },
    );
  }
}

class _DottedTrackPainter extends CustomPainter {
  const _DottedTrackPainter({
    required this.progress,
    required this.accent,
    required this.dotColor,
  });

  final double progress;
  final Color accent;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    const thumbRadius = 14.0;
    const dotRadius = 3.0;
    const dotSpacing = 9.0;
    final left = thumbRadius;
    final right = size.width - thumbRadius;
    final cy = size.height / 2;
    final length = right - left;
    if (length <= 0) return;

    final count = (length / dotSpacing).floor().clamp(2, 256);
    final spacing = length / (count - 1);
    final edgeX = left + length * progress;

    for (var i = 0; i < count; i++) {
      final dx = left + i * spacing;
      final active = dx <= edgeX;
      final dotPaint = Paint()
        ..color = active ? accent : dotColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dx, cy), dotRadius, dotPaint);
    }

    // Distinct, solid thumb that pops against the dot track.
    canvas.drawCircle(
      Offset(edgeX, cy),
      thumbRadius,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(edgeX, cy),
      thumbRadius - 1.5,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _DottedTrackPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.dotColor != dotColor;
}

class _ChapterDownloadTask {
  bool cancelled = false;
  int done = 0;
  int total = 0;

  void cancel() => cancelled = true;
}

// --- CHAPTER TRANSITION TOAST WIDGET ---
class _ChapterPageToast extends StatelessWidget {
  final String label;

  const _ChapterPageToast({required this.label});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF1C1B1F);
    final accent = dark
        ? Colors.white70
        : Theme.of(context).colorScheme.primary;
    final border = dark ? Colors.white24 : Colors.black12;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: dark ? const Color(0xE6202020) : const Color(0xFAFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.4 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(RemixIcons.book_2_line, size: 15, color: accent),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
