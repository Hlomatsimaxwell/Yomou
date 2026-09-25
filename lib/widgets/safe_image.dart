import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yomou/core/cache/app_cache.dart';
import 'package:yomou/data/sources/mf_scramble.dart';
import 'package:image/image.dart' as img;

/// Background-isolate callback that de-scrambles a MangaFire chapter page.
Uint8List? _unscrambleMfPage((Uint8List, int) message) {
  return MfScramble.unscramble(message.$1, message.$2);
}

/// Decodes an encoded image on a background isolate and re-encodes it as PNG.
///
/// Flutter on Android API 28+ decodes through `android.graphics.ImageDecoder`,
/// which throws `unimplemented` for formats some devices (notably Huawei) lack
/// support for, e.g. lossless/animated WebP, HEIF or AVIF. PNG/JPEG are decoded
/// by every Android version, so transcoding a problem image to PNG lets it
/// render. Returns null when the bytes cannot be decoded at all.
Uint8List? _transcodeToPng(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return img.encodePng(decoded);
  } catch (_) {
    return null;
  }
}

/// Drop-in replacement for [CachedNetworkImage] that falls back to a pure-Dart
/// decode (via `package:image`) when the platform codec fails. Healthy images
/// (JPEG/PNG/GIF) keep using the fast, hardware-accelerated engine path; only
/// failures are transcoded, so there is no cost in the common case.
class SafeNetworkImage extends StatefulWidget {
  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.httpHeaders,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.placeholderFadeInDuration,
    this.gaplessPlayback = false,
    this.alignment = Alignment.center,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Map<String, String>? httpHeaders;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final Duration fadeInDuration;
  final Duration? placeholderFadeInDuration;
  final bool gaplessPlayback;
  final Alignment alignment;

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  bool _fallback = false;
  Future<Uint8List?>? _decoded;

  void _startFallback() {
    if (_fallback) return;
    setState(() {
      _fallback = true;
      _decoded = _loadTranscoded();
    });
  }

  Future<Uint8List?> _loadTranscoded() async {
    try {
      // Reuses the bytes CachedNetworkImage already downloaded (when it did).
      final file = await AppImageCache.instance.manager.getSingleFile(
        widget.imageUrl,
        headers: widget.httpHeaders,
      );
      final bytes = await file.readAsBytes();
      return compute(_transcodeToPng, bytes);
    } catch (_) {
      return null;
    }
  }

  // --- MangaFire scrambled pages ---

  /// MangaFire serves some chapter images as a shuffled tile grid; URLs carry
  /// a `#scrambled_N` fragment. Those pages can't be shown by the platform
  /// decoder, so they are de-scrambled to PNG on a background isolate instead.
  Widget _buildScrambled(int offset) {
    return _sized(
      FutureBuilder<Uint8List?>(
        future: _loadScrambled(offset),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return widget.placeholder?.call(context, widget.imageUrl) ??
                const _CoverFallback();
          }
          final bytes = snapshot.data;
          if (bytes == null) return _showError('Failed to decode image');

          return Image.memory(
            bytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
            gaplessPlayback: widget.gaplessPlayback,
            errorBuilder: (context, error, stack) => _showError(error),
          );
        },
      ),
    );
  }

  Future<Uint8List?> _loadScrambled(int offset) async {
    try {
      final file = await AppImageCache.instance.manager.getSingleFile(
        widget.imageUrl,
        headers: widget.httpHeaders,
      );
      final bytes = await file.readAsBytes();
      final decoded = await compute(_unscrambleMfPage, (bytes, offset));
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Widget _showError(Object error) {
    final builder = widget.errorWidget;
    if (builder != null) {
      return builder(context, widget.imageUrl, error);
    }
    return const _CoverFallback();
  }

  /// Locks the widget to its requested dimensions. `CachedNetworkImage`
  /// enforces [width]/[height] itself, but the transcode fallback path replaces
  /// it with a bare box, so without this a loose parent (e.g. the detail header)
  /// would collapse the cover to the icon size.
  Widget _sized(Widget child) {
    if (widget.width != null && widget.height != null) {
      return SizedBox(width: widget.width, height: widget.height, child: child);
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final mfOffset = MfScramble.offsetFromUrl(widget.imageUrl);
    if (mfOffset != null) {
      return _buildScrambled(mfOffset);
    }
    if (!_fallback) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        cacheManager: AppImageCache.instance.manager,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        httpHeaders: widget.httpHeaders,
        placeholder: widget.placeholder,
        placeholderFadeInDuration: widget.placeholderFadeInDuration,
        fadeInDuration: widget.fadeInDuration,
        alignment: widget.alignment,
        errorWidget: (context, url, error) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _startFallback();
          });
          return _showError(error);
        },
      );
    }

    return _sized(
      FutureBuilder<Uint8List?>(
        future: _decoded,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return widget.placeholder?.call(context, widget.imageUrl) ??
                const _CoverFallback();
          }
          final bytes = snapshot.data;
          if (bytes == null) return _showError('Failed to decode image');

          return Image.memory(
            bytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
            gaplessPlayback: widget.gaplessPlayback,
            errorBuilder: (context, error, stack) => _showError(error),
          );
        },
      ),
    );
  }
}

