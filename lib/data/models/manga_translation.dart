/// One translation (language variant) of a manga on a source.
///
/// Sources that publish the same work in several languages return these from
/// their details lookup; each variant is its own manga id, so it gets its own
/// library entry and its own reading progress (a Spanish scan of a series is a
/// different book from the English one).
class MangaTranslation {
  /// Language code of the variant, e.g. `en`, `es`, `pt-br`, `es-la`.
  final String language;

  /// The manga id to open for this translation.
  final String mangaId;

  /// Localized title when the source exposes one (defaults to the base title).
  final String title;

  const MangaTranslation({
    required this.language,
    required this.mangaId,
    this.title = '',
  });

  factory MangaTranslation.fromJson(Map<String, dynamic> json) {
    return MangaTranslation(
      language: json['language'] ?? '',
      mangaId: json['mangaId'] ?? '',
      title: json['title'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'mangaId': mangaId,
        'title': title,
      };
}

/// Human-readable names for the language codes sources use.
///
/// Sources disagree on spelling ("pt-BR" vs "pt-br") and MangaDex uses a much
/// wider set than MangaFire, so labels are resolved case-insensitively and an
/// unknown code falls back to itself (e.g. "es-la" -> "Spanish (Latin)").
abstract final class MangaLanguage {
  static const Map<String, String> _labels = {
    'en': 'English',
    'es': 'Spanish',
    'es-la': 'Spanish (Latin)',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'pt-br': 'Portuguese (Brazil)',
    'ru': 'Russian',
    'uk': 'Ukrainian',
    'pl': 'Polish',
    'nl': 'Dutch',
    'tr': 'Turkish',
    'ar': 'Arabic',
    'he': 'Hebrew',
    'fa': 'Persian',
    'hi': 'Hindi',
    'bn': 'Bengali',
    'id': 'Indonesian',
    'ms': 'Malay',
    'th': 'Thai',
    'vi': 'Vietnamese',
    'ja': 'Japanese',
    'zh': 'Chinese',
    'ko': 'Korean',
    'cs': 'Czech',
    'ro': 'Romanian',
    'hu': 'Hungarian',
    'el': 'Greek',
    'sr': 'Serbian',
    'hr': 'Croatian',
    'bg': 'Bulgarian',
    'sk': 'Slovak',
    'sl': 'Slovenian',
    'lt': 'Lithuanian',
    'lv': 'Latvian',
    'et': 'Estonian',
    'ca': 'Catalan',
    'eu': 'Basque',
    'gl': 'Galician',
    'af': 'Afrikaans',
    'sw': 'Swahili',
  };

  static String label(String code) {
    final key = code.trim().toLowerCase();
    return _labels[key] ?? code;
  }

  /// The emoji flag for a translation code, in the reference's spirit: a
  /// language-only code points at the language's home country (en -> GB), a
  /// country suffix beats it (pt-br -> BR), and the codes that are not
  /// countries on their own are mapped by hand -- ko is not an ISO country,
  /// and es-la would otherwise be Laos. Null when no flag can be drawn, so
  /// a caller can fall back to the generic icon.
  static String? flagEmoji(String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized == 'es-la') return _flagFromCountry('ES');
    final parts = normalized.split(RegExp(r'[-_ ]'));
    final primary = parts.first;
    final suffix = parts.length > 1 ? parts.last : '';
    final home = switch (primary) {
      'en' => 'GB',
      'ja' => 'JP',
      'vi' => 'VN',
      'zh' => 'CN',
      'ar' => 'SA',
      'ko' => 'KR',
      'he' => 'IL',
      'fa' => 'IR',
      'hi' => 'IN',
      'uk' => 'UA',
      'ms' => 'MY',
      'bn' => 'BD',
      'el' => 'GR',
      'cs' => 'CZ',
      'sr' => 'RS',
      'sl' => 'SI',
      'et' => 'EE',
      'af' => 'ZA',
      'sw' => 'KE',
      _ => primary.toUpperCase(),
    };
    // A country suffix (pt-br) names the variety's own country and wins over
    // the home country above.
    final country = RegExp(r'^[a-z]{2}$').hasMatch(suffix)
        ? suffix.toUpperCase()
        : home;
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(country)) return null;
    return _flagFromCountry(country);
  }

  /// Two regional-indicator symbols -- the emoji flag for an ISO3166 alpha-2
  /// code, drawn by the system font.
  static String _flagFromCountry(String country) => country.codeUnits
      .map((unit) => String.fromCharCode(0x1F1E6 + (unit - 0x41)))
      .join();

  /// Appends a `.<language>` suffix to a manga id to address one translation of
  /// a work (e.g. `38922` + `es` -> `38922.es`). Reads back with
  /// [baseIdOf] / [suffixOf]. Chosen over `@` because manga ids are used in
  /// file paths for downloaded chapters.
  ///
  /// Some sources already carry a dot in their ids (`slug.38922` on MangaFire),
  /// so the suffix is only read back when the trailing segment actually looks
  /// like a language code.
  static String withSuffix(String mangaId, String language) =>
      '$mangaId.$language';

  static final RegExp _languageCode = RegExp(r'^[a-z]{2,3}(-[a-z]{2,4})?$');

  static bool _looksLikeLanguage(String segment) =>
      _languageCode.hasMatch(segment.toLowerCase());

  /// The plain manga id with any language suffix removed.
  static String baseIdOf(String mangaId) {
    final dot = mangaId.lastIndexOf('.');
    if (dot <= 0) return mangaId;
    final tail = mangaId.substring(dot + 1);
    return _looksLikeLanguage(tail) ? mangaId.substring(0, dot) : mangaId;
  }

  /// The language suffix of a manga id, or null when it has none.
  static String? suffixOf(String mangaId) {
    final dot = mangaId.lastIndexOf('.');
    if (dot <= 0 || dot == mangaId.length - 1) return null;
    final tail = mangaId.substring(dot + 1);
    return _looksLikeLanguage(tail) ? tail : null;
  }
}
