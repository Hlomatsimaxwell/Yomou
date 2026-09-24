import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yomou/features/suggestions/screens/suggestions_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/library/screens/favorites_screen.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/explore/screens/explore_screen.dart';
import 'package:yomou/features/feed/screens/feed_screen.dart';
import 'package:yomou/features/feed/providers/updates_provider.dart';
import 'package:yomou/core/theme/layout.dart';
import 'package:yomou/features/reader/screens/reader_screen.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/notifications/background_tasks.dart';
import 'package:yomou/core/notifications/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomou/data/models/chapter.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/core/security/app_lock.dart';
import 'package:yomou/core/security/pin_lock_screen.dart';
import 'package:yomou/core/providers/incognito_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:remixicon/remixicon.dart';

/// Navigator handle used to route notification taps (deep link) after the
/// widget tree is built.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Fix the Database Crash for Linux/Windows/MacOS
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final mobile = Platform.isAndroid || Platform.isIOS;
  if (mobile) {
    try {
      await NotificationService.instance.init(
        onSelect: _handleNotificationResponse,
      );
    } catch (_) {
      // Notification init failing (e.g. missing icon resource on some
      // releases) must never block the app from starting.
    }
    if (await NotificationService.instance.isEnabled()) {
      try {
        await registerUpdateCheckTask();
      } catch (_) {}
    }
  }

  // 2. Run the app.
  runApp(const ProviderScope(child: YomouApp()));

  // 3. If a notification launched the app, open the feed once we have a frame.
  if (mobile) {
    final payload = await NotificationService.instance.launchPayload();
    if (payload != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: payload,
          ),
        ),
      );
    }
  }
}

/// Routes taps and action button presses on notifications:
/// - tap on the group summary / feed payload → updates feed,
/// - tap on an individual "new chapter" alert → the series page (only when the
///   series actually exists in the library; preview payloads are skipped).
void _handleNotificationResponse(NotificationResponse response) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;
  if (response.actionId != null) return;
  if (response.payload == NotificationService.payloadFeed) {
    navigator.push(MaterialPageRoute(builder: (_) => const FeedScreen()));
    return;
  }
  final target = NotificationService.decodeTarget(response.payload);
  if (target == null || target.mangaId.isEmpty) return;
  // Suggestions aren't in the library yet, so they open straight into the
  // detail page instead of being resolved through the database first.
  if (target.kind == 'suggestion') {
    _openMangaDetail(navigator, target);
    return;
  }
  unawaited(_openSeriesFromNotification(navigator, target));
}

void _openMangaDetail(NavigatorState navigator, NotificationTarget target) {
  // Skip targets missing a real source (e.g. the preview suggestion).
  if (target.sourceId == null) return;
  if (!navigator.mounted) return;
  navigator.push(
    MaterialPageRoute(
      builder: (_) => MangaDetailScreen(
        mangaId: target.mangaId,
        title: target.title,
        imageUrl: target.coverUrl,
        sourceId: target.sourceId,
      ),
    ),
  );
}

Future<void> _openSeriesFromNotification(
  NavigatorState navigator,
  NotificationTarget target,
) async {
  final row = await DatabaseHelper.instance.getManga(target.mangaId);
  if (row == null || !navigator.mounted) return;
  _openMangaDetail(navigator, target);
}

class YomouApp extends ConsumerWidget {
  const YomouApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    final language = ref.watch(appearanceSettingsProvider).language;