/// File counterpart to [SafeNetworkImage] for locally stored cover/page images.
/// Tries the normal engine decoder first and only transcodes on failure, so
/// downloaded WebP pages still render on Android 9.
class SafeFileImage extends StatefulWidget {
  const SafeFileImage({
    super.key,
    required this.file,
    this.width,
    this.height,
    this.fit,
    this.errorWidget,
    this.gaplessPlayback = false,
    this.alignment = Alignment.center,
  });

  final File file;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final bool gaplessPlayback;
  final Alignment alignment;

  @override
  State<SafeFileImage> createState() => _SafeFileImageState();
}

class _SafeFileImageState extends State<SafeFileImage> {
  bool _fallback = false;
  Future<Uint8List?>? _decoded;

  void _startFallback() {
    if (_fallback) return;
    setState(() {
      _fallback = true;
      _decoded = _loadTranscoded();
    });
  }

  Future<Uint8List?> _loadTranscoded() async {
    try {
      final bytes = await widget.file.readAsBytes();
      return compute(_transcodeToPng, bytes);
    } catch (_) {
      return null;
    }
  }

  Widget _showError(Object error) {
    final builder = widget.errorWidget;
    if (builder != null) {
      return builder(context, widget.file.path, error);
    }
    return Container(
      color: Colors.black26,
      alignment: Alignment.center,
      child: const Icon(Icons.menu_book_outlined, color: Colors.white38),
    );
  }

  /// See [_SafeNetworkImageState._sized]: keeps the box locked to its size so a
  /// loose parent cannot collapse the cover while a local image is transcoded.
  Widget _sized(Widget child) {
    if (widget.width != null && widget.height != null) {
      return SizedBox(width: widget.width, height: widget.height, child: child);
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    if (!_fallback) {
      return Image.file(
        widget.file,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        gaplessPlayback: widget.gaplessPlayback,
        errorBuilder: (context, error, stack) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _startFallback();
          });
          return _showError(error);
        },
      );
    }

    return _sized(
      FutureBuilder<Uint8List?>(
        future: _decoded,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CoverFallback();
          }
          final bytes = snapshot.data;
          if (bytes == null) return _showError('Failed to decode image');

          return Image.memory(
            bytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
            gaplessPlayback: widget.gaplessPlayback,
            errorBuilder: (context, error, stack) => _showError(error),
          );
        },
      ),
    );
  }
}

/// Full-size broken-cover fallback: dark box with a centered book icon. Used
/// whenever an image cannot be decoded, so a failed cover never collapses to a
/// zero-size flash mid-transcode.
class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      alignment: Alignment.center,
      child: const Icon(Icons.menu_book_outlined, color: Colors.white38),
    );
  }
}
