import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Set once the welcome sheet has been completed.
///
/// Read on the first build to decide whether the sheet is presented at all, so
/// it stays a plain pref rather than living behind the async load of a
/// settings provider -- the sheet has to be decided before the home screen's
/// first frame, and waiting on a provider that is still loading would show the
/// home screen and then pop the welcome over it a beat later.
const String kWelcomeCompletedKey = 'onboarding.welcomeCompleted';

const String _languagesKey = 'onboarding.languages';
const String _formatsKey = 'onboarding.formats';

/// Formats a source row is allowed to declare.
///
/// These are the words the source registry already uses in its `language` tag
/// list -- a row reads `'Manga, Manhwa, Manhua, English'`, where the first
/// words are the formats the site publishes and the last is the scanlation
/// language. Keeping the vocabulary in step with that list is what makes the
/// "Type" section a real filter instead of a label with nothing behind it.
const List<String> kContentFormats = ['Manga', 'Manhwa', 'Manhua', 'Novel'];

/// Languages offered by the welcome sheet, in display order.
const List<String> kContentLanguages = [
  'English',
  'Spanish',
  'Portuguese',
  'French',
  'Japanese',
  'Korean',
  'Chinese',
  'Arabic',
  'Russian',
  'Italian',
  'German',
  'Indonesian',
];

/// Every language name the registry is known to declare.
///
/// Used only to tell "this row is in a language the reader did not pick" apart
/// from "this row declares no language at all". Komga's row says
/// `'Self-hosted (API)'` and the mock says `'Mock'`; neither is a scanlation
/// language, and filtering either out because someone chose English would hide
/// a library the user hosts themselves.
const Set<String> kKnownContentLanguages = {
  'albanian', 'arabic', 'bengali', 'bulgarian', 'catalan', 'chinese', 'czech',
  'danish', 'dutch', 'english', 'finnish', 'french', 'german', 'greek',
  'hebrew', 'hindi', 'hungarian', 'icelandic', 'indonesian', 'italian',
  'japanese', 'kannada', 'korean', 'malay', 'malayalam', 'nepali', 'norwegian',
  'persian', 'polish', 'portuguese', 'romanian', 'russian', 'serbian',
  'slovak', 'slovenian', 'spanish', 'swedish', 'tamil', 'thai', 'turkish',
  'ukrainian', 'vietnamese',
};

final Set<String> _formatTags =
    kContentFormats.map((f) => f.toLowerCase()).toSet();

/// The reader's content preferences: which languages they read and which
/// formats they care about.
///
/// Empty selections mean "no preference" and filter nothing, so the sheet can
/// never lock a reader out of a source by accident.
class ContentPreferences {
  const ContentPreferences({
    this.languages = const {},
    this.formats = const {},
  });

  final Set<String> languages;
  final Set<String> formats;

  ContentPreferences copyWith({
    Set<String>? languages,
    Set<String>? formats,
  }) {
    return ContentPreferences(
      languages: languages ?? this.languages,
      formats: formats ?? this.formats,
    );
  }

  /// Whether a source row survives these preferences.
  bool accepts(Map<String, dynamic> row) => acceptsSourceRow(row, this);
}

/// Splits a source row's `language` string into its lowercase tag set.
///
/// Rows that carry no `language` key at all come back empty.
Set<String> languageTagsOf(Map<String, dynamic> row) {
  final raw = row['language'];
  if (raw is! String || raw.trim().isEmpty) return const {};
  return raw
      .split(',')
      .map((t) => t.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toSet();
}

/// Whether [row] belongs to a reader with these [prefs].
///
/// A row is hidden only when it positively contradicts the choice:
/// - it declares formats and none of them were picked, or
/// - it declares languages and none of them were picked.
///
/// Rows that declare neither (self-hosted servers, the mock source, and rows
/// written before either field existed) always pass.
bool acceptsSourceRow(Map<String, dynamic> row, ContentPreferences prefs) {
  // Selections are stored in display casing ("Portuguese (BR)") and the tags
  // off a source row are lowercased, so both sides meet in lowercase. Comparing
  // them as-stored matches nothing at all, which reads as "the filter is
  // broken" rather than as an obvious case bug.
  final wantedFormats = prefs.formats.map((f) => f.toLowerCase()).toSet();
  final wantedLanguages = prefs.languages.map((l) => l.toLowerCase()).toSet();

  final tags = languageTagsOf(row);
  final rowFormats = tags.where(_formatTags.contains).toSet();
  final rowLanguages = tags.difference(rowFormats);

  if (wantedFormats.isNotEmpty &&
      rowFormats.isNotEmpty &&
      !rowFormats.any(wantedFormats.contains)) {
    return false;
  }

  if (wantedLanguages.isNotEmpty && rowLanguages.isNotEmpty) {
    // Only rows naming a language we recognise are filtered. Anything else is
    // declaring something this filter does not understand, and guessing it
    // away would hide sources for no reason the reader can see.
    if (!rowLanguages.any(
      (tag) => languageTagMatches(tag, kKnownContentLanguages),
    )) {
      return true;
    }
    if (!rowLanguages.any((tag) => languageTagMatches(tag, wantedLanguages))) {
      return false;
    }
  }

  return true;
}

/// Whether a source row's language tag is covered by [wanted].
///
/// Handles the parenthetical spellings the registry uses for regional
/// variants: `"portuguese (br)"` is still Portuguese, and reading it as an
/// unrecognised language would both hide it from a Portuguese reader and let
/// it through every filter as a wildcard.
bool languageTagMatches(String tag, Set<String> wanted) {
  if (wanted.contains(tag)) return true;
  final paren = tag.indexOf(' (');
  return paren > 0 && wanted.contains(tag.substring(0, paren));
}

/// Whether the welcome sheet has already been completed on this install.
Future<bool> isWelcomeCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kWelcomeCompletedKey) ?? false;
}

/// Records the welcome sheet as done so it is never shown again.
Future<void> markWelcomeCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kWelcomeCompletedKey, true);
}

class ContentPreferencesNotifier extends StateNotifier<ContentPreferences> {
  ContentPreferencesNotifier() : super(const ContentPreferences()) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = ContentPreferences(
      languages: (p.getStringList(_languagesKey) ?? const []).toSet(),
      formats: (p.getStringList(_formatsKey) ?? const []).toSet(),
    );
  }

  /// Adds or removes [value] from the language selection and persists it.
  ///
  /// Applied immediately rather than on save: the same editor backs both the
  /// welcome sheet and the settings screen, and a picker that only commits on
  /// a button press would silently drop its changes when the settings route
  /// underneath it is popped.
  void toggleLanguage(String value) => _toggle(state.languages, value, true);

  void toggleFormat(String value) => _toggle(state.formats, value, false);

  void _toggle(Set<String> current, String value, bool isLanguage) {
    final next = {...current};
    if (!next.remove(value)) next.add(value);
    state = isLanguage
        ? state.copyWith(languages: next)
        : state.copyWith(formats: next);
    _persist();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_languagesKey, state.languages.toList());
    await p.setStringList(_formatsKey, state.formats.toList());
  }
}

final contentPreferencesProvider =
    StateNotifierProvider<ContentPreferencesNotifier, ContentPreferences>(
      (ref) => ContentPreferencesNotifier(),
    );
