import 'package:remixicon/remixicon.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/widgets/safe_image.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/source_cache.dart';
import '../../../core/widgets/ios/ios_press.dart';
import '../../../core/widgets/ios/ios_sheet.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/features/history/providers/history_provider.dart';
import 'package:yomou/features/library/providers/downloads_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
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
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  PageController _pageController = PageController();
  final List<String> _pages = [];
  final List<int> _loadedChapterIndices = [];

  int _currentChapterIndex = 0;
  bool _isLoadingNextChapter = false;
  bool _isLoadingPreviousChapter = false;
  int _lastPageIndex = -1;
  bool _hasMoreChapters = true;
  bool _showControls = true;

  // Chapter transition toast (Kotatsu-style chapter/page pill).
  double _toastOpacity = 0;
  int _toastShownChapter = -1;
  Timer? _toastTimer;
  Timer? _scrollStopTimer;
  bool _isSaving = false;
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
  bool _autoScroll = false;
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
  }

  int get _currentPageIndex {
    if (_pages.isEmpty) return 0;
    if (_isHorizontal && _pageController.hasClients) {
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

  // Horizontal strip of chapter page thumbnails shown above the bottom capsule
  // while the controls are visible. Honors the "Show pages thumbnails" setting.
  Widget _buildPageThumbnailStrip() {
    if (!ref.watch(appearanceSettingsProvider).showPagesThumbnails) {
      return const SizedBox.shrink();
    }
    final pages = _pages;
    if (pages.isEmpty) return const SizedBox.shrink();
    final current = _currentPageIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = Theme.of(context).colorScheme.primary;

    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xE6212124)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final active = index == current;
          return GestureDetector(
            onTap: () => _jumpToPage(index),
            child: Container(
              width: 36,
              height: 64,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: active
                      ? activeColor
                      : isDark
                          ? Colors.white24
                          : Colors.black26,
                  width: active ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _pageThumb(pages[index]),
                    Positioned(
                      bottom: 2,
                      right: 4,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: isDark ? Colors.black87 : Colors.white70,
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pageThumb(String ref) {
    if (ref.startsWith('http')) {
      return SafeNetworkImage(
        imageUrl: ref,
        fit: BoxFit.cover,
        placeholder: (context, url) => const ColoredBox(
          color: Colors.black26,
        ),
        errorWidget: (context, url, error) => const ColoredBox(
          color: Colors.black26,
        ),
      );
    }
    return SafeFileImage(
      file: File(ref),
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => const ColoredBox(
        color: Colors.black26,
      ),
    );
  }

  Widget _buildProgressTrack() {
    return _ReaderProgressTrack(
      totalPages: _pages.length,
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
    setState(() {
      _readingMode = mode;
      _autoScroll = false;
    });
    _saveReaderMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToPage(approxPage);
    });
  }

  // --- SETTINGS ACTIONS ---

  void _toggleTwoPages(bool value) {
    if (value == _useTwoPagesLayout) return;
    final lastApprox = _currentPageIndex;
    setState(() {
      _useTwoPagesLayout = value;
      _pageController.dispose();
      _pageController = PageController(viewportFraction: value ? 0.5 : 1.0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  void _toggleAutoScroll(bool value) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (!value) {
      setState(() => _autoScroll = false);
      return;
    }
    // Auto-scroll only makes sense in a continuous (vertical) reading mode.
    if (_isHorizontal) {
      _setReadingMode(ReadingMode.webtoon);
    }
    setState(() => _autoScroll = true);
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 2) {
        _autoScrollTimer?.cancel();
        _autoScrollTimer = null;
        setState(() => _autoScroll = false);
        return;
      }
      _scrollController.jumpTo(position.pixels + 2);
    });
  }

  void _showColorCorrectionDialog() {
    Navigator.pop(context);
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
    });
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          controller: _trayExtentController,
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, sheetController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                final dark = Theme.of(context).brightness == Brightness.dark;
                _trayOpen = true;
                _trayRefresh = () => setSheetState(() {});
                if (!didJump) {
                  _jumpToCurrentInSheet(sheetController, currentIndex, 72, 0);
                  didJump = true;
                }

                return Column(
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
                    _buildChapterSheetHeader(
                      listView,
                      setSheetState,
                      _jumpToCurrentInSheetFor(sheetController, currentIndex),
                    ),
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
                        'download' => _buildDownloadsView(sheetController),
                        _ => _buildChapterListView(
                          sheetController,
                          currentIndex,
                        ),
                      },
                    ),
                  ],
                );
              },
            );
          },
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

  void Function() _jumpToCurrentInSheetFor(
    ScrollController controller,
    int index,
  ) {
    return () {
      if (!controller.hasClients) return;
      final viewDim = controller.position.viewportDimension;
      final target = (index * 72 - viewDim / 2).clamp(
        0.0,
        controller.position.maxScrollExtent,
      );
      controller.jumpTo(target);
    };
  }

  Widget _buildChapterSheetHeader(
    String listView,
    StateSetter setSheetState,
    VoidCallback scrollToCurrent,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = dark ? Colors.white : const Color(0xFF1C1B1F);
    final selectedCount = _selectedIds.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                key: const ValueKey('viewToggleHeader'),
                children: [
                  _buildViewToggle(
                    icon: RemixIcons.list_unordered,
                    selected: listView == 'list',
                    onTap: () => setSheetState(() => listView = 'list'),
                  ),
                  const SizedBox(width: 10),
                  _buildViewToggle(
                    icon: RemixIcons.grid_line,
                    selected: listView == 'grid',
                    onTap: () => setSheetState(() => listView = 'grid'),
                  ),
                  const SizedBox(width: 10),
                  _buildViewToggle(
                    icon: RemixIcons.bookmark_3_line,
                    selected: listView == 'bookmark',
                    onTap: () => setSheetState(() => listView = 'bookmark'),
                  ),
                  const SizedBox(width: 10),
                  _buildViewToggle(
                    icon: RemixIcons.download_cloud_line,
                    selected: listView == 'download',
                    onTap: () => setSheetState(() => listView = 'download'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: AppLocalizations.of(context).readerCurrentChapter,
                    icon: Icon(
                      RemixIcons.crosshair_line,
                      color: dark ? Colors.white54 : Colors.black54,
                    ),
                    onPressed: scrollToCurrent,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildViewToggle({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: selected
              ? dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected
              ? dark
                    ? Colors.black
                    : Colors.white
              : dark
              ? Colors.white70
              : const Color(0xFF49454F),
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
        final downloaded = _downloadedChapters.contains(chapter.id);
        final active = _activeDownloads[chapter.id];

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
              : isCurrent
              ? (dark ? Colors.white10 : Colors.black12)
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
                        : isCurrent
                        ? (dark
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface)
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
            style: TextStyle(
              color: dark ? Colors.white38 : Colors.black38,
              fontSize: 11,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectionMode && downloaded)
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
              else if (active != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: active.total > 0
                          ? (active.done / active.total).clamp(0.0, 1.0)
                          : null,
                      strokeWidth: 2.5,
                      color: dark
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      backgroundColor: dark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                )
              else if (!_selectionMode)
                _buildChapterDownloadControl(chapter),
            ],
          ),
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

  Widget _buildChapterDownloadControl(Chapter chapter) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = _activeDownloads[chapter.id];
    if (active != null) {
      final pct = active.total == 0
          ? 0
          : (active.done / active.total * 100).round();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$pct%',
            style: TextStyle(
              color: dark ? Colors.white54 : Colors.black54,
              fontSize: 11,
            ),
          ),
          IconButton(
            icon: Icon(
              RemixIcons.close_line,
              color: dark ? Colors.white54 : Colors.black54,
              size: 18,
            ),
            tooltip: AppLocalizations.of(context).readerCancelDownload,
            onPressed: active.cancel,
          ),
        ],
      );
    }
    final downloaded = _downloadedChapters.contains(chapter.id);
    return IconButton(
      tooltip: downloaded
          ? AppLocalizations.of(context).removeDownloadTooltip
          : AppLocalizations.of(context).readerDownloadChapter,
      icon: Icon(
        downloaded ? RemixIcons.cloud_fill : RemixIcons.download_cloud_line,
        color: downloaded
            ? _activeGreen
            : (dark ? Colors.white38 : Colors.black38),
        size: 22,
      ),
      onPressed: () => _toggleChapterDownload(chapter),
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
    final group = chapter.scanlator.isNotEmpty ? chapter.scanlator : '';
    return [num, date, group].where((p) => p.isNotEmpty).join(' • ');
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
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.readerMoreSheetTitle,
                              style: TextStyle(
                                color: dark
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xFF232328)
                                    : Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                RemixIcons.close_line,
                                color: dark
                                    ? Colors.white70
                                    : const Color(0xFF49454F),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Quick actions.
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickActionTile(
                              icon: RemixIcons.download_line,
                              label: l.readerSavePage,
                              onTap: _saveCurrentPage,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickActionTile(
                              icon: _isCurrentPageBookmarked
                                  ? RemixIcons.bookmark_2_fill
                                  : RemixIcons.bookmark_3_line,
                              label: _isCurrentPageBookmarked
                                  ? l.readerRemoveBookmark
                                  : l.readerAddBookmark,
                              accent: _isCurrentPageBookmarked,
                              onTap: () async {
                                await _toggleBookmark();
                                if (context.mounted) setSheetState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      _buildSectionHeader(l.readerSectionReadingMode),
                      const SizedBox(height: 10),
                      _buildReadModeSelector(
                        afterChange: () => setSheetState(() {}),
                      ),
                      const SizedBox(height: 22),

                      _buildSectionHeader(l.readerSectionOptions),
                      const SizedBox(height: 10),
                      _buildSettingsCard(
                        children: [
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            activeTrackColor: _activeGreen,
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: dark
                                ? Colors.white12
                                : Colors.black12,
                            inactiveThumbColor: dark
                                ? Colors.white54
                                : Colors.black54,
                            dense: true,
                            title: _tileText(l.readerTwoPagesLandscape),
                            subtitle: _tileSubtext(l.readerExperimental),
                            value: _useTwoPagesLayout,
                            onChanged: (value) {
                              _toggleTwoPages(value);
                              setSheetState(() {});
                            },
                          ),
                          _cardDivider(),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            activeTrackColor: _activeGreen,
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: dark
                                ? Colors.white12
                                : Colors.black12,
                            inactiveThumbColor: dark
                                ? Colors.white54
                                : Colors.black54,
                            dense: true,
                            title: _tileText(l.readerRotateScreen),
                            subtitle: _tileSubtext(
                              _rotateScreen
                                  ? l.readerLandscapeOrientation
                                  : l.readerRotateToLandscape,
                            ),
                            value: _rotateScreen,
                            onChanged: (value) {
                              _toggleRotateScreen(value);
                              setSheetState(() {});
                            },
                          ),
                          _cardDivider(),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            activeTrackColor: _activeGreen,
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: dark
                                ? Colors.white12
                                : Colors.black12,
                            inactiveThumbColor: dark
                                ? Colors.white54
                                : Colors.black54,
                            dense: true,
                            title: _tileText(l.readerAutoScroll),
                            subtitle: _tileSubtext(l.readerContinuousScroll),
                            value: _autoScroll,
                            onChanged: (value) {
                              _toggleAutoScroll(value);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      _buildSectionHeader(l.readerSectionTools),
                      const SizedBox(height: 10),
                      _buildSettingsCard(
                        children: [
                          _iconTile(
                            icon: RemixIcons.palette_line,
                            title: l.colorCorrection,
                            subtitle: l.readerBrightnessContrastSepia,
                            chevron: true,
                            onTap: _showColorCorrectionDialog,
                          ),
                          _cardDivider(),
                          _iconTile(
                            icon: RemixIcons.settings_3_line,
                            title: l.settings,
                            subtitle: l.readerAppPreferences,
                            chevron: true,
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

  Widget _buildQuickActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final bgColor = accent
        ? primary.withValues(alpha: 0.18)
        : dark
        ? const Color(0xFF232328)
        : Colors.white;
    final fgColor = accent
        ? primary
        : dark
        ? Colors.white
        : const Color(0xFF1C1B1F);
    return AppPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent
                ? _activeGreen.withValues(alpha: 0.4)
                : dark
                ? Colors.white10
                : Colors.black12,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: fgColor, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadModeSelector({VoidCallback? afterChange}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    const modes = [
      (ReadingMode.standard, RemixIcons.book_open_line, ''),
      (ReadingMode.rightToLeft, RemixIcons.book_open_line, ''),
      (ReadingMode.vertical, RemixIcons.smartphone_line, ''),
      (ReadingMode.webtoon, RemixIcons.list_view, ''),
    ];
    final labels = <ReadingMode, String>{
      ReadingMode.standard: l.readerModeStandard,
      ReadingMode.rightToLeft: l.readerModeRTL,
      ReadingMode.vertical: l.readerModeVertical,
      ReadingMode.webtoon: l.readerModeWebtoon,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: modes.map((mode) {
            final isSelected = _readingMode == mode.$1;
            return GestureDetector(
              onTap: () {
                _setReadingMode(mode.$1);
                afterChange?.call();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected
                      ? null
                      : dark
                      ? const Color(0xFF232328)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : dark
                        ? Colors.white10
                        : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      mode.$2,
                      color: isSelected
                          ? Colors.white
                          : dark
                          ? Colors.white70
                          : const Color(0xFF49454F),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        labels[mode.$1] ?? mode.$1.name,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : dark
                              ? Colors.white70
                              : const Color(0xFF49454F),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        RemixIcons.checkbox_circle_fill,
                        color: Colors.white,
                        size: 16,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Text(
          AppLocalizations.of(context).readerRememberedNote,
          style: TextStyle(
            color: dark ? Colors.white38 : Colors.black38,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // Active/current accent — resolved from the active color scheme preset.
  Color get _activeGreen => Theme.of(context).colorScheme.primary;

  Widget _buildSectionHeader(String text) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: dark ? Colors.white54 : Colors.black54,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF232328) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _cardDivider() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      color: dark ? const Color(0xFF3A3A40) : Colors.black12,
    );
  }

  Widget _tileText(String text) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        color: dark ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
      ),
    );
  }

  Widget _tileSubtext(String text) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        color: dark ? Colors.white38 : Colors.black38,
        fontSize: 12,
      ),
    );
  }

  Widget _iconTile({
    required IconData icon,
    required String title,
    String? subtitle,
    bool chevron = false,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2F2F36) : Colors.black12,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: dark ? Colors.white70 : const Color(0xFF49454F),
          size: 20,
        ),
      ),
      title: _tileText(title),
      subtitle: subtitle == null ? null : _tileSubtext(subtitle),
      trailing: chevron
          ? Icon(
              RemixIcons.arrow_right_s_line,
              color: dark ? Colors.white38 : Colors.black38,
            )
          : null,
      onTap: onTap,
    );
  }

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
        if (mounted) _maybeShowToast();
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
    final frontChapter =
        _pagesChapters.isNotEmpty ? _pagesChapters.first : _currentChapterIndex;
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

  void _handleScrollTicker() {
    final pos = _scrollController.position;
    // Near the top -> load the previous chapter (backward symmetry with the
    // next-chapter load at the bottom).
    if (pos.pixels <= 800 && !_isLoadingPreviousChapter) {
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

  void _toggleChapterDownload(Chapter chapter) {
    if (_activeDownloads.containsKey(chapter.id)) {
      _activeDownloads[chapter.id]?.cancel();
      return;
    }
    if (_downloadedChapters.contains(chapter.id)) {
      _confirmRemoveDownload(chapter.id, chapter.title);
      return;
    }
    _downloadChapter(chapter);
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
      0.9,
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
    final currentChapter = widget.allChapters[_currentChapterIndex];
    final chLabel = currentChapter.chapterNumber.isNotEmpty
        ? currentChapter.chapterNumber
        : '${_currentChapterIndex + 1}';
    final activeSource = ref.watch(currentSourceProvider);
    final Map<String, String>? activeHeaders = activeSource.headers;

    final readerSource = widget.sourceId != null
        ? getSourceBySourceId(widget.sourceId!)
        : null;
    final headers = readerSource?.headers ?? activeHeaders;

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

              // --- TOP APP BAR OVERLAY ---
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                top: _showControls ? 0 : -100,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 4,
                    bottom: 12,
                    left: 8,
                    right: 16,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          RemixIcons.arrow_left_line,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          await _saveCascadingReadProgress();
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.mangaTitle ?? currentChapter.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
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
                              style: const TextStyle(
                                color: Colors.white70,
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

              // --- PAGE THUMBNAIL STRIP (opt-in) ---
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                bottom: _showControls ? 92 : -150,
                left: 16,
                right: 16,
                child: _buildPageThumbnailStrip(),
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
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (index) {
        _maybeShowToast();
        // Swiping back into page 0 -> load the previous chapter so the pager
        // can keep going backward across the chapter boundary.
        if (_lastPageIndex > 0 && index == 0) {
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
        placeholder: (context, url) => Container(
          height: 500,
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white24),
          ),
        ),
        errorWidget: (context, url, error) => _buildPageError(index: index),
      );
    }
    return _buildZoomablePage(
      index: index,
      child: _applyColorFilter(image),
    );
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
    final controller =
        _zoomControllers.putIfAbsent(index, TransformationController.new);
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
    if (size == null || size.width <= 0 || size.height <= 0) return matrix.clone();
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
        await DefaultCacheManager().removeFile(_pages[index]);
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
    required this.totalPages,
    required this.isHorizontal,
    required this.scrollController,
    required this.pageController,
    required this.onSeek,
  });

  final int totalPages;
  final bool isHorizontal;
  final ScrollController scrollController;
  final PageController pageController;
  final ValueChanged<int> onSeek;

  @override
  State<_ReaderProgressTrack> createState() => _ReaderProgressTrackState();
}

class _ReaderProgressTrackState extends State<_ReaderProgressTrack> {
  // Cap the dots so a chapter with hundreds of pages doesn't turn the track
  // into a solid line; most chapters (<= _maxDots pages) get one dot per page.
  static const int _maxDots = 30;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onMoved);
    widget.pageController.addListener(_onMoved);
  }

  @override
  void didUpdateWidget(_ReaderProgressTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onMoved);
      widget.scrollController.addListener(_onMoved);
    }
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController.removeListener(_onMoved);
      widget.pageController.addListener(_onMoved);
    }
    if (oldWidget.totalPages != widget.totalPages && widget.totalPages > 0) {
      _currentIndex = _currentIndex.clamp(0, widget.totalPages - 1);
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
      idx = page.round().clamp(0, widget.totalPages - 1);
    } else {
      if (!widget.scrollController.hasClients) return;
      const perPage = 600.0;
      idx = (widget.scrollController.offset / perPage).floor().clamp(
        0,
        widget.totalPages - 1,
      );
    }
    if (idx != _currentIndex) setState(() => _currentIndex = idx);
  }

  void _seek(double fraction) {
    if (widget.totalPages <= 0) return;
    final clamped = fraction.clamp(0.0, 1.0);
    final page = (clamped * (widget.totalPages - 1)).round();
    widget.onSeek(page);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final total = widget.totalPages <= 0 ? 1 : widget.totalPages;
    final current = (_currentIndex + 1).clamp(1, total);
    final progress = total > 1 ? (current - 1) / (total - 1) : 0.0;
    final dotCount = total.clamp(1, _maxDots);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _seek(details.localPosition.dx / constraints.maxWidth),
          onHorizontalDragUpdate: (details) =>
              _seek(details.localPosition.dx / constraints.maxWidth),
          child: CustomPaint(
            size: Size(constraints.maxWidth, 36),
            painter: _DottedProgressPainter(
              progress: progress,
              dotCount: dotCount,
              activeDotColor: dark
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              inactiveDotColor: dark ? Colors.white24 : Colors.black26,
            ),
          ),
        );
      },
    );
  }
}

