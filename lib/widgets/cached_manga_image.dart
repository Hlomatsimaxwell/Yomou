import 'dart:io';

import 'package:flutter/material.dart';

import 'package:yomou/core/image_referer.dart';
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
    this.decodeWidth,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Duration? placeholderFadeInDuration;
  final Duration fadeInDuration;

  /// Physical-pixel decode cap that overrides the one derived from [width].
  ///
  /// The full-screen viewer draws far larger than a grid cell and knows the
  /// screen size, so it caps the decode itself rather than decoding a
  /// multi-thousand-pixel original only to shrink it back down. Null keeps the
  /// [width]-derived behaviour.
  final int? decodeWidth;

  /// Prefix for covers that live in the app's own storage rather than on a
  /// remote host. The value is a filesystem path.
  static const String localScheme = 'local://';

  /// CDN host suffix -> the referer that host expects.
  ///
  /// The table itself lives in [ImageReferer] so the notification fetches can
  /// send the same headers; the public `refererFor` static keeps the source
  /// tests working without re-typing the table here.

  /// Path prefix -> the referer that host expects, for sources whose image host
  /// rotates and so cannot be listed by name.
  ///
  /// MangaBall serves its page images from a different subdomain per crawl -
  /// `bulbasaur.poke-black-and-white.net`, `chikorita.red-and-blue.net` and
  /// others - and they are all hotlink-protected: the same URL answers 403 with
  /// no referer or a foreign one, and 200 only for `https://mangaball.com/`.
  /// Every one of them serves the same `/storage/<id>/0/<n>/<site>/<lang>/`
  /// path, so the path is what identifies them. Matching on the host instead
  /// meant listing hosts that stop working the next time the site is crawled.
  ///
  /// The leading slash is what keeps `2xstorage.com` out of this: that host
  /// matches a name, never a `/storage/` path.

  /// The referer [imageUrl]'s host expects, or null when it needs none.
  ///
  /// Public so a test can assert the mapping against real captured markup: a
  /// cover host missing from this table is a silent 403, not a broken URL, so
  /// nothing in the app would otherwise complain about it.
  static String? refererFor(Uri uri) => ImageReferer.refererFor(uri);

  Map<String, String>? get _headers {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || uri.host.isEmpty) return null;
    final referer = refererFor(uri);
    return referer == null ? null : {'Referer': referer};
  }

  /// The physical-pixel width to decode a cover at, or null to decode as-is.
  ///
  /// Only a finite, positive [width] yields a bound. `double.infinity` means
  /// "fill the parent", so the real size is not knowable here - four screens
  /// ask for that - and guessing would decode every cover at an arbitrary size.
  /// Those stay uncapped, which is correct if not optimal.
  int? _decodeWidth(BuildContext context) {
    final w = width;
    if (w == null || !w.isFinite || w <= 0) return null;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final px = (w * dpr).round();
    // Anything under 8px is a layout artefact, not a size worth honouring.
    return px < 8 ? null : px;
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
      decodeWidth: decodeWidth ?? _decodeWidth(context),
      httpHeaders: _headers,
      placeholder: placeholder,
      errorWidget:
          errorWidget ??
          (context, url, error) => Container(
            color: Colors.black26,
            alignment: Alignment.center,
            child: const Icon(Icons.menu_book_outlined, color: Colors.white38),
          ),
      placeholderFadeInDuration: placeholderFadeInDuration,
      fadeInDuration: fadeInDuration,
    );
  }
}
