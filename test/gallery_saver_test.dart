import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/gallery/gallery_saver.dart';

/// The viewer hands its already-fetched bytes to the native MediaStore writer.
/// These pin the hand-off (method, file name, mime) and the two ways it can come
/// back: success, and a refused storage permission on older Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.hlomatsi.yomou/gallery');

  void mock(Future<Object?> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  }

  test('posts the bytes, name and mime to the gallery channel', () async {
    final dir = await Directory.systemTemp.createTemp('yomou_save');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/cover.jpg')
      ..writeAsBytesSync(List<int>.filled(16, 7));

    MethodCall? call;
    mock((c) async {
      call = c;
      return 'content://media/external/images/media/1';
    });

    final outcome = await saveCoverToGallery(
      imageUrl: 'local://${file.path}',
      title: 'My Cover',
    );

    expect(outcome, CoverSaveOutcome.saved);
    expect(call?.method, 'saveImage');
    final args = call!.arguments as Map;
    expect(args['name'], 'My Cover.jpg');
    expect(args['mime'], 'image/jpeg');
    expect(args['bytes'], isA<Uint8List>());
    expect((args['bytes'] as Uint8List).length, 16);
  });

  test('reports a refused storage permission', () async {
    final dir = await Directory.systemTemp.createTemp('yomou_save');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/cover.png')..writeAsBytesSync([1, 2, 3]);

    mock((c) async => throw PlatformException(code: 'permission'));

    final outcome = await saveCoverToGallery(
      imageUrl: 'local://${file.path}',
      title: 'Denied',
    );
    expect(outcome, CoverSaveOutcome.permissionDenied);
  });

  test('fails cleanly when the image cannot be read', () async {
    final outcome = await saveCoverToGallery(
      imageUrl: 'local:///no/such/file.jpg',
      title: 'Missing',
    );
    expect(outcome, CoverSaveOutcome.failed);
  });
}
