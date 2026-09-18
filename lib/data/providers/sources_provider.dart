import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/manga_source.dart';
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
MangaSource getSourceByName(String name) {
  switch (name) {
    case 'MangaDex': // <--- 2. ADD THIS CASE
      return MangaDexSource();
    case 'WeebCentral':
      return WeebCentralSource();
    case 'MangaKatana':
      return MangakatanaSource();
    case 'MangaTown':
      return MangatownSource();
    case 'Anime-API':
      return AnimeApiSource();
    case 'Manganato':
      return ManganatoService();
    case 'Arenascan':
      return ArenascanSource();
    case 'Asura Scans':
      return AsuraScansSource();
    case 'ComicK':
      return ComickSource();
    case 'Mgeko':
      return MgekoSource();
    case 'Like Manga':
      return LikeMangaSource();
    case 'Mock Source':
      return MockSource();
    default:
      return MangaDexSource(); // Changed fallback to MangaDex
  }
}

// Lookup a source by its id (used to resolve which source a manga came from)
MangaSource? getSourceBySourceId(String sourceId) {
  switch (sourceId) {
    case 'mangadex':
      return MangaDexSource();
    case 'anime_api':
      return AnimeApiSource();
    case 'weebcentral':
      return WeebCentralSource();
    case 'mangakatana':
      return MangakatanaSource();
    case 'mangatown':
      return MangatownSource();
    case 'arenascan':
      return ArenascanSource();
    case 'asurascans':
      return AsuraScansSource();
    case 'comick':
      return ComickSource();
    case 'mgeko':
      return MgekoSource();
    case 'likemanga':
      return LikeMangaSource();
    case 'manganato':
      return ManganatoService();
    case 'mock':
      return MockSource();
    default:
      return null;
  }
}

// 2. DYNAMIC ACTIVE SOURCE
final currentSourceProvider = StateProvider<MangaSource>((ref) {
  // 3. SET DEFAULT TO MANGADEX so you can test immediately!
  return MangaDexSource();
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
