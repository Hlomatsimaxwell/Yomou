import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/database/database_helper.dart';

import 'isolated_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedTestDatabase();

  test('saveMangaProgress -> getHistory -> clearHistory', () async {
    final db = DatabaseHelper.instance;

    // Clear any existing state
    await db.clearHistory();

    final historyBefore = await db.getHistory();
    expect(historyBefore, isEmpty);

    // Simulate reading a chapter
    await db.saveMangaProgress(
      mangaId: 'abc-123',
      title: 'Solo Leveling',
      coverUrl: 'https://example.com/cover.jpg',
      sourceId: 'mangadex',
      totalChapters: 10,
      lastReadChapter: 3,
    );

    final history = await db.getHistory();
    expect(history, hasLength(1));
    expect(history.first['mangaId'], 'abc-123');
    expect(history.first['title'], 'Solo Leveling');
    expect(history.first['coverUrl'], 'https://example.com/cover.jpg');
    expect(history.first['sourceId'], 'mangadex');
    expect(history.first['lastReadChapter'], 3.0);

    // Reading a LOWER chapter resets the read position to that chapter, so
    // every chapter above it is considered unread again.
    await db.saveMangaProgress(
      mangaId: 'abc-123',
      title: 'Solo Leveling',
      sourceId: 'mangadex',
      lastReadChapter: 1,
    );
    final afterLower = await db.getHistory();
    expect(afterLower.first['lastReadChapter'], 1.0);

    // Clearing history empties it
    await db.clearHistory();
    final historyAfter = await db.getHistory();
    expect(historyAfter, isEmpty);
  });
}
