import 'dart:typed_data';

/// Reads the pixel dimensions of an encoded image from its header.
///
/// Only the leading bytes are needed, so a page can be measured without
/// decoding it. The reader uses this to reserve the right height for a page
/// *before* its image is ready: without it every page is laid out as a
/// placeholder of some guessed height and then grows or shrinks when the image
/// decodes, which moves the list under the reader and makes a seek drift.
///
/// Returns null when the bytes are not a format this understands, or the header
/// is truncated. AVIF and HEIF are deliberately not parsed -- they are rare as
/// chapter pages and the caller has an estimate to fall back on.
(int width, int height)? imageDimensions(Uint8List bytes) {
  // Each parser checks the bytes it needs; this only rejects a stub that cannot
  // even hold a GIF header.
  if (bytes.length < 12) return null;
  if (_isJpeg(bytes)) return _jpegDimensions(bytes);
  if (_isPng(bytes)) return _pngDimensions(bytes);
  if (_isGif(bytes)) return _gifDimensions(bytes);
  if (_isWebp(bytes)) return _webpDimensions(bytes);
  return null;
}

bool _isJpeg(Uint8List b) => b[0] == 0xFF && b[1] == 0xD8;

/// Walks the JPEG marker segments to the frame header (SOFn).
///
/// The dimensions live in the first SOF segment, which comes before the scan
/// data. Everything ahead of it -- EXIF, ICC profiles, quantisation and Huffman
/// tables -- is skipped by its declared length.
(int, int)? _jpegDimensions(Uint8List b) {
  var i = 2;
  while (i + 9 < b.length) {
    if (b[i] != 0xFF) {
      // Padding between segments is not legal but is common enough in the wild.
      i++;
      continue;
    }
    final marker = b[i + 1];
    // Standalone markers carry no length field.
    if (marker == 0xD8 ||
        marker == 0xD9 ||
        marker == 0x01 ||
        (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    if (i + 3 >= b.length) return null;
    final length = (b[i + 2] << 8) | b[i + 3];
    if (length < 2) return null;
    // SOF0..SOF15, minus DHT (C4), JPG (C8) and DAC (CC), which share the range
    // but are not frame headers.
    if (marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC) {
      if (i + 9 >= b.length) return null;
      final height = (b[i + 5] << 8) | b[i + 6];
      final width = (b[i + 7] << 8) | b[i + 8];
      if (width <= 0 || height <= 0) return null;
      return (width, height);
    }
    i += 2 + length;
  }
  return null;
}

bool _isPng(Uint8List b) =>
    b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;

/// PNG puts the size in the IHDR chunk, which is always first.
(int, int)? _pngDimensions(Uint8List b) {
  if (b.length < 24) return null;
  final width = _be32(b, 16);
  final height = _be32(b, 20);
  if (width <= 0 || height <= 0) return null;
  return (width, height);
}

bool _isGif(Uint8List b) => b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46;

(int, int)? _gifDimensions(Uint8List b) {
  if (b.length < 10) return null;
  final width = b[6] | (b[7] << 8);
  final height = b[8] | (b[9] << 8);
  if (width <= 0 || height <= 0) return null;
  return (width, height);
}

bool _isWebp(Uint8List b) =>
    b[0] == 0x52 &&
    b[1] == 0x49 &&
    b[2] == 0x46 &&
    b[3] == 0x46 &&
    b[8] == 0x57 &&
    b[9] == 0x45 &&
    b[10] == 0x42 &&
    b[11] == 0x50;

/// WebP has three encodings, each with its own dimension layout.
(int, int)? _webpDimensions(Uint8List b) {
  if (b.length < 30) return null;
  final fourcc = String.fromCharCodes(b.sublist(12, 16));
  switch (fourcc) {
    case 'VP8 ':
      // Lossy: a 3-byte frame tag, then the 3-byte sync code, then the size.
      if (b[23] != 0x9D || b[24] != 0x01 || b[25] != 0x2A) return null;
      final width = (b[26] | (b[27] << 8)) & 0x3FFF;
      final height = (b[28] | (b[29] << 8)) & 0x3FFF;
      if (width <= 0 || height <= 0) return null;
      return (width, height);
    case 'VP8L':
      // Lossless: 14 bits of (width-1) then 14 bits of (height-1), little
      // endian, packed after the 0x2F signature byte.
      if (b[20] != 0x2F) return null;
      final bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
      final width = (bits & 0x3FFF) + 1;
      final height = ((bits >> 14) & 0x3FFF) + 1;
      return (width, height);
    case 'VP8X':
      // Extended: 24-bit canvas size, stored as (dimension - 1).
      final width = (b[24] | (b[25] << 8) | (b[26] << 16)) + 1;
      final height = (b[27] | (b[28] << 8) | (b[29] << 16)) + 1;
      return (width, height);
  }
  return null;
}

int _be32(Uint8List b, int offset) =>
    (b[offset] << 24) |
    (b[offset + 1] << 16) |
    (b[offset + 2] << 8) |
    b[offset + 3];
