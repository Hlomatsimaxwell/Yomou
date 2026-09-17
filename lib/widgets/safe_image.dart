import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart' as img;

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
      final file = await DefaultCacheManager().getSingleFile(
        widget.imageUrl,
        headers: widget.httpHeaders,
      );
      final bytes = await file.readAsBytes();
      return compute(_transcodeToPng, bytes);
    } catch (_) {
      return null;
    }
  }

  Widget _showError(Object error) {
    final builder = widget.errorWidget;
    if (builder != null) {
      return builder(context, widget.imageUrl, error);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (!_fallback) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
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

    return FutureBuilder<Uint8List?>(
      future: _decoded,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.placeholder?.call(context, widget.imageUrl) ??
              const SizedBox.shrink();
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
    return const SizedBox.shrink();
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

    return FutureBuilder<Uint8List?>(
      future: _decoded,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
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
    );
  }
}
