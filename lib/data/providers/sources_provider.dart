import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/manga_source.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import 'package:yomou/features/content_preferences/providers/content_preferences_provider.dart';
import '../sources/mangaball_source.dart';
import '../sources/manganato_service.dart';
import '../sources/mock_source.dart';
import '../sources/manga_dex_source.dart';
import '../sources/weebcentral_source.dart';
import '../sources/mangakatana_source.dart';
import '../sources/mangatown_source.dart';
import '../sources/arenascan_source.dart';
import '../sources/asurascans_source.dart';
import '../sources/comick_source.dart';
import '../sources/mgeko_source.dart';
import '../sources/likemanga_source.dart';
import '../sources/toonily_source.dart';
import '../sources/reaperscans_source.dart';
import '../sources/mangapill_source.dart';
import '../sources/manhwa18_source.dart';
import '../sources/flame_source.dart';
import '../sources/komga_source.dart';
import '../sources/mangabat_source.dart';
import '../sources/mangafire_source.dart';
import '../sources/manhuaplus_source.dart';

// 1. THE SOURCE REGISTRY
//
// Sources are cached per id so a single instance (and its lazy Dio client,
// HTTP connection pool and in-memory caches) is shared across every caller.
// Recreating a source per call used to throw away the connection pool each
// time, forcing a fresh TLS handshake + DNS lookup on every request.
final Map<String, MangaSource> _sourceInstances = {};

MangaSource _shared(String id, MangaSource Function() create) =>
    _sourceInstances.putIfAbsent(id, create);

/// MangaBall publishes one variant per site language, all served by the same
/// API and filtered by `filters[translatedLanguage][]`, so the variants are
/// generated from this table instead of 41 hand-written cases.
const Map<String, String> kMangaBallLanguages = {
  'ar': 'Arabic',
  'bg': 'Bulgarian',
  'bn': 'Bengali',
  'ca': 'Catalan',
  'cs': 'Czech',
  'da': 'Danish',
  'de': 'German',
  'el': 'Greek',
  'en': 'English',
  'es': 'Spanish',
  'fa': 'Persian',
  'fi': 'Finnish',
  'fr': 'French',
  'he': 'Hebrew',
  'hi': 'Hindi',
  'hu': 'Hungarian',
  'id': 'Indonesian',
  'it': 'Italian',
  'is': 'Icelandic',
  'ja': 'Japanese',
  'ko': 'Korean',
  'kn': 'Kannada',
  'ml': 'Malayalam',
  'ms': 'Malay',
  'ne': 'Nepali',
  'nl': 'Dutch',
  'no': 'Norwegian',
  'pl': 'Polish',
  'pt': 'Portuguese',
  'ro': 'Romanian',
  'ru': 'Russian',
  'sk': 'Slovak',
  'sl': 'Slovenian',
  'sq': 'Albanian',
  'sr': 'Serbian',
  'sv': 'Swedish',
  'ta': 'Tamil',
  'th': 'Thai',
  'tr': 'Turkish',
  'uk': 'Ukrainian',
  'vi': 'Vietnamese',
  'zh': 'Chinese',
};

/// Reverse of [kMangaBallLanguages]: the source list stores display names, so
/// a variant is resolved by the language name it shows.
final Map<String, String> kMangaBallCodesByLanguage = {
  for (final e in kMangaBallLanguages.entries) e.value: e.key,
};

MangaSource? _mangaBallByName(String name) {
  if (!name.startsWith('MangaBall ')) return null;
  final language = name.substring('MangaBall '.length);
  final code = kMangaBallCodesByLanguage[language];
  if (code == null) return null;
  final id = 'mangaball-$code';
  return _shared(
    id,
    () => MangaBallSource(sourceId: id, displayName: name, langCode: code),
  );
}

MangaSource getSourceByName(String name) {
  switch (name) {
    case 'MangaDex': // <--- 2. ADD THIS CASE
      return _shared('mangadex', MangaDexSource.new);
    case 'MangaDex Español':
      return _shared(
        'mangadex-es',
        () => MangaDexSource(
          sourceId: 'mangadex-es',
          displayName: 'MangaDex Español',
          langCode: 'es',
        ),
      );
    case 'MangaDex Portuguese BR':
      return _shared(
        'mangadex-ptbr',
        () => MangaDexSource(
          sourceId: 'mangadex-ptbr',
          displayName: 'MangaDex Portuguese BR',
          langCode: 'pt-br',
        ),
      );
    case 'WeebCentral':
      return _shared('weebcentral', WeebCentralSource.new);
    case 'MangaKatana':
      return _shared('mangakatana', MangakatanaSource.new);
    case 'MangaTown':
      return _shared('mangatown', MangatownSource.new);
    case 'Manganato':
      return _shared('manganato', ManganatoService.new);
    case 'Arenascan':
      return _shared('arenascan', ArenascanSource.new);
    case 'Asura Scans':
      return _shared('asurascans', AsuraScansSource.new);
    case 'ComicK':
      return _shared('comick', ComickSource.new);
    case 'Mgeko':
      return _shared('mgeko', MgekoSource.new);
    case 'Like Manga':
      return _shared('likemanga', LikeMangaSource.new);
    case 'Toonily':
      return _shared('toonily', ToonilySource.new);
    case 'Reaper Scans':
      return _shared('reaperscans', ReaperScansSource.new);
    case 'ManhuaPlus':
      return _shared('manhuaplus', ManhuaPlusSource.new);
    case 'MangaPill':
      return _shared('mangapill', MangaPillSource.new);
    case 'Manhwa18':
      return _shared('manhwa18', Manhwa18Source.new);
    case 'Flame Scans':
      return _shared('flamescans', FlameScansSource.new);
    case 'Komga':
      return _shared('komga', KomgaSource.new);
    case 'MangaBat':
      return _shared('mangabat', MangaBatSource.new);
    case 'MangaFire English':
      return _shared(
        'mangafire-en',
        () => MangaFireSource(sourceId: 'mangafire-en', langCode: 'en'),
      );
    case 'MangaFire Spanish':
      return _shared(
        'mangafire-es',
        () => MangaFireSource(sourceId: 'mangafire-es', langCode: 'es'),
      );
    case 'MangaFire Spanish Latin':
      return _shared(
        'mangafire-esla',
        () => MangaFireSource(sourceId: 'mangafire-esla', langCode: 'es-la'),
      );
    case 'MangaFire French':
      return _shared(
        'mangafire-fr',
        () => MangaFireSource(sourceId: 'mangafire-fr', langCode: 'fr'),
      );
    case 'MangaFire Japanese':
      return _shared(
        'mangafire-ja',
        () => MangaFireSource(sourceId: 'mangafire-ja', langCode: 'ja'),
      );
    case 'MangaFire Portuguese':
      return _shared(
        'mangafire-pt',
        () => MangaFireSource(sourceId: 'mangafire-pt', langCode: 'pt'),
      );
    case 'MangaFire Portuguese Brazil':
      return _shared(
        'mangafire-ptbr',
        () => MangaFireSource(sourceId: 'mangafire-ptbr', langCode: 'pt-br'),
      );
    case 'Mock Source':
      return _shared('mock', MockSource.new);
    default:
      return _mangaBallByName(name) ??
          _shared(
            'mangadex',
            MangaDexSource.new,
          ); // Changed fallback to MangaDex
  }
}

// Lookup a source by its id (used to resolve which source a manga came from)
MangaSource? getSourceBySourceId(String sourceId) {
  if (sourceId.startsWith('mangaball-')) {
    // The map is keyed by code and holds the language name, so the code is
    // compared against the key. Matching the value instead never resolves,
    // which silently left every variant without details and chapters.
    final code = sourceId.substring('mangaball-'.length);
    for (final entry in kMangaBallLanguages.entries) {
      if (entry.key == code) {
        return _mangaBallByName('MangaBall ${entry.value}');
      }
    }
  }
  switch (sourceId) {
    case 'mangadex':
      return getSourceByName('MangaDex');
    case 'mangadex-es':
      return getSourceByName('MangaDex Español');
    case 'mangadex-ptbr':
      return getSourceByName('MangaDex Portuguese BR');
    case 'weebcentral':
      return getSourceByName('WeebCentral');
    case 'mangakatana':
      return getSourceByName('MangaKatana');
    case 'mangatown':
      return getSourceByName('MangaTown');
    case 'arenascan':
      return getSourceByName('Arenascan');
    case 'asurascans':
      return getSourceByName('Asura Scans');
    case 'comick':
      return getSourceByName('ComicK');
    case 'mgeko':
      return getSourceByName('Mgeko');
    case 'likemanga':
      return getSourceByName('Like Manga');
    case 'toonily':
      return getSourceByName('Toonily');
    case 'reaperscans':
      return getSourceByName('Reaper Scans');
    case 'manhuaplus':
      return getSourceByName('ManhuaPlus');
    case 'mangapill':
      return getSourceByName('MangaPill');
    case 'manhwa18':
      return getSourceByName('Manhwa18');
    case 'flamescans':
      return getSourceByName('Flame Scans');
    case 'komga':
      return getSourceByName('Komga');
    case 'mangabat':
      return getSourceByName('MangaBat');
    case 'mangafire-en':
      return getSourceByName('MangaFire English');
    case 'mangafire-es':
      return getSourceByName('MangaFire Spanish');
    case 'mangafire-esla':
      return getSourceByName('MangaFire Spanish Latin');
    case 'mangafire-fr':
      return getSourceByName('MangaFire French');
    case 'mangafire-ja':
      return getSourceByName('MangaFire Japanese');
    case 'mangafire-pt':
      return getSourceByName('MangaFire Portuguese');
    case 'mangafire-ptbr':
      return getSourceByName('MangaFire Portuguese Brazil');
    case 'manganato':
      return getSourceByName('Manganato');
    case 'mock':
      return getSourceByName('Mock Source');
    default:
      return null;
  }
}

// 2. DYNAMIC ACTIVE SOURCE
final currentSourceProvider = StateProvider<MangaSource>((ref) {
  // 3. SET DEFAULT TO MANGADEX so you can test immediately!
  return getSourceByName('MangaDex');
});

/// A source is enabled unless explicitly disabled. Older saved preference
/// lists have no `isEnabled` key, so they default to enabled.
bool isSourceEnabled(Map<String, dynamic> source) =>
    source['isEnabled'] != false;

/// Resolves the usable source objects from the registry rows: enabled only,
/// skipping the mock source and collapsing rows that map to the same id.
List<MangaSource> resolveActiveSources(List<Map<String, dynamic>> rows) {
  final seen = <String>{};
  final list = <MangaSource>[];
  for (final row in rows) {
    if (!isSourceEnabled(row)) continue;
    final name = row['name'] as String? ?? '';
    if (name.isEmpty || name == 'Mock Source') continue;
    final source = getSourceByName(name);
    if (seen.add(source.id)) list.add(source);
  }
  return list;
}

/// The family a source id belongs to: `mangaball-pt` -> `mangaball`. Sources
/// without a language suffix (single-variant sites) are their own family and
/// are never bounded.
String sourceFamilyOf(String sourceId) {
  final dash = sourceId.indexOf('-');
  return dash <= 0 ? sourceId : sourceId.substring(0, dash);
}

/// Bounds a multi-variant family so fan-outs (suggestions feed, search) do not
/// queue every language version of the same site.
///
/// MangaBall registers one source per language (currently 42), and every
/// variant talks to the same site — through the app's *single* WebView for the
/// JS-gated calls. Firing the whole family at once queues ~1.7s of in-page
/// work per variant, a ~70s backlog that the reader's chapter loads also queue
/// behind, and most of the queued calls never finish inside a fan-out window
/// anyway (each variant's per-source timeout starts before its turn in the
/// queue). Keeping an even spread of [maxPerFamily] variants preserves
/// language variety while cutting that backlog to seconds.
///
/// Every family is spread independently (see [_spreadSourcesFamily]) so one
/// oversized site doesn't crowd out the languages of another.
List<MangaSource> boundVariantFamilies(
  List<MangaSource> sources, {
  int maxPerFamily = 8,
}) {
  final byFamily = <String, List<MangaSource>>{};
  for (final s in sources) {
    byFamily.putIfAbsent(sourceFamilyOf(s.id), () => []).add(s);
  }
  final out = <MangaSource>[];
  for (final family in byFamily.values) {
    if (family.length <= maxPerFamily) {
      out.addAll(family);
    } else {
      out.addAll(_spreadSourcesFamily(family, maxPerFamily));
    }
  }
  return out;
}

/// Evenly spreads at most [limit] picks across [items] instead of truncating
/// the head, so a bounded subset isn't decided by registry order.
List<T> _spreadSourcesFamily<T>(List<T> items, int limit) {
  if (items.length <= limit) return items;
  final step = items.length / limit;
  return [for (var i = 0; i < limit; i++) items[(i * step).floor()]];
}

/// Source ids that the user has explicitly disabled in the registry rows.
Set<String> disabledSourceIds(List<Map<String, dynamic>> rows) {
  final ids = <String>{};
  for (final row in rows) {
    if (isSourceEnabled(row)) continue;
    final name = row['name'] as String? ?? '';
    if (name.isNotEmpty) ids.add(getSourceByName(name).id);
  }
  return ids;
}

/// Resolves the source registry rows saved in prefs, falling back to the
/// built-in defaults when the user never customized the list. Background
/// tasks rely on this so they work on a fresh install.
List<Map<String, dynamic>> sourceRowsFromPrefs(SharedPreferences prefs) {
  final raw = prefs.getString('pinned_sources_list');
  if (raw != null) {
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
  }
  return SourcesNotifier.defaultSources;
}

class SourcesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  SourcesNotifier() : super(defaultSources) {
    _loadFromPrefs();
  }

  static const String _prefsKey = 'pinned_sources_list';

  /// The built-in source list used before the user customizes the registry
  /// (or when nothing was saved yet).
  static final List<Map<String, dynamic>> defaultSources = [
    {
      'name': 'MangaBall Arabic',
      'language': 'Manga, Arabic',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Bulgarian',
      'language': 'Manga, Bulgarian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Bengali',
      'language': 'Manga, Bengali',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Catalan',
      'language': 'Manga, Catalan',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Czech',
      'language': 'Manga, Czech',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Danish',
      'language': 'Manga, Danish',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall German',
      'language': 'Manga, German',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Greek',
      'language': 'Manga, Greek',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall English',
      'language': 'Manga, English',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Spanish',
      'language': 'Manga, Spanish',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Persian',
      'language': 'Manga, Persian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Finnish',
      'language': 'Manga, Finnish',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall French',
      'language': 'Manga, French',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Hebrew',
      'language': 'Manga, Hebrew',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Hindi',
      'language': 'Manga, Hindi',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Hungarian',
      'language': 'Manga, Hungarian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Indonesian',
      'language': 'Manga, Indonesian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Italian',
      'language': 'Manga, Italian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Icelandic',
      'language': 'Manga, Icelandic',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Japanese',
      'language': 'Manga, Japanese',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Korean',
      'language': 'Manga, Korean',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Kannada',
      'language': 'Manga, Kannada',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Malayalam',
      'language': 'Manga, Malayalam',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Malay',
      'language': 'Manga, Malay',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Nepali',
      'language': 'Manga, Nepali',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Dutch',
      'language': 'Manga, Dutch',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Norwegian',
      'language': 'Manga, Norwegian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Polish',
      'language': 'Manga, Polish',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Portuguese',
      'language': 'Manga, Portuguese',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Romanian',
      'language': 'Manga, Romanian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Russian',
      'language': 'Manga, Russian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Slovak',
      'language': 'Manga, Slovak',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Slovenian',
      'language': 'Manga, Slovenian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Albanian',
      'language': 'Manga, Albanian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Serbian',
      'language': 'Manga, Serbian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Swedish',
      'language': 'Manga, Swedish',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Tamil',
      'language': 'Manga, Tamil',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Thai',
      'language': 'Manga, Thai',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Turkish',
      'language': 'Manga, Turkish',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Ukrainian',
      'language': 'Manga, Ukrainian',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Vietnamese',
      'language': 'Manga, Vietnamese',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaBall Chinese',
      'language': 'Manga, Chinese',
      'bgColor': const Color(0xFF1E88E5),
      'text': 'MB',
      'iconUrl': 'https://mangaball.com/images/favicon.png',
      'isPinned': false,
    },
    {
      'name': 'MangaDex', // Moved to top for easier testing
      'language': 'Manga, Various languages',
      'bgColor': const Color(0xFF381F1D),
      'text': '🐱',
      'textColor': Colors.orangeAccent,
      'iconUrl': 'https://mangadex.org/favicon.ico',
      'isPinned': true,
      'nsfw': true,
    },
    {
      'name': 'MangaDex Español',
      'language': 'Manga, Spanish',
      'bgColor': const Color(0xFF381F1D),
      'text': '🐱',
      'textColor': Colors.orangeAccent,
      'iconUrl': 'https://mangadex.org/favicon.ico',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'MangaDex Portuguese BR',
      'language': 'Manga, Portuguese (BR)',
      'bgColor': const Color(0xFF381F1D),
      'text': '🐱',
      'textColor': Colors.orangeAccent,
      'iconUrl': 'https://mangadex.org/favicon.ico',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'WeebCentral',
      'language': 'Manga, Manhwa, Manhua, English',
      'bgColor': const Color(0xFF334155),
      'text': 'W',
      'iconUrl': 'https://weebcentral.com/favicon.ico',
      'isPinned': true,
    },
    {
      'name': 'MangaKatana',
      'language': 'Manga, Manhwa, Manhua, English',
      'bgColor': const Color(0xFF003C8F),
      'text': 'K',
      'iconUrl': 'https://mangakatana.com/favicon.ico',
      'isPinned': true,
    },
    {
      'name': 'MangaTown',
      'language': 'Manga, Manhwa, Manhua, English',
      'bgColor': const Color(0xFF7A1F1F),
      'text': 'M',
      'iconUrl': 'https://www.mangatown.com/favicon.ico',
      'isPinned': true,
    },
    {
      'name': 'Manganato',
      'language': 'English',
      'bgColor': const Color(0xFFE67E22),
      'text': 'M',
      'iconUrl': 'https://manganato.com/favicon.ico',
      'isPinned': true,
    },
    {
      'name': 'Arenascan',
      'language': 'Manhwa, Manhua, English',
      'bgColor': const Color(0xFF5A2DA6),
      'text': 'A',
      'iconUrl': 'https://arenascan.com/favicon.ico',
      'isPinned': false,
    },
    {
      'name': 'Asura Scans',
      'language': 'Manhwa, Manhua, English',
      'bgColor': const Color(0xFFDB0032),
      'text': 'A',
      'iconUrl': 'https://asurascans.com/favicon.ico',
      'isPinned': false,
    },
    {
      'name': 'Mgeko',
      'language': 'Manhwa, Manhua, English',
      'bgColor': const Color(0xFF0F766E),
      'text': 'M',
      'iconUrl': 'https://mgeko.cc/static/img/logo_200x200.png',
      'isPinned': false,
    },
    {
      'name': 'Like Manga',
      'language': 'Manhwa, Manhua, English',
      'bgColor': const Color(0xFFB4345C),
      'text': 'L',
      'iconUrl': 'https://likemanga.ink/favicon.ico',
      'isPinned': false,
    },
    {
      'name': 'Mock Source',
      'language': 'Mock',
      'bgColor': const Color(0xFF95A5A6),
      'text': '?',
      'iconUrl': '',
      'isPinned': false,
    },
    {
      'name': 'Toonily',
      'language': 'Manhwa, Manhua, English',
      'bgColor': const Color(0xFF7A1F2B),
      'text': 'T',
      'iconUrl':
          'https://static.tnlycdn.com/2017/10/toonily_favicon2-300x300.png',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'Reaper Scans',
      'language': 'Manhwa, Manhua, English',
      'bgColor': const Color(0xFFDB0032),
      'text': 'R',
      'iconUrl': 'https://reaperscans.com/favicon.ico',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'ManhuaPlus',
      'language': 'Manhua, English',
      'bgColor': const Color(0xFFE23D28),
      'text': 'M',
      'iconUrl':
          'https://manhuaplus.com/wp-content/uploads/2020/07/cropped-manhua-vuong-den-1-192x192.jpg',
      'isPinned': false,
    },
    {
      'name': 'MangaPill',
      'language': 'Manga, English',
      'bgColor': const Color(0xFF2563EB),
      'text': 'P',
      'iconUrl': 'https://mangapill.com/favicon.ico',
      'isPinned': false,
    },
    {
      'name': 'Manhwa18',
      'language': 'Manhwa, Manhua, English',
      'bgColor': const Color(0xFFB4345C),
      'text': 'M',
      'iconUrl': 'https://manhwa18.com/favicon.ico',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'Flame Scans',
      'language': 'Manhwa, Manhua, English',
      'bgColor': const Color(0xFF101113),
      'text': 'F',
      'iconUrl': 'https://flamecomics.xyz/favicon.ico',
      'isPinned': false,
    },
    {
      'name': 'Komga',
      'language': 'Self-hosted (API)',
      'bgColor': const Color(0xFF334155),
      'text': 'K',
      'iconUrl': '',
      'isPinned': false,
      'isEnabled': false,
    },
    {
      'name': 'MangaBat',
      'language': 'Manga, English',
      'bgColor': const Color(0xFF9C27B0),
      'text': 'B',
      'iconUrl': 'https://www.mangabats.com/favicon.ico',
      'isPinned': false,
    },
    {
      'name': 'MangaFire English',
      'language': 'English',
      'bgColor': const Color(0xFFF97316),
      'text': 'F',
      'iconUrl': 'https://mangafire.to/assets/mangafire/logo.png',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'MangaFire Spanish',
      'language': 'Spanish',
      'bgColor': const Color(0xFFF97316),
      'text': 'F',
      'iconUrl': 'https://mangafire.to/assets/mangafire/logo.png',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'MangaFire Spanish Latin',
      'language': 'Spanish (Latin)',
      'bgColor': const Color(0xFFF97316),
      'text': 'F',
      'iconUrl': 'https://mangafire.to/assets/mangafire/logo.png',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'MangaFire French',
      'language': 'French',
      'bgColor': const Color(0xFFF97316),
      'text': 'F',
      'iconUrl': 'https://mangafire.to/assets/mangafire/logo.png',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'MangaFire Japanese',
      'language': 'Japanese',
      'bgColor': const Color(0xFFF97316),
      'text': 'F',
      'iconUrl': 'https://mangafire.to/assets/mangafire/logo.png',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'MangaFire Portuguese',
      'language': 'Portuguese',
      'bgColor': const Color(0xFFF97316),
      'text': 'F',
      'iconUrl': 'https://mangafire.to/assets/mangafire/logo.png',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'MangaFire Portuguese Brazil',
      'language': 'Portuguese (Brazil)',
      'bgColor': const Color(0xFFF97316),
      'text': 'F',
      'iconUrl': 'https://mangafire.to/assets/mangafire/logo.png',
      'isPinned': false,
      'nsfw': true,
    },
    {
      'name': 'ComicK',
      'language': 'Manga, Various languages',
      'bgColor': const Color(0xFF2C2C2E),
      'text': '🦄',
      'iconUrl': 'https://comick.io/favicon.ico',
      'isPinned': false,
      'nsfw': true,
    },
  ];

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString(_prefsKey);

    if (savedJson != null) {
      final List<dynamic> decoded = jsonDecode(savedJson);
      final pinnedMap = <String, bool>{};
      final enabledMap = <String, bool>{};

      for (var item in decoded) {
        pinnedMap[item['name']] = item['isPinned'] ?? false;
        enabledMap[item['name']] = item['isEnabled'] ?? true;
      }

      final updatedList = state.map((source) {
        final name = source['name'] as String;
        return {
          ...source,
          'isPinned': pinnedMap[name] ?? false,
          'isEnabled': enabledMap[name] ?? true,
        };
      }).toList();

      state = _sortSources(updatedList);
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dataToSave = state
        .map(
          (source) => {
            'name': source['name'],
            'isPinned': source['isPinned'],
            'isEnabled': isSourceEnabled(source),
          },
        )
        .toList();

    await prefs.setString(_prefsKey, jsonEncode(dataToSave));
  }

  void togglePin(String sourceName) {
    final updatedList = state.map((source) {
      if (source['name'] == sourceName) {
        final currentPinned = source['isPinned'] == true;
        return {...source, 'isPinned': !currentPinned};
      }
      return source;
    }).toList();

    state = _sortSources(updatedList);
    _saveToPrefs();
  }

  void toggleEnabled(String sourceName) {
    final updatedList = state.map((source) {
      if (source['name'] == sourceName) {
        return {...source, 'isEnabled': !isSourceEnabled(source)};
      }
      return source;
    }).toList();

    state = _sortSources(updatedList);
    _saveToPrefs();
  }

  void moveToTop(String sourceName) {
    final index = state.indexWhere((s) => s['name'] == sourceName);
    if (index != -1) {
      final item = state[index];
      final newList = List<Map<String, dynamic>>.from(state)..removeAt(index);
      newList.insert(0, item);
      state = newList;
      _saveToPrefs();
    }
  }

  void enableAll() {
    state = state.map((source) {
      return {...source, 'isEnabled': true};
    }).toList();
    _saveToPrefs();
  }

  List<Map<String, dynamic>> _sortSources(List<Map<String, dynamic>> list) {
    final pinned = list.where((s) => s['isPinned'] == true).toList();
    final unpinned = list.where((s) => s['isPinned'] != true).toList();
    return [...pinned, ...unpinned];
  }
}

final sourcesProvider =
    StateNotifierProvider<SourcesNotifier, List<Map<String, dynamic>>>((ref) {
      return SourcesNotifier();
    });

/// A source row is NSFW when explicitly flagged. New sources added later only
/// need the `nsfw: true` flag to be filtered automatically.
bool isNsfwSource(Map<String, dynamic> source) => source['nsfw'] == true;

/// All source rows, minus any flagged NSFW when "Disable NSFW" is on, and
/// minus any contradicting the reader's content preferences (languages and
/// formats picked on the welcome sheet).
///
/// This is the single gate every discovery surface should watch; library/update
/// paths keep using [sourcesProvider] so existing favorites are never hidden.
final visibleSourceRowsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final rows = ref.watch(sourcesProvider);
  final disableNsfw = ref.watch(disableNsfwProvider);
  final content = ref.watch(contentPreferencesProvider);

  return rows.where((row) {
    if (disableNsfw && isNsfwSource(row)) return false;
    return content.accepts(row);
  }).toList();
});