class _DottedProgressPainter extends CustomPainter {
  final double progress;
  final int dotCount;
  final Color activeDotColor;
  final Color inactiveDotColor;

  _DottedProgressPainter({
    required this.progress,
    required this.dotCount,
    this.activeDotColor = Colors.white,
    this.inactiveDotColor = Colors.white24,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    const activeRadius = 2.2;
    const currentRadius = 3.8;
    const baseGap = 5.0;

    final occupied = dotCount * activeRadius * 2 + (dotCount - 1) * baseGap;
    final spacing = occupied >= size.width && dotCount > 1
        ? (size.width - dotCount * activeRadius * 2) / (dotCount - 1)
        : baseGap;
    final totalWidth = dotCount * activeRadius * 2 + (dotCount - 1) * spacing;
    final startX = (size.width - totalWidth) / 2;

    final currentIndex = dotCount > 1
        ? (progress * (dotCount - 1)).round().clamp(0, dotCount - 1)
        : 0;

    final activePaint = Paint()..color = activeDotColor;
    final inactivePaint = Paint()..color = inactiveDotColor;

    for (var i = 0; i < dotCount; i++) {
      final x = startX + activeRadius + i * (activeRadius * 2 + spacing);
      final isCurrent = i == currentIndex;
      final isActive = i <= currentIndex;

      canvas.drawCircle(
        Offset(x, centerY),
        isCurrent ? currentRadius : activeRadius,
        isActive ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DottedProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.dotCount != dotCount ||
        oldDelegate.activeDotColor != activeDotColor ||
        oldDelegate.inactiveDotColor != inactiveDotColor;
  }
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
