import 'package:intl/intl.dart';

/// Configuration for one ZeistManga-themed (Blogger feeds) site.
///
/// Every bundled ZeistManga engine uses the same Blogger-feed based theme:
/// the manga catalogue, chapter index and even the reader images are published
/// as posts/labels. Sites differ only in base URL, name, language, icon and a
/// handful of overrides, so one [ZeistMangaSource] serves them all, exactly
/// like [MadaraSiteConfig]/[MadaraSource] and
/// [MangaThemesiaSiteConfig]/[MangaThemesiaSource].
class ZeistMangaSiteConfig {
  const ZeistMangaSiteConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.language = 'Manga',
    this.langCode = 'en',
    this.iconUrl = '',
    this.isNsfw = false,
    this.mangaCategory = 'Series',
    this.pageSelector,
    this.datePattern = 'yyyy-MM-dd',
  });

  /// Source id, also stored as `sourceId` on manga rows.
  final String id;

  /// Display name shown in the source list.
  final String name;

  /// Blogger site origin, e.g. `https://galaxscanlator.blogspot.com`.
  final String baseUrl;

  /// Human-readable language shown on the source tile.
  final String language;

  /// ISO language code used for localized date parsing.
  final String langCode;

  /// Logo shown on the source tile.
  final String iconUrl;

  /// Whether the catalog marks this site as adult-only.
  final bool isNsfw;

  /// Blogger label holding the manga catalogue posts. Most sites use
  /// `Series`; a few (e.g. GALAX Scans) publish under `Recentes`.
  final String mangaCategory;

  /// Optional reader-image selector for sites whose markup differs from the
  /// theme default (Manhatok, Temaki mangás).
  final String? pageSelector;

  /// Date pattern used for chapter timestamps (Blogger publishes ISO dates,
  /// so this is mainly a fallback).
  final String datePattern;

  /// Full manga page URL. ZeistManga ids are the post URL itself.
  String mangaUrl(String mangaId) =>
      mangaId.startsWith('http') ? mangaId : '$baseUrl/$mangaId';

  /// Blogger JSON feed for a label, with the query string Kotatsu's parser
  /// uses (`alt=json`, newest first, and `q=label:...` for title search).
  String feedUrl(
    String label, {
    required int maxResults,
    int startIndex = 1,
    String? query,
  }) {
    final Uri base = Uri.parse(
      '$baseUrl/feeds/posts/default/-/${Uri.encodeComponent(label)}',
    );
    return base.replace(
      queryParameters: <String, String>{
        'alt': 'json',
        'orderby': 'published',
        'max-results': '$maxResults',
        'start-index': '$startIndex',
        if (query != null && query.trim().isNotEmpty)
          'q': 'label:$label ${query.trim()}',
      },
    ).toString();
  }

  /// Parses a Blogger `published` value (ISO 8601, sometimes with a fractional
  /// second or timezone) into a DateTime for the Updates feed.
  DateTime? parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;
    final locale = langCode.replaceAll('-', '_');
    for (final pattern in [datePattern, 'yyyy-MM-dd', 'dd/MM/yyyy']) {
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

  factory ZeistMangaSiteConfig.fromJson(Map<String, dynamic> json) {
    return ZeistMangaSiteConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      language: json['language'] as String? ?? 'Manga',
      langCode: json['langCode'] as String? ?? 'en',
      iconUrl: json['iconUrl'] as String? ?? '',
      isNsfw: json['nsfw'] as bool? ?? false,
      mangaCategory: json['mangaCategory'] as String? ?? 'Series',
      pageSelector: json['pageSelector'] as String?,
      datePattern: json['datePattern'] as String? ?? 'yyyy-MM-dd',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'language': language,
      'langCode': langCode,
      'iconUrl': iconUrl,
      'nsfw': isNsfw,
      'mangaCategory': mangaCategory,
      if (pageSelector != null) 'pageSelector': pageSelector,
      'datePattern': datePattern,
    };
  }
}
