import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yomou/data/sources/giga_scramble.dart';
import 'package:yomou/data/sources/mf_scramble.dart';
import 'package:yomou/data/sources/source_network.dart';
import 'package:yomou/features/settings/providers/download_settings_provider.dart';

/// Downloads chapter image pages to local storage so they can be read
/// offline ("cached chapters").
///
/// Layout: `<downloadsFolder>/<mangaId>/<chapterId>/page_<N>.<ext>`, where
/// `downloadsFolder` is the one picked in Settings > Downloads (by default the
/// app's private support directory).
class ChapterDownloader {
  static Future<Directory> _chaptersRoot() async {
    final dir = await DownloadSettings.chaptersRoot();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> chapterDir(String mangaId, String chapterId) async {
    final root = await _chaptersRoot();
    final dir = Directory(p.join(root.path, mangaId, chapterId));
    return dir;
  }

  /// Returns the local path for a single downloaded page, or null if the
  /// chapter is not downloaded on disk.
  static Future<String?> localFileFor({
    required String mangaId,
    required String chapterId,
    required int pageIndex,
    required String url,
  }) async {
    final dir = await chapterDir(mangaId, chapterId);
    if (!await dir.exists()) return null;
    final file = File(p.join(dir.path, _pageFileName(pageIndex, url)));
    return await file.exists() ? file.path : null;
  }

  /// Returns a path per page when the chapter is fully present on disk,
  /// otherwise null (caller falls back to the network).
  static Future<List<String>?> localPathsForChapter({
    required String mangaId,
    required String chapterId,
    required List<String> pages,
  }) async {
    if (pages.isEmpty) return null;
    final dir = await chapterDir(mangaId, chapterId);
    if (!await dir.exists()) return null;
    return [
      for (var i = 0; i < pages.length; i++)
        p.join(dir.path, _pageFileName(i, pages[i])),
    ];
  }

  /// Downloads every page of a chapter to disk. Sequential (polite to the
  /// server). Returns the saved file paths, or null if cancelled/failed
  /// (partial files are cleaned up on abort).
  static Future<List<String>?> downloadChapter({
    required String mangaId,
    required String chapterId,
    required List<String> pages,
    Map<String, String>? headers,
    String? networkSourceId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (pages.isEmpty) return null;
    final dir = await chapterDir(mangaId, chapterId);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final slowdown = networkSourceId == null
        ? false
        : (await SourceNetworkConfig.forSource(networkSourceId))
                .downloadSlowdown ??
            false;

    final saved = <String>[];
    for (var i = 0; i < pages.length; i++) {
      if (isCancelled?.call() ?? false) {
        await dir.delete(recursive: true);
        return null;
      }
      if (slowdown && i > 0) {
        // Polite pacing between page downloads avoids IP blocking.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final url = pages[i];
      final file = File(p.join(dir.path, _pageFileName(i, url)));
      final exists = await file.exists();
      if (!exists) {
        final bytes = await _fetchPageBytes(url, headers);
        if (bytes == null) {
          await dir.delete(recursive: true);
          return null;
        }
        try {
          await file.writeAsBytes(bytes, flush: true);
        } catch (_) {
          await dir.delete(recursive: true);
          return null;
        }
      }
      saved.add(file.path);
      onProgress?.call(i + 1, pages.length);
    }
    return saved;
  }

  /// Fetches one page, undoing any source-side scramble so the bytes are safe
  /// to store on disk. Returns null on a non-200 response or a network error.
  static Future<List<int>?> _fetchPageBytes(
    String url,
    Map<String, String>? headers,
  ) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode != 200) return null;
      var bytes = response.bodyBytes;
      final mfOffset = MfScramble.offsetFromUrl(url);
      if (mfOffset != null) {
        final fixed = MfScramble.unscramble(bytes, mfOffset);
        if (fixed != null) bytes = fixed;
      } else if (GigaScramble.isScrambledUrl(url)) {
        final fixed = GigaScramble.unscramble(bytes);
        if (fixed != null) bytes = fixed;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Re-fetches a single downloaded page over the network and replaces the
  /// local file. Used by the reader's per-page "Re-download" action when a
  /// stored page is corrupt or truncated: plain retry only re-reads the same
  /// broken file. Writes to a sibling temp file first so a failed fetch never
  /// leaves a half-written page behind.
  static Future<bool> redownloadPage({
    required String url,
    required String localPath,
    Map<String, String>? headers,
  }) async {
    if (url.isEmpty) return false;
    final bytes = await _fetchPageBytes(url, headers);
    if (bytes == null) return false;

    final temp = File('$localPath.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(localPath);
      return true;
    } catch (_) {
      // Leave the original file untouched; the user can retry.
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      return false;
    }
  }

  static Future<void> removeChapterFiles(
    String mangaId,
    String chapterId,
  ) async {
    final dir = await chapterDir(mangaId, chapterId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<bool> isDownloaded(String mangaId, String chapterId) async {
    final dir = await chapterDir(mangaId, chapterId);
    return await dir.exists();
  }

  /// Total size in bytes of all downloaded pages for [mangaId].
  static Future<int> getDownloadSize(String mangaId) async {
    final root = await _chaptersRoot();
    final mangaDir = Directory(p.join(root.path, mangaId));
    if (!await mangaDir.exists()) return 0;
    int total = 0;
    await for (final entity in mangaDir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  static String _pageFileName(int pageIndex, String url) {
    return 'page_${pageIndex + 1}.${_imageExtension(url)}';
  }

  static String _imageExtension(String url) {
    final dotIndex = url.lastIndexOf('.');
    if (dotIndex != -1) {
      final ext = url.substring(dotIndex + 1).split('?').first.toLowerCase();
      if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) &&
          ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext)) {
        return ext;
      }
    }
    return 'png';
  }
}
