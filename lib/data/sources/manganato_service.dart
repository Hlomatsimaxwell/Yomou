import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' as parser;
import '../models/manga_source.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/manga_details.dart';

class ManganatoService implements MangaSource {
  @override
  String get id => 'manganato';

  @override
  Future<List<(String url, String? label)>> getAltCovers(String mangaId) async {
    return [];
  }

  @override
  String get name => 'Manganato';
  @override
  String get baseUrl => 'https://manganato.com';
  String get iconUrl => 'https://manganato.com/favicon.ico';
  @override
  String get readerBaseUrl => 'https://chapmanganato.to';

  @override
  Map<String, String> get headers => {
    'Referer': 'https://manganato.com/',
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
  };

  // We return 'dynamic' so the IDE stops trying to verify the type
  dynamic _getRegex(String pattern) {
    return RegExp(pattern, caseSensitive: false);
  }

  Future<String> _fetchHtmlWithWebView(String url) async {
    Completer<String> completer = Completer<String>();
    HeadlessInAppWebView? webView;

    webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
      ),
      onLoadStop: (controller, url) async {
        String? html = await controller.getHtml();
        completer.complete(html ?? "");
        webView?.dispose();
      },
      onReceivedError: (controller, request, error) {
        completer.complete("");
      },
    );

    // FIX: Removed the '!' to stop the warning
    await webView?.run();
    return completer.future;
  }

  @override
  Future<List<Manga>> getPopularManga({int page = 1}) async {
    final html = await _fetchHtmlWithWebView('$baseUrl/genre-all/$page');
    if (html.isEmpty) return [];
    final document = parser.parse(html);
    final elements = document.querySelectorAll('.content-genres-item');
    return elements.map((element) {
      final titleEl = element.querySelector('.genres-item-name');
      final imgEl = element.querySelector('img');
      final url = titleEl?.attributes['href'] ?? '';
      final id = url.split('/').last;
      return Manga(
        id: id,
        sourceId: this.id,
        title: titleEl?.text.trim() ?? '',
        coverUrl: imgEl?.attributes['src'] ?? '',
      );
    }).toList();
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    final html = await _fetchHtmlWithWebView('$baseUrl/manga-$mangaId');
    if (html.isEmpty) return [];
    final document = parser.parse(html);
    final elements = document.querySelectorAll('.row-content-chapter .a-h');
    return elements.map((element) {
      final url = element.attributes['href'] ?? '';
      final id = url.split('/').last;
      var numRegex = _getRegex(r'[^0-9.]');
      var cleanNum = element.text.replaceAll(numRegex, '');
      return Chapter(
        id: id,
        title: element.text.trim(),
        chapterNumber: cleanNum,
        releaseDate: '',
        url: url,
      );
    }).toList();
  }

  @override
  Future<List<String>> getPageUrls(String chapterId) async {
    try {
      final String targetUrl = chapterId.startsWith('http')
          ? chapterId
          : '$readerBaseUrl/$chapterId';

      Completer<List<String>> completer = Completer<List<String>>();
      HeadlessInAppWebView? webView;

      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(targetUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
        ),
        onLoadStop: (controller, url) async {
          // --- THE JS SNIPER ---
          // We run this script inside the browser. It finds all images,
          // checks their data-src/src, and joins them into one long string.
          final result = await controller.evaluateJavascript(
            source: """
            (function() {
              var images = document.querySelectorAll('img');
              var urls = [];
              for (var i = 0; i < images.length; i++) {
                var src = images[i].getAttribute('data-src') || 
                           images[i].getAttribute('data-original') || 
                           images[i].getAttribute('data-lazy-src') || 
                           images[i].src;
                if (src && !src.includes('placeholder') && !src.includes('loading')) {
                  urls.push(src);
                }
              }
              return urls.join(',');
            })();
          """,
          );

          if (result != null && result is String && result.isNotEmpty) {
            List<String> pages = result.split(',');
            completer.complete(pages);
          } else {
            completer.complete([]);
          }
          webView?.dispose();
        },
        onReceivedError: (controller, request, error) {
          completer.complete([]);
        },
      );

      await webView!.run();

      final List<String> finalPages = await completer.future;

      // Filter out any junk that JS might have picked up
      final cleanedPages = finalPages
          .where((url) => _isValidMangaUrl(url))
          .toList();

      debugPrint('JS Sniper found ${cleanedPages.length} real pages.');
      return cleanedPages;
    } catch (e) {
      debugPrint('JS Sniper Error: $e');
      return [];
    }
  }

  bool _isValidMangaUrl(String url) {
    if (url.isEmpty) return false;
    if (url.contains('placeholder') ||
        url.contains('loading') ||
        url.contains('wheel'))
      return false;
    if (url.contains('mangadex') || url.contains('logo')) return false;
    return url.contains('.jpg') ||
        url.contains('.png') ||
        url.contains('.webp') ||
        url.contains('.jpeg');
  }

  @override
  Future<MangaDetails?> getMangaDetails(String mangaId) async {
    try {
      final html = await _fetchHtmlWithWebView('$baseUrl/manga-$mangaId');
      if (html.isEmpty) return null;
      final document = parser.parse(html);

      final infoEl = document.querySelector('.story-info-right');
      final titleEl = document.querySelector('.story-info-right h1');

      var rating = '';
      String description = '';
      List<String> genres = [];
      String author = '';
      String status = '';

      final allPTags = document.querySelectorAll('.story-info-right p');
      for (final p in allPTags) {
        final label = p.text.trim();
        if (label.contains('Author')) {
          author = p.querySelector('.author-content')?.text.trim() ?? '';
        } else if (label.contains('Status')) {
          status = p.querySelector('.status-content')?.text.trim() ?? '';
        } else if (label.contains('Rating')) {
          rating = p.text.replaceAll('Rating :', '').trim();
        }
      }

      final genreAnchors = infoEl?.querySelectorAll('.genres a');
      if (genreAnchors != null) {
        genres = genreAnchors.map((a) => a.text.trim()).toList();
      }

      final descEl = document.querySelector('#panel-story-description');
      if (descEl != null) {
        description = descEl.text.trim();
      }

      final imgEl = document.querySelector('.story-info-left img');

      return MangaDetails(
        id: mangaId,
        sourceId: id,
        title: titleEl?.text.trim() ?? 'Unknown',
        coverUrl: imgEl?.attributes['src'] ?? '',
        description: description,
        author: author,
        status: status,
        year: rating,
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
  Future<int> getTotalChapters(String mangaId) async => 0;

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
      final html = await _fetchHtmlWithWebView(
        '$baseUrl/search/story/$searchQuery',
      );
      if (html.isEmpty) return [];
      final document = parser.parse(html);
      final elements = document.querySelectorAll('.search-story-item');
      return elements.map((element) {
        final titleEl = element.querySelector('.item-title');
        final imgEl = element.querySelector('.item-img img');
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
