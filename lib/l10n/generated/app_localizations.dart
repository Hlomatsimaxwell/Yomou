import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get yesterday;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @suggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get suggestions;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @mangaSources.
  ///
  /// In en, this message translates to:
  /// **'Manga sources'**
  String get mangaSources;

  /// No description provided for @searchManga.
  ///
  /// In en, this message translates to:
  /// **'Search manga'**
  String get searchManga;

  /// No description provided for @lastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get lastUsed;

  /// No description provided for @jan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get jan;

  /// No description provided for @feb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get feb;

  /// No description provided for @mar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get mar;

  /// No description provided for @apr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get apr;

  /// No description provided for @may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// No description provided for @jun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get jun;

  /// No description provided for @jul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get jul;

  /// No description provided for @aug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get aug;

  /// No description provided for @sep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get sep;

  /// No description provided for @oct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get oct;

  /// No description provided for @nov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get nov;

  /// No description provided for @dec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get dec;

  /// No description provided for @dateLong.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String dateLong(Object month, Object day, Object year);

  /// No description provided for @pressBackToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get pressBackToExit;

  /// No description provided for @noReadingHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No reading history yet'**
  String get noReadingHistoryYet;

  /// No description provided for @noSourceAvailable.
  ///
  /// In en, this message translates to:
  /// **'No source available'**
  String get noSourceAvailable;

  /// No description provided for @noChaptersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No chapters available'**
  String get noChaptersAvailable;

  /// No description provided for @failedToContinueReading.
  ///
  /// In en, this message translates to:
  /// **'Failed to continue reading: {error}'**
  String failedToContinueReading(Object error);

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, List mode, Language'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @settingsMangaSources.
  ///
  /// In en, this message translates to:
  /// **'Manga sources'**
  String get settingsMangaSources;

  /// No description provided for @settingsMangaSourcesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'1033 of 931 on'**
  String get settingsMangaSourcesSubtitle;

  /// No description provided for @settingsReader.
  ///
  /// In en, this message translates to:
  /// **'Reader settings'**
  String get settingsReader;

  /// No description provided for @settingsReaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read mode, Scale mode, Switch pages'**
  String get settingsReaderSubtitle;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage and network'**
  String get settingsStorage;

  /// No description provided for @settingsStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Storage usage, Proxy, Content preloading'**
  String get settingsStorageSubtitle;

  /// No description provided for @settingsDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get settingsDownloads;

  /// No description provided for @settingsDownloadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads folder, Download only via Wi-Fi'**
  String get settingsDownloadsSubtitle;

  /// No description provided for @settingsNewChapters.
  ///
  /// In en, this message translates to:
  /// **'Check for new chapters'**
  String get settingsNewChapters;

  /// No description provided for @settingsNewChaptersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Look for updates, Notifications settings'**
  String get settingsNewChaptersSubtitle;

  /// No description provided for @settingsServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get settingsServices;

  /// No description provided for @settingsServicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Suggestions, Synchronization, Tracking'**
  String get settingsServicesSubtitle;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get settingsBackup;

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create or restore a backup, Periodic backups'**
  String get settingsBackupSubtitle;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version 9.8.1'**
  String get settingsAboutSubtitle;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @appearanceColorScheme.
  ///
  /// In en, this message translates to:
  /// **'Color Scheme'**
  String get appearanceColorScheme;

  /// No description provided for @appearanceSectionThemeOptions.
  ///
  /// In en, this message translates to:
  /// **'Theme Options'**
  String get appearanceSectionThemeOptions;

  /// No description provided for @appearanceSectionMangaList.
  ///
  /// In en, this message translates to:
  /// **'Manga List'**
  String get appearanceSectionMangaList;

  /// No description provided for @appearanceSectionMainScreen.
  ///
  /// In en, this message translates to:
  /// **'Main Screen'**
  String get appearanceSectionMainScreen;

  /// No description provided for @appearanceNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get appearanceNone;

  /// No description provided for @appearanceThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appearanceThemeTitle;

  /// No description provided for @appearanceThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appearanceThemeSystem;

  /// No description provided for @appearanceThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceThemeLight;

  /// No description provided for @appearanceThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceThemeDark;

  /// No description provided for @appearanceLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get appearanceLanguageTitle;

  /// No description provided for @languageFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageFollowSystem;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageEs.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageEs;

  /// No description provided for @languageFr.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFr;

  /// No description provided for @languageDe.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageDe;

  /// No description provided for @languagePt.
  ///
  /// In en, this message translates to:
  /// **'Português'**
  String get languagePt;

  /// No description provided for @languageIt.
  ///
  /// In en, this message translates to:
  /// **'Italiano'**
  String get languageIt;

  /// No description provided for @languageRu.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRu;

  /// No description provided for @languageJa.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJa;

  /// No description provided for @languageKo.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get languageKo;

  /// No description provided for @languageZh.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageZh;

  /// No description provided for @languageAr.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageAr;

  /// No description provided for @languageHi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageHi;

  /// No description provided for @appearanceListModeTitle.
  ///
  /// In en, this message translates to:
  /// **'List mode'**
  String get appearanceListModeTitle;

  /// No description provided for @listModeGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get listModeGrid;

  /// No description provided for @listModeList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get listModeList;

  /// No description provided for @appearanceGridSize.
  ///
  /// In en, this message translates to:
  /// **'Grid size: {percent}%'**
  String appearanceGridSize(int percent);

  /// No description provided for @appearanceQuickFilters.
  ///
  /// In en, this message translates to:
  /// **'Show quick filters'**
  String get appearanceQuickFilters;

  /// No description provided for @appearanceReadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Show reading progress'**
  String get appearanceReadingProgress;

  /// No description provided for @appearanceBadges.
  ///
  /// In en, this message translates to:
  /// **'Badges in lists'**
  String get appearanceBadges;

  /// No description provided for @appearanceDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get appearanceDetails;

  /// No description provided for @appearanceCollapseDescription.
  ///
  /// In en, this message translates to:
  /// **'Collapse long description'**
  String get appearanceCollapseDescription;

  /// No description provided for @appearancePagesThumbnails.
  ///
  /// In en, this message translates to:
  /// **'Show pages thumbnails'**
  String get appearancePagesThumbnails;

  /// No description provided for @appearanceDefaultTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Default tab'**
  String get appearanceDefaultTabTitle;

  /// No description provided for @appearanceSearchSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search suggestions'**
  String get appearanceSearchSuggestionsTitle;

  /// No description provided for @appearanceMainSectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Main screen sections'**
  String get appearanceMainSectionsTitle;

  /// No description provided for @appearanceMainSectionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Categories to show in the main screen'**
  String get appearanceMainSectionsSubtitle;

  /// No description provided for @appearanceFloatingContinue.
  ///
  /// In en, this message translates to:
  /// **'Show floating Continue button'**
  String get appearanceFloatingContinue;

  /// No description provided for @appearanceNavLabels.
  ///
  /// In en, this message translates to:
  /// **'Show labels in navigation bar'**
  String get appearanceNavLabels;

  /// No description provided for @appearanceFloatingNav.
  ///
  /// In en, this message translates to:
  /// **'Floating navigation bar'**
  String get appearanceFloatingNav;

  /// No description provided for @appearancePinNav.
  ///
  /// In en, this message translates to:
  /// **'Pin navigation UI'**
  String get appearancePinNav;

  /// No description provided for @appearancePinNavSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Do not hide navigation bar and search view on scroll'**
  String get appearancePinNavSubtitle;

  /// No description provided for @appearanceExitConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Exit confirmation'**
  String get appearanceExitConfirmation;

  /// No description provided for @appearanceExitConfirmationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Press Back twice to exit the app'**
  String get appearanceExitConfirmationSubtitle;

  /// No description provided for @appearanceRecentShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Show recent manga shortcuts'**
  String get appearanceRecentShortcuts;

  /// No description provided for @appearanceHideNsfwShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Hide NSFW from shortcuts'**
  String get appearanceHideNsfwShortcuts;

  /// No description provided for @appearancePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get appearancePrivacy;

  /// No description provided for @appearanceProtectApp.
  ///
  /// In en, this message translates to:
  /// **'Protect the app'**
  String get appearanceProtectApp;

  /// No description provided for @appearanceProtectAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require authentication to open Yomou'**
  String get appearanceProtectAppSubtitle;

  /// No description provided for @appearanceScreenshotPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Screenshot policy'**
  String get appearanceScreenshotPolicyTitle;

  /// No description provided for @screenshotPolicyAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get screenshotPolicyAllow;

  /// No description provided for @screenshotPolicyBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get screenshotPolicyBlock;

  /// No description provided for @appLockEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get appLockEnterTitle;

  /// No description provided for @appLockEnterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit PIN to open Yomou'**
  String get appLockEnterSubtitle;

  /// No description provided for @appLockSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get appLockSetTitle;

  /// No description provided for @appLockSetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a 4-digit PIN to protect the app'**
  String get appLockSetSubtitle;

  /// No description provided for @appLockVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter current PIN'**
  String get appLockVerifyTitle;

  /// No description provided for @appLockVerifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your current PIN'**
  String get appLockVerifySubtitle;

  /// No description provided for @appLockWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN, try again'**
  String get appLockWrongPin;

  /// No description provided for @appLockCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get appLockCancel;

  /// No description provided for @homeRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get homeRecent;

  /// No description provided for @suggestionHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get suggestionHistory;

  /// No description provided for @suggestionTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get suggestionTrending;

  /// No description provided for @suggestionNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get suggestionNew;

  /// No description provided for @suggestionPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get suggestionPopular;

  /// No description provided for @defaultTabLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get defaultTabLastUsed;

  /// No description provided for @defaultTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get defaultTabHistory;

  /// No description provided for @defaultTabFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get defaultTabFavorites;

  /// No description provided for @defaultTabSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get defaultTabSuggestions;

  /// No description provided for @defaultTabExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get defaultTabExplore;

  /// No description provided for @defaultTabUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get defaultTabUpdates;

  /// No description provided for @favoritesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search favorites'**
  String get favoritesSearchHint;

  /// No description provided for @favoritesCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load favorites'**
  String get favoritesCouldNotLoad;

  /// No description provided for @favoritesNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No favorites match your search'**
  String get favoritesNoMatch;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesEmpty;

  /// No description provided for @favoritesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any manga to add it here.'**
  String get favoritesEmptySubtitle;

  /// No description provided for @bookmarksTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarksTitle;

  /// No description provided for @deleteBookmarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete bookmark?'**
  String get deleteBookmarkTitle;

  /// No description provided for @bookmarkPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String bookmarkPage(int page);

  /// No description provided for @bookmarkItem.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" • page {page}'**
  String bookmarkItem(Object title, int page);

  /// No description provided for @bookmarksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get bookmarksEmpty;

  /// No description provided for @bookmarksEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmark pages while reading to save them here'**
  String get bookmarksEmptySubtitle;

  /// No description provided for @deleteBookmarkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete bookmark'**
  String get deleteBookmarkTooltip;

  /// No description provided for @removeDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove download?'**
  String get removeDownloadTitle;

  /// No description provided for @removeDownloadContent.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be deleted from your device.'**
  String removeDownloadContent(Object title);

  /// No description provided for @downloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No downloaded chapters yet'**
  String get downloadsEmpty;

  /// No description provided for @downloadsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download chapters in the reader to read offline'**
  String get downloadsEmptySubtitle;

  /// No description provided for @chapterNum.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String chapterNum(Object number);

  /// No description provided for @downloadsPagesDate.
  ///
  /// In en, this message translates to:
  /// **'{pages} pages • {date}'**
  String downloadsPagesDate(int pages, Object date);

  /// No description provided for @removeDownloadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get removeDownloadTooltip;

  /// No description provided for @exploreLocalStorage.
  ///
  /// In en, this message translates to:
  /// **'Local storage'**
  String get exploreLocalStorage;

  /// No description provided for @exploreRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get exploreRandom;

  /// No description provided for @exploreManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get exploreManage;

  /// No description provided for @exploreMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get exploreMore;

  /// No description provided for @manageSources.
  ///
  /// In en, this message translates to:
  /// **'Manage sources'**
  String get manageSources;

  /// No description provided for @incognitoMode.
  ///
  /// In en, this message translates to:
  /// **'Incognito mode'**
  String get incognitoMode;

  /// No description provided for @noRandomRightNow.
  ///
  /// In en, this message translates to:
  /// **'No manga available for Random right now'**
  String get noRandomRightNow;

  /// No description provided for @couldNotFindRandom.
  ///
  /// In en, this message translates to:
  /// **'Could not find a random manga'**
  String get couldNotFindRandom;

  /// No description provided for @historyClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get historyClearTitle;

  /// No description provided for @historyClearLastHours.
  ///
  /// In en, this message translates to:
  /// **'Last 2 hours'**
  String get historyClearLastHours;

  /// No description provided for @historyClearToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyClearToday;

  /// No description provided for @historyClearNotFavorites.
  ///
  /// In en, this message translates to:
  /// **'Not in favorites'**
  String get historyClearNotFavorites;

  /// No description provided for @historyClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all history'**
  String get historyClearAll;

  /// No description provided for @historyClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get historyClear;

  /// No description provided for @historyUpdated.
  ///
  /// In en, this message translates to:
  /// **'History updated'**
  String get historyUpdated;

  /// No description provided for @historyListMode.
  ///
  /// In en, this message translates to:
  /// **'List mode'**
  String get historyListMode;

  /// No description provided for @historyCompactMode.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get historyCompactMode;

  /// No description provided for @historyDetailsMode.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get historyDetailsMode;

  /// No description provided for @historyGridSize.
  ///
  /// In en, this message translates to:
  /// **'Grid size'**
  String get historyGridSize;

  /// No description provided for @historyGridSizeColumns.
  ///
  /// In en, this message translates to:
  /// **'{columns} Columns'**
  String historyGridSizeColumns(int columns);

  /// No description provided for @historySortingOrder.
  ///
  /// In en, this message translates to:
  /// **'Sorting order'**
  String get historySortingOrder;

  /// No description provided for @historySortAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get historySortAdded;

  /// No description provided for @historySortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get historySortOldest;

  /// No description provided for @historySortProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get historySortProgress;

  /// No description provided for @historySortUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get historySortUnread;

  /// No description provided for @historySortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get historySortName;

  /// No description provided for @historySortNameReversed.
  ///
  /// In en, this message translates to:
  /// **'Name reversed'**
  String get historySortNameReversed;

  /// No description provided for @historySortNewChapters.
  ///
  /// In en, this message translates to:
  /// **'New chapters'**
  String get historySortNewChapters;

  /// No description provided for @historySortLastRead.
  ///
  /// In en, this message translates to:
  /// **'Last read'**
  String get historySortLastRead;

  /// No description provided for @historySortLongAgo.
  ///
  /// In en, this message translates to:
  /// **'Long time ago read'**
  String get historySortLongAgo;

  /// No description provided for @historySortUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get historySortUpdated;

  /// No description provided for @historyGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get historyGroup;

  /// No description provided for @historyListOptions.
  ///
  /// In en, this message translates to:
  /// **'List options'**
  String get historyListOptions;

  /// No description provided for @historyStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get historyStatistics;

  /// No description provided for @historyOnDevice.
  ///
  /// In en, this message translates to:
  /// **'On device'**
  String get historyOnDevice;

  /// No description provided for @historyNewChapters.
  ///
  /// In en, this message translates to:
  /// **'New chapters'**
  String get historyNewChapters;

  /// No description provided for @historyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get historyCompleted;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No reading history found'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manga you read will appear here.'**
  String get historyEmptySubtitle;

  /// No description provided for @historyGroupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyGroupToday;

  /// No description provided for @historyGroupYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get historyGroupYesterday;

  /// No description provided for @historyGroupDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String historyGroupDaysAgo(Object count);

  /// No description provided for @historyGroupRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get historyGroupRest;

  /// No description provided for @historyLastReadChapter.
  ///
  /// In en, this message translates to:
  /// **'Last read: Chapter {chapter}'**
  String historyLastReadChapter(Object chapter);

  /// No description provided for @historyChapterShort.
  ///
  /// In en, this message translates to:
  /// **'Ch. {chapter}'**
  String historyChapterShort(Object chapter);

  /// No description provided for @searchEverywhereBusy.
  ///
  /// In en, this message translates to:
  /// **'Searching \"{tag}\" everywhere...'**
  String searchEverywhereBusy(Object tag);

  /// No description provided for @searchOnSource.
  ///
  /// In en, this message translates to:
  /// **'Search on {source}'**
  String searchOnSource(Object source);

  /// No description provided for @searchEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Search everywhere'**
  String get searchEverywhere;

  /// No description provided for @sourceNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This source is not supported from here.'**
  String get sourceNotSupported;

  /// No description provided for @chapterStatusReadDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Read • Downloaded'**
  String get chapterStatusReadDownloaded;

  /// No description provided for @chapterStatusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get chapterStatusRead;

  /// No description provided for @chapterStatusDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get chapterStatusDownloaded;

  /// No description provided for @downloadedChaptersCount.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {count} chapter(s)'**
  String downloadedChaptersCount(int count);

  /// No description provided for @deletedSelectedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Deleted selected downloads'**
  String get deletedSelectedDownloads;

  /// No description provided for @pagesHintStartReading.
  ///
  /// In en, this message translates to:
  /// **'Start reading to see pages'**
  String get pagesHintStartReading;

  /// No description provided for @pagesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No pages available'**
  String get pagesUnavailable;

  /// No description provided for @mangaDetailBookmarkItem.
  ///
  /// In en, this message translates to:
  /// **'{title} • Page {page}'**
  String mangaDetailBookmarkItem(Object title, int page);

  /// No description provided for @noNote.
  ///
  /// In en, this message translates to:
  /// **'No note'**
  String get noNote;

  /// No description provided for @selectRange.
  ///
  /// In en, this message translates to:
  /// **'Select range'**
  String get selectRange;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// No description provided for @toggleRead.
  ///
  /// In en, this message translates to:
  /// **'Toggle read'**
  String get toggleRead;

  /// No description provided for @detailDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get detailDownload;

  /// No description provided for @favorited.
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get favorited;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @chapterOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Chapter {current} of {total}'**
  String chapterOfTotal(int current, int total);

  /// No description provided for @chaptersCount.
  ///
  /// In en, this message translates to:
  /// **'{total} chapters'**
  String chaptersCount(int total);

  /// No description provided for @detailSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get detailSource;

  /// No description provided for @detailAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get detailAuthor;

  /// No description provided for @detailYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get detailYear;

  /// No description provided for @detailState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get detailState;

  /// No description provided for @detailChapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get detailChapters;

  /// No description provided for @detailProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get detailProgress;

  /// No description provided for @detailOnDevice.
  ///
  /// In en, this message translates to:
  /// **'On Device'**
  String get detailOnDevice;

  /// No description provided for @mockSource.
  ///
  /// In en, this message translates to:
  /// **'Mock Source'**
  String get mockSource;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description available.'**
  String get noDescription;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @relatedManga.
  ///
  /// In en, this message translates to:
  /// **'Related manga'**
  String get relatedManga;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @readAction.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get readAction;

  /// No description provided for @chapterDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chapterDateToday;

  /// No description provided for @chapterDateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chapterDateYesterday;

  /// No description provided for @chapterDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String chapterDaysAgo(int days);

  /// No description provided for @mangaDetailBookmarksEmpty.
  ///
  /// In en, this message translates to:
  /// **'You can create bookmarks while reading manga.'**
  String get mangaDetailBookmarksEmpty;

  /// No description provided for @colorCorrection.
  ///
  /// In en, this message translates to:
  /// **'Color correction'**
  String get colorCorrection;

  /// No description provided for @filterBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get filterBrightness;

  /// No description provided for @filterContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get filterContrast;

  /// No description provided for @filterSepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get filterSepia;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @readerPageSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Page saved to {path}'**
  String readerPageSavedTo(Object path);

  /// No description provided for @readerFailedToSavePage.
  ///
  /// In en, this message translates to:
  /// **'Failed to save page'**
  String get readerFailedToSavePage;

  /// No description provided for @readerCurrentChapter.
  ///
  /// In en, this message translates to:
  /// **'Current chapter'**
  String get readerCurrentChapter;

  /// No description provided for @readerCancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get readerCancelDownload;

  /// No description provided for @readerDownloadChapter.
  ///
  /// In en, this message translates to:
  /// **'Download chapter'**
  String get readerDownloadChapter;

  /// No description provided for @readerPagesLoading.
  ///
  /// In en, this message translates to:
  /// **'Pages loading...'**
  String get readerPagesLoading;

  /// No description provided for @readerFailedToLoadBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Failed to load bookmarks'**
  String get readerFailedToLoadBookmarks;

  /// No description provided for @readerBookmarksHint.
  ///
  /// In en, this message translates to:
  /// **'Bookmark pages while reading to save them here'**
  String get readerBookmarksHint;

  /// No description provided for @readerNoDownloads.
  ///
  /// In en, this message translates to:
  /// **'No downloaded chapters yet'**
  String get readerNoDownloads;

  /// No description provided for @readerRemoveBookmarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark?'**
  String get readerRemoveBookmarkTitle;

  /// No description provided for @readerBookmarkLine.
  ///
  /// In en, this message translates to:
  /// **'{title} • Page {page}'**
  String readerBookmarkLine(Object title, int page);

  /// No description provided for @readerChapterNotFound.
  ///
  /// In en, this message translates to:
  /// **'Chapter not found'**
  String get readerChapterNotFound;

  /// No description provided for @readerSavePage.
  ///
  /// In en, this message translates to:
  /// **'Save page'**
  String get readerSavePage;

  /// No description provided for @readerRemoveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get readerRemoveBookmark;

  /// No description provided for @readerAddBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add bookmark'**
  String get readerAddBookmark;

  /// No description provided for @readerSectionReadingMode.
  ///
  /// In en, this message translates to:
  /// **'Reading mode'**
  String get readerSectionReadingMode;

  /// No description provided for @readerSectionOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get readerSectionOptions;

  /// No description provided for @readerTwoPagesLandscape.
  ///
  /// In en, this message translates to:
  /// **'Two pages on landscape'**
  String get readerTwoPagesLandscape;

  /// No description provided for @readerExperimental.
  ///
  /// In en, this message translates to:
  /// **'Experimental'**
  String get readerExperimental;

  /// No description provided for @readerRotateScreen.
  ///
  /// In en, this message translates to:
  /// **'Rotate screen'**
  String get readerRotateScreen;

  /// No description provided for @readerLandscapeOrientation.
  ///
  /// In en, this message translates to:
  /// **'Landscape orientation'**
  String get readerLandscapeOrientation;

  /// No description provided for @readerRotateToLandscape.
  ///
  /// In en, this message translates to:
  /// **'Rotate to landscape'**
  String get readerRotateToLandscape;

  /// No description provided for @readerAutoScroll.
  ///
  /// In en, this message translates to:
  /// **'Automatic scroll'**
  String get readerAutoScroll;

  /// No description provided for @readerContinuousScroll.
  ///
  /// In en, this message translates to:
  /// **'Continuous vertical scroll'**
  String get readerContinuousScroll;

  /// No description provided for @readerSectionTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get readerSectionTools;

  /// No description provided for @readerBrightnessContrastSepia.
  ///
  /// In en, this message translates to:
  /// **'Brightness, contrast, sepia'**
  String get readerBrightnessContrastSepia;

  /// No description provided for @readerAppPreferences.
  ///
  /// In en, this message translates to:
  /// **'App preferences'**
  String get readerAppPreferences;

  /// No description provided for @readerModeStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get readerModeStandard;

  /// No description provided for @readerModeRTL.
  ///
  /// In en, this message translates to:
  /// **'R-to-L'**
  String get readerModeRTL;

  /// No description provided for @readerModeVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get readerModeVertical;

  /// No description provided for @readerModeWebtoon.
  ///
  /// In en, this message translates to:
  /// **'Webtoon'**
  String get readerModeWebtoon;

  /// No description provided for @readerRememberedNote.
  ///
  /// In en, this message translates to:
  /// **'The chosen configuration will be remembered for this manga.'**
  String get readerRememberedNote;

  /// No description provided for @readerFailedLoadChapterPages.
  ///
  /// In en, this message translates to:
  /// **'Failed to load chapter pages'**
  String get readerFailedLoadChapterPages;

  /// No description provided for @readerFailedDownloadChapter.
  ///
  /// In en, this message translates to:
  /// **'Failed to download chapter'**
  String get readerFailedDownloadChapter;

  /// No description provided for @readerDownloadedChapter.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {title}'**
  String readerDownloadedChapter(Object title);

  /// No description provided for @readerRemoveDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove download?'**
  String get readerRemoveDownloadTitle;

  /// No description provided for @readerThisChapter.
  ///
  /// In en, this message translates to:
  /// **'This chapter'**
  String get readerThisChapter;

  /// No description provided for @readerSavedFromChapter.
  ///
  /// In en, this message translates to:
  /// **'Saved from {title}'**
  String readerSavedFromChapter(Object title);

  /// No description provided for @readerBookmarkRemovedNice.
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed — {title} • Page {page}'**
  String readerBookmarkRemovedNice(Object title, int page);

  /// No description provided for @readerBookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked {title} • Page {page}'**
  String readerBookmarked(Object title, int page);

  /// No description provided for @readerChapterShort.
  ///
  /// In en, this message translates to:
  /// **'Ch. {chapter}'**
  String readerChapterShort(Object chapter);

  /// No description provided for @readerFailedLoadPage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load page'**
  String get readerFailedLoadPage;

  /// No description provided for @readerLoadingNextChapter.
  ///
  /// In en, this message translates to:
  /// **'Loading next chapter...'**
  String get readerLoadingNextChapter;

  /// No description provided for @readerReachedLatestChapter.
  ///
  /// In en, this message translates to:
  /// **'You have reached the latest chapter!'**
  String get readerReachedLatestChapter;

  /// No description provided for @readerPreviousChapter.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter'**
  String get readerPreviousChapter;

  /// No description provided for @readerNextChapter.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get readerNextChapter;

  /// No description provided for @readerDownloadedChapterDate.
  ///
  /// In en, this message translates to:
  /// **'{count} pages • downloaded {date}'**
  String readerDownloadedChapterDate(int count, Object date);

  /// No description provided for @readerMoreSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get readerMoreSheetTitle;

  /// No description provided for @searchSources.
  ///
  /// In en, this message translates to:
  /// **'Search sources...'**
  String get searchSources;

  /// No description provided for @switchedToSource.
  ///
  /// In en, this message translates to:
  /// **'Switched to {source}'**
  String switchedToSource(Object source);

  /// No description provided for @toTop.
  ///
  /// In en, this message translates to:
  /// **'To top'**
  String get toTop;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @enableSource.
  ///
  /// In en, this message translates to:
  /// **'Enable source'**
  String get enableSource;

  /// No description provided for @disableSource.
  ///
  /// In en, this message translates to:
  /// **'Disable source'**
  String get disableSource;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @cannotDisableActiveSource.
  ///
  /// In en, this message translates to:
  /// **'Switch to another source before disabling this one'**
  String get cannotDisableActiveSource;

  /// No description provided for @cannotSelectDisabledSource.
  ///
  /// In en, this message translates to:
  /// **'Enable this source before browsing it'**
  String get cannotSelectDisabledSource;

  /// No description provided for @createShortcut.
  ///
  /// In en, this message translates to:
  /// **'Create shortcut'**
  String get createShortcut;

  /// No description provided for @disableNsfw.
  ///
  /// In en, this message translates to:
  /// **'Disable NSFW'**
  String get disableNsfw;

  /// No description provided for @notificationSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Checks your library in the background and alerts you when a series you follow gets a new chapter.'**
  String get notificationSettingsDescription;

  /// No description provided for @notificationSettingsEnable.
  ///
  /// In en, this message translates to:
  /// **'New chapter notifications'**
  String get notificationSettingsEnable;

  /// No description provided for @notificationSettingsOn.
  ///
  /// In en, this message translates to:
  /// **'Checking in the background'**
  String get notificationSettingsOn;

  /// No description provided for @notificationSettingsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get notificationSettingsOff;

  /// No description provided for @notificationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification permission was denied. Enable it in system settings.'**
  String get notificationPermissionDenied;

  /// No description provided for @notificationPreviewSection.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get notificationPreviewSection;

  /// No description provided for @notificationPreviewNewChapters.
  ///
  /// In en, this message translates to:
  /// **'New chapters notification'**
  String get notificationPreviewNewChapters;

  /// No description provided for @notificationPreviewSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested manga notification'**
  String get notificationPreviewSuggested;

  /// No description provided for @notificationOptionsSection.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get notificationOptionsSection;

  /// No description provided for @notificationWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Only on Wi-Fi'**
  String get notificationWifiOnly;

  /// No description provided for @notificationWifiOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Do not check using metered network connections'**
  String get notificationWifiOnlySubtitle;

  /// No description provided for @notificationFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency of check'**
  String get notificationFrequency;

  /// No description provided for @frequencyManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get frequencyManual;

  /// No description provided for @frequencyLess.
  ///
  /// In en, this message translates to:
  /// **'Less frequently'**
  String get frequencyLess;

  /// No description provided for @frequencyDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get frequencyDefault;

  /// No description provided for @frequencyMore.
  ///
  /// In en, this message translates to:
  /// **'More frequently'**
  String get frequencyMore;

  /// No description provided for @notificationScope.
  ///
  /// In en, this message translates to:
  /// **'Look for updates'**
  String get notificationScope;

  /// No description provided for @notificationScopeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{enabled} of {total} on'**
  String notificationScopeSubtitle(int enabled, int total);

  /// No description provided for @notificationScopeFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get notificationScopeFavorites;

  /// No description provided for @notificationScopeHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get notificationScopeHistory;

  /// No description provided for @notificationCategories.
  ///
  /// In en, this message translates to:
  /// **'Favorite categories'**
  String get notificationCategories;

  /// No description provided for @notificationCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{enabled} of {total} on'**
  String notificationCategoriesSubtitle(int enabled, int total);

  /// No description provided for @notificationCategoriesNone.
  ///
  /// In en, this message translates to:
  /// **'No favorite categories yet'**
  String get notificationCategoriesNone;

  /// No description provided for @notificationNsfw.
  ///
  /// In en, this message translates to:
  /// **'Disable NSFW notifications'**
  String get notificationNsfw;

  /// No description provided for @notificationNsfwSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip mature content when checking and suggesting'**
  String get notificationNsfwSubtitle;

  /// No description provided for @notificationDownload.
  ///
  /// In en, this message translates to:
  /// **'Download new chapters'**
  String get notificationDownload;

  /// No description provided for @autoDownloadNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get autoDownloadNever;

  /// No description provided for @autoDownloadDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Manga with downloaded chapters'**
  String get autoDownloadDownloaded;

  /// No description provided for @autoDownloadRecentlyRead.
  ///
  /// In en, this message translates to:
  /// **'Recently read manga'**
  String get autoDownloadRecentlyRead;

  /// No description provided for @notificationCheckLogSection.
  ///
  /// In en, this message translates to:
  /// **'Debug & System'**
  String get notificationCheckLogSection;

  /// No description provided for @notificationCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check for new chapters now'**
  String get notificationCheckNow;

  /// No description provided for @notificationCheckRunning.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get notificationCheckRunning;

  /// No description provided for @notificationCheckDone.
  ///
  /// In en, this message translates to:
  /// **'Check completed'**
  String get notificationCheckDone;

  /// No description provided for @notificationCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Check failed'**
  String get notificationCheckFailed;

  /// No description provided for @notificationLog.
  ///
  /// In en, this message translates to:
  /// **'Checking for new chapters log'**
  String get notificationLog;

  /// No description provided for @notificationLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No checks have run yet'**
  String get notificationLogEmpty;

  /// No description provided for @notificationBattery.
  ///
  /// In en, this message translates to:
  /// **'Disable battery optimization'**
  String get notificationBattery;

  /// No description provided for @notificationBatterySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Android may kill background workers unless you whitelist this app'**
  String get notificationBatterySubtitle;

  /// No description provided for @notificationLogChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked {scanned} series'**
  String notificationLogChecked(int scanned);

  /// No description provided for @notificationLogFound.
  ///
  /// In en, this message translates to:
  /// **'{series} series, {chapters} new chapters'**
  String notificationLogFound(int series, int chapters);

  /// No description provided for @notificationLogSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested {title}'**
  String notificationLogSuggested(String title);

  /// No description provided for @searchCatalog.
  ///
  /// In en, this message translates to:
  /// **'Search catalog...'**
  String get searchCatalog;

  /// No description provided for @noMangaFound.
  ///
  /// In en, this message translates to:
  /// **'No manga found'**
  String get noMangaFound;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search query.'**
  String get tryDifferentSearch;

  /// No description provided for @searchHintAny.
  ///
  /// In en, this message translates to:
  /// **'Enter manga title or genre'**
  String get searchHintAny;

  /// No description provided for @searchEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchEllipsis;

  /// No description provided for @searchThisSource.
  ///
  /// In en, this message translates to:
  /// **'Search this source...'**
  String get searchThisSource;

  /// No description provided for @randomMangaTooltip.
  ///
  /// In en, this message translates to:
  /// **'Random manga'**
  String get randomMangaTooltip;

  /// No description provided for @feedNoNewUpdates.
  ///
  /// In en, this message translates to:
  /// **'No new updates yet'**
  String get feedNoNewUpdates;

  /// No description provided for @suggestionsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No suggestions found'**
  String get suggestionsNoResults;

  /// No description provided for @suggestionsNoGenreResults.
  ///
  /// In en, this message translates to:
  /// **'No manga found for this genre on this source'**
  String get suggestionsNoGenreResults;

  /// No description provided for @clearSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get clearSearchHistory;

  /// No description provided for @failedToSearch.
  ///
  /// In en, this message translates to:
  /// **'Failed to search'**
  String get failedToSearch;

  /// No description provided for @refreshResults.
  ///
  /// In en, this message translates to:
  /// **'Refresh results'**
  String get refreshResults;

  /// No description provided for @clearSearchQuery.
  ///
  /// In en, this message translates to:
  /// **'Clear search query'**
  String get clearSearchQuery;

  /// No description provided for @filterUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get filterUpdated;

  /// No description provided for @failedToLoadManga.
  ///
  /// In en, this message translates to:
  /// **'Failed to load manga'**
  String get failedToLoadManga;

  /// No description provided for @hideFailedSources.
  ///
  /// In en, this message translates to:
  /// **'Hide failed sources'**
  String get hideFailedSources;

  /// No description provided for @showFailedSources.
  ///
  /// In en, this message translates to:
  /// **'Show failed sources'**
  String get showFailedSources;

  /// No description provided for @showAllCount.
  ///
  /// In en, this message translates to:
  /// **'Show all ({count})'**
  String showAllCount(int count);

  /// No description provided for @sourceFailed.
  ///
  /// In en, this message translates to:
  /// **'Source failed'**
  String get sourceFailed;

  /// No description provided for @contentNotFoundRemoved.
  ///
  /// In en, this message translates to:
  /// **'Content not found or removed'**
  String get contentNotFoundRemoved;

  /// No description provided for @feedUpdatesHint.
  ///
  /// In en, this message translates to:
  /// **'Manga you read will show here when new chapters are released.'**
  String get feedUpdatesHint;

  /// No description provided for @failedToLoadUpdates.
  ///
  /// In en, this message translates to:
  /// **'Failed to load updates'**
  String get failedToLoadUpdates;

  /// No description provided for @failedToLoadSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Failed to load suggestions'**
  String get failedToLoadSuggestions;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get checking;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @refreshed.
  ///
  /// In en, this message translates to:
  /// **'Refreshed'**
  String get refreshed;

  /// No description provided for @updatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updatesTitle;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get showLess;

  /// No description provided for @mangaEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get mangaEdit;

  /// No description provided for @findSimilar.
  ///
  /// In en, this message translates to:
  /// **'Find similar'**
  String get findSimilar;

  /// No description provided for @alternatives.
  ///
  /// In en, this message translates to:
  /// **'Alternatives'**
  String get alternatives;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in web browser'**
  String get openInBrowser;

  /// No description provided for @urlUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The web address for this manga is unavailable.'**
  String get urlUnavailable;

  /// No description provided for @replaceSource.
  ///
  /// In en, this message translates to:
  /// **'Replace source'**
  String get replaceSource;

  /// No description provided for @shortcutCreated.
  ///
  /// In en, this message translates to:
  /// **'Home-screen shortcut created'**
  String get shortcutCreated;

  /// No description provided for @editMangaTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get editMangaTitle;

  /// No description provided for @editMangaCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get editMangaCover;

  /// No description provided for @editMangaTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get editMangaTags;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @metadataSaved.
  ///
  /// In en, this message translates to:
  /// **'Manga metadata updated'**
  String get metadataSaved;

  /// No description provided for @replaceSourceDone.
  ///
  /// In en, this message translates to:
  /// **'Re-bound to {source}'**
  String replaceSourceDone(Object source);

  /// No description provided for @noSourceToReplace.
  ///
  /// In en, this message translates to:
  /// **'No source available to switch to'**
  String get noSourceToReplace;

  /// No description provided for @saveManga.
  ///
  /// In en, this message translates to:
  /// **'Save manga'**
  String get saveManga;

  /// No description provided for @chapters.
  ///
  /// In en, this message translates to:
  /// **'chapters'**
  String get chapters;

  /// No description provided for @downloadWholeManga.
  ///
  /// In en, this message translates to:
  /// **'Whole manga ({count} chapters)'**
  String downloadWholeManga(Object count);

  /// No description provided for @downloadFirstChapters.
  ///
  /// In en, this message translates to:
  /// **'First {count} chapters'**
  String downloadFirstChapters(Object count);

  /// No description provided for @downloadNextUnread.
  ///
  /// In en, this message translates to:
  /// **'Next {count} unread chapters'**
  String downloadNextUnread(Object count);

  /// No description provided for @downloadHint.
  ///
  /// In en, this message translates to:
  /// **'You can select chapters to download by long click on item in the chapter list.'**
  String get downloadHint;

  /// No description provided for @startDownload.
  ///
  /// In en, this message translates to:
  /// **'Start download'**
  String get startDownload;

  /// No description provided for @startDownloadQueueHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off to queue downloads instead of starting immediately.'**
  String get startDownloadQueueHint;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @destinationDirectory.
  ///
  /// In en, this message translates to:
  /// **'Destination directory'**
  String get destinationDirectory;

  /// No description provided for @preferredFormat.
  ///
  /// In en, this message translates to:
  /// **'Preferred download format'**
  String get preferredFormat;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadsQueued.
  ///
  /// In en, this message translates to:
  /// **'Downloads queued'**
  String get downloadsQueued;

  /// No description provided for @downloadNotReady.
  ///
  /// In en, this message translates to:
  /// **'Chapters are still loading. Try again in a moment.'**
  String get downloadNotReady;

  /// No description provided for @formatAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get formatAutomatic;

  /// No description provided for @formatCbz.
  ///
  /// In en, this message translates to:
  /// **'CBZ'**
  String get formatCbz;

  /// No description provided for @formatImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get formatImages;

  /// No description provided for @destInternalStorage.
  ///
  /// In en, this message translates to:
  /// **'Internal shared storage'**
  String get destInternalStorage;

  /// No description provided for @destAppFiles.
  ///
  /// In en, this message translates to:
  /// **'App external files'**
  String get destAppFiles;

  /// No description provided for @destCacheFolder.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get destCacheFolder;

  /// No description provided for @historySelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String historySelectedCount(int count);

  /// No description provided for @historyRemovedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} removed from history'**
  String historyRemovedCount(int count);

  /// No description provided for @historyUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get historyUndo;

  /// No description provided for @historyEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get historyEdit;

  /// No description provided for @historyMarkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark as completed'**
  String get historyMarkCompleted;

  /// No description provided for @historyComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get historyComingSoon;

  /// No description provided for @historyFavoritedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} added to favorites'**
  String historyFavoritedCount(int count);

  /// No description provided for @historyAlreadyFavorite.
  ///
  /// In en, this message translates to:
  /// **'Already in favorites'**
  String get historyAlreadyFavorite;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @historyUnfavoritedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} removed from favorites'**
  String historyUnfavoritedCount(int count);

  /// No description provided for @historyNotFavorite.
  ///
  /// In en, this message translates to:
  /// **'Not in favorites'**
  String get historyNotFavorite;

  /// No description provided for @editPickFromFiles.
  ///
  /// In en, this message translates to:
  /// **'Pick image file'**
  String get editPickFromFiles;

  /// No description provided for @editCoversFromSources.
  ///
  /// In en, this message translates to:
  /// **'Covers from other sources'**
  String get editCoversFromSources;

  /// No description provided for @editUseDefaultCover.
  ///
  /// In en, this message translates to:
  /// **'Use default cover'**
  String get editUseDefaultCover;

  /// No description provided for @editCustomCover.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get editCustomCover;

  /// No description provided for @editTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Manga title'**
  String get editTitleHint;

  /// No description provided for @editChangesNote.
  ///
  /// In en, this message translates to:
  /// **'These changes will affect how manga is displayed in the app.'**
  String get editChangesNote;

  /// No description provided for @editDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get editDiscardTitle;

  /// No description provided for @editDiscardContent.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. They will be lost if you leave now.'**
  String get editDiscardContent;

  /// No description provided for @editDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get editDiscard;

  /// No description provided for @editNoAltCovers.
  ///
  /// In en, this message translates to:
  /// **'No alternative covers available for this source.'**
  String get editNoAltCovers;

  /// No description provided for @editCoverSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the picked image.'**
  String get editCoverSaveFailed;

  /// No description provided for @editSelectOneToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select exactly one manga to edit'**
  String get editSelectOneToEdit;

  /// No description provided for @coversProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} sources'**
  String coversProgress(int done, int total);

  /// No description provided for @coversCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current cover'**
  String get coversCurrent;

  /// No description provided for @coversUseThis.
  ///
  /// In en, this message translates to:
  /// **'Use this cover'**
  String get coversUseThis;

  /// No description provided for @coversNoResults.
  ///
  /// In en, this message translates to:
  /// **'No alternative covers found'**
  String get coversNoResults;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
