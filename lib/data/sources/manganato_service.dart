import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';
import 'source_network.dart';

/// Manganato source.
///
/// The manganato family migrated off manganato.com in 2025 onto the
/// "MangaNato" template served from multiple mirrors. Everything the page
/// needs is reachable over plain HTTP (no JS), exactly like Mihon's own
/// Manganato extension:
///   - lists:  /manga-list/hot-manga?page=N
///   - info:   /manga/{slug}
///   - chapters: /api/manga/{slug}/chapters?limit=-1 (JSON)
///   - pages:  /manga/{slug}/{chapterSlug} (cdns + chapterImages script vars)
class ManganatoService extends DioSource implements MangaSource {
  @override
  String get id => 'manganato';
  @override
  String get networkSourceId => id;

  /// Working mirrors. [mirrors.first] is the preferred one and is ordinarily
  /// reachable over plain HTTP, so it clears Cloudflare without a WebView; the
  /// others are used as fallbacks, mirroring Mihon's per-source mirror list.
  static const List<String> mirrors = [
    'https://www.manganato.gg',
    'https://www.natomanga.com',
    'https://www.nelomanga.net',
  ];

  @override
  Future<List<(String url, String? label)>> getAltCovers(String mangaId) async {
    return [];
  }

  @override
  String get name => 'Manganato';
  @override
  String get baseUrl => mirrors.first;
  @override
  String get iconUrl => '${mirrors.first}/favicon.ico';
  @override
  String get readerBaseUrl => mirrors.first;

  @override
  Map<String, String> get headers => {
    'Referer': '${mirrors.first}/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  };

  /// Fetches [url] with plain HTTP ([DioSource.grabText]). If the preferred
  /// mirror is Cloudflare-blocked it retries across the other mirrors.
  Future<String> _fetchHtml(String url) async {
    for (final mirror in mirrors) {
      final effective = url.contains('://')
          ? url.replaceFirst(RegExp(r'https?://[^/]+'), mirror)
          : '$mirror/$url';
      final html = await grabText(
        effective,
        extraHeaders: {'Referer': '$mirror/'},
        useBaseUrl: false,
      );
      if (html.isNotEmpty && !html.contains('Just a moment')) return html;
    }
    debugPrint('Manganato all mirrors failed');
    return '';
  }

  Future<Map<String, dynamic>?> _fetchJson(String url) async {
    for (final mirror in mirrors) {
      final effective = url.contains('://')
          ? url.replaceFirst(RegExp(r'https?://[^/]+'), mirror)
          : '$mirror/$url';
      final body = await grabText(
        effective,
        extraHeaders: {'Referer': '$mirror/'},
        useBaseUrl: false,
      );
      if (body.isEmpty) continue;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // Not JSON — likely a Cloudflare challenge page; try next mirror.
      }
    }
    return null;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    final html = await _fetchHtml('$baseUrl/manga-list/hot-manga?page=$page');
    if (html.isEmpty) return [];
    final document = parser.parse(html);
    final items = document.querySelectorAll('.item');
    if (items.isEmpty) {
      return document
          .querySelectorAll('.content-genres-item')
          .map(_fromListElement)
          .toList();
    }
    return items.map((item) {
      final a = item.querySelector('h3 a, .slide-caption a');
      final img = item.querySelector('img');
      final href = a?.attributes['href'] ?? '';
      return Manga(
        id: href.split('/').last,
        sourceId: id,
        title: a?.text.trim() ?? img?.attributes['alt'] ?? '',
        coverUrl: img?.attributes['src'] ?? '',
      );
    }).where((m) => m.id.isNotEmpty).toList();
  }

