import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/notifications/suggestion_ranking.dart';
import 'package:yomou/core/providers/periodic_refresh_provider.dart';
import 'package:yomou/core/utils/concurrent.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/data/sources/webview_fetcher.dart';

List<String> _storedTagList(String? raw) {
  if (raw == null || raw.isEmpty || raw == '[]') return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [for (final e in decoded) if (e is String) e];
  } on Exception {
    return const [];
  }
}

/// Number of results the suggestions feed keeps after de-duplicating.
const _suggestionLimit = 160;

/// Per-source result cap.
const _perSourceCap = 20;

/// Raw fan-out pool size.
const _rawFanoutPool = 280;

/// Minimum results required.
const _minResults = 12;

/// Per-source network budget, so one slow source can't stall the whole feed.
const _sourceTimeout = Duration(seconds: 12);

/// Fan-out window for a single feed build. Kept in sync with [_sourceTimeout]
/// so a slow cold-start source is still given its full per-source budget.
///
/// A short window alone doesn't stop the feed resolving emptily - it just
/// makes it likely, because it also gives up on everything still in flight.
/// [_fanout] is what actually prevents that; see the note there.
const _fanoutDeadline = Duration(seconds: 12);

/// Extra window granted when a fan-out pass comes back with nothing useful.
/// The pass has already started every source by then, so this only waits
/// longer on work that is genuinely in flight; it never issues a second
/// request. See [_fanout] for why the first pass can resolve emptily.
const _fanoutRetryWindow = Duration(seconds: 20);

/// Genre chips are cosmetic - the strip renders empty while they load - and
/// this fan-out shares the same single-slot WebView queue as the feed. Firing
/// it at every source is what pushed the feed past [_fanoutDeadline] on a cold
/// cache, so it runs against a bounded subset instead.
const _maxGenreTagSources = 8;

/// Resolves the app's enabled sources from the registry rows, collapsing
/// duplicates that map to the same source id.
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

/// Runs a source fan-out that gives up on nothing.
///
/// A pass that comes back empty is provisional, not final: every source is
/// started before [_fanoutDeadline] expires, so on a cold cache the first
/// responses can land seconds after the window closes — the stragglers are
/// still running and are about to write to [SourceCache]. Resolving on the
/// first pass meant the feed settled on an empty list and the user had to pull
/// to refresh to see anything, even though the data was milliseconds away.
/// [_fanoutRetryWindow] buys those stragglers a second chance; see
/// [waitFastest] for why re-waiting the same futures is free.
///
/// A source that throws resolves to an empty result rather than hanging, so
/// "some future finished" is not the same as "we got something" — hence the
/// explicit [hasResult] rather than the default non-empty check.
Future<List<T>> _fanout<T>(
  List<Future<T>> futures, {
  required bool Function(List<T> results) hasResult,
  bool Function(List<T> results)? earlyResolve,
}) {
  return waitFastest(
    futures,
    deadline: _fanoutDeadline,
    grace: _fanoutRetryWindow,
    hasResult: hasResult,
    earlyResolve: earlyResolve,
  );
}

