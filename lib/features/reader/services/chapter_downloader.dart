import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:yomou/data/sources/mf_scramble.dart';
import 'package:yomou/data/sources/source_network.dart';

/// Downloads chapter image pages to local storage so they can be read
/// offline ("cached chapters").
///
/// Layout: `<appSupport>/chapters/<mangaId>/<chapterId>/page_<N>.<ext>`
class ChapterDownloader {
  static Directory? _root;

  static Future<Directory> _chaptersRoot() async {
    if (_root != null) return _root!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'chapters'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _root = dir;
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
        try {
          final response = await http.get(Uri.parse(url), headers: headers);
          if (response.statusCode != 200) {
            await dir.delete(recursive: true);
            return null;
          }
          var bytes = response.bodyBytes;
          final mfOffset = MfScramble.offsetFromUrl(url);
          if (mfOffset != null) {
            // Offline pages must be stored de-scrambled or the file is tiled.
            final fixed = MfScramble.unscramble(bytes, mfOffset);
            if (fixed != null) bytes = fixed;
          }
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
