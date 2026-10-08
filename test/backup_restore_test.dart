import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/backup/backup_restore.dart';

/// The reader picks one file and is never asked which format it is: a Yomou
/// `.json` and a Mihon `.json` are both just "my backup" to the person holding
/// it, and `.tachibk` is gzipped protobuf that shares an extension with
/// nothing. Getting this wrong either restores nothing silently or hands a
/// Mihon file to the Yomou parser.
void main() {
  Uint8List bytes(String source) => Uint8List.fromList(utf8.encode(source));

  group('Yomou backups', () {
    test('a file with history, favorites or bookmarks is Yomou', () {
      expect(
        BackupRestore.detect(bytes('{"history": [], "favorites": []}')),
        BackupFormat.yomou,
      );
      expect(
        BackupRestore.detect(bytes('{"bookmarks": []}')),
        BackupFormat.yomou,
      );
    });

    test('leading whitespace does not defeat the sniff', () {
      expect(
        BackupRestore.detect(bytes('\n\n  {"history": []}')),
        BackupFormat.yomou,
      );
    });
  });

  group('Tachiyomi backups', () {
    test('gzip is always Tachiyomi, whatever it contains', () {
      final gzipped = Uint8List.fromList(
        gzip.encode(utf8.encode('{"history": []}')),
      );
      expect(BackupRestore.detect(gzipped), BackupFormat.tachiyomi);
    });

    test('legacy JSON is Tachiyomi', () {
      expect(
        BackupRestore.detect(bytes('{"manga": [], "info": {}}')),
        BackupFormat.tachiyomi,
      );
    });

    test('bare protobuf is Tachiyomi', () {
      // Neither gzipped nor JSON: the leading byte is not an opening brace.
      expect(
        BackupRestore.detect(bytes(' not json')),
        BackupFormat.tachiyomi,
      );
    });
  });
}