/// Evenly spreads at most [limit] picks across [items] instead of truncating
/// the head, so a bounded subset isn't decided by registry order.
///
/// Public because the Explore hero needs the same deal: it shows a bounded
/// number of the feed, and taking the first twelve of it put exactly the same
/// twelve covers on that card row as the Suggestions tab opens with.
List<T> spreadAcross<T>(List<T> items, int limit) {
  if (items.length <= limit) return items;
  final step = items.length / limit;
  return [for (var i = 0; i < limit; i++) items[(i * step).floor()]];
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
  // Re-roll the feed on a timer (recommendations + the Explore featured
  // carousel) without any interaction.
  ref.watch(periodicSuggestionsRefreshProvider);
  final sources = boundVariantFamilies(
    sourcesFromRows(ref.watch(visibleSourceRowsProvider)),
  );
  if (sources.isEmpty) return [];

  if (genre != null) {
    final perSource = await WebViewFetcher.runBackground(
      () => _fanout(
        sources.map((source) async {
          try {
            final res = await _tags(source, [genre]);
            return res.take(_perSourceCap).toList();
          } catch (_) {
            return <Manga>[];
          }
        }).toList(),
        hasResult: (per) => per.any((lists) => lists.isNotEmpty),
        // Several sources should be in before the feed shows: the first one in
        // alone gave a single-source-correct-looking feed once the WebView
        // variants started landing.
        earlyResolve: (per) =>
            per.where((lists) => lists.isNotEmpty).length >= 2,
      ),
    );
    return _mixSources(perSource);
  }

  final db = DatabaseHelper.instance;
  final history = await db.getHistory();
  final favorites = await db.getFavorites();

  final favouriteKeys = <String>{
    for (final row in favorites)
      if ((row['isFavorite'] as int? ?? 0) == 1)
        '${row['sourceId']?.toString() ?? ''}\u0000${row['mangaId']}'
  };

  final seenKeys = <String>{};
  final seedRows = <Map<String, dynamic>>[];
  void takeSeed(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      if (seedRows.length >= 40) break;
      final id = row['mangaId']?.toString();
      if (id == null || id.isEmpty) continue;
      final key = '${row['sourceId']?.toString() ?? ''}\u0000$id';
      if (!seenKeys.add(key)) continue;
      if (favouriteKeys.contains(key)) {
        seedRows.add(row);
        continue;
      }
      final total = (row['totalChapters'] as int?) ?? 0;
      double? percent;
      final lastReadChapter = (row['lastReadChapter'] as num?)?.toDouble() ?? 0;
      if (total > 0) {
        percent = (lastReadChapter.clamp(0.0, total.toDouble()) / total);
      }
      final lastReadAt = DateTime.tryParse(row['lastReadAt']?.toString() ?? '');
      if (isDropped(percent, lastReadAt, DateTime.now())) continue;
      seedRows.add(row);
    }
  }

  takeSeed(history.take(20).toList());
  final favSorted = [...favorites]
    ..sort((a, b) {
      final aAt = DateTime.tryParse(a['lastReadAt']?.toString() ?? '');
      final bAt = DateTime.tryParse(b['lastReadAt']?.toString() ?? '');
      return (bAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(aAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    });
  takeSeed(favSorted.take(20).toList());

  List<String> rankedTags = [];
  if (seedRows.isNotEmpty) {
    final corpus = TagStatistics.fromRows(await db.getMangaWithTags());
    final seedTags = <String>[
      for (final row in seedRows)
        ..._storedTagList(row['tags']?.toString() ?? '[]'),
    ];
    rankedTags = distinctiveTags(seedTags, corpus.rarity, 10);
  } else {
    rankedTags = await db.getUserTopTags(limit: 10);
  }

  final perSource = await WebViewFetcher.runBackground(
    () => _fanout(
      sources.map((source) async {
        try {
          if (rankedTags.isNotEmpty) {
            final matched = await _tags(source, rankedTags);
            if (matched.isNotEmpty) {
              return matched.take(_perSourceCap).toList();
            }
          }
          final pop = await _popular(source);
          return pop.take(_perSourceCap).toList();
        } catch (_) {
          return const <Manga>[];
        }
      }).toList(),
      hasResult: (per) => per.any((lists) => lists.isNotEmpty),
      earlyResolve: (per) =>
          per.where((lists) => lists.isNotEmpty).length >=
          _minResults.clamp(2, sources.length),
    ),
  );

  return _mixSources(perSource);
});

/// Genre/theme chips unioned across the active sources, so the filter strip
/// isn't limited to whichever source happens to be selected.
///
/// Bounded to [_maxGenreTagSources] sources and no per-source timeout: this
/// fan-out runs alongside the feed and competes with it for the WebView queue,
/// and it is the one that isn't worth starving anything for. The subset is
/// spread rather than truncated (see [spreadAcross]) so which sources get asked
/// is not decided by registry order. Chips read from disk once warm, so the
/// steady-state cost is a cache lookup per source.
final genreTagsProvider = FutureProvider<List<String>>((ref) async {
  // Bound each variant family first (42 MangaBall languages) so the spread
  // below actually samples across *sites* rather than mostly MangaBall.
  final sources = spreadAcross(
    boundVariantFamilies(sourcesFromRows(ref.watch(visibleSourceRowsProvider))),
    _maxGenreTagSources,
  );
  final perSource = await WebViewFetcher.runBackground(
    () => _fanout(
      sources.map((source) async {
        try {
          return await SourceCache.tags(
            sourceId: source.id,
            fetch: source.getAvailableTags,
          );
        } catch (_) {
          return const <String>[];
        }
      }).toList(),
      hasResult: (per) => per.any((tags) => tags.isNotEmpty),
      earlyResolve: (per) => per.where((tags) => tags.isNotEmpty).length >= 2,
    ),
  );

  final nsfwTags = const {'adult', 'hentai', 'smut', 'r18', 'nsfw', 'porn', 'ecchi', 'mature'};
  final seen = <String>{};
  final tags = <String>[];
  for (final tag in perSource.expand((list) => list)) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) continue;
    if (nsfwTags.contains(trimmed.toLowerCase())) continue;
    if (seen.add(trimmed.toLowerCase())) {
      tags.add(trimmed);
    }
  }
  tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return tags;
});
