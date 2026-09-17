import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomou/core/database/database_helper.dart';
import 'package:yomou/core/database/source_cache.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/data/providers/sources_provider.dart';

/// Returns manga suggestions, optionally filtered by [genre].
///
/// When [genre] is set, returns manga matching that specific genre (possibly
/// empty), so the UI can show a "no results for this genre" state instead of
/// silently substituting unrelated results.
/// When [genre] is null, picks the user's top 5 tags from history/favorites,
/// falling back to popular manga when the source has no usable tags.
final suggestionsProvider = FutureProvider.family<List<Manga>, String?>((
  ref,
  genre,
) async {
  final source = ref.watch(currentSourceProvider);

  if (genre != null) {
    return SourceCache.mangaList(
      sourceId: source.id,
      kind: 'tags',
      arg: genre.toLowerCase(),
      page: 1,
      fetch: () => source.searchMangaByTags([genre]),
    );
  }

  // Personalised: use the user's most-read tags.
  final topTags = await DatabaseHelper.instance.getUserTopTags(limit: 5);
  if (topTags.isNotEmpty) {
    final results = await SourceCache.mangaList(
      sourceId: source.id,
      kind: 'tags',
      arg: topTags.join(',').toLowerCase(),
      page: 1,
      fetch: () => source.searchMangaByTags(topTags),
    );
    if (results.isNotEmpty) return results;
  }

  // Fallback: popular manga.
  return SourceCache.mangaList(
    sourceId: source.id,
    kind: 'popular',
    page: 1,
    fetch: () => source.getPopularManga(page: 1),
  );
});

/// The full genre/theme tag list from the active source.
/// Provides chips even when the user has no reading history yet.
final genreTagsProvider = FutureProvider<List<String>>((ref) async {
  final source = ref.watch(currentSourceProvider);
  return SourceCache.tags(sourceId: source.id, fetch: source.getAvailableTags);
});
