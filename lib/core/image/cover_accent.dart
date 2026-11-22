import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import 'package:yomou/core/cache/app_cache.dart';
import 'package:yomou/core/image_referer.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// A muted colour sampled from a cover, for decorative use only.
///
/// Functional controls keep the user's chosen app accent. This is deliberately
/// just a wash behind the detail screen's existing cover plate: pulling a
/// scheme out of arbitrary cover art would fight the appearance settings and
/// produce unreadable buttons on a bright or monochrome cover.
final coverAccentProvider = FutureProvider.family<Color?, String>((ref, url) async {
  if (url.isEmpty) return null;
  final argb = await _loadCoverAccent(url);
  if (argb == null) return null;
  // Mute it towards neutral before it ever reaches the UI. A vivid red cover
  // should tint the plate, not turn the whole header red.
  return Color.lerp(Color(argb), const Color(0xFF8A9099), 0.35);
});

Future<int?> _loadCoverAccent(String url) async {
  Uint8List? bytes;
  try {
    if (url.startsWith(CachedMangaImage.localScheme)) {
      final file = File(url.substring(CachedMangaImage.localScheme.length));
      if (await file.exists()) bytes = await file.readAsBytes();
    } else {
      final uri = Uri.tryParse(url);
      final referer = uri == null ? null : ImageReferer.refererFor(uri);
      final file = await AppImageCache.instance.manager.getSingleFile(
        url,
        headers: referer == null ? null : {'Referer': referer},
      );
      bytes = await file.readAsBytes();
    }
  } catch (_) {
    return null;
  }
  if (bytes == null || bytes.isEmpty) return null;
  return compute(sampleCoverAccent, bytes);
}

/// Picks a weighted average of the most colourful mid-tone bucket in the image.
///
/// Top-level so [compute] can send it to a background isolate. Returns an ARGB
/// int; converting to a Flutter [Color] happens on the main isolate. Palettes
/// and white/black extremes are ignored, so a black-and-white cover or a
/// screenshot with a big white margin yields no accent at all rather than grey.
@visibleForTesting
int? sampleCoverAccent(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // Truncated or corrupt covers make some decoders throw instead of
    // returning null. A decorative tint is never worth failing the screen.
    return null;
  }
  if (decoded == null || decoded.width == 0 || decoded.height == 0) return null;

  img.Image sample;
  try {
    // Sampling a small copy keeps the isolate cheap even for a 4000px cover.
    sample = img.copyResize(decoded, width: 48);
  } catch (_) {
    return null;
  }
  const bucketBits = 5; // 32 levels per channel
  const bucketCount = 1 << (bucketBits * 3);
  final weights = Float64List(bucketCount);
  final sumsR = Float64List(bucketCount);
  final sumsG = Float64List(bucketCount);
  final sumsB = Float64List(bucketCount);

  for (var y = 0; y < sample.height; y++) {
    for (var x = 0; x < sample.width; x++) {
      final pixel = sample.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final alpha = pixel.a.toInt();
      if (alpha < 128) continue;

      final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
      if (max < 38 || max > 235 || max - min < 46) continue;
      final saturation = (max - min) / max;
      final value = max / 255;
      // Favour saturated mid-tones; very dark and very light pixels wash out.
      final weight = saturation * (1 - (value - 0.55).abs());
      if (weight <= 0) continue;

      final index = ((r >> bucketBits) << (bucketBits * 2)) |
          ((g >> bucketBits) << bucketBits) |
          (b >> bucketBits);
      weights[index] += weight;
      sumsR[index] += r * weight;
      sumsG[index] += g * weight;
      sumsB[index] += b * weight;
    }
  }

  var best = -1;
  var bestWeight = 0.0;
  for (var i = 0; i < bucketCount; i++) {
    if (weights[i] > bestWeight) {
      bestWeight = weights[i];
      best = i;
    }
  }
  if (best < 0) return null;

  final r = (sumsR[best] / bestWeight).round().clamp(0, 255);
  final g = (sumsG[best] / bestWeight).round().clamp(0, 255);
  final b = (sumsB[best] / bestWeight).round().clamp(0, 255);
  return (0xFF << 24) | (r << 16) | (g << 8) | b;
}
