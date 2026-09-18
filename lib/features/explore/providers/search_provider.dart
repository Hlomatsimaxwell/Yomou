import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/data/models/manga.dart';
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

  // Genre/theme match -> tag search.
  final tags = await SourceCache.tags(
    sourceId: source.id,
    fetch: source.getAvailableTags,
  );
  final exactTag = tags
      .where((t) => t.toLowerCase() == trimmed.toLowerCase())
      .toList();
  if (exactTag.isNotEmpty) {
    final results = await SourceCache.mangaList(
      sourceId: source.id,
      kind: 'tags',
      arg: exactTag.join(',').toLowerCase(),
      page: 1,
      fetch: () => source.searchMangaByTags(exactTag),
    );
    if (results.isNotEmpty) return results;
  }

  // Otherwise -> free-text title search.
  return SourceCache.mangaList(
    sourceId: source.id,
    kind: 'title',
    arg: trimmed.toLowerCase(),
    page: 1,
    fetch: () => source.searchByTitle(trimmed),
  );
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
final globalSearchProvider =
    FutureProvider.family<List<SourceSearchResult>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return [];

      // Resolve enabled sources (dedupe by id).
      final sources = resolveActiveSources(ref.watch(sourcesProvider));

      // Tag detection: if the query exactly matches a genre/theme tag, search by
      // tag on every source; otherwise fall back to free-text title search.
      List<String>? exactTag;
      try {
        final tags = await SourceCache.tags(
          sourceId: 'mangadex',
          fetch: () => getSourceByName('MangaDex').getAvailableTags(),
        );
        final match = tags
            .where((t) => t.toLowerCase() == trimmed.toLowerCase())
            .toList();
        if (match.isNotEmpty) exactTag = match;
      } catch (_) {
        // Ignore tag detection failures; fall through to title search.
      }

      final results = await Future.wait(
        sources.map((source) async {
          try {
            final manga = await SourceCache.mangaList(
              sourceId: source.id,
              kind: exactTag != null ? 'tags' : 'title',
              arg: exactTag != null
                  ? exactTag.join(',').toLowerCase()
                  : trimmed.toLowerCase(),
              page: 1,
              fetch: () => exactTag != null
                  ? source.searchMangaByTags(exactTag)
                  : source.searchByTitle(trimmed),
            );
            return SourceSearchResult(
              sourceId: source.id,
              sourceName: source.name,
              manga: manga,
            );
          } catch (e) {
            return SourceSearchResult(
              sourceId: source.id,
              sourceName: source.name,
              hasError: true,
              errorMessage: e.toString(),
            );
          }
        }),
      );

      return results;
    });
