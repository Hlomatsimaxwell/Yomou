import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yomou/core/theme/amoled.dart';
import 'package:yomou/data/sources/favicon_resolver.dart';
import 'package:yomou/data/sources/source_network.dart' show DioSource;
import 'package:yomou/widgets/safe_image.dart';

/// Universal "Premium Icon Plate": every source icon, everywhere, sits on the
/// exact same rounded square so grids read as a uniform "gallery of apps" and
/// lists read as one straight vertical line of identical geometry.
///
/// * Plate: fixed 56×56, radius 12dp (Kotatsu-Redo's FaviconDrawable.Large
///   corner size), solid background (`#F5F5F5` off-white in light mode,
///   elevated panel in dark mode) with a hairline border. Never transparent.
/// * Logo: full-bleed app-icon style — clipped with [ClipRRect] into the
///   rounded square and [BoxFit.cover] so it fills the plate edge to edge like
///   a launcher icon, exactly matching the letter-tile fallback.
/// * Fallback: when no logo comes through, the plate holds the reference's
///   FaviconDrawable-style brand tile — the theme's own surface with a single
///   bold letter in the source's deterministic hue. It doubles as the
///   placeholder while the logo is still being resolved.
/// * Discovery: the source's homepage is scraped for every logo the site
///   advertises *before anything is displayed* (Kotatsu-Redo's
///   FaviconParser/Favicons.find pipeline, see [FaviconResolver]); the plate
///   holds the letter tile meanwhile, walks those candidates until one
///   loads, and only after the walk is spent does the declared [iconUrl] get
///   its try — the reference's favicon.ico fallback role.
class SourceIcon extends StatefulWidget {
  const SourceIcon({
    super.key,
    required this.name,
    this.iconUrl = '',
    this.siteUrl = '',
    this.size = 56,
    this.assetPath = '',
  });

  final String name;
  final String iconUrl;

  /// The source's own website, whose homepage is scraped for the real logo.
  /// When empty, discovery falls back to [iconUrl]'s origin — correct for a
  /// source that hosts its icon itself, wrong for one whose icon lives on a
  /// CDN (the catalog's `cdn.jsdelivr.net` icons would otherwise make the
  /// CDN's favicon the source's logo).
  final String siteUrl;
  final double size;

  /// Bundled artwork, used when [iconUrl] cannot be decoded by Flutter (a
  /// remote `.ico`/`.svg`, or an unreachable host). Empty when there is none.
  final String assetPath;

  /// Source name prefixes whose icon is bundled in `assets/source_icons/`
  /// (their remote icons are `.ico`/`.svg`, which Flutter cannot decode).
  static const Map<String, String> _bundledByPrefix = {};

  /// The loader behind every remote logo. Production wiring is
  /// [SourceIcon.defaultLoader]; tests can pin a strictly in-frame fake
  /// instead, so the failure walk runs without dragging the real
  /// cache-manager machinery (whose store timers are unschedulable under the
  /// test clock) into a widget test.
  @visibleForTesting
  static SourceIconImageLoader? debugImageLoader;

  static Widget defaultLoader({
    Key? key,
    required String imageUrl,
    required BoxFit fit,
    int? decodeWidth,
    required Map<String, String>? httpHeaders,
    required Widget? Function(BuildContext, String) placeholder,
    required Widget? Function(BuildContext, String, Object) errorWidget,
  }) {
    // Some sites (MangaFire) publish their logo only as an SVG; the raster
    // pipeline below cannot decode that and the tile would fall back to the
    // letter glyph, so render vectors through flutter_svg instead.
    if (imageUrl.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        imageUrl,
        key: key,
        headers: httpHeaders,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        placeholderBuilder: (context) =>
            placeholder(context, imageUrl) ?? const SizedBox.shrink(),
        errorBuilder: (context, error, stack) =>
            errorWidget(context, imageUrl, error) ??
            const SizedBox.shrink(),
      );
    }
    return SafeNetworkImage(
      key: key,
      imageUrl: imageUrl,
      httpHeaders: httpHeaders,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      decodeWidth: decodeWidth,
      placeholder: (context, url) => placeholder(context, url) ?? const SizedBox.shrink(),
      errorWidget: (context, url, err) =>
          errorWidget(context, url, err) ?? const SizedBox.shrink(),
    );
  }

  @override
  State<SourceIcon> createState() => _SourceIconState();
}

/// The contract [SourceIcon] asks of a remote-logo renderer.
typedef SourceIconImageLoader =
    Widget Function({
      Key? key,
      required String imageUrl,
      required BoxFit fit,
      int? decodeWidth,
      required Map<String, String>? httpHeaders,
      required Widget? Function(BuildContext, String) placeholder,
      required Widget? Function(BuildContext, String, Object) errorWidget,
    });

class _SourceIconState extends State<SourceIcon> {
  /// Logos recovered from the site's own homepage, in [FaviconResolver]'s
  /// trial order. Null while the discovery is under way — the plate holds the
  /// letter tile for that moment, the same placeholder the reference's
  /// FaviconView shows while Coil resolves. Empty means the site gave
  /// nothing up; the declared URL gets its turn after that.
  List<String>? _recovered;

  @override
  void initState() {
    super.initState();
    _discover();
  }

  @override
  void didUpdateWidget(covariant SourceIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iconUrl != widget.iconUrl ||
        oldWidget.siteUrl != widget.siteUrl ||
        oldWidget.name != widget.name ||
        oldWidget.assetPath != widget.assetPath) {
      // A different source behind the same plate: resolve it instead.
      _recovered = null;
      _discover();
    }
  }

  void _discover() {
    final chain = FaviconResolver.candidates(
      widget.iconUrl,
      siteUrl: widget.siteUrl,
    );
    chain?.then((candidates) {
      if (!mounted) return;
      setState(() => _recovered = candidates);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final letter = widget.name.isEmpty ? '?' : widget.name[0];

    // Cotatsu-Redo's FaviconDrawable tile: the theme's own background with an
    // outline stroke, and the first letter painted in a colour scrolled off
    // the name. It is both the no-logo fallback and the in-flight placeholder,
    // so a source whose logo has not arrived yet (or never will) never sits as
    // an empty plate.
    Widget fallback() =>
        _BrandFallback(name: widget.name, letter: letter, size: widget.size);

    // The mandatory plate geometry. Kotatsu's FaviconDrawable style rounds at
    // 12dp in the large role (8dp in the small one), which is what keeps a
    // tile square where ours at 16dp read rounder than the reference's; the
    // scale matches at any size.
    final radius = widget.size >= 40 ? 12.0 : widget.size * (12 / 56);

    final bundled = widget.assetPath.isNotEmpty
        ? widget.assetPath
        : (SourceIcon._bundledByPrefix.entries
                  .where((e) => widget.name.trim().startsWith(e.key))
                  .map((e) => e.value)
                  .firstOrNull ??
              '');


    // The plate is at most [size] logical pixels, so that is all the bitmap
    // that can ever be shown. The plate itself paints at `double.infinity` to
    // fill whatever box it is given, which is exactly the case
    // [SafeNetworkImage.decodeWidth] cannot infer -- so it is passed explicitly
    // here. Without it every tile in the sources wall decoded its remote logo
    // at full resolution (these are app icons, routinely 256-512px), and a wall
    // of a hundred of them filled the image cache and evicted the icons the
    // list was about to redraw.
    final decodeWidth =
        (widget.size * MediaQuery.of(context).devicePixelRatio).round();

    Widget load(
      String imageUrl, {
      required Widget? Function(BuildContext, String) placeholder,
      required Widget? Function(BuildContext, String, Object) errorWidget,
    }) {
      final parsed = Uri.tryParse(imageUrl);
      final headers = <String, String>{
        // Logos are ordinary images for every other request in the app, but
        // many CDNs (and Cloudflare-gated sites like WeebCentral) 403 a
        // request that arrives without a browser user agent — the same
        // header the reference's web client puts on its favicon fetches.
        'User-Agent': DioSource.defaultUserAgent,
        // The image's own origin, the way an <img> tag on the source's site
        // would send it, keeps referrer-checked CDNs from turning the
        // request away.
        if (parsed != null && parsed.host.isNotEmpty)
          'Referer': '${parsed.scheme}://${parsed.host}/',
        'Accept':
            'image/avif,image/webp,image/png,image/svg+xml,image/*,*/*;q=0.8',
      };
      return (SourceIcon.debugImageLoader ?? SourceIcon.defaultLoader)(
        // The loader is stateful about its URL, and a walk replaces a failed
        // logo with a different one at the same tree position: keyed so the
        // next candidate starts from a fresh state.
        key: ValueKey(imageUrl),
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        decodeWidth: decodeWidth,
        httpHeaders: headers,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    }

    Widget primary() {
      if (widget.iconUrl.isEmpty) {
        // Nothing to fall back on: the letter tile is the plate.
        return fallback();
      }
      return load(
        widget.iconUrl,
        placeholder: (context, url) => fallback(),
        errorWidget: (context, url, error) => fallback(),
      );
    }

    /// One candidate, and its own failure tips the next one out of the chain
    /// — the reference's `FaviconFetcher` walk (`favicons -= icon`, find
    /// again) expressed as a cascade of errorWidget buldings. When the whole
    /// chain is spent, the declared URL gets the last word before the letter
    /// tile claims the plate.
    Widget recovered(int index) {
      if (index >= _recovered!.length) return primary();
      final url = _recovered![index];
      return load(
        url,
        placeholder: (context, url) => fallback(),
        errorWidget: (context, url, error) => recovered(index + 1),
      );
    }

    Widget logo() {
      if (bundled.isNotEmpty) {
        return Image.asset(
          bundled,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: decodeWidth,
          errorBuilder: (context, error, stack) => fallback(),
        );
      }
      if (_recovered == null) return fallback();
      return recovered(0);
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: dark ? amoled(context, 0xFF2C2C2E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: (widget.iconUrl.isNotEmpty ||
                widget.siteUrl.isNotEmpty ||
                bundled.isNotEmpty)
            ? logo()
            : fallback(),
      ),
    );
  }
}

class _BrandFallback extends StatelessWidget {
  const _BrandFallback({required this.name, required this.letter, required this.size});

  final String name;
  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // The name's own colour, the same recipe KotatsuColors.random follows:
    // hue = |String.hashCode| % 360 at saturation/lightness 0.5. Wrapping in
    // signed 32-bit arithmetic reproduces Kotlin's String.hashCode() exactly,
    // so a source wears the same hue here as in the reference app, and the
    // same source always wears the same hue here session to session.
    final hue = (kotlinStringHash(name).abs() % 360).toDouble();
    final raw = HSLColor.fromAHSL(1, hue, 0.5, 0.5).toColor();

    // MaterialColors.harmonize leans the letter's colour toward the tile it
    // sits on so no hue ever fights the background; a blend toward the tile's
    // own surface is the same idea.
    final foreground = Color.lerp(raw, cs.surface, 0.15)!;

    return DecoratedBox(
      // The tile takes the theme's own background so it reads exactly like
      // the reference's FaviconDrawable tiles, and nothing more: the plate
      // that holds it already paints the same hairline edge as every other
      // tile, so a letter tile never wears a different rim from a favicon
      // sitting beside it.
      decoration: BoxDecoration(color: cs.surface),
      child: Center(
        // The letter is drawn slightly right of centre in the reference
        // (cx at 60% of the width) -- the little offset that keeps a bold
        // glyph from looking optically left-heavy.
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            letter.toUpperCase(),
            // Kotatsu sizes the letter to roughly half of what would fill the
            // tile, which is what makes their tiles read as a logo rather
            // than as a caption.
            style: TextStyle(
              fontSize: _fittedLetterSize(),
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }

  /// Half of the font size at which [letter] would span the tile's inner
  /// width, mirroring `FaviconDrawable.getTextSizeForWidth` and its `* 0.5f`.
  double _fittedLetterSize() {
    const probe = 48.0;
    final painter = TextPainter(
      text: TextSpan(
        text: letter.toUpperCase(),
        style: const TextStyle(
          fontSize: probe,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final inner = size;
    return probe * inner / painter.width * 0.5;
  }
}

/// Kotlin's `String.hashCode()`: the Java spelling, wrapping each step in
/// signed 32-bit arithmetic. Dart's int is 64-bit, so without the wrap the
/// multiplication runs away and the hue stops matching the reference's.
int kotlinStringHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0xFFFFFFFF;
    if (h >= 0x80000000) h -= 0x100000000;
    if (h < -0x80000000) h += 0x100000000;
  }
  return h;
}
