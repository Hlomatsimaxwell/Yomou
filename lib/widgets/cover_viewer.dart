import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/gallery/gallery_saver.dart';
import 'package:yomou/core/image_url.dart';
import 'package:yomou/core/widgets/ios/ios_toast.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// Opens a cover full-screen over a black backdrop.
///
/// When [heroTag] is given the art flies out of the cover it was tapped on, so
/// the expand reads as that same image growing rather than a new screen
/// appearing. Pinch to zoom; tap anywhere, or hit the close button, to dismiss.
Future<void> showCoverViewer(
  BuildContext context, {
  required String imageUrl,
  required String title,
  String? heroTag,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => _CoverViewerScreen(
        imageUrl: imageUrl,
        title: title,
        heroTag: heroTag,
      ),
    ),
  );
}

class _CoverViewerScreen extends StatefulWidget {
  const _CoverViewerScreen({
    required this.imageUrl,
    required this.title,
    this.heroTag,
  });

  final String imageUrl;
  final String title;
  final String? heroTag;

  @override
  State<_CoverViewerScreen> createState() => _CoverViewerScreenState();
}

class _CoverViewerScreenState extends State<_CoverViewerScreen> {
  bool _saving = false;

  /// The art, sharpened in place.
  ///
  /// Sources list a thumbnail (MangaDex's `.256.jpg`, WordPress's
  /// `-193x278.jpg`) and keep the original beside it. The thumbnail is drawn
  /// first — it is already cached, so the flight out of the tapped cover has
  /// something to carry — and the original is layered on top, fading in once
  /// it has decoded. If the original is missing, its error slot is empty and
  /// the thumbnail simply stays.
  Widget _buildArt(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cap = (MediaQuery.sizeOf(context).width * dpr).round();
    final decodeWidth = cap >= 8 ? cap : null;

    final full = fullSizedImageUrl(widget.imageUrl);
    if (full == widget.imageUrl) {
      return CachedMangaImage(
        imageUrl: widget.imageUrl,
        fit: BoxFit.contain,
        decodeWidth: decodeWidth,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedMangaImage(imageUrl: widget.imageUrl, fit: BoxFit.contain),
        CachedMangaImage(
          imageUrl: full,
          fit: BoxFit.contain,
          decodeWidth: decodeWidth,
          errorWidget: (context, url, error) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    final outcome = await saveCoverToGallery(
      imageUrl: widget.imageUrl,
      title: widget.title,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    showIosToast(
      context,
      message: switch (outcome) {
        CoverSaveOutcome.saved => l.coverSaved,
        CoverSaveOutcome.permissionDenied => l.coverSavePermission,
        CoverSaveOutcome.failed => l.coverSaveFailed,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final art = _buildArt(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // One gesture surface for both jobs: the tap dismisses, and the zoom
          // view beneath it keeps the pinch and pan. They share an arena, so a
          // drag zooms while a still tap falls through to the dismiss.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: widget.heroTag == null
                    ? art
                    : Hero(tag: widget.heroTag!, child: art),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(RemixIcons.close_line, color: Colors.white),
                tooltip: l.close,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: _saving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        RemixIcons.download_2_line,
                        color: Colors.white,
                      ),
                      tooltip: l.coverSaveImage,
                      onPressed: _save,
                    ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