    return MaterialApp(
      title: 'Yomou',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      themeMode: theme.mode,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      locale: language == 'system' ? null : Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => Stack(
        children: [
          child!,
          // Sits above every route so the PIN lock covers the whole app
          // (reader, detail views, settings) whenever it's active.
          Consumer(
            builder: (context, ref, _) {
              final lock = ref.watch(appLockProvider);
              return lock.locked
                  ? const PinLockScreen()
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static const _tabNames = [
    'History',
    'Favorites',
    'Suggestions',
    'Explore',
    'Updates',
  ];
  static const _lastUsedTabKey = 'appearance.lastUsedTab';

  int _currentIndex = 0;
  bool _isContinuing = false;
  bool _wasBackgrounded = false;

  // Tabs are built lazily: a tab is only constructed the first time it is
  // visited, then kept alive by the IndexedStack. This avoids paying for every
  // tab's network fetches (e.g. multi-source suggestions) at app launch.
  final Set<int> _visitedTabs = {0};

  // Scroll-hide state for the nav bar + FAB (used when pinNavUiOnScroll is off).
  bool _navHiddenOnScroll = false;

  // Double-back-to-exit tracking (only active when exitConfirmation is on).
  DateTime? _lastBackPress;

  final List<Widget> _screens = [
    const HistoryScreen(),
    const FavoritesScreen(),
    const SuggestionsScreen(),
    const ExploreScreen(),
    const FeedScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTab());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-locks the app (if a PIN is set and "Protect the app" is on) whenever
  // Yomou returns from the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_wasBackgrounded) {
        _wasBackgrounded = false;
        final lock = ref.read(appLockProvider);
        final protect = ref.read(appearanceSettingsProvider).protectApp;
        if (!lock.locked && lock.hasPin && protect) {
          ref.read(appLockProvider.notifier).setLocked(true);
        }
      }
    }
  }

  // Resolves the starting tab from the "Default tab" appearance setting.
  // Reads prefs directly (rather than the provider) so this runs even before
  // the async settings load completes.
  Future<void> _initTab() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = ref.read(appearanceSettingsProvider);
    final enabled = _enabledTabIndices(settings);
    final defaultTab = prefs.getString('appearance.defaultTab') ?? 'Last used';

    int idx;
    if (defaultTab == 'Last used') {
      idx = prefs.getInt(_lastUsedTabKey) ?? 0;
    } else {
      idx = _tabNames.indexOf(defaultTab);
      if (idx < 0) idx = 0;
    }
    if (!enabled.contains(idx)) idx = enabled.first;
    if (mounted && idx != _currentIndex) setState(() => _currentIndex = idx);
  }

  Future<void> _persistLastUsed(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastUsedTabKey, index);
  }

  // Which bottom-nav tabs are shown, honoring the "Main screen sections"
  // appearance setting. Falls back to History if none are enabled.
  List<int> _enabledTabIndices(AppearanceSettings settings) {
    final enabled = <int>[];
    for (var i = 0; i < _tabNames.length; i++) {
      if (settings.mainScreenSections[_tabNames[i]] ?? true) enabled.add(i);
    }
    return enabled.isEmpty ? const [0] : enabled;
  }

