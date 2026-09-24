import 'dart:io';

import 'package:flutter/material.dart';

import 'package:yomou/widgets/safe_image.dart';

/// Network image that renders manga covers with source-specific referer
/// headers and survives Android's flaky platform decoder by falling back to a
/// pure-Dart decode (see [SafeNetworkImage]).
///
/// Automatically attaches the referer header required by the CDNs behind
/// hotlink-protected sources (MangaTown, ComicK, Like Manga, Arenascan,
/// Mgeko, ...), which otherwise return 403. Also renders user-picked custom
/// covers stored on disk via `local://<path>`.
class CachedMangaImage extends StatelessWidget {
  const CachedMangaImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.placeholderFadeInDuration,
    this.fadeInDuration = const Duration(milliseconds: 500),
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Duration? placeholderFadeInDuration;
  final Duration fadeInDuration;

  /// Prefix for covers that live in the app's own storage rather than on a
  /// remote host. The value is a filesystem path.
  static const String localScheme = 'local://';

  /// CDN host suffix -> the referer that host expects.
  static const Map<String, String> _referers = {
    'mangahere.com': 'https://www.mangatown.com/',
    'mangahere.org': 'https://www.mangatown.com/',
    'comicknew.pictures': 'https://comick.live/',
    'comick.pictures': 'https://comick.live/',
    'likemanga.ink': 'https://likemanga.ink/',
    'mgread.io': 'https://likemanga.ink/',
    'arenascan.com': 'https://arenascan.com/',
    'asurascans.com': 'https://asurascans.com/',
    '2xstorage.com': 'https://www.manganato.gg/',
    'waitst.com': 'https://www.manganato.gg/',
    'mgeko.cc': 'https://www.mgeko.cc/',
    'imgsrv4.com': 'https://www.mgeko.cc/',
    'imgsrv5.com': 'https://www.mgeko.cc/',
  };

  Map<String, String>? get _headers {
    final host = Uri.tryParse(imageUrl)?.host ?? '';
    if (host.isEmpty) return null;
    for (final entry in _referers.entries) {
      if (host == entry.key || host.endsWith('.${entry.key}')) {
        return {'Referer': entry.value};
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith(localScheme)) {
      final path = imageUrl.substring(localScheme.length);
      return SafeFileImage(
        file: File(path),
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        errorWidget: errorWidget,
      );
    }

    return SafeNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: _headers,
      placeholder: placeholder,
      errorWidget:
          errorWidget ??
          (context, url, error) => Container(
            color: Colors.black26,
            child: const Icon(Icons.menu_book_outlined, color: Colors.white38),
          ),
      placeholderFadeInDuration: placeholderFadeInDuration,
      fadeInDuration: fadeInDuration,
    );
  }
}
