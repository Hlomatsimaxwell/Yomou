import '../models/manga_source.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';

class MockSource implements MangaSource {
  @override
  String get id => 'mock';

  @override
  String get name => 'Mock Source';

  @override
  String get baseUrl => 'https://mock.com';
  String get iconUrl => '';

  @override
  String get readerBaseUrl => 'https://mock-reader.com';

  @override
  Future<List<(String url, String? label)>> getAltCovers(String mangaId) async {
    return [];
  }

  @override
  Map<String, String>? get headers => null;

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    return [
      Manga(
        id: '1',
        sourceId: id,
        title: 'Mock Manga 1',
        coverUrl: 'https://picsum.photos/seed/mock1/300/450',
      ),
      Manga(
        id: '2',
        sourceId: id,
        title: 'Mock Manga 2',
        coverUrl: 'https://picsum.photos/seed/mock2/300/450',
      ),
    ];
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    return [
      Chapter(
        id: 'c1',
        title: 'Chapter 1',
        chapterNumber: '1',
        releaseDate: '',
        url: '',
      ),
      Chapter(
        id: 'c2',
        title: 'Chapter 2',
        chapterNumber: '2',
        releaseDate: '',
        url: '',
      ),
    ];
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    return MangaDetails(
      id: mangaId,
      sourceId: id,
      title: 'Mock Manga $mangaId',
      coverUrl: 'https://picsum.photos/seed/mock$mangaId/300/450',
      description:
          'This is a sample description for the mock source. It is used to '
          'demonstrate how real manga details render on the detail screen.',
      author: 'Mock Author',
      status: 'Ongoing',
      year: '2024',
      tags: const ['Action', 'Fantasy', 'Adventure'],
      followers: 1234,
      totalChapters: 2,
    );
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    return List.generate(
      10,
      (index) =>
          'https://picsum.photos/seed/mock_ch_$chapterId${index + 1}/800/1200',
    );
  }

  @override
  Future<int> getTotalChapters(String mangaId) async => 0;

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async => [];

  @override
  Future<List<String>> getAvailableTags() async => [];

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async => null;

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async => [];
}
