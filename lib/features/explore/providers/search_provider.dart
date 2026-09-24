import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/core/utils/concurrent.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/models/manga_source.dart';
import 'package:yomou/data/providers/sources_provider.dart';

/// Searches manga by query text against the active source.
///
/// If the query exactly matches a known genre/theme tag, it searches by tag
/// (genre chips on the search screen rely on this). Otherwise it does a
/// free-text title search.
final searchResultsProvider = FutureProvider.family<List<Manga>, String>((
  ref,
  query,
) async {
  final source = ref.watch(currentSourceProvider);
  final trimmed = query.trim();
  if (trimmed.isEmpty) return [];

  // Kick off the title search and the tag-based search concurrently. The tag
  // lookup (and its genre results) only ever wins if it resolves *first*, so
  // a cold tag cache can never delay the (common) free-text results.
  final titleFuture = SourceCache.mangaList(
    sourceId: source.id,
    kind: 'title',
    arg: trimmed.toLowerCase(),
    page: 1,
    fetch: () => source.searchByTitle(trimmed),
  );
  final tagFuture = SourceCache.tags(
    sourceId: source.id,
    fetch: source.getAvailableTags,
  ).then<List<Manga>?>(
    (tags) async {
      final exactTag = tags
          .where((t) => t.toLowerCase() == trimmed.toLowerCase())
          .toList();
      if (exactTag.isEmpty) return null;
      final matches = await SourceCache.mangaList(
        sourceId: source.id,
        kind: 'tags',
        arg: exactTag.join(',').toLowerCase(),
        page: 1,
        fetch: () => source.searchMangaByTags(exactTag),
      );
      return matches;
    },
    onError: (_, _) => null,
  );

  final winner = await Future.any<Object?>([
    titleFuture,
    tagFuture,
  ]);
  if (winner is List && winner.isNotEmpty) return winner as List<Manga>;
  return titleFuture;
});

/// Popular manga from the active source (used for "Trending" on the search
/// screen).
final trendingMangaProvider = FutureProvider<List<Manga>>((ref) async {
  final source = ref.watch(currentSourceProvider);
  return SourceCache.mangaList(
    sourceId: source.id,
    kind: 'popular',
    page: 1,
    fetch: source.getPopularManga,
  );
});

/// A single source's contribution to a global multi-source search.
class SourceSearchResult {
  final String sourceId;
  final String sourceName;
  final List<Manga> manga;
  final bool hasError;
  final String? errorMessage;

  const SourceSearchResult({
    required this.sourceId,
    required this.sourceName,
    this.manga = const [],
    this.hasError = false,
    this.errorMessage,
  });

  bool get hasResults => manga.isNotEmpty;
}

/// Global multi-source search.
///
/// Fans the query out to every implemented source in parallel and returns one
/// entry per source so the UI can group results under source headers. Sources
/// that return nothing or throw are reported (via [SourceSearchResult.hasError])
/// so callers can hide them by default and optionally reveal them.
///
/// The title fan-out and the genre/theme tag fan-out run concurrently; both are
/// bounded by a shared deadline so one slow source can't stall the whole page.
final globalSearchProvider =
    FutureProvider.family<List<SourceSearchResult>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return [];

      // Resolve enabled sources (dedupe by id).
      final sources = resolveActiveSources(ref.watch(visibleSourceRowsProvider));

      // Title search: the common path, started immediately.
      final titleFuture = _searchAllSources(
        sources,
        kind: 'title',
        arg: trimmed.toLowerCase(),
        fetch: (source) => source.searchByTitle(trimmed),
      );

      // Tag detection runs concurrently with the title search: if the query
      // exactly matches a genre/theme tag we prefer the targeted tag search.
      // A cold tag cache must never delay the (common) free-text results, so
      // tag detection carries its own short timeout.
      final tagFuture = Future<List<String>?>.sync(() async {
        try {
          final tags = await SourceCache.tags(
            sourceId: 'mangadex',
            fetch: () => getSourceByName('MangaDex').getAvailableTags(),
          ).timeout(const Duration(seconds: 2), onTimeout: () => const <String>[]);
          final match = tags
              .where((t) => t.toLowerCase() == trimmed.toLowerCase())
              .toList();
          return match.isNotEmpty ? match : null;
        } catch (_) {
          return null;
        }
      }).then<List<SourceSearchResult>>((exactTag) async {
        if (exactTag == null || exactTag.isEmpty) return const [];
        return _searchAllSources(
          sources,
          kind: 'tags',
          arg: exactTag.join(',').toLowerCase(),
          fetch: (source) => source.searchMangaByTags(exactTag),
        );
      });

      // Both fan-outs run in parallel; whichever resolves shows up first,
      // but targeted tag results win over plain title results when present.
      final titleResults = await titleFuture;
      final tagResults = await tagFuture;
      if (tagResults.any((s) => s.hasResults)) return tagResults;
      return titleResults;
    });

Future<List<SourceSearchResult>> _searchAllSources(
  List<MangaSource> sources, {
  required String kind,
  required String arg,
  required Future<List<Manga>> Function(MangaSource source) fetch,
}) async {
  return waitFastest(
    sources
        .map(
          (source) => SourceCache.mangaList(
            sourceId: source.id,
            kind: kind,
            arg: arg,
            page: 1,
            fetch: () => fetch(source),
          ).then(
            (manga) => SourceSearchResult(
              sourceId: source.id,
              sourceName: source.name,
              manga: manga,
            ),
            onError: (e) => SourceSearchResult(
              sourceId: source.id,
              sourceName: source.name,
              hasError: true,
              errorMessage: e.toString(),
            ),
          ),
        )
        .toList(),
    deadline: const Duration(seconds: 10),
  );
}
