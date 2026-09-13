import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// [CachedNetworkImage] that automatically attaches the referer header
/// required by the CDNs behind hotlink-protected sources (MangaTown,
/// ComicK, Like Manga, Arenascan, Mgeko, ...), which otherwise return 403.
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
    return CachedNetworkImage(
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