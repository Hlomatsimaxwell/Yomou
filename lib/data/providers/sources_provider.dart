import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/manga_source.dart';
import 'package:yomou/features/settings/providers/cache_settings_provider.dart';
import '../sources/manganato_service.dart';
import '../sources/mock_source.dart';
import '../sources/anime_api_source.dart';
import '../sources/manga_dex_source.dart'; // <--- 1. ADD THIS IMPORT
import '../sources/weebcentral_source.dart';
import '../sources/mangakatana_source.dart';
import '../sources/mangatown_source.dart';
import '../sources/arenascan_source.dart';
import '../sources/asurascans_source.dart';
import '../sources/comick_source.dart';
import '../sources/mgeko_source.dart';
import '../sources/likemanga_source.dart';

// 1. THE SOURCE REGISTRY
//
// Sources are cached per id so a single instance (and its lazy Dio client,
// HTTP connection pool and in-memory caches) is shared across every caller.
// Recreating a source per call used to throw away the connection pool each
// time, forcing a fresh TLS handshake + DNS lookup on every request.
final Map<String, MangaSource> _sourceInstances = {};

MangaSource _shared(String id, MangaSource Function() create) =>
    _sourceInstances.putIfAbsent(id, create);

MangaSource getSourceByName(String name) {
  switch (name) {
    case 'MangaDex': // <--- 2. ADD THIS CASE
      return _shared('mangadex', MangaDexSource.new);
    case 'WeebCentral':
      return _shared('weebcentral', WeebCentralSource.new);
    case 'MangaKatana':
      return _shared('mangakatana', MangakatanaSource.new);
    case 'MangaTown':
      return _shared('mangatown', MangatownSource.new);
    case 'Anime-API':
      return _shared('anime_api', AnimeApiSource.new);
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
    case 'Mock Source':
      return _shared('mock', MockSource.new);
    default:
      return _shared('mangadex', MangaDexSource.new); // Changed fallback to MangaDex
  }
}

// Lookup a source by its id (used to resolve which source a manga came from)
MangaSource? getSourceBySourceId(String sourceId) {
  switch (sourceId) {
    case 'mangadex':
      return getSourceByName('MangaDex');
    case 'anime_api':
      return getSourceByName('Anime-API');
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
      'name': 'Anime-API',
      'language': 'English',
      'bgColor': const Color(0xFF6200EE),
      'text': 'A',
      'iconUrl': 'https://anime-api.vercel.app/favicon.ico',
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

/// All source rows, minus any flagged NSFW when "Disable NSFW" is on. This is
/// the single gate every discovery surface should watch; library/update paths
/// keep using [sourcesProvider] so existing favorites are never hidden.
final visibleSourceRowsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final rows = ref.watch(sourcesProvider);
  final disableNsfw = ref.watch(disableNsfwProvider);
  if (!disableNsfw) return rows;
  return rows.where((row) => !isNsfwSource(row)).toList();
});
