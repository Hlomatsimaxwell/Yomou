import 'package:intl/intl.dart';

/// Configuration for one MangaThemesia-themed site.
///
/// All the bundled MangaThemesia engines share one theme library
/// (`lib-multisrc/mangathemesia` in keiyoushi/extensions-source). Sites differ
/// only in base URL, name, language, icon, and a handful of overridable
/// selectors — so one [MangaThemesiaSource] class serves them all, driven by
/// this config (the same pattern [MadaraSiteConfig] / [MadaraSource] uses for
/// Madara sites).
class MangaThemesiaSiteConfig {
  const MangaThemesiaSiteConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.language = 'Manga, English',
    this.langCode = 'en',
    this.iconUrl = '',
    this.isNsfw = false,
    this.mangaUrlDirectory = '/manga',
    this.projectPageString = '/project',
    this.datePattern = 'MMMM d, yyyy',
    this.sendViewCount = true,
    this.hasProjectPage = false,
    this.searchMangaSelector,
    this.seriesDetailsSelector,
    this.seriesTitleSelector,
    this.chapterListSelector,
    this.pageSelector,
    this.statusSelector,
  });

  /// Source id, also stored as `sourceId` on manga rows.
  final String id;

  /// Display name shown in the source list.
  final String name;

  /// Site origin, e.g. `https://leemiau.com`. May include a path when the
  /// WordPress install lives below the host root (`https://site.com/wp`).
  final String baseUrl;

  /// Human-readable language, e.g. `Manga, English`.
  final String language;

  /// ISO language code used for localized date parsing and translation rows.
  final String langCode;

  /// Logo shown on the source tile.
  final String iconUrl;

  /// Whether the catalog marks this site as adult-only.
  final bool isNsfw;

  /// URL segment for manga pages, e.g. `/manga`.
  final String mangaUrlDirectory;

  /// URL segment for project pages, e.g. `/project`.
  final String projectPageString;

  /// Date format pattern for chapter "updated on" timestamps.
  final String datePattern;

  /// Whether the extension reports view counts back to the site.
  final bool sendViewCount;

  /// Whether the site has project pages.
  final bool hasProjectPage;

  /// CSS selector for one manga card on search/popular pages.
  final String? searchMangaSelector;

  /// Container selector around series details on the manga page.
  final String? seriesDetailsSelector;

  /// Title selector within [seriesDetailsSelector].
  final String? seriesTitleSelector;

  /// Chapter entry selector on the manga page.
  final String? chapterListSelector;

  /// Reader page image selector on the chapter page.
  final String? pageSelector;

  /// Status row selector on the manga page.
  final String? statusSelector;

  /// Site origin without a path, for requests that must stay at the host root
  /// (`/wp-admin/admin-ajax.php` on installs served from a subdirectory).
  String get origin {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme) return baseUrl;
    return '${uri.scheme}://${uri.host}';
  }

  /// Full manga page URL, e.g. `https://leemiau.com/manga/slug`.
  String mangaUrl(String mangaId) =>
      mangaId.startsWith('http') ? mangaId : '$baseUrl/$mangaId';

  /// Full chapter page URL.
  String chapterUrl(String chapterId) =>
      chapterId.startsWith('http') ? chapterId : '$baseUrl/$chapterId';

  /// Listing URL with the search/filter parameters the theme understands.
  ///
  /// `genres` are raw filter values; callers pass slugs (see
  /// [MangaThemesiaSource] genre map) and prefix a value with `-` to exclude
  /// it, mirroring the theme's `genre[]` tri-state behaviour.
  String listingUrl({
    required int page,
    String query = '',
    String? status,
    String? type,
    String? order,
    List<String>? genres,
    String? author,
    String? year,
    String? yearTo,
    bool projectFilterOn = false,
  }) {
    final params = <String, dynamic>{
      if (query.isNotEmpty) 'title': query,
      'page': '$page',
      if (status != null && status.isNotEmpty) 'status': status,
      if (type != null && type.isNotEmpty) 'type': type,
      if (order != null && order.isNotEmpty) 'order': order,
      if (genres != null && genres.isNotEmpty) 'genre[]': genres,
      if (author != null && author.isNotEmpty) 'author': author,
      if (year != null && year.isNotEmpty)
        'yearx': yearTo != null && yearTo.isNotEmpty && yearTo != year
            ? '$year-$yearTo'
            : year,
    };
    final directory = projectFilterOn && hasProjectPage
        ? projectPageString
        : mangaUrlDirectory;
    final uri = Uri.parse('$baseUrl$directory/');
    return uri.replace(queryParameters: params).toString();
  }

  /// Parses a chapter date with [datePattern] in the site's language, falling
  /// back to the US-style `MMMM d, yyyy` and plain ISO dates.
  ///
  /// Localized date symbols are loaded once from `main()` via
  /// `initializeDateFormatting`; if that has not happened (unit tests), the
  /// localized format throws and the fallbacks still handle English/ISO.
  DateTime? parseChapterDate(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    final locale = langCode.replaceAll('-', '_');
    for (final pattern in [
      datePattern,
      'MMMM d, yyyy',
      'd MMMM yyyy',
      'd MMMM, yyyy',
      'MMMM d,yyyy',
      'dd/MM/yyyy',
      'd/M/yyyy',
      'dd-MM-yyyy',
    ]) {
      for (final candidate in [locale, 'en_US']) {
        try {
          return DateFormat(pattern, candidate).parse(trimmed);
        } catch (_) {
          // Try the next pattern/locale.
        }
      }
    }
    return null;
  }

  factory MangaThemesiaSiteConfig.fromJson(Map<String, dynamic> json) {
    return MangaThemesiaSiteConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      language: json['language'] as String? ?? 'Manga, English',
      langCode: json['langCode'] as String? ?? 'en',
      iconUrl: json['iconUrl'] as String? ?? '',
      isNsfw: json['nsfw'] as bool? ?? false,
      mangaUrlDirectory: json['mangaUrlDirectory'] as String? ?? '/manga',
      projectPageString: json['projectPageString'] as String? ?? '/project',
      datePattern: json['datePattern'] as String? ?? 'MMMM d, yyyy',
      sendViewCount: json['sendViewCount'] as bool? ?? true,
      hasProjectPage: json['hasProjectPage'] as bool? ?? false,
      searchMangaSelector: json['searchMangaSelector'] as String?,
      seriesDetailsSelector: json['seriesDetailsSelector'] as String?,
      seriesTitleSelector: json['seriesTitleSelector'] as String?,
      chapterListSelector: json['chapterListSelector'] as String?,
      pageSelector: json['pageSelector'] as String?,
      statusSelector: json['statusSelector'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'language': language,
      'langCode': langCode,
      'iconUrl': iconUrl,
      'nsfw': isNsfw,
      'mangaUrlDirectory': mangaUrlDirectory,
      'projectPageString': projectPageString,
      'datePattern': datePattern,
      'sendViewCount': sendViewCount,
      'hasProjectPage': hasProjectPage,
      if (searchMangaSelector != null) 'searchMangaSelector': searchMangaSelector,
      if (seriesDetailsSelector != null)
        'seriesDetailsSelector': seriesDetailsSelector,
      if (seriesTitleSelector != null) 'seriesTitleSelector': seriesTitleSelector,
      if (chapterListSelector != null) 'chapterListSelector': chapterListSelector,
      if (pageSelector != null) 'pageSelector': pageSelector,
      if (statusSelector != null) 'statusSelector': statusSelector,
    };
  }
}
