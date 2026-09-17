import 'manga.dart';
import 'chapter.dart';
import 'manga_details.dart';

abstract class MangaSource {
  String get id;
  String get name;
  String get baseUrl;
  String get readerBaseUrl;

  /// URL of the source's favicon/logo, used as the tile icon in UIs.
  /// Empty when the source has no usable icon (callers fall back to a letter).
  String get iconUrl => '';

  Map<String, String>? get headers => null;

  Future<List<Manga>> getPopularManga({int page = 1});
  Future<MangaDetails?> getMangaDetails(String mangaId);
  Future<List<Chapter>> getChapters(String mangaId);
  Future<List<String>> getPageUrls(String chapterId);

  // The source's authoritative chapter count (may exceed the number of
  // chapter *entries* currently loaded). Returns 0 when unknown.
  Future<int> getTotalChapters(String mangaId) async {
    return 0;
  }

  // Search for manga matching the given tag names. Returns an empty list
  // when the source does not support tag-based search.
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async {
    return [];
  }

  // Returns the available genre/theme tag names for the source.
  // Returns empty when the source doesn't expose a tag list.
  Future<List<String>> getAvailableTags() async {
    return [];
  }

  /// Returns the most recent chapter (title + publish date) for a manga,
  /// or null when unavailable. Used by the Updates feed for "new chapter"
  /// tracking and date grouping.
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async {
    return null;
  }

  /// Searches manga by free-text title. Returns an empty list when the
  /// source doesn't support title search.
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    return [];
  }

  /// Alternative cover artworks for a manga (e.g. volume art on MangaDex),
  /// as `(url, optional label)` pairs. Returns an empty list when the source
  /// exposes no alternative covers.
  Future<List<(String url, String? label)>> getAltCovers(String mangaId) async {
    return [];
  }
}