  @override
  Widget build(BuildContext context) {
    final updatesCount = ref.watch(updatesCountProvider);
    final accent = ref.watch(accentProvider);
    final settings = ref.watch(appearanceSettingsProvider);
    // Keep the global incognito flag loaded from the very first frame so the
    // DB/search layers never write during an incognito session.
    ref.watch(incognitoProvider);

    final enabledTabs = _enabledTabIndices(settings);
    // If the current tab got disabled, jump to the first enabled one.
    if (!enabledTabs.contains(_currentIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !enabledTabs.contains(_currentIndex)) {
          setState(() => _currentIndex = enabledTabs.first);
        }
      });
    }

    final showFab =
        settings.showFloatingContinueButton &&
        enabledTabs.contains(0) &&
        _currentIndex == 0;
    _visitedTabs.add(_currentIndex);

    return PopScope(
      canPop: !settings.exitConfirmation,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        final recent =
            _lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2);
        if (recent) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.pressBackToExit),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: Stack(
            children: [
              // Main body content — placed first so lists/grids extend
              // edge-to-edge and scroll underneath the floating bar.
              Positioned.fill(
                child: IndexedStack(
                  index: _currentIndex,
                  children: List.generate(
                    _screens.length,
                    (i) => _visitedTabs.contains(i)
                        ? _screens[i]
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              // Bottom navigation overlay (floating or solid) + the conditional
              // Continue FAB (History tab only, opt-in). The FAB sits beside the
              // floating pill in one bottom-centered row; with the solid bar it
              // stays docked above it. Everything hides together on scroll-down
              // unless pinNavUiOnScroll is on.
              AnimatedSlide(
                offset: Offset(0, _navHiddenOnScroll ? 1.5 : 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    if (settings.useFloatingNavBar)
                      _buildFloatingNav(
                        context,
                        updatesCount,
                        accent,
                        settings,
                        enabledTabs,
                        showFab: showFab,
                      )
                    else ...[
                      _buildSolidNav(
                        context, updatesCount, accent, settings, enabledTabs),
                      Positioned(
                        right: 20,
                        bottom: bottomBarTopEdge(context) + 12,
                        child: showFab
                            ? KeyedSubtree(
                                key: const ValueKey('continue-fab'),
                                child: _buildContinueFab(accent),
                              )
                            : const SizedBox(
                                key: ValueKey('fab-hidden'),
                                width: 60,
                                height: 60,
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Hides the nav bar + FAB on downward scroll unless pinNavUiOnScroll is on.
  bool _onScrollNotification(ScrollNotification notification) {
    final pinned = ref.read(appearanceSettingsProvider).pinNavUiOnScroll;
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final pixels = notification.metrics.pixels;
      final scrollingDown = delta > 0;
      final enoughScrolled = pixels > 40;

      if (!pinned) {
        if (scrollingDown && enoughScrolled && !_navHiddenOnScroll) {
          setState(() => _navHiddenOnScroll = true);
        } else if (!scrollingDown && _navHiddenOnScroll) {
          setState(() => _navHiddenOnScroll = false);
        }
      }
    }
    return false;
  }

  Widget _buildFloatingNav(
    BuildContext context,
    int updatesCount,
    Color accent,
    AppearanceSettings settings,
    List<int> enabledTabs, {
    required bool showFab,
  }) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            left: kBottomBarSideMargin,
            right: kBottomBarSideMargin,
            bottom: kBottomBarBottomMargin,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: showFab
                      ? Alignment.centerLeft
                      : Alignment.center,
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: kFloatingPillMaxWidth),
                    child: _buildFloatingPill(context, updatesCount, accent, settings, enabledTabs),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: showFab
                      ? KeyedSubtree(
                          key: const ValueKey('continue-fab'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              _buildContinueFab(accent),
                            ],
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('fab-hidden'),
                          width: 0,
                          height: kBottomBarHeight,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingPill(
    BuildContext context,
    int updatesCount,
    Color accent,
    AppearanceSettings settings,
    List<int> enabledTabs,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: kBottomBarHeight,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0x661C1C1E)
                : Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0x332C2C30)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: _buildNavRow(updatesCount, accent, settings, enabledTabs),
        ),
      ),
    );
  }

  Widget _buildSolidNav(
    BuildContext context,
    int updatesCount,
    Color accent,
    AppearanceSettings settings,
    List<int> enabledTabs,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        height: kBottomBarHeight + MediaQuery.paddingOf(context).bottom,
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1C1C1E)
              : Colors.white,
        child: _buildNavRow(updatesCount, accent, settings, enabledTabs),
      ),
    );
  }

  Widget _buildNavRow(
    int updatesCount,
    Color accent,
    AppearanceSettings settings,
    List<int> enabledTabs,
  ) {
    // Items size to their content; spacing stretches to fill whatever the pill
    // gives us, so the row adapts as the width changes (e.g. FAB visibility).
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final index in enabledTabs)
          _buildNavItem(index, updatesCount, accent, settings),
      ],
    );
  }

  // Updates icon with its unread-count badge.
  Widget _buildUpdatesIcon(
    int badgeCount,
    IconData icon,
    Color color,
    Color accent, {
    double size = 22,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Icon(icon, size: size, color: color),
        if (badgeCount > 0)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  color:
                      ThemeData.estimateBrightnessForColor(accent) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _navLabel(BuildContext context, int index) {
    final l = AppLocalizations.of(context);
    return switch (index) {
      0 => l.history,
      1 => l.favorites,
      2 => l.suggestions,
      3 => l.explore,
      _ => l.updates,
    };
  }

  // Icon + label slot (friend's iOS-style bar, Remix icons). Every tab shows
  // icon + small label; the active tab swaps to the fill glyph, tints with the
  // accent and scales up 5%. Each item is Expanded so the 5 tabs share the
  // available width evenly; the label is wrapped in FittedBox so it scales down
  // instead of overflowing on narrow screens.
  Widget _buildNavItem(
    int index,
    int updatesCount,
    Color accent,
    AppearanceSettings settings,
  ) {
    final active = _currentIndex == index;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = active
        ? accent
        : dark
        ? const Color(0xFF8E8E93)
        : const Color(0xFF49454F);
    final showLabels = settings.showNavLabels;

    final (IconData line, IconData fill) = switch (index) {
      0 => (RemixIcons.history_line, RemixIcons.history_fill),
      1 => (RemixIcons.heart_3_line, RemixIcons.heart_3_fill),
      2 => (RemixIcons.lightbulb_line, RemixIcons.lightbulb_fill),
      3 => (RemixIcons.compass_3_line, RemixIcons.compass_3_fill),
      _ => (RemixIcons.rss_line, RemixIcons.rss_fill),
    };

    return SizedBox(
      height: kBottomBarHeight - 16,
      child: InkWell(
        onTap: () {
          setState(() => _currentIndex = index);
          _persistLastUsed(index);
        },
        borderRadius: BorderRadius.circular(20),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.26
                          : 0.16,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: active ? 14 : 6,
              vertical: active ? 8 : 4,
            ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: index == 4
                    ? KeyedSubtree(
                        key: ValueKey<bool>(active),
                        child: _buildUpdatesIcon(
                          updatesCount,
                          active ? fill : line,
                          color,
                          accent,
                        ),
                      )
                    : Icon(
                        active ? fill : line,
                        key: ValueKey<bool>(active),
                        size: 22,
                        color: color,
                      ),
              ),
              if (showLabels && active) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _navLabel(context, index),
                      softWrap: false,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildContinueFab(Color accent) {
    return GestureDetector(
      onTap: _isContinuing ? null : _continueReading,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isContinuing ? const Color(0xFF2A2A2E) : accent,
          border: _isContinuing
              ? Border.all(color: const Color(0xFF3A3A40))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _isContinuing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Icon(
                  RemixIcons.book_open_line,
                  color:
                      ThemeData.estimateBrightnessForColor(accent) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  size: 30,
                ),
        ),
      ),
    );
  }

  Future<void> _continueReading() async {
    if (_isContinuing) return;
    setState(() => _isContinuing = true);

    try {
      final rows = await DatabaseHelper.instance.getHistory();
      if (rows.isEmpty) {
        if (mounted) {
          final l = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.noReadingHistoryYet),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final last = rows.first;
      final mangaId = last['mangaId'] as String;
      final sourceId = last['sourceId'] as String?;
      final title = last['title'] as String;
      final coverUrl = last['coverUrl'] as String?;
      final lastReadChapter =
          (last['lastReadChapter'] as num?)?.toDouble() ?? 0;
      final lastReadPage = (last['lastReadPage'] as int?) ?? 0;
      final totalChaptersDb = (last['totalChapters'] as int?) ?? 0;

      final source = sourceId != null
          ? getSourceBySourceId(sourceId) ?? ref.read(currentSourceProvider)
          : ref.read(currentSourceProvider);
      if (source == null) {
        if (mounted) {
          final l = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.noSourceAvailable),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final chapters = await SourceCache.chapters(
        sourceId: source.id,
        mangaId: mangaId,
        fetch: () => source.getChapters(mangaId),
      );
      if (chapters.isEmpty) {
        if (mounted) {
          final l = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.noChaptersAvailable),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Chapters are used oldest-first so reading advances forward through
      // the series; resume at the first unread chapter (same as the tray).
      final sorted = [...chapters]
        ..sort((a, b) {
          double numOf(Chapter c) =>
              double.tryParse(
                RegExp(
                      r'(\d+(\.\d+)?)',
                    ).firstMatch(c.chapterNumber)?.group(1) ??
                    '',
              ) ??
              0;
          return (numOf(a) - numOf(b)).toInt();
        });
      final lastReadInt = lastReadChapter.round();
      int chapterIndex = (lastReadInt - 1).clamp(0, sorted.length - 1);
      final total = totalChaptersDb > 0 ? totalChaptersDb : sorted.length;

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderScreen(
            allChapters: sorted,
            initialChapterIndex: chapterIndex,
            initialPageIndex: lastReadPage,
            mangaId: mangaId,
            sourceId: sourceId,
            mangaTitle: title,
            mangaCoverUrl: coverUrl,
            totalChapters: total,
          ),
        ),
      );

      // After closing the reader, return to the History tab.
      if (mounted) setState(() => _currentIndex = 0);
    } catch (e) {
      debugPrint('Continue reading error: $e');
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.failedToContinueReading(e)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }
}
