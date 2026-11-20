import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomou/core/cache/image_dimensions.dart';
import 'package:yomou/core/cache/page_geometry.dart';

/// Builds a PNG header: signature, then the IHDR chunk that carries the size.
Uint8List pngHeader(int width, int height) {
  final bytes = Uint8List(33);
  bytes.setAll(0, const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
    0, 0, 0, 13, // IHDR length
    0x49, 0x48, 0x44, 0x52, // "IHDR"
  ]);
  void be32(int offset, int value) {
    bytes[offset] = (value >> 24) & 0xFF;
    bytes[offset + 1] = (value >> 16) & 0xFF;
    bytes[offset + 2] = (value >> 8) & 0xFF;
    bytes[offset + 3] = value & 0xFF;
  }

  be32(16, width);
  be32(20, height);
  return bytes;
}

/// Builds a JPEG with a single SOF0 frame header after the SOI marker.
Uint8List jpegHeader(int width, int height) {
  return Uint8List.fromList([
    0xFF, 0xD8, // SOI
    0xFF, 0xC0, 0x00, 0x11, // SOF0, segment length 17
    0x08, // precision
    (height >> 8) & 0xFF, height & 0xFF,
    (width >> 8) & 0xFF, width & 0xFF,
    0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
  ]);
}

Uint8List gifHeader(int width, int height) {
  return Uint8List.fromList([
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // "GIF89a"
    width & 0xFF, (width >> 8) & 0xFF,
    height & 0xFF, (height >> 8) & 0xFF,
    0x00, 0x00, 0x00,
  ]);
}

Uint8List webpExtendedHeader(int width, int height) {
  final bytes = Uint8List(30);
  bytes.setAll(0, ascii.encode('RIFF'));
  bytes.setAll(8, ascii.encode('WEBP'));
  bytes.setAll(12, ascii.encode('VP8X'));
  void le24(int offset, int value) {
    bytes[offset] = value & 0xFF;
    bytes[offset + 1] = (value >> 8) & 0xFF;
    bytes[offset + 2] = (value >> 16) & 0xFF;
  }

  le24(24, width - 1);
  le24(27, height - 1);
  return bytes;
}

void main() {
  group('imageDimensions', () {
    test('reads a PNG', () {
      expect(imageDimensions(pngHeader(720, 4000)), (720, 4000));
    });

    test('reads a JPEG', () {
      expect(imageDimensions(jpegHeader(2560, 6400)), (2560, 6400));
    });

    test('reads a GIF', () {
      expect(imageDimensions(gifHeader(320, 200)), (320, 200));
    });

    test('reads an extended WebP', () {
      expect(imageDimensions(webpExtendedHeader(1080, 7200)), (1080, 7200));
    });

    test('returns null for bytes it does not recognise', () {
      expect(imageDimensions(Uint8List.fromList(utf8.encode('<html>404'))),
          isNull);
      expect(imageDimensions(Uint8List(4)), isNull);
    });

    test('returns null for a truncated header', () {
      final png = pngHeader(100, 100);
      expect(imageDimensions(Uint8List.sublistView(png, 0, 20)), isNull);
    });
  });

  group('PageGeometryCache', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('page_geometry_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    PageGeometryCache cache() =>
        PageGeometryCache(saveDelay: Duration.zero)..debugDirectory = dir;

    test('remembers a page ratio from the decoded pixel size', () {
      final c = cache();
      c.remember('https://example.com/1.jpg', 694, 4531);
      expect(c.ratioFor('https://example.com/1.jpg'), closeTo(6.5288, 0.0001));
    });

    test('ignores empty keys and zero dimensions', () {
      final c = cache();
      c.remember('', 100, 200);
      c.remember('https://example.com/1.jpg', 0, 200);
      expect(c.ratioFor(''), isNull);
      expect(c.ratioFor('https://example.com/1.jpg'), isNull);
    });

    test('survives a restart', () async {
      final first = cache();
      first.remember('https://example.com/1.jpg', 800, 1200);
      await first.flush();

      final second = cache();
      await second.ensureLoaded();
      expect(second.ratioFor('https://example.com/1.jpg'), 1.5);
    });

    test('drops the oldest page once it is full', () {
      final c = PageGeometryCache(maxEntries: 2, saveDelay: Duration.zero)
        ..debugDirectory = dir;
      c.remember('a', 100, 200);
      c.remember('b', 100, 300);
      c.remember('c', 100, 400);
      expect(c.ratioFor('a'), isNull);
      expect(c.ratioFor('b'), 3.0);
      expect(c.ratioFor('c'), 4.0);
    });

    test('clear forgets everything on disk and in memory', () async {
      final c = cache();
      c.remember('https://example.com/1.jpg', 100, 200);
      await c.flush();
      await c.clear();

      final reopened = cache();
      await reopened.ensureLoaded();
      expect(reopened.ratioFor('https://example.com/1.jpg'), isNull);
    });
  });
}
