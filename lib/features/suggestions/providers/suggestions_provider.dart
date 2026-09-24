import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/utils/concurrent.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/providers/sources_provider.dart';

/// Number of results the suggestions feed keeps after de-duplicating.
const _suggestionLimit = 40;

/// Per-source network budget, so one slow source can't stall the whole feed.
const _sourceTimeout = Duration(seconds: 12);

/// Fan-out window for a single feed build. Kept in sync with [_sourceTimeout]
/// so slow cold-start sources aren't dropped mid-flight, which would make the
/// feed "complete" emptily and flash a no-results state.
const _fanoutDeadline = Duration(seconds: 12);

/// Resolves the app's enabled sources from the registry rows, skipping the
/// mock source and collapsing duplicates that map to the same source id.
List<MangaSource> sourcesFromRows(List<Map<String, dynamic>> rows) =>
    resolveActiveSources(rows);

String _titleKey(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Merges per-source results round-robin so no single (richest) source can
/// fill the whole feed. Each pass takes one eligible item from every source,
/// skipping already-seen ids/titles, until the cap is reached or all lists
/// are exhausted. De-duplicating by title still collapses the same series
/// coming from several sources, keeping the first hit in order.
///
/// [seed] (default: now) rotates which source leads each pass and shuffles the
/// per-source queues, so re-opening the app or pulling to refresh yields a
/// visibly different arrangement even if the underlying lists are unchanged.
List<Manga> _mixSources(
  List<List<Manga>> perSource, {
  int limit = _suggestionLimit,
  int? seed,
}) {
  final rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
  final queues = perSource.map((l) => List<Manga>.of(l)..shuffle(rng)).toList();
  final seenIds = <String>{};
  final seenTitles = <String>{};
  final out = <Manga>[];

  // Skip empty sources so the rotation lands on a provider that has items.
  final live = queues.where((q) => q.isNotEmpty).toList();
  var start = live.isEmpty ? 0 : rng.nextInt(live.length);

  while (out.length < limit && live.any((q) => q.isNotEmpty)) {
    var addedAny = false;
    for (var k = 0; k < live.length; k++) {
      if (out.length >= limit) break;
      final queue = live[(start + k) % live.length];
      while (queue.isNotEmpty) {
        final manga = queue.removeAt(0);
        if (manga.id.isEmpty) continue;
        if (!seenIds.add('${manga.sourceId}:${manga.id}')) continue;
        final key = _titleKey(manga.title);
        if (key.isNotEmpty && !seenTitles.add(key)) continue;
        out.add(manga);
        addedAny = true;
        break;
      }
    }
    if (!addedAny) break;
    start = (start + 1) % live.length;
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
  final sources = sourcesFromRows(ref.watch(visibleSourceRowsProvider));
  if (sources.isEmpty) return [];

  if (genre != null) {
    final perSource = await waitFastest(
      sources.map((source) async {
        try {
          return await _tags(source, [genre]);
        } catch (_) {
          return <Manga>[];
        }
      }).toList(),
      deadline: _fanoutDeadline,
    );
    return _mixSources(perSource);
  }

  final topTags = await DatabaseHelper.instance.getUserTopTags(limit: 5);

  final perSource = await waitFastest(
    sources.map((source) async {
      try {
        if (topTags.isNotEmpty) {
          final matched = await _tags(source, topTags);
          if (matched.isNotEmpty) {
            return [matched];
          }
        }
        return [await _popular(source)];
      } catch (_) {
        return const <List<Manga>>[];
      }
    }).toList(),
    deadline: _fanoutDeadline,
  );

  return _mixSources(perSource.expand((lists) => lists).toList());
});

/// Genre/theme chips unioned across all active sources, so the filter strip
/// isn't limited to whichever source happens to be selected.
final genreTagsProvider = FutureProvider<List<String>>((ref) async {
  final sources = sourcesFromRows(ref.watch(visibleSourceRowsProvider));
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
