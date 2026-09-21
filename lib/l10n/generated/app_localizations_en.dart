// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get today => 'today';

  @override
  String get yesterday => 'yesterday';

  @override
  String get history => 'History';

  @override
  String get favorites => 'Favorites';

  @override
  String get suggestions => 'Suggestions';

  @override
  String get explore => 'Explore';

  @override
  String get updates => 'Updates';

  @override
  String get settings => 'Settings';

  @override
  String get downloads => 'Downloads';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get mangaSources => 'Manga sources';

  @override
  String get searchManga => 'Search manga';

  @override
  String get lastUsed => 'Last used';

  @override
  String get jan => 'Jan';

  @override
  String get feb => 'Feb';

  @override
  String get mar => 'Mar';

  @override
  String get apr => 'Apr';

  @override
  String get may => 'May';

  @override
  String get jun => 'Jun';

  @override
  String get jul => 'Jul';

  @override
  String get aug => 'Aug';

  @override
  String get sep => 'Sep';

  @override
  String get oct => 'Oct';

  @override
  String get nov => 'Nov';

  @override
  String get dec => 'Dec';

  @override
  String dateLong(Object month, Object day, Object year) {
    return '$month $day, $year';
  }

  @override
  String get pressBackToExit => 'Press back again to exit';

  @override
  String get noReadingHistoryYet => 'No reading history yet';

  @override
  String get noSourceAvailable => 'No source available';

  @override
  String get noChaptersAvailable => 'No chapters available';

  @override
  String failedToContinueReading(Object error) {
    return 'Failed to continue reading: $error';
  }

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSubtitle => 'Theme, List mode, Language';

  @override
  String get settingsMangaSources => 'Manga sources';

  @override
  String get settingsMangaSourcesSubtitle => '1033 of 931 on';

  @override
  String get settingsReader => 'Reader settings';

  @override
  String get settingsReaderSubtitle => 'Read mode, Scale mode, Switch pages';

  @override
  String get settingsStorage => 'Storage and network';

  @override
  String get settingsStorageSubtitle =>
      'Storage usage, Proxy, Content preloading';

  @override
  String get settingsDownloads => 'Downloads';

  @override
  String get settingsDownloadsSubtitle =>
      'Downloads folder, Download only via Wi-Fi';

  @override
  String get settingsNewChapters => 'Check for new chapters';

  @override
  String get settingsNewChaptersSubtitle =>
      'Look for updates, Notifications settings';

  @override
  String get settingsServices => 'Services';

  @override
  String get settingsServicesSubtitle =>
      'Suggestions, Synchronization, Tracking';

  @override
  String get settingsBackup => 'Backup and restore';

  @override
  String get settingsBackupSubtitle =>
      'Create or restore a backup, Periodic backups';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutSubtitle => 'Version 9.8.1';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceColorScheme => 'Color Scheme';

  @override
  String get appearanceSectionThemeOptions => 'Theme Options';

  @override
  String get appearanceSectionMangaList => 'Manga List';

  @override
  String get appearanceSectionMainScreen => 'Main Screen';

  @override
  String get appearanceNone => 'None';

  @override
  String get appearanceThemeTitle => 'Theme';

  @override
  String get appearanceThemeSystem => 'System';

  @override
  String get appearanceThemeLight => 'Light';

  @override
  String get appearanceThemeDark => 'Dark';

  @override
  String get appearanceLanguageTitle => 'Language';

  @override
  String get languageFollowSystem => 'Follow system';

  @override
  String get languageEn => 'English';

  @override
  String get languageEs => 'Español';

  @override
  String get languageFr => 'Français';

  @override
  String get languageDe => 'Deutsch';

  @override
  String get languagePt => 'Português';

  @override
  String get languageIt => 'Italiano';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageJa => '日本語';

  @override
  String get languageKo => '한국어';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageAr => 'العربية';

  @override
  String get languageHi => 'हिन्दी';

  @override
  String get appearanceListModeTitle => 'List mode';

  @override
  String get listModeGrid => 'Grid';

  @override
  String get listModeList => 'List';

  @override
  String appearanceGridSize(int percent) {
    return 'Grid size: $percent%';
  }

  @override
  String get appearanceQuickFilters => 'Show quick filters';

  @override
  String get appearanceReadingProgress => 'Show reading progress';

  @override
  String get appearanceBadges => 'Badges in lists';

  @override
  String get appearanceDetails => 'Details';

  @override
  String get appearanceCollapseDescription => 'Collapse long description';

  @override
  String get appearancePagesThumbnails => 'Show pages thumbnails';

  @override
  String get appearanceDefaultTabTitle => 'Default tab';

  @override
  String get appearanceSearchSuggestionsTitle => 'Search suggestions';

  @override
  String get appearanceMainSectionsTitle => 'Main screen sections';

  @override
  String get appearanceMainSectionsSubtitle =>
      'Categories to show in the main screen';

  @override
  String get appearanceFloatingContinue => 'Show floating Continue button';

  @override
  String get appearanceNavLabels => 'Show labels in navigation bar';

  @override
  String get appearanceFloatingNav => 'Floating navigation bar';

  @override
  String get appearancePinNav => 'Pin navigation UI';

  @override
  String get appearancePinNavSubtitle =>
      'Do not hide navigation bar and search view on scroll';

  @override
  String get appearanceExitConfirmation => 'Exit confirmation';

  @override
  String get appearanceExitConfirmationSubtitle =>
      'Press Back twice to exit the app';

  @override
  String get appearanceRecentShortcuts => 'Show recent manga shortcuts';

  @override
  String get appearanceHideNsfwShortcuts => 'Hide NSFW from shortcuts';

  @override
  String get appearancePrivacy => 'Privacy';

  @override
  String get appearanceProtectApp => 'Protect the app';

  @override
  String get appearanceProtectAppSubtitle =>
      'Require authentication to open Yomou';

  @override
  String get appearanceScreenshotPolicyTitle => 'Screenshot policy';

  @override
  String get screenshotPolicyAllow => 'Allow';

  @override
  String get screenshotPolicyBlock => 'Block';

  @override
  String get appLockEnterTitle => 'Enter PIN';

  @override
  String get appLockEnterSubtitle => 'Enter your 4-digit PIN to open Yomou';

  @override
  String get appLockSetTitle => 'Set PIN';

  @override
  String get appLockSetSubtitle => 'Choose a 4-digit PIN to protect the app';

  @override
  String get appLockVerifyTitle => 'Enter current PIN';

  @override
  String get appLockVerifySubtitle => 'Confirm your current PIN';

  @override
  String get appLockWrongPin => 'Wrong PIN, try again';

  @override
  String get appLockCancel => 'Cancel';

  @override
  String get homeRecent => 'Recent';

  @override
  String get suggestionHistory => 'History';

  @override
  String get suggestionTrending => 'Trending';

  @override
  String get suggestionNew => 'New';

  @override
  String get suggestionPopular => 'Popular';

  @override
  String get defaultTabLastUsed => 'Last used';

  @override
  String get defaultTabHistory => 'History';

  @override
  String get defaultTabFavorites => 'Favorites';

  @override
  String get defaultTabSuggestions => 'Suggestions';

  @override
  String get defaultTabExplore => 'Explore';

  @override
  String get defaultTabUpdates => 'Updates';

  @override
  String get favoritesSearchHint => 'Search favorites';

  @override
  String get favoritesCouldNotLoad => 'Could not load favorites';

  @override
  String get favoritesNoMatch => 'No favorites match your search';

  @override
  String get favoritesEmpty => 'No favorites yet';

  @override
  String get favoritesEmptySubtitle =>
      'Tap the heart on any manga to add it here.';

  @override
  String get bookmarksTitle => 'Bookmarks';

  @override
  String get deleteBookmarkTitle => 'Delete bookmark?';

  @override
  String bookmarkPage(int page) {
    return 'Page $page';
  }

  @override
  String bookmarkItem(Object title, int page) {
    return '\"$title\" • page $page';
  }

  @override
  String get bookmarksEmpty => 'No bookmarks yet';

  @override
  String get bookmarksEmptySubtitle =>
      'Bookmark pages while reading to save them here';

  @override
  String get deleteBookmarkTooltip => 'Delete bookmark';

  @override
  String get removeDownloadTitle => 'Remove download?';

  @override
  String removeDownloadContent(Object title) {
    return '\"$title\" will be deleted from your device.';
  }

  @override
  String get downloadsEmpty => 'No downloaded chapters yet';

  @override
  String get downloadsEmptySubtitle =>
      'Download chapters in the reader to read offline';

  @override
  String chapterNum(Object number) {
    return 'Chapter $number';
  }

  @override
  String downloadsPagesDate(int pages, Object date) {
    return '$pages pages • $date';
  }

  @override
  String get removeDownloadTooltip => 'Remove download';

  @override
  String get exploreLocalStorage => 'Local storage';

  @override
  String get exploreRandom => 'Random';

  @override
  String get exploreManage => 'Manage';

  @override
  String get exploreMore => 'More';

  @override
  String get manageSources => 'Manage sources';

  @override
  String get incognitoMode => 'Incognito mode';

  @override
  String get noRandomRightNow => 'No manga available for Random right now';

  @override
  String get couldNotFindRandom => 'Could not find a random manga';

  @override
  String get historyClearTitle => 'Clear history';

  @override
  String get historyClearLastHours => 'Last 2 hours';

  @override
  String get historyClearToday => 'Today';

  @override
  String get historyClearNotFavorites => 'Not in favorites';

  @override
  String get historyClearAll => 'Clear all history';

  @override
  String get historyClear => 'Clear';

  @override
  String get historyUpdated => 'History updated';

  @override
  String get historyListMode => 'List mode';

  @override
  String get historyCompactMode => 'Compact';

  @override
  String get historyDetailsMode => 'Details';

  @override
  String get historyGridSize => 'Grid size';

  @override
  String historyGridSizeColumns(int columns) {
    return '$columns Columns';
  }

  @override
  String get historySortingOrder => 'Sorting order';

  @override
  String get historySortAdded => 'Added';

  @override
  String get historySortOldest => 'Oldest';

  @override
  String get historySortProgress => 'Progress';

  @override
  String get historySortUnread => 'Unread';

  @override
  String get historySortName => 'Name';

  @override
  String get historySortNameReversed => 'Name reversed';

  @override
  String get historySortNewChapters => 'New chapters';

  @override
  String get historySortLastRead => 'Last read';

  @override
  String get historySortLongAgo => 'Long time ago read';

  @override
  String get historySortUpdated => 'Updated';

  @override
  String get historyGroup => 'Group';

  @override
  String get historyListOptions => 'List options';

  @override
  String get historyStatistics => 'Statistics';

  @override
  String get historyOnDevice => 'On device';

  @override
  String get historyNewChapters => 'New chapters';

  @override
  String get historyCompleted => 'Completed';

  @override
  String get historyEmptyTitle => 'No reading history found';

  @override
  String get historyEmptySubtitle => 'Manga you read will appear here.';

  @override
  String get historyGroupToday => 'Today';

  @override
  String get historyGroupYesterday => 'Yesterday';

  @override
  String historyGroupDaysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String get historyGroupRest => 'Rest';

  @override
  String historyLastReadChapter(Object chapter) {
    return 'Last read: Chapter $chapter';
  }

  @override
  String historyChapterShort(Object chapter) {
    return 'Ch. $chapter';
  }

  @override
  String searchEverywhereBusy(Object tag) {
    return 'Searching \"$tag\" everywhere...';
  }

  @override
  String searchOnSource(Object source) {
    return 'Search on $source';
  }

  @override
  String get searchEverywhere => 'Search everywhere';

  @override
  String get sourceNotSupported => 'This source is not supported from here.';

  @override
  String get chapterStatusReadDownloaded => 'Read • Downloaded';

  @override
  String get chapterStatusRead => 'Read';

  @override
  String get chapterStatusDownloaded => 'Downloaded';

  @override
  String downloadedChaptersCount(int count) {
    return 'Downloaded $count chapter(s)';
  }

  @override
  String get deletedSelectedDownloads => 'Deleted selected downloads';

  @override
  String get pagesHintStartReading => 'Start reading to see pages';

  @override
  String get pagesUnavailable => 'No pages available';

  @override
  String mangaDetailBookmarkItem(Object title, int page) {
    return '$title • Page $page';
  }

  @override
  String get noNote => 'No note';

  @override
  String get selectRange => 'Select range';

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get toggleRead => 'Toggle read';

  @override
  String get detailDownload => 'Download';

  @override
  String get favorited => 'Favorited';

  @override
  String get favorite => 'Favorite';

  @override
  String chapterOfTotal(int current, int total) {
    return 'Chapter $current of $total';
  }

  @override
  String chaptersCount(int total) {
    return '$total chapters';
  }

  @override
  String get detailSource => 'Source';

  @override
  String get detailAuthor => 'Author';

  @override
  String get detailYear => 'Year';

  @override
  String get detailState => 'State';

  @override
  String get detailChapters => 'Chapters';

  @override
  String get detailProgress => 'Progress';

  @override
  String get detailOnDevice => 'On Device';

  @override
  String get mockSource => 'Mock Source';

  @override
  String get unknown => 'Unknown';

  @override
  String get noDescription => 'No description available.';

  @override
  String get description => 'Description';

  @override
  String get relatedManga => 'Related manga';

  @override
  String get showAll => 'Show all';

  @override
  String get continueAction => 'Continue';

  @override
  String get readAction => 'Read';

  @override
  String get chapterDateToday => 'Today';

  @override
  String get chapterDateYesterday => 'Yesterday';

  @override
  String chapterDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get mangaDetailBookmarksEmpty =>
      'You can create bookmarks while reading manga.';

  @override
  String get colorCorrection => 'Color correction';

  @override
  String get filterBrightness => 'Brightness';

  @override
  String get filterContrast => 'Contrast';

  @override
  String get filterSepia => 'Sepia';

  @override
  String get reset => 'Reset';

  @override
  String get done => 'Done';

  @override
  String readerPageSavedTo(Object path) {
    return 'Page saved to $path';
  }

  @override
  String get readerFailedToSavePage => 'Failed to save page';

  @override
  String get readerCurrentChapter => 'Current chapter';

  @override
  String get readerCancelDownload => 'Cancel download';

  @override
  String get readerDownloadChapter => 'Download chapter';

  @override
  String get readerPagesLoading => 'Pages loading...';

  @override
  String get readerFailedToLoadBookmarks => 'Failed to load bookmarks';

  @override
  String get readerBookmarksHint =>
      'Bookmark pages while reading to save them here';

  @override
  String get readerNoDownloads => 'No downloaded chapters yet';

  @override
  String get readerRemoveBookmarkTitle => 'Remove bookmark?';

  @override
  String readerBookmarkLine(Object title, int page) {
    return '$title • Page $page';
  }

  @override
  String get readerChapterNotFound => 'Chapter not found';

  @override
  String get readerSavePage => 'Save page';

  @override
  String get readerRemoveBookmark => 'Remove bookmark';

  @override
  String get readerAddBookmark => 'Add bookmark';

  @override
  String get readerSectionReadingMode => 'Reading mode';

  @override
  String get readerSectionOptions => 'Options';

  @override
  String get readerTwoPagesLandscape => 'Two pages on landscape';

  @override
  String get readerExperimental => 'Experimental';

  @override
  String get readerRotateScreen => 'Rotate screen';

  @override
  String get readerLandscapeOrientation => 'Landscape orientation';

  @override
  String get readerRotateToLandscape => 'Rotate to landscape';

  @override
  String get readerAutoScroll => 'Automatic scroll';

  @override
  String get readerContinuousScroll => 'Continuous vertical scroll';

  @override
  String get readerSectionTools => 'Tools';

  @override
  String get readerBrightnessContrastSepia => 'Brightness, contrast, sepia';

  @override
  String get readerAppPreferences => 'App preferences';

  @override
  String get readerModeStandard => 'Standard';

  @override
  String get readerModeRTL => 'R-to-L';

  @override
  String get readerModeVertical => 'Vertical';

  @override
  String get readerModeWebtoon => 'Webtoon';

  @override
  String get readerRememberedNote =>
      'The chosen configuration will be remembered for this manga.';

  @override
  String get readerFailedLoadChapterPages => 'Failed to load chapter pages';

  @override
  String get readerFailedDownloadChapter => 'Failed to download chapter';

  @override
  String readerDownloadedChapter(Object title) {
    return 'Downloaded $title';
  }

  @override
  String get readerRemoveDownloadTitle => 'Remove download?';

  @override
  String get readerThisChapter => 'This chapter';

  @override
  String readerSavedFromChapter(Object title) {
    return 'Saved from $title';
  }

  @override
  String readerBookmarkRemovedNice(Object title, int page) {
    return 'Bookmark removed — $title • Page $page';
  }

  @override
  String readerBookmarked(Object title, int page) {
    return 'Bookmarked $title • Page $page';
  }

  @override
  String readerChapterShort(Object chapter) {
    return 'Ch. $chapter';
  }

  @override
  String get readerFailedLoadPage => 'Failed to load page';

  @override
  String get readerLoadingNextChapter => 'Loading next chapter...';

  @override
  String get readerReachedLatestChapter =>
      'You have reached the latest chapter!';

  @override
  String get readerPreviousChapter => 'Previous chapter';

  @override
  String get readerNextChapter => 'Next chapter';

  @override
  String readerDownloadedChapterDate(int count, Object date) {
    return '$count pages • downloaded $date';
  }

  @override
  String get readerMoreSheetTitle => 'More';

  @override
  String get searchSources => 'Search sources...';

  @override
  String switchedToSource(Object source) {
    return 'Switched to $source';
  }

  @override
  String get toTop => 'To top';

  @override
  String get pin => 'Pin';

  @override
  String get enableSource => 'Enable source';

  @override
  String get disableSource => 'Disable source';

  @override
  String get disabled => 'Disabled';

  @override
  String get cannotDisableActiveSource =>
      'Switch to another source before disabling this one';

  @override
  String get cannotSelectDisabledSource =>
      'Enable this source before browsing it';

  @override
  String get createShortcut => 'Create shortcut';

  @override
  String get disableNsfw => 'Disable NSFW';

  @override
  String get notificationSettingsDescription =>
      'Checks your library in the background and alerts you when a series you follow gets a new chapter.';

  @override
  String get notificationSettingsEnable => 'New chapter notifications';

  @override
  String get notificationSettingsOn => 'Checking in the background';

  @override
  String get notificationSettingsOff => 'Off';

  @override
  String get notificationPermissionDenied =>
      'Notification permission was denied. Enable it in system settings.';

  @override
  String get notificationPreviewSection => 'Preview';

  @override
  String get notificationPreviewNewChapters => 'New chapters notification';

  @override
  String get notificationPreviewSuggested => 'Suggested manga notification';

  @override
  String get notificationOptionsSection => 'Options';

  @override
  String get notificationWifiOnly => 'Only on Wi-Fi';

  @override
  String get notificationWifiOnlySubtitle =>
      'Do not check using metered network connections';

  @override
  String get notificationFrequency => 'Frequency of check';

  @override
  String get frequencyManual => 'Manual';

  @override
  String get frequencyLess => 'Less frequently';

  @override
  String get frequencyDefault => 'Default';

  @override
  String get frequencyMore => 'More frequently';

  @override
  String get notificationScope => 'Look for updates';

  @override
  String notificationScopeSubtitle(int enabled, int total) {
    return '$enabled of $total on';
  }

  @override
  String get notificationScopeFavorites => 'Favorites';

  @override
  String get notificationScopeHistory => 'History';

  @override
  String get notificationCategories => 'Favorite categories';

  @override
  String notificationCategoriesSubtitle(int enabled, int total) {
    return '$enabled of $total on';
  }

  @override
  String get notificationCategoriesNone => 'No favorite categories yet';

  @override
  String get notificationNsfw => 'Disable NSFW notifications';

  @override
  String get notificationNsfwSubtitle =>
      'Skip mature content when checking and suggesting';

  @override
  String get notificationDownload => 'Download new chapters';

  @override
  String get autoDownloadNever => 'Never';

  @override
  String get autoDownloadDownloaded => 'Manga with downloaded chapters';

  @override
  String get autoDownloadRecentlyRead => 'Recently read manga';

  @override
  String get notificationCheckLogSection => 'Debug & System';

  @override
  String get notificationCheckNow => 'Check for new chapters now';

  @override
  String get notificationCheckRunning => 'Checking...';

  @override
  String get notificationCheckDone => 'Check completed';

  @override
  String get notificationCheckFailed => 'Check failed';

  @override
  String get notificationLog => 'Checking for new chapters log';

  @override
  String get notificationLogEmpty => 'No checks have run yet';

  @override
  String get notificationBattery => 'Disable battery optimization';

  @override
  String get notificationBatterySubtitle =>
      'Android may kill background workers unless you whitelist this app';

  @override
  String notificationLogChecked(int scanned) {
    return 'Checked $scanned series';
  }

  @override
  String notificationLogFound(int series, int chapters) {
    return '$series series, $chapters new chapters';
  }

  @override
  String notificationLogSuggested(String title) {
    return 'Suggested $title';
  }

  @override
  String get searchCatalog => 'Search catalog...';

  @override
  String get noMangaFound => 'No manga found';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get tryDifferentSearch => 'Try a different search query.';

  @override
  String get searchHintAny => 'Enter manga title or genre';

  @override
  String get searchEllipsis => 'Search...';

  @override
  String get searchThisSource => 'Search this source...';

  @override
  String get randomMangaTooltip => 'Random manga';

  @override
  String get feedNoNewUpdates => 'No new updates yet';

  @override
  String get suggestionsNoResults => 'No suggestions found';

  @override
  String get suggestionsNoGenreResults =>
      'No manga found for this genre on this source';

  @override
  String get clearSearchHistory => 'Clear search history';

  @override
  String get failedToSearch => 'Failed to search';

  @override
  String get refreshResults => 'Refresh results';

  @override
  String get clearSearchQuery => 'Clear search query';

  @override
  String get filterUpdated => 'Updated';

  @override
  String get failedToLoadManga => 'Failed to load manga';

  @override
  String get hideFailedSources => 'Hide failed sources';

  @override
  String get showFailedSources => 'Show failed sources';

  @override
  String showAllCount(int count) {
    return 'Show all ($count)';
  }

  @override
  String get sourceFailed => 'Source failed';

  @override
  String get contentNotFoundRemoved => 'Content not found or removed';

  @override
  String get feedUpdatesHint =>
      'Manga you read will show here when new chapters are released.';

  @override
  String get failedToLoadUpdates => 'Failed to load updates';

  @override
  String get failedToLoadSuggestions => 'Failed to load suggestions';

  @override
  String get checking => 'Checking';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshed => 'Refreshed';

  @override
  String get updatesTitle => 'Updates';

  @override
  String get showMore => 'More';

  @override
  String get showLess => 'Less';

  @override
  String get mangaEdit => 'Edit';

  @override
  String get findSimilar => 'Find similar';

  @override
  String get alternatives => 'Alternatives';

  @override
  String get openInBrowser => 'Open in web browser';

  @override
  String get urlUnavailable => 'The web address for this manga is unavailable.';

  @override
  String get replaceSource => 'Replace source';

  @override
  String get shortcutCreated => 'Home-screen shortcut created';

  @override
  String get editMangaTitle => 'Title';

  @override
  String get editMangaCover => 'Cover';

  @override
  String get editMangaTags => 'Tags';

  @override
  String get save => 'Save';

  @override
  String get metadataSaved => 'Manga metadata updated';

  @override
  String replaceSourceDone(Object source) {
    return 'Re-bound to $source';
  }

  @override
  String get noSourceToReplace => 'No source available to switch to';

  @override
  String get saveManga => 'Save manga';

  @override
  String get chapters => 'chapters';

  @override
  String downloadWholeManga(Object count) {
    return 'Whole manga ($count chapters)';
  }

  @override
  String downloadFirstChapters(Object count) {
    return 'First $count chapters';
  }

  @override
  String downloadNextUnread(Object count) {
    return 'Next $count unread chapters';
  }

  @override
  String get downloadHint =>
      'You can select chapters to download by long click on item in the chapter list.';

  @override
  String get startDownload => 'Start download';

  @override
  String get startDownloadQueueHint =>
      'Turn off to queue downloads instead of starting immediately.';

  @override
  String get moreOptions => 'More options';

  @override
  String get destinationDirectory => 'Destination directory';

  @override
  String get preferredFormat => 'Preferred download format';

  @override
  String get download => 'Download';

  @override
  String get downloadsQueued => 'Downloads queued';

  @override
  String get downloadNotReady =>
      'Chapters are still loading. Try again in a moment.';

  @override
  String get formatAutomatic => 'Automatic';

  @override
  String get formatCbz => 'CBZ';

  @override
  String get formatImages => 'Images';

  @override
  String get destInternalStorage => 'Internal shared storage';

  @override
  String get destAppFiles => 'App external files';

  @override
  String get destCacheFolder => 'Cache';

  @override
  String historySelectedCount(int count) {
    return '$count selected';
  }

  @override
  String historyRemovedCount(int count) {
    return '$count removed from history';
  }

  @override
  String get historyUndo => 'Undo';

  @override
  String get historyEdit => 'Edit';

  @override
  String get historyMarkCompleted => 'Mark as completed';

  @override
  String get historyComingSoon => 'Coming soon';

  @override
  String historyFavoritedCount(int count) {
    return '$count added to favorites';
  }

  @override
  String get historyAlreadyFavorite => 'Already in favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String historyUnfavoritedCount(int count) {
    return '$count removed from favorites';
  }

  @override
  String get historyNotFavorite => 'Not in favorites';

  @override
  String get editPickFromFiles => 'Pick image file';

  @override
  String get editCoversFromSources => 'Covers from other sources';

  @override
  String get editUseDefaultCover => 'Use default cover';

  @override
  String get editCustomCover => 'Custom';

  @override
  String get editTitleHint => 'Manga title';

  @override
  String get editChangesNote =>
      'These changes will affect how manga is displayed in the app.';

  @override
  String get editDiscardTitle => 'Discard changes?';

  @override
  String get editDiscardContent =>
      'You have unsaved changes. They will be lost if you leave now.';

  @override
  String get editDiscard => 'Discard';

  @override
  String get editNoAltCovers =>
      'No alternative covers available for this source.';

  @override
  String get editCoverSaveFailed => 'Could not save the picked image.';

  @override
  String get editSelectOneToEdit => 'Select exactly one manga to edit';

  @override
  String coversProgress(int done, int total) {
    return '$done / $total sources';
  }

  @override
  String get coversCurrent => 'Current cover';

  @override
  String get coversUseThis => 'Use this cover';

  @override
  String get coversNoResults => 'No alternative covers found';

  @override
  String get storageCacheSection => 'Image cache';

  @override
  String get storageCacheMaxTitle => 'Cache size';

  @override
  String storageCacheMaxSubtitle(Object count) {
    return '$count files';
  }

  @override
  String get storageCacheStaleTitle => 'Cache staleness';

  @override
  String storageCacheStaleSubtitle(Object count) {
    return '$count days';
  }

  @override
  String get storagePreloadTitle => 'Pre-cache next chapter';

  @override
  String get storagePreloadSubtitle =>
      'Download the next chapter in the background while reading';

  @override
  String get storageClearTitle => 'Clear image cache';

  @override
  String storageClearSubtitle(Object size) {
    return 'Currently using $size';
  }

  @override
  String get storageClearConfirmTitle => 'Clear image cache?';

  @override
  String get storageClearConfirmBody =>
      'All cached pages and covers will be removed. They are re-downloaded when you next view them.';

  @override
  String get storageCancel => 'Cancel';

  @override
  String get storageClearDone => 'Image cache cleared';

  @override
  String get storageUnknown => 'unknown';
}
