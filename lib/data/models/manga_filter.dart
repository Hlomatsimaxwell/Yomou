/// Sort orders offered by the source-catalog filter sheet.
const kFilterSorts = [
  ('updated', 'Updated'),
  ('alphabetical', 'Alphabetical'),
  ('popularity', 'Popularity'),
  ('chapterCount', 'Chapter Count'),
];

/// Translation languages offered by the filter sheet (ISO 639-1 codes).
const kFilterLanguages = [
  ('en', 'English'),
  ('es', 'Spanish'),
  ('ru', 'Russian'),
  ('fr', 'French'),
  ('de', 'German'),
  ('it', 'Italian'),
  ('pt', 'Portuguese'),
  ('ja', 'Japanese'),
  ('zh', 'Chinese'),
  ('ko', 'Korean'),
  ('id', 'Indonesian'),
  ('vi', 'Vietnamese'),
  ('th', 'Thai'),
  ('ar', 'Arabic'),
  ('hi', 'Hindi'),
  ('tl', 'Filipino'),
];

/// Publication states handled by the filter sheet.
const kFilterStatuses = ['finished', 'dropped', 'upcoming'];

/// A single source-catalog query: sort, language, included/excluded genres,
/// publication states and a release-year range. Bundled up by the source grid
/// and handed to [MangaSource.searchWithFilter] to rebuild the "with filter"
/// request; the filter itself is persisted per source.
class MangaFilter {
  final String sort;
  final String? language;
  final List<String> genres;
  final List<String> excludeGenres;
  final List<String> status;
  final int? yearFrom;
  final int? yearTo;

  const MangaFilter({
    this.sort = 'updated',
    this.language,
    this.genres = const [],
    this.excludeGenres = const [],
    this.status = const [],
    this.yearFrom,
    this.yearTo,
  });

  bool get isDefault =>
      sort == 'updated' &&
      language == null &&
      genres.isEmpty &&
      excludeGenres.isEmpty &&
      status.isEmpty &&
      yearFrom == null &&
      yearTo == null;

  /// Stable identifier used to namespace the disk cache per filter combo.
  String get cacheKey =>
      '${sort}_${language ?? 'all'}_${genres.join(',')}_'
      '${excludeGenres.join(',')}_${status.join(',')}_'
      '${yearFrom ?? 0}_${yearTo ?? 0}';

  MangaFilter copyWith({
    String? sort,
    String? language,
    List<String>? genres,
    List<String>? excludeGenres,
    List<String>? status,
    int? yearFrom,
    int? yearTo,
    bool clearYearRange = false,
  }) {
    return MangaFilter(
      sort: sort ?? this.sort,
      language: language ?? this.language,
      genres: genres ?? this.genres,
      excludeGenres: excludeGenres ?? this.excludeGenres,
      status: status ?? this.status,
      yearFrom: clearYearRange ? null : (yearFrom ?? this.yearFrom),
      yearTo: clearYearRange ? null : (yearTo ?? this.yearTo),
    );
  }

  MangaFilter resetFull() => const MangaFilter();

  factory MangaFilter.fromJson(Map<String, dynamic> json) {
    return MangaFilter(
      sort: json['sort'] as String? ?? 'updated',
      language: json['language'] as String?,
      genres: (json['genres'] as List?)?.cast<String>() ?? const [],
      excludeGenres:
          (json['excludeGenres'] as List?)?.cast<String>() ?? const [],
      status: (json['status'] as List?)?.cast<String>() ?? const [],
      yearFrom: json['yearFrom'] as int?,
      yearTo: json['yearTo'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sort': sort,
      'language': language,
      'genres': genres,
      'excludeGenres': excludeGenres,
      'status': status,
      'yearFrom': yearFrom,
      'yearTo': yearTo,
    };
  }
}

/// A named, saved filter preset. Persisted per source so the user can recall
/// a previously saved combination and re-apply it in the filter sheet.
class SavedFilter {
  final String name;
  final MangaFilter filter;

  const SavedFilter({required this.name, required this.filter});

  factory SavedFilter.fromJson(Map<String, dynamic> json) {
    return SavedFilter(
      name: json['name'] as String? ?? '',
      filter: MangaFilter.fromJson(json['filter'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'filter': filter.toJson()};
  }
}