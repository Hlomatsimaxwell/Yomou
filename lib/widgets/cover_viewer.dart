import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
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

class _CoverViewerScreen extends StatelessWidget {
  const _CoverViewerScreen({
    required this.imageUrl,
    required this.title,
    this.heroTag,
  });

  final String imageUrl;
  final String title;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final image = CachedMangaImage(imageUrl: imageUrl, fit: BoxFit.contain);
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
                child: heroTag == null
                    ? image
                    : Hero(tag: heroTag!, child: image),
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
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  title,
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
