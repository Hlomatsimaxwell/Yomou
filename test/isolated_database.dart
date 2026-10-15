import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Points this test file's database at a throwaway file instead of the one the
/// app uses.
///
/// The ffi factory's default databases path is
/// `<working directory>/.dart_tool/sqflite_common_ffi/databases`, and a
/// `flutter run -d linux` session resolves the same directory -- the desktop app
/// builds its database path from the working directory too. Left alone, a test
/// reads the developer's own library rather than its fixtures, and writes back
/// into it: `kotatsu_restore_db_test` asserted an exact favourites set and was
/// handed a real library instead.
///
/// Call once, at the top of `main()`.
void useIsolatedTestDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dir = Directory.systemTemp.createTempSync('yomou_test_db_');
  // The non-deprecated spelling of this lives on the ffi factory's mixin, which
  // sqflite_common does not export, so the interface's method is the only one
  // reachable. It stores the path synchronously, so there is nothing to await.
  // ignore: deprecated_member_use
  unawaited(databaseFactory.setDatabasesPath(dir.path));

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
}
