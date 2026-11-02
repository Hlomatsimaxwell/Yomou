import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/backup/encrypted_backup.dart';

void main() {
  test('encrypted backup round trip', () {
    final favs = [
      {'mangaId': 'm1', 'title': 'T', 'sourceId': 's', 'isEnabled': true},
    ];
    final bms = [
      {'mangaId': 'm1', 'pageUrl': 'u', 'chapterTitle': 'c1'},
    ];
    final rps = [
      {'mangaId': 'm1', 'chapterId': 'ch1', 'chapterNumber': 1.0},
    ];

    final bytes = EncryptedBackupCodec.export(
      favorites: favs,
      bookmarks: bms,
      readingProgress: rps,
      password: 'secret',
    );

    final res = EncryptedBackupCodec.import(bytes, 'secret');
    expect(res.favorites.length, 1);
    expect(res.bookmarks.length, 1);
    expect(res.readingProgress.length, 1);
    expect(res.favorites.first['title'], 'T');

    // wrong password throws
    expect(
      () => EncryptedBackupCodec.import(bytes, 'wrong'),
      throwsFormatException,
    );
  });
}
