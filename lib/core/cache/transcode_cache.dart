import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk store for the PNGs that [SafeNetworkImage] / [SafeFileImage] produce
/// when the platform codec cannot decode the source image (WebP on Android 9,
/// AVIF, HEIF, ...).
///
/// Transcoding is a pure-Dart decode plus a PNG encode on a background isolate,
/// which is the slow part of showing such a page - on a large reader page it
/// costs hundreds of milliseconds to seconds. The result is deterministic for
/// a given source, so it is kept here and read back on the next session instead
/// of being recomputed every time the page is opened.
///
/// Keys are content addresses, not URLs:
///  - network images hash the URL ([networkKey]);
///  - local images hash the path plus size and mtime ([fileKey]), so a chapter
///    re-downloaded to the same path is transcoded again rather than serving
///    the previous file's pixels.
///
/// The directory lives under the temporary directory, beside the image cache,
/// and is bounded by file count and total size with LRU eviction.
class TranscodeCache {
  TranscodeCache._();

  static final TranscodeCache instance = TranscodeCache._();

  static const _dirName = 'transcoded_png';
  static const _maxFiles = 200;
  static const _maxBytes = 96 * 1024 * 1024;

  /// Evict after this many writes rather than on every one: the sweep is a
  /// directory listing plus a stat per file, which is wasted work when a
  /// chapter is filling the cache a page at a time.
  static const _writesPerEviction = 8;

  Directory? _dir;
  int _writes = 0;

  /// Test hook: when set, the cache uses the returned directory instead of
  /// resolving one under the temporary directory.
  @visibleForTesting
  static Future<Directory> Function()? debugDirectoryOverride;

  static String networkKey(String url) => 'n_${_hash(url)}';

  static String fileKey(
    File file, {
    required int length,
    required int modifiedMs,
  }) =>
      'f_${_hash('${file.path}|$length|$modifiedMs')}';

  static String _hash(String value) =>
      sha1.convert(utf8.encode(value)).toString();

  Future<Directory> _directory() async {
    final cached = _dir;
    if (cached != null) return cached;
    final override = debugDirectoryOverride;
    if (override != null) {
      final dir = await override();
      await dir.create(recursive: true);
      return _dir = dir;
    }
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, _dirName));
    await dir.create(recursive: true);
    return _dir = dir;
  }

  File _fileIn(Directory dir, String key) => File(p.join(dir.path, '$key.png'));

  /// The stored PNG for [key], or null when it has not been produced yet.
  ///
  /// Touches the file's mtime so LRU eviction keeps what is actually in use.
  Future<Uint8List?> read(String key) async {
    try {
      final dir = await _directory();
      final file = _fileIn(dir, key);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      // Best effort: a failed touch must not lose the read.
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Stores [png] under [key]. Failures are ignored: the caller still has the
  /// bytes in memory and simply pays the transcode again next time.
  Future<void> write(String key, Uint8List png) async {
    try {
      final dir = await _directory();
      await _fileIn(dir, key).writeAsBytes(png, flush: true);
      _writes++;
      if (_writes >= _writesPerEviction) {
        _writes = 0;
        await _evict();
      }
    } catch (_) {}
  }

  /// Drops every stored transcode. Called when the user clears the image cache
  /// so the two caches stay in step.
  Future<void> clear() async {
    try {
      final dir = await _directory();
      if (await dir.exists()) await dir.delete(recursive: true);
      _dir = null;
      _writes = 0;
    } catch (_) {}
  }

  /// Bytes currently held by the transcode folder.
  Future<int> usageBytes() async {
    try {
      final dir = await _directory();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _evict() async {
    try {
      final dir = await _directory();
      if (!await dir.exists()) return;
      final entries = <({File file, DateTime modified, int size})>[];
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        entries.add((file: entity, modified: stat.modified, size: stat.size));
        total += stat.size;
      }
      if (entries.length <= _maxFiles && total <= _maxBytes) return;
      // Oldest first: [read] touches mtime, so this is an LRU sweep.
      entries.sort((a, b) => a.modified.compareTo(b.modified));
      var count = entries.length;
      for (final entry in entries) {
        if (count <= _maxFiles && total <= _maxBytes) break;
        try {
          await entry.file.delete();
          count--;
          total -= entry.size;
        } catch (_) {}
      }
    } catch (_) {}
  }
}