  Manga _fromListElement(dynamic element) {
    final titleEl = element.querySelector('.genres-item-name');
    final imgEl = element.querySelector('img');
    final url = titleEl?.attributes['href'] ?? '';
    return Manga(
      id: url.split('/').last,
      sourceId: id,
      title: titleEl?.text.trim() ?? '',
      coverUrl: imgEl?.attributes['src'] ?? '',
    );
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    final json = await _fetchJson('$baseUrl/api/manga/$mangaId/chapters?limit=-1');
    if (json == null || json['success'] != true) return [];
    final entries = ((json['data'] as Map?)?['chapters'] as List?) ?? const [];
    final chapters = <Chapter>[];
    for (final raw in entries) {
      final c = raw is Map ? raw : const {};
      final slug = c['chapter_slug']?.toString() ?? '';
      if (slug.isEmpty) continue;
      final name = c['chapter_name']?.toString() ?? 'Chapter';
      chapters.add(
        Chapter(
          id: '/manga/$mangaId/$slug',
          title: name,
          chapterNumber: c['chapter_num']?.toString() ?? '',
          releaseDate: c['updated_at']?.toString() ?? '',
          url: '$baseUrl/manga/$mangaId/$slug',
        ),
      );
    }
    // API returns newest-first; the app/reader expect oldest-first.
    return chapters.reversed.toList();
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final String targetUrl = chapterId.startsWith('http')
          ? chapterId
          : '$readerBaseUrl${chapterId.startsWith('/') ? '' : '/'}$chapterId';

      // Chapter pages ship two script variables — `cdns` (image CDNs) and
      // `chapterImages` (paths under the first CDN). Same approach Mihon's
      // Manganato extension uses.
      final html = await _fetchHtml(targetUrl);
      if (html.isEmpty) return [];

      final cdns = _extractJsArray(
        html,
        RegExp(r'cdns\s*=\s*\[([^\]]+)\]'),
      )..removeWhere((u) => !u.startsWith('http'));

      final images = _extractJsArray(
        html,
        RegExp(r'(?:chapterImages|backupImages)\s*=\s*\[([^\]]+)\]'),
      );

      if (cdns.isNotEmpty && images.isNotEmpty) {
        final base = cdns.first.replaceAll(RegExp(r'/$'), '');
        return images
            .map((p) => '$base${p.startsWith('/') ? p : '/$p'}')
            .toList();
      }

      // Fallback: static images in the reader container.
      final document = parser.parse(html);
      final staticImages = <String>[];
      for (final img in document.querySelectorAll('.container-chapter-reader img')) {
        final src = img.attributes['src'] ?? '';
        if (src.isNotEmpty && !staticImages.contains(src)) {
          staticImages.add(src);
        }
      }
      return staticImages.where(_isValidMangaUrl).toList();
    } catch (e) {
      debugPrint('Manganato Pages Error: $e');
      return [];
    }
  }

  List<String> _extractJsArray(String html, RegExp regex) {
    final match = regex.firstMatch(html);
    if (match == null) return [];
    return match
        .group(1)!
        .split(',')
        .map((s) => s.trim().replaceAll('"', '').replaceAll(r'\/', '/'))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  bool _isValidMangaUrl(String url) {
    if (url.isEmpty) return false;
    if (url.contains('placeholder') ||
        url.contains('loading') ||
        url.contains('wheel')) {
      return false;
    }
    return url.contains('.jpg') ||
        url.contains('.png') ||
        url.contains('.webp') ||
        url.contains('.jpeg');
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await _fetchHtml('$baseUrl/manga/$mangaId');
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final topEl =
          document.querySelector('.manga-info-top') ??
          document.querySelector('.panel-story-info');
      final titleEl =
          topEl?.querySelector('h1') ??
          document.querySelector('.story-info-right h1');
      final imgEl =
          document.querySelector('.manga-info-pic img') ??
          document.querySelector('.story-info-left img');

      final text = document.querySelector('.manga-info-top')?.text ?? '';
      var author = '';
      var status = '';
      final authorMatch = RegExp(
        r"Author?s?:?\s*([A-Za-z0-9 ,.!&'\-\uac00-\ud7af]+)",
        caseSensitive: false,
      ).firstMatch(text);
      if (authorMatch != null) author = authorMatch.group(1)!.trim();
      final statusMatch = RegExp(
        r'Status:?\s*([A-Za-z]+)',
        caseSensitive: false,
      ).firstMatch(text);
      if (statusMatch != null) status = statusMatch.group(1)!.trim();

      final genres = <String>[];
      for (final a in document.querySelectorAll('.manga-info-top a[href*="/genre/"], .genres a')) {
        final g = a.text.trim();
        if (g.isNotEmpty && !genres.contains(g)) genres.add(g);
      }

      final descEl =
          document.querySelector('#panel-story-description') ??
          document.querySelector('#noidungm');
      final description = descEl?.text.trim() ?? '';

      return MangaDetails(
        id: mangaId,
        sourceId: id,
        title: titleEl?.text.trim() ?? 'Unknown',
        coverUrl: imgEl?.attributes['src'] ?? '',
        description: description,
        author: author,
        status: status,
        year: '',
        tags: genres,
        followers: 0,
        totalChapters: 0,
      );
    } catch (e) {
      debugPrint('Manganato Details Error: $e');
      return null;
    }
  }

  @override
  Future<int> getTotalChapters(String mangaId) async {
    final json = await _fetchJson('$baseUrl/api/manga/$mangaId/chapters?limit=-1');
    if (json == null || json['success'] != true) return 0;
    final entries = ((json['data'] as Map?)?['chapters'] as List?) ?? const [];
    return entries.length;
  }

  @override
  Future<List<Manga>> searchMangaByTags(
    List<String> tags, {
    int page = 1,
  }) async => [];

  @override
  Future<List<String>> getAvailableTags() async => [];

  @override
  Future<(String, DateTime)?> getLatestChapter(String mangaId) async => null;

  @override
  Future<List<Manga>> searchByTitle(String query, {int page = 1}) async {
    try {
      final searchQuery = query.trim().replaceAll(' ', '_');
      final html = await _fetchHtml('$baseUrl/search/story/$searchQuery');
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final elements = document.querySelectorAll('.search-story-item, .panel_story_list .story_item');
      return elements.map((element) {
        final titleEl = element.querySelector('.item-title, .story_name a');
        final imgEl = element.querySelector('.item-img img, img');
        final url = titleEl?.attributes['href'] ?? '';
        final id = url.split('/').last;
        return Manga(
          id: id,
          sourceId: this.id,
          title: titleEl?.text.trim() ?? '',
          coverUrl: imgEl?.attributes['src'] ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('Manganato Search Error: $e');
      return [];
    }
  }
}