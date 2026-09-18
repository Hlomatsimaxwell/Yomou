import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/providers/sources_provider.dart';

/// Number of results the suggestions feed keeps after de-duplicating.
const _suggestionLimit = 40;

/// Per-source network budget, so one slow source can't stall the whole feed.
const _sourceTimeout = Duration(seconds: 12);

/// Resolves the app's enabled sources from the registry rows, skipping the
/// mock source and collapsing duplicates that map to the same source id.
List<MangaSource> sourcesFromRows(List<Map<String, dynamic>> rows) =>
    resolveActiveSources(rows);

String _titleKey(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// De-duplicates by source+id and by normalized title, preserving order, and
/// caps the result. This lets the same series coming from several sources
/// collapse to one entry while keeping the first (highest-priority) hit.
List<Manga> _dedupe(Iterable<Manga> items, {int limit = _suggestionLimit}) {
  final seenIds = <String>{};
  final seenTitles = <String>{};
  final out = <Manga>[];
  for (final manga in items) {
    if (manga.id.isEmpty) continue;
    if (!seenIds.add('${manga.sourceId}:${manga.id}')) continue;
    final key = _titleKey(manga.title);
    if (key.isNotEmpty && !seenTitles.add(key)) continue;
    out.add(manga);
    if (out.length >= limit) break;
  }
  return out;
}

Future<List<Manga>> _tags(MangaSource source, List<String> tags) {
  return SourceCache.mangaList(
    sourceId: source.id,
    kind: 'tags',
    arg: tags.join(',').toLowerCase(),
    page: 1,
    fetch: () => source.searchMangaByTags(tags),
  ).timeout(_sourceTimeout, onTimeout: () => const []);
}

Future<List<Manga>> _popular(MangaSource source) {
  return SourceCache.mangaList(
    sourceId: source.id,
    kind: 'popular',
    page: 1,
    fetch: () => source.getPopularManga(page: 1),
  ).timeout(_sourceTimeout, onTimeout: () => const []);
}

/// Suggestion feed aggregated across every active source.
///
/// - A specific [genre] searches that genre on all sources; an empty result is
///   valid, so the UI can show a "no results for this genre" state.
/// - With no genre, taste is derived from the tags of manga the user has
///   actually opened (history + favorites). A fresh install has no such tags,
///   so the feed starts as popular-across-sources and leans toward the user's
///   genres as they read. Sources that match the taste tags contribute those
///   first; the rest fill in with their popular list.
final suggestionsProvider = FutureProvider.family<List<Manga>, String?>((
  ref,
  genre,
) async {
  final sources = sourcesFromRows(ref.watch(sourcesProvider));
  if (sources.isEmpty) return [];

  if (genre != null) {
    final perSource = await Future.wait(
      sources.map((source) async {
        try {
          return await _tags(source, [genre]);
        } catch (_) {
          return <Manga>[];
        }
      }),
    );
    return _dedupe(perSource.expand((list) => list));
  }

  final topTags = await DatabaseHelper.instance.getUserTopTags(limit: 5);

  final perSource = await Future.wait(
    sources.map((source) async {
      try {
        if (topTags.isNotEmpty) {
          final matched = await _tags(source, topTags);
          if (matched.isNotEmpty) {
            return (taste: matched, fill: const <Manga>[]);
          }
        }
        return (taste: const <Manga>[], fill: await _popular(source));
      } catch (_) {
        return (taste: const <Manga>[], fill: const <Manga>[]);
      }
    }),
  );

  return _dedupe([
    ...perSource.expand((r) => r.taste),
    ...perSource.expand((r) => r.fill),
  ]);
});

/// Genre/theme chips unioned across all active sources, so the filter strip
/// isn't limited to whichever source happens to be selected.
final genreTagsProvider = FutureProvider<List<String>>((ref) async {
  final sources = sourcesFromRows(ref.watch(sourcesProvider));
  final perSource = await Future.wait(
    sources.map((source) async {
      try {
        return await SourceCache.tags(
          sourceId: source.id,
          fetch: source.getAvailableTags,
        ).timeout(_sourceTimeout, onTimeout: () => const []);
      } catch (_) {
        return <String>[];
      }
    }),
  );

  final seen = <String>{};
  final tags = <String>[];
  for (final tag in perSource.expand((list) => list)) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && seen.add(trimmed.toLowerCase())) {
      tags.add(trimmed);
    }
  }
  tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return tags;
});
