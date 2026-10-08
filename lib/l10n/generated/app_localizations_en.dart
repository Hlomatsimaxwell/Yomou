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
  String settingsMangaSourcesSubtitle(Object enabled, Object total) {
    return '$enabled of $total on';
  }

  @override
  String get sourcesSortingOrder => 'Sorting order';

  @override
  String get sourcesSortOrderManual => 'Manual';

  @override
  String get sourcesSortOrderName => 'Name';

  @override
  String get sourcesManage => 'Manage sources';

  @override
  String get sourcesShowInGrid => 'Show in grid view';

  @override
  String get sourcesEnableAll => 'Enable all manga sources';

  @override
  String get sourcesChooseMirror => 'Choose mirror automatically';

  @override
  String get sourcesHandleLinks => 'Handle links';

  @override
  String get sourcesIncognitoNsfw => 'Incognito mode for NSFW manga';

  @override
  String get sourcesIncognitoEnable => 'Enable';

  @override
  String get sourcesIncognitoAsk => 'Ask every time';

  @override
  String get sourcesIncognitoDisable => 'Disable';

  @override
  String get sourcesCatalog => 'Sources catalog';

  @override
  String get sourcesCatalogSubtitle => 'Catalog of all available sources';

  @override
  String get settingsReader => 'Reader settings';

  @override
  String get settingsReaderSubtitle => 'Reading mode, scale, page flash';

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
  String get dlsDirsTitle => 'Local manga directories';

  @override
  String dlsDirsCount(int count) {
    return '$count items';
  }

  @override
  String get dlsFolderTitle => 'Downloads folder';

  @override
  String get dlsFolderChapters => 'Chapter downloads';

  @override
  String get dlsFolderPublic => 'Public downloads';

  @override
  String get dlsFolderDocuments => 'App documents';

  @override
  String dlsFolderCustom(String name) {
    return 'Custom: $name';
  }

  @override
  String get dlsNotSet => 'Not set';

  @override
  String get dlsFormatTitle => 'Preferred download format';

  @override
  String get dlsFormatAuto => 'Automatic';

  @override
  String get dlsFormatCbz => 'Single CBZ file';

  @override
  String get dlsFormatCbzs => 'Multiple CBZ files';

  @override
  String get dlsNetworkTitle => 'Downloading over cellular network';

  @override
  String get dlsNetworkAllow => 'Allow always';

  @override
  String get dlsNetworkAsk => 'Ask every time';

  @override
  String get dlsNetworkDeny => 'Don\'t allow';

  @override
  String get dlsInfoBody =>
      'Downloaded chapters and saved pages stay on this device so you can read them offline. Everything stored here is removed when you uninstall Yomou.';

  @override
  String get dlsSectionSaving => 'Saving pages';

  @override
  String get dlsSaveDirTitle => 'Default page save directory';

  @override
  String get dlsAskDirTitle => 'Ask for the destination dir every time';

  @override
  String get dlsAskDirSubtitle =>
      'Choose where each download is saved before it starts';

  @override
  String get dlsChaptersName => 'Chapter downloads';

  @override
  String get dlsPublicName => 'Public downloads';

  @override
  String get dlsDocumentsName => 'App documents';

  @override
  String dlsCustomName(int n) {
    return 'Custom folder $n';
  }

  @override
  String get dlsAddSheetTitle => 'Add download directory';

  @override
  String get dlsAddCustom => 'Pick custom folder';

  @override
  String get dlsAddCustomSubtitle => 'Choose an existing folder on this device';

  @override
  String get dlsAdd => 'Add';

  @override
  String get dlsDefaultMarker => 'Default directory';

  @override
  String get dlsDefaultSet => 'Default directory updated';

  @override
  String dlsDirAdded(String name) {
    return '$name added';
  }

  @override
  String get dlsWarning =>
      'Uninstalling Yomou deletes all downloaded chapters and saved pages. Back up anything you want to keep.';

  @override
  String dlsAvailable(String size) {
    return '$size available';
  }

  @override
  String get dlsNoStats => 'Not available for this location';

  @override
  String get dlsNoWritePermission => 'Yomou can\'t write to this folder';

  @override
  String get dlsCellularConfirmTitle =>
      'Allow downloads over cellular network?';

  @override
  String get dlsCellularConfirmBody =>
      'You\'re on mobile data. Downloading chapters can use a lot of data.';

  @override
  String get dlsCellularAllowOnce => 'Allow once';

  @override
  String get dlsCellularAllowAlways => 'Allow always';

  @override
  String get dlsCellularDontAllow => 'Don\'t allow';

  @override
  String get dlsCellularBlocked =>
      'Download skipped — mobile data downloads are off';

  @override
  String dlgChapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String dlgSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get dlgRemoveAll => 'Remove all downloads';

  @override
  String get dlgRemoveAllTitle => 'Remove all downloads?';

  @override
  String get dlgRemoveAllBody =>
      'This deletes every downloaded chapter from this device. It can\'t be undone.';

  @override
  String get dlgRemoveSelectedTitle => 'Remove selected downloads?';

  @override
  String dlgRemoveSelectedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This deletes $count downloaded chapters from this device.',
      one: 'This deletes 1 downloaded chapter from this device.',
    );
    return '$_temp0 It can\'t be undone.';
  }

  @override
  String get dlgSettingsItem => 'Downloads settings';

  @override
  String get dlgSettingsItemSubtitle =>
      'Where chapters and saved pages are stored';

  @override
  String get dlgRead => 'read';

  @override
  String get dlgDownloadChannelName => 'Downloads';

  @override
  String get dlgDownloadChannelDescription =>
      'Progress and results for chapters being saved to this device';

  @override
  String get dlgDownloadPreparing => 'Preparing download…';

  @override
  String dlgDownloadPreparingChapters(int count) {
    return 'Preparing $count chapters…';
  }

  @override
  String get dlgDownloadQueued => 'Waiting to start';

  @override
  String get dlgDownloadPaused => 'Paused';

  @override
  String dlgDownloadPages(Object done, Object total) {
    return '$done of $total pages';
  }

  @override
  String dlgDownloadChapterOf(Object done, Object total) {
    return 'Chapter $done of $total';
  }

  @override
  String get dlgDownloadComplete => 'Download complete';

  @override
  String dlgDownloadCompleteBody(int done) {
    return '$done chapters saved to this device';
  }

  @override
  String get dlgDownloadFailed => 'Download failed';

  @override
  String get dlgDownloadCancelled => 'Download cancelled';

  @override
  String dlgDownloadPartialBody(int done, int total) {
    return '$done of $total chapters saved';
  }

  @override
  String get dlgDownloadResume => 'Resume';

  @override
  String get dlgDownloadPause => 'Pause';

  @override
  String get dlgDownloadCancel => 'Cancel download';

  @override
  String get dlgDownloadCancelTitle => 'Cancel this download?';

  @override
  String dlgDownloadCancelBody(int saved, int total) {
    return '$saved of $total chapters are already saved and will stay on this device. The rest will not be downloaded.';
  }

  @override
  String get dlgDownloadRemoveJob => 'Remove from list';

  @override
  String get dlgInProgress => 'In progress';

  @override
  String get dlgQueued => 'Queued';

  @override
  String get dlgFailed => 'Failed';

  @override
  String dlgQueuedDownload(int count) {
    return 'Queued $count chapters for download';
  }

  @override
  String get dlgAlreadyDownloaded => 'Already downloaded';

  @override
  String get dlgDownloadNothingQueued => 'Nothing to download';

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
  String get settingsServicesUnavailable => 'Nothing to configure yet';

  @override
  String get settingsBackup => 'Backup and restore';

  @override
  String get settingsBackupSubtitle =>
      'Create or restore a backup, Periodic backups';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutBuild => 'Build';

  @override
  String get settingsAboutPackage => 'Package';

  @override
  String get settingsAboutPlatform => 'Platform';

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
  String get appearanceFrostedGlass => 'Frosted glass';

  @override
  String get appearanceFrostedGlassSubtitle =>
      'Frosted blur on the nav bar, reader controls and floating buttons';

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
  String get featuredManga => 'Featured';

  @override
  String get readNow => 'Read now';

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
  String get favoritesGridSize => 'Grid size';

  @override
  String favoritesGridSizeColumns(int columns) {
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
  String get readingStatistics => 'Reading statistics';

  @override
  String get statsTimeDay => 'Day';

  @override
  String get statsTimeWeek => 'Week';

  @override
  String get statsTimeMonth => 'Month';

  @override
  String get statsTimeThreeMonths => 'Three months';

  @override
  String get statsTimeAllTime => 'All time';

  @override
  String get statsFavorites => 'Favorites';

  @override
  String get statsOtherManga => 'Other manga';

  @override
  String statsMinutes(num minutes) {
    return '$minutes minutes';
  }

  @override
  String get statsMinute => '1 minute';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsEmptyTitle => 'No reading yet';

  @override
  String get statsEmptySubtitle =>
      'Time you spend reading will show up here once you start a chapter.';

  @override
  String get statsClearTitle => 'Clear statistics?';

  @override
  String get statsClearMessage =>
      'This removes all recorded reading time and the chapter log used for the charts. Your library is untouched.';

  @override
  String get statsClear => 'Clear statistics';

  @override
  String get statsCleared => 'Statistics cleared';

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
  String get detailTranslation => 'Translation';

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
  String get readerChaptersTitle => 'Chapters';

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
  String get readerTwoPagesLandscape =>
      'Use two pages layout on landscape orientation (beta)';

  @override
  String get readerExperimental => 'Experimental';

  @override
  String get readerRotateScreen => 'Lock screen rotation';

  @override
  String get readerLandscapeOrientation => 'Landscape orientation';

  @override
  String get readerRotateToLandscape => 'Rotate to landscape';

  @override
  String get readerAutoScroll => 'Automatic scroll';

  @override
  String get readerContinuousScroll => 'Continuous vertical scroll';

  @override
  String get readerShowStatus => 'Show reader status';

  @override
  String get readerHideControlsStatus =>
      'Show progress, battery and time when controls are hidden';

  @override
  String get readerPreferences => 'Reader preferences';

  @override
  String get readerPreferencesSubtitle =>
      'Two-page layout, auto-scroll, status bar and more';

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
  String get filterTitle => 'Filter';

  @override
  String get filterClose => 'Close filters';

  @override
  String get filterReset => 'Reset filters';

  @override
  String get filterSort => 'Sort';

  @override
  String get filterLanguage => 'Language';

  @override
  String get filterGenres => 'Genres';

  @override
  String get filterExcludeGenres => 'Exclude genres';

  @override
  String get filterMangaState => 'Manga state';

  @override
  String get filterYear => 'Release year';

  @override
  String get filterSaved => 'Filter saved';

  @override
  String get filterSavePresetTitle => 'Save filter';

  @override
  String get filterSavePresetHint => 'Filter name';

  @override
  String filterSavedPreset(String name) {
    return 'Saved \"$name\"';
  }

  @override
  String get filterCancel => 'Cancel';

  @override
  String get filterSavedFilters => 'Saved Filters';

  @override
  String filterPresetApplied(String name) {
    return 'Applied \"$name\"';
  }

  @override
  String get filterRename => 'Rename';

  @override
  String get filterDelete => 'Delete';

  @override
  String get filterDeleteConfirmTitle => 'Delete filter?';

  @override
  String filterDeleteConfirmBody(String name) {
    return 'This will remove \"$name\".';
  }

  @override
  String get filterPresetDeleted => 'Filter deleted';

  @override
  String get filterSave => 'Save';

  @override
  String get filterDone => 'Done';

  @override
  String get filterApply => 'Apply';

  @override
  String get sourcePreview => 'Preview';

  @override
  String get openFullDetails => 'Open full details';

  @override
  String get previewSourceMissing => 'Source not available';

  @override
  String get previewSourceMissingSubtitle =>
      'This title came from a source that is no longer installed, so its details cannot be loaded.';

  @override
  String get filterAllLanguages => 'All';

  @override
  String get filterStateFinished => 'Finished';

  @override
  String get filterStateDropped => 'Dropped';

  @override
  String get filterStateUpcoming => 'Upcoming';

  @override
  String get filterNoTags => 'This source has no genre list.';

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
  String get altEnabledSources => 'Enabled sources';

  @override
  String altSourcesCount(num x, num y) {
    return '$x/$y sources';
  }

  @override
  String get altMigrateTitle => 'Manga migration';

  @override
  String altMigrateBody(
    String fromTitle,
    String fromSource,
    String toTitle,
    String toSource,
  ) {
    return '$fromTitle from $fromSource will be replaced with $toTitle from $toSource in your history and favorites (if present).';
  }

  @override
  String get altMigrate => 'Migrate';

  @override
  String get altMigrateFailed => 'Migration failed. Please try again.';

  @override
  String get altSortTitle => 'Sorting order';

  @override
  String get altSortBest => 'Best match';

  @override
  String get altSortMostChapters => 'Most chapters';

  @override
  String get altSortClosest => 'Closest chapter count';

  @override
  String get altSortPriority => 'Source priority';

  @override
  String get altSources => 'Manga sources';

  @override
  String get altAllSources => 'All sources';

  @override
  String get altSameLanguage => 'Same language as current';

  @override
  String get altSameType => 'Same content type as current';

  @override
  String get altReplace => 'Replace';

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

  @override
  String get backupRestore => 'Backup and restore';

  @override
  String get createDataBackup => 'Create data backup';

  @override
  String get backupSubtitle =>
      'You can create backup of your history and favorites and restore it';

  @override
  String get restoreFromBackup => 'Restore from backup';

  @override
  String get restoreSubtitle => 'Restore previously created backup';

  @override
  String get backupFixLibrary => 'Remove unreadable entries';

  @override
  String get backupFixLibrarySubtitle =>
      'Drop library items whose ids can never load chapters (e.g. mis-imported)';

  @override
  String get backupFixLibraryNone => 'Library is clean';

  @override
  String backupFixLibraryConfirm(num count) {
    return 'Remove $count unreadable entries?';
  }

  @override
  String get backupFixLibraryRemove => 'Remove';

  @override
  String backupFixLibraryDone(num count) {
    return 'Removed $count entries';
  }

  @override
  String get exportTachiyomi => 'Export to Tachiyomi/Mihon';

  @override
  String get exportTachiyomiSubtitle =>
      'Export favorites and history in Tachiyomi format';

  @override
  String get importTachiyomi => 'Import from Tachiyomi/Mihon';

  @override
  String get importTachiyomiSubtitle =>
      'Import favorites from a .tachibk backup';

  @override
  String tachiyomiExportDone(int count) {
    return '$count manga exported to Tachiyomi/Mihon';
  }

  @override
  String tachiyomiImportDone(int count) {
    return '$count manga imported from Tachiyomi/Mihon';
  }

  @override
  String backupSkipped(int count) {
    return '$count skipped';
  }

  @override
  String get importResultsTitle => 'Import results';

  @override
  String importResultsImported(int count) {
    return '$count imported';
  }

  @override
  String importResultsNotImported(int count) {
    return '$count not imported';
  }

  @override
  String get importResultsAllImported => 'All manga were imported successfully';

  @override
  String get importResultsImportedSection => 'Imported';

  @override
  String get importResultsSkippedSection => 'Not imported';

  @override
  String importResultsSkippedReasonSource(String source) {
    return 'No supported source for $source';
  }

  @override
  String get importResultsSkippedReasonSourceFallback =>
      'Yomou doesn\'t have this source';

  @override
  String get importResultsSkippedReasonId => 'Couldn\'t match a manga url';

  @override
  String importResultsReadTo(num chapter) {
    return 'Read to chapter $chapter';
  }

  @override
  String get tachiyomiExportNone => 'No compatible manga found to export';

  @override
  String get tachiyomiImportInvalid => 'Invalid Tachiyomi backup file';

  @override
  String get tachiyomiImportNone => 'No compatible manga found to import';

  @override
  String get periodicBackups => 'Periodic backups';

  @override
  String get enablePeriodicBackups => 'Enable periodic backups';

  @override
  String get backupsOutputDirectory => 'Backups output directory';

  @override
  String get backupsOutputDirectoryNone => 'No directory chosen';

  @override
  String get backupCreationFrequency => 'Backup creation frequency';

  @override
  String get deleteOldBackups => 'Delete old backups';

  @override
  String get maxNumberOfBackups => 'Max number of backups';

  @override
  String get lastSuccessfulBackup => 'Last successful backup';

  @override
  String lastSuccessfulBackupTime(String time) {
    return 'Last successful backup: $time';
  }

  @override
  String get backupNever => 'Never';

  @override
  String get backupJustNow => 'Just now';

  @override
  String backupMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String backupHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String backupDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String backupWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String backupMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String backupYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String get refreshEveryHour => 'Every hour';

  @override
  String get refreshEvery3Hours => 'Every 3 hours';

  @override
  String get refreshEvery6Hours => 'Every 6 hours';

  @override
  String get refreshEvery12Hours => 'Every 12 hours';

  @override
  String get refreshDaily => 'Daily';

  @override
  String get refreshEvery2Days => 'Every 2 days';

  @override
  String get refreshEvery4Days => 'Every 4 days';

  @override
  String get refreshWeekly => 'Every week';

  @override
  String get suggestionsRefresh => 'Suggestions refresh';

  @override
  String get suggestionsRefreshTitle => 'Suggestions refresh rate';

  @override
  String get sourceFilter => 'Filter';

  @override
  String get sourceListOptions => 'List options';

  @override
  String get sourceListMode => 'List mode';

  @override
  String get sourceGridSize => 'Grid size';

  @override
  String sourceGridSizeColumns(int columns) {
    return '$columns Columns';
  }

  @override
  String get sourceDomain => 'Domain';

  @override
  String sourceDefault(String value) {
    return 'Default: $value';
  }

  @override
  String get sourceUserAgent => 'UserAgent header';

  @override
  String get sourceSignIn => 'Sign in';

  @override
  String get sourceNotSignedIn => 'Not signed in';

  @override
  String get sourceClearCookies => 'Clear cookies';

  @override
  String get sourceClearCookiesSubtitle =>
      'Clear cookies for specified domain only. In most cases this will invalidate authorization.';

  @override
  String get sourceCookiesCleared => 'All cookies were removed';

  @override
  String get sourceAuthorized => 'Authorized';

  @override
  String get sourceCaptchaSolver => 'Disable automatic CAPTCHA solving';

  @override
  String get sourceCaptchaSolverSubtitle =>
      'Don\'t try to solve CAPTCHA silently in the background. You will be asked to solve it manually instead.';

  @override
  String get sourceCaptchaNotif => 'Disable CAPTCHA notifications';

  @override
  String get sourceCaptchaNotifSubtitle =>
      'You will not receive notifications about solving CAPTCHA for this source, but this can lead to breaking background operations (checking for new chapters, obtaining recommendations, etc.).';

  @override
  String get sourceDownloadSlowdown => 'Download slowdown';

  @override
  String get sourceDownloadSlowdownSubtitle =>
      'Helps avoid blocking your IP address.';

  @override
  String get sourceTest => 'Test source';

  @override
  String get sourceTestSubtitle =>
      'Check the connection and see the raw response';

  @override
  String get sourceTestTitles => 'Titles';

  @override
  String get sourceTestError => 'Error';

  @override
  String get sourceTestUnknown => 'Source not found';

  @override
  String get sourceOpenInBrowser => 'Open in web browser';

  @override
  String get signInLoggedInAs => 'Logged in as';

  @override
  String get captchaRequiredTitle =>
      'This source requires solving a captcha to continue.';

  @override
  String get captchaSolve => 'Solve';

  @override
  String get captchaSolveTitle => 'Solve captcha';

  @override
  String get captchaSolveHint =>
      'Finish the check in the browser below, then continue.';

  @override
  String get captchaContinue => 'Continue';

  @override
  String get captchaStatusTitle => 'What the browser is showing';

  @override
  String get captchaStatusPage => 'Page';

  @override
  String get captchaStatusChallenge => 'Challenge';

  @override
  String get captchaStatusContent => 'Content';

  @override
  String get captchaStatusCookies => 'Cookies';

  @override
  String get captchaChallengeNone => 'none seen';

  @override
  String get captchaChallengeOnScreen => 'ON SCREEN';

  @override
  String get captchaChallengeUnknown => 'page not loaded yet';

  @override
  String get captchaContentEmpty => 'empty';

  @override
  String get captchaContentLoaded => 'loaded';

  @override
  String get webviewMissingTitle => 'No embedded browser here';

  @override
  String get webviewMissingBody =>
      'This screen needs an in-app browser, which this platform does not have. A source behind a captcha check cannot be opened here.';

  @override
  String get rsetDefaultsNote =>
      'These are the defaults for a new title. A manga you have already configured keeps its own setting.';

  @override
  String get rsetDefaultMode => 'Default mode';

  @override
  String get rsetDefaultModeSub =>
      'How a chapter opens when you have not set one for this title';

  @override
  String get rsetModeStandard => 'Standard';

  @override
  String get rsetModeRtl => 'Right-to-left';

  @override
  String get rsetModeVertical => 'Vertical';

  @override
  String get rsetModeWebtoon => 'Webtoon';

  @override
  String get rsetScaleMode => 'Scale mode';

  @override
  String get rsetScaleModeSub => 'How a page fills the screen';

  @override
  String get rsetScaleFitCenter => 'Fit center';

  @override
  String get rsetScaleFitHeight => 'Fit to height';

  @override
  String get rsetScaleFitWidth => 'Fit to width';

  @override
  String get rsetScaleKeepAtStart => 'Keep at start';

  @override
  String get rsetSectionReading => 'Reading';

  @override
  String get rsetSectionStrip => 'Vertical & webtoon';

  @override
  String get rsetWebtoonZoomOut => 'Default zoom out';

  @override
  String get rsetWebtoonZoomOutSub =>
      'Narrows the strip so long panels are easier to read';

  @override
  String get rsetWebtoonGaps => 'Gaps between pages';

  @override
  String get rsetWebtoonGapsSub =>
      'Separate the panels so the seam between them is visible';

  @override
  String get rsetStripUnavailable =>
      'Only used in the vertical and webtoon modes';

  @override
  String get rsetTwoPagesUnavailable =>
      'Only used in the standard and right-to-left modes';

  @override
  String get rsetVolumeButtons => 'Enable volume buttons';

  @override
  String get rsetVolumeButtonsSub =>
      'Turn pages with the volume keys while a chapter is open';

  @override
  String get rsetVolumeButtonsUnavailable =>
      'Not available on this device — iOS gives apps no way to read the volume buttons';

  @override
  String get rsetInvertNavigation => 'Invert navigation control';

  @override
  String get rsetInvertNavigationSub => 'Swipe and page the other way round';

  @override
  String get rsetReduceMemory => 'Reduce memory consumption (beta)';

  @override
  String get rsetReduceMemorySub =>
      'Cuts the page cache and preloads less ahead';

  @override
  String get rsetSectionEInk => 'E-Ink';

  @override
  String get rsetSectionControls => 'Controls';

  @override
  String get rsetFlashOnChange => 'Flash on page change';

  @override
  String get rsetFlashOnChangeSub =>
      'Clear the screen between pages to drop ghosting';

  @override
  String get rsetFlashDuration => 'Flash duration';

  @override
  String get rsetFlashDurationSub => 'How long the screen stays cleared';

  @override
  String get rsetFlashEvery => 'Flash every';

  @override
  String get rsetFlashEverySub =>
      'Clear the screen once every few pages instead of every page';

  @override
  String rsetFlashEveryUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get rsetFlashWith => 'Flash with';

  @override
  String get rsetFlashWithSub => 'Which colour the screen is cleared to';

  @override
  String get rsetFlashWhite => 'White';

  @override
  String get rsetFlashBlack => 'Black';

  @override
  String get rsetSectionDisplay => 'Display';

  @override
  String get rsetFullscreen => 'Fullscreen mode';

  @override
  String get rsetFullscreenSub => 'Hide the system bars while you read';

  @override
  String get rsetOrientation => 'Screen orientation';

  @override
  String get rsetOrientationSub =>
      'Default keeps the reader the way you opened it';

  @override
  String get rsetOrientDefault => 'Default';

  @override
  String get rsetOrientAutomatic => 'Automatic';

  @override
  String get rsetOrientPortrait => 'Portrait';

  @override
  String get rsetOrientLandscape => 'Landscape';

  @override
  String get rsetKeepScreenOn => 'Keep screen on';

  @override
  String get rsetKeepScreenOnSub =>
      'Stop the display sleeping while a chapter is open';

  @override
  String get rsetShowInfoBar => 'Show information bar in reader';

  @override
  String get rsetShowInfoBarSub => 'Progress, battery and time over the page';

  @override
  String get rsetTransparentInfoBar => 'Transparent reader information bar';

  @override
  String get rsetTransparentInfoBarSub =>
      'Off puts a dark strip behind the text instead';

  @override
  String get rsetShowChapterPopup => 'Show chapter change popup';

  @override
  String get rsetShowChapterPopupSub =>
      'Say the chapter name when the page changes';

  @override
  String get rsetSectionPages => 'Pages';

  @override
  String get rsetBackground => 'Background';

  @override
  String get rsetBackgroundSub => 'The colour behind the page';

  @override
  String get rsetBgDefault => 'Default';

  @override
  String get rsetBgLight => 'Light';

  @override
  String get rsetBgDark => 'Dark';

  @override
  String get rsetBgWhite => 'White';

  @override
  String get rsetBgBlack => 'Black';

  @override
  String get rsetNumberedPages => 'Numbered pages';

  @override
  String get rsetNumberedPagesSub =>
      'Print the page counter onto the page itself';

  @override
  String get rsetPreload => 'Preload pages';

  @override
  String get rsetPreloadSub => 'Fetch pages ahead of the one you are reading';

  @override
  String get rsetPreloadAlways => 'Always';

  @override
  String get rsetPreloadWifiOnly => 'Only on Wi-Fi';

  @override
  String get rsetPreloadNever => 'Never';

  @override
  String get rsetTwoPages => 'Two pages in landscape';

  @override
  String get rsetTwoPagesSub => 'Show a spread instead of a single page';

  @override
  String get rsetReset => 'Reset reader settings';

  @override
  String get rsetResetSub =>
      'Put every setting on this screen back to how it shipped';

  @override
  String get rsetResetTitle => 'Reset reader settings?';

  @override
  String get rsetResetBody =>
      'Every reader setting goes back to its default. Settings you have made on individual titles are not touched.';

  @override
  String get settingsReaderActions => 'Reader actions';

  @override
  String get ractMenuSubtitle => 'What a tap does in each part of the page';

  @override
  String get ractMenuOverflow => 'More';

  @override
  String get ractReset => 'Reset';

  @override
  String get ractDisableAll => 'Disable all';

  @override
  String get ractResetDone => 'Reader actions reset';

  @override
  String get ractDisabledAll => 'All reader actions disabled';

  @override
  String get ractTapAction => 'Tap action';

  @override
  String get ractLongTapAction => 'Long tap action';

  @override
  String get ractActionNone => 'None';

  @override
  String get ractActionNextPage => 'Next page';

  @override
  String get ractActionPrevPage => 'Previous page';

  @override
  String get ractActionNextChapter => 'Next chapter';

  @override
  String get ractActionPrevChapter => 'Previous chapter';

  @override
  String get ractActionToggleUi => 'Show/hide UI';

  @override
  String get ractActionShowMenu => 'Show menu';

  @override
  String get welcomeTitle => 'Welcome';

  @override
  String get welcomeIntro =>
      'Yomou reads from community sources that each publish in their own languages and formats. Pick what you read and Explore, Search and Suggestions will favour it. Nothing here is permanent — you can change it later in Settings.';

  @override
  String get welcomeRestoreBackup => 'Restore from backup';

  @override
  String get welcomeLoginSync => 'Login to sync account';

  @override
  String get welcomeComingSoon => 'Coming soon';

  @override
  String get welcomeLocalDirs => 'Local manga directories';

  @override
  String get welcomeLanguages => 'Languages';

  @override
  String get welcomeType => 'Type';

  @override
  String get welcomeStart => 'Start reading';

  @override
  String backupRestoreDone(int count) {
    return 'Restored $count items';
  }

  @override
  String backupRestoreKeptNewer(int count) {
    return '$count kept — already further along on this device';
  }

  @override
  String get backupRestoreNone => 'Nothing to restore in that file';

  @override
  String get settingsContentPreferences => 'Content preferences';

  @override
  String get settingsContentPreferencesSubtitle =>
      'The languages and formats you read';

  @override
  String get langEnglish => 'English';

  @override
  String get langSpanish => 'Spanish';

  @override
  String get langPortuguese => 'Portuguese';

  @override
  String get langFrench => 'French';

  @override
  String get langJapanese => 'Japanese';

  @override
  String get langKorean => 'Korean';

  @override
  String get langChinese => 'Chinese';

  @override
  String get langArabic => 'Arabic';

  @override
  String get langRussian => 'Russian';

  @override
  String get langItalian => 'Italian';

  @override
  String get langGerman => 'German';

  @override
  String get langIndonesian => 'Indonesian';

  @override
  String get formatManga => 'Manga';

  @override
  String get formatManhwa => 'Manhwa';

  @override
  String get formatManhua => 'Manhua';

  @override
  String get formatNovel => 'Novel';

  @override
  String get presetsAllSources => 'All sources';

  @override
  String get presetsMySources => 'My sources';

  @override
  String get presetsManage => 'Manage presets';

  @override
  String get presetsNew => 'New preset';

  @override
  String get presetsEdit => 'Edit preset';

  @override
  String get presetsDelete => 'Delete preset';

  @override
  String presetsDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get presetsRename => 'Rename preset';

  @override
  String get presetsNameHint => 'Preset name';

  @override
  String get presetsLanguages => 'Languages';

  @override
  String get presetsCreateFromCurrent => 'Save current selection';

  @override
  String get presetsEmpty => 'No presets yet';

  @override
  String get presetsCancel => 'Cancel';

  @override
  String get presetsSave => 'Save';

  @override
  String get presetsDeleteAction => 'Delete';

  @override
  String get presetsDefaultName => 'My sources';
}
