import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yomou/core/cache/transcode_cache.dart';
import 'package:yomou/widgets/safe_image.dart';

Uint8List _png(int width, int height) {
  final canvas = img.Image(width: width, height: height);
  img.fill(canvas, color: img.ColorRgb8(20, 120, 220));
  return Uint8List.fromList(img.encodePng(canvas));
}

void main() {
  group('TranscodeCache keys', () {
    test('network keys are stable per URL and differ between URLs', () {
      const a = 'https://cdn.example.com/ch1/01.webp';
      const b = 'https://cdn.example.com/ch1/02.webp';

      expect(TranscodeCache.networkKey(a), TranscodeCache.networkKey(a));
      expect(TranscodeCache.networkKey(a), isNot(TranscodeCache.networkKey(b)));
      expect(TranscodeCache.networkKey(a), matches(RegExp(r'^n_[0-9a-f]{40}$')));
    });

    test('file keys change with size and mtime', () {
      final file = File('/tmp/chapter/01.webp');
      final base = TranscodeCache.fileKey(file, length: 100, modifiedMs: 1000);

      expect(base, matches(RegExp(r'^f_[0-9a-f]{40}$')));
      // Same path, new bytes: a re-download must not reuse the old pixels.
      expect(
        TranscodeCache.fileKey(file, length: 101, modifiedMs: 1000),
        isNot(base),
      );
      expect(
        TranscodeCache.fileKey(file, length: 100, modifiedMs: 2000),
        isNot(base),
      );
    });
  });

  group('TranscodeCache storage', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('yomou_transcode_');
      TranscodeCache.debugDirectoryOverride = () async => dir;
      await TranscodeCache.instance.clear();
    });

    tearDown(() async {
      TranscodeCache.debugDirectoryOverride = null;
      await TranscodeCache.instance.clear();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('round trips stored bytes', () async {
      final key = TranscodeCache.networkKey('https://cdn.example.com/01.webp');
      expect(await TranscodeCache.instance.read(key), isNull);

      final png = _png(8, 8);
      await TranscodeCache.instance.write(key, png);

      final read = await TranscodeCache.instance.read(key);
      expect(read, isNotNull);
      expect(read, equals(png));
    });

    test('clear drops every stored transcode', () async {
      final key = TranscodeCache.networkKey('https://cdn.example.com/02.webp');
      await TranscodeCache.instance.write(key, _png(4, 4));
      expect(await TranscodeCache.instance.read(key), isNotNull);

      await TranscodeCache.instance.clear();
      expect(await TranscodeCache.instance.read(key), isNull);
    });

    test('usageBytes counts stored files', () async {
      final png = _png(16, 16);
      await TranscodeCache.instance.write(
        TranscodeCache.networkKey('https://cdn.example.com/03.webp'),
        png,
      );
      expect(await TranscodeCache.instance.usageBytes(), png.length);
    });
  });

  group('transcodeToPng', () {
    test('re-encodes a decodable image at its own size', () {
      final source = _png(40, 30);
      final out = transcodeToPng((source, null));

      expect(out, isNotNull);
      final decoded = img.decodePng(out!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 40);
      expect(decoded.height, 30);
    });

    test('downscales to the requested width', () {
      final source = _png(200, 100);
      final out = transcodeToPng((source, 50));

      expect(out, isNotNull);
      final decoded = img.decodePng(out!)!;
      expect(decoded.width, 50);
      expect(decoded.height, 25);
    });

    test('leaves images narrower than the target alone', () {
      final source = _png(30, 30);
      final out = transcodeToPng((source, 200));

      expect(out, isNotNull);
      expect(img.decodePng(out!)!.width, 30);
    });

    test('returns null for bytes that are not an image', () {
      final garbage = Uint8List.fromList(List<int>.generate(64, (i) => i));
      expect(transcodeToPng((garbage, null)), isNull);
    });
  });
}
