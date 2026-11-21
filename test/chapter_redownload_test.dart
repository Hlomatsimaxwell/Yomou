import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/features/reader/services/chapter_downloader.dart';

/// A downloaded page can be corrupt (truncated write, bad scramble fix, stale
/// file from a CDN change). Plain retry only re-reads those same bytes, so the
/// reader's re-download action has to fetch fresh bytes and replace the file.
/// These use a loopback server so the real http.get path is exercised.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test otherwise answers every request with a 400.
  HttpOverrides.global = null;

  Future<HttpServer> serverReturning(int status, List<int> bytes) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) {
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.binary
        ..add(bytes)
        ..close();
    });
    return server;
  }

  Future<File> corruptPage() async {
    final dir = await Directory.systemTemp.createTemp('yomou_redownload_test');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final file = File('${dir.path}/page_1.jpg');
    await file.writeAsBytes(const [9, 9, 9, 9, 9, 9]);
    return file;
  }

  test('replaces a corrupt page with freshly fetched bytes', () async {
    final server = await serverReturning(200, [1, 2, 3, 4]);
    final file = await corruptPage();

    final ok = await ChapterDownloader.redownloadPage(
      url: 'http://127.0.0.1:${server.port}/page.jpg',
      localPath: file.path,
    );

    expect(ok, isTrue);
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
    // The temp file is cleaned up by the atomic rename.
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  });

  test('a failed fetch leaves the existing file untouched', () async {
    final server = await serverReturning(404, const []);
    final file = await corruptPage();

    final ok = await ChapterDownloader.redownloadPage(
      url: 'http://127.0.0.1:${server.port}/page.jpg',
      localPath: file.path,
    );

    expect(ok, isFalse);
    expect(await file.readAsBytes(), [9, 9, 9, 9, 9, 9]);
  });

  test('an empty URL is rejected without touching the file', () async {
    final file = await corruptPage();

    final ok = await ChapterDownloader.redownloadPage(
      url: '',
      localPath: file.path,
    );

    expect(ok, isFalse);
    expect(await file.readAsBytes(), [9, 9, 9, 9, 9, 9]);
  });
}
