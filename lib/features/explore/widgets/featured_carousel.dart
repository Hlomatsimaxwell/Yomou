import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/widgets/ios/ios_press.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/features/suggestions/providers/suggestions_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// Kotatsu-style featured hero at the top of Explore: a carousel of taste-based
/// suggestions in large "story" cards with a framing cover and a dot indicator
/// underneath. Rides the shared suggestions feed so it costs no extra network
/// work.
///
/// Everything the card paints is derived from the width this section is
/// actually given -- see [_FeaturedLayout]. A fixed 204px height and a fixed
/// 104x150 cover meant the card was squeezed to 166px of text column on a
/// 320dp phone and stretched to a 5.4:1 strip with a 104px cover adrift in
/// 1095px on a desktop window: wrong at both ends, for the same reason the
/// grids were.
class FeaturedCarousel extends ConsumerStatefulWidget {
  const FeaturedCarousel({super.key});

  @override
  ConsumerState<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends ConsumerState<FeaturedCarousel> {
  PageController? _pageController;
  double? _pageFraction;

  /// Index into the current feed, already wrapped.
  ///
  /// Wrapped where it is stored rather than at each use. The page controller
  /// starts the carousel deep in the list so it can be swiped forever without
  /// running off either end, which means the raw page index runs into the
  /// thousands -- and the dot row compared its widths against that raw value
  /// while its colours were compared against the wrapped one. The wide pill was
  /// therefore painted in the *inactive* colour, permanently, on every card.
  int _current = 0;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  /// The controller for [layout], rebuilt only when the fraction it was made
  /// with no longer fits.
  ///
  /// A new one rather than a mutation because the fraction is derived from the
  /// width: resizing a desktop window changes how many cards fit at the target
  /// card width, and a PageController cannot be told.
  ///
  /// The old controller is disposed after the frame rather than here, because
  /// it is still attached to the PageView this build is about to hand a new one
  /// to; disposing it now throws on the next frame's scroll notification.
  PageController _controllerFor(_FeaturedLayout layout, int count) {
    if (_pageController == null || _pageFraction != layout.viewportFraction) {
      final stale = _pageController;
      _pageFraction = layout.viewportFraction;
      _current = 0;
      _pageController = PageController(
        viewportFraction: layout.viewportFraction,
        // Deep enough that neither end of the feed is ever reachable, so the
        // carousel can be swiped in either direction for as long as the user
        // likes. Wrapped against [count] by [_current], hence the multiple.
        initialPage: count * 400,
      );
      if (stale != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => stale.dispose());
      }
    }
    return _pageController!;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measured from the constraints rather than the window. The nav rail
        // sits beside Explore on a wide layout and takes 80px off it, and
        // MediaQuery still reports the window width down here -- so a fraction
        // taken from the window sized cards for space this section does not
        // have.
        final layout = _FeaturedLayout.resolve(constraints.maxWidth);
        final suggestions = ref.watch(suggestionsProvider(null));
        // Sampled across the whole feed rather than its head, so the hero is
        // not the Suggestions tab's first screenful in the same order. Still
        // the same feed: that is deliberate, it is what makes the hero free.
        //
        // valueOrNull, not `value ?? const []`: `value` rethrows the error
        // rather than yielding null, so unwrapping it before the state has been
        // checked throws out of this build on a failed feed rather than drawing
        // the reason for it.
        final featured = spreadAcross(
          suggestions.valueOrNull ?? const <Manga>[],
          _featuredCount,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (suggestions.isLoading)
              _CarouselSkeleton(layout: layout)
            else if (suggestions.hasError)
              _CarouselError(
                layout: layout,
                error: suggestions.error?.toString() ?? '',
                onRetry: () => ref.invalidate(suggestionsProvider(null)),
              )
            else if (featured.isNotEmpty) ...[
              SizedBox(
                height: layout.height,
                child: PageView.builder(
                  controller: _controllerFor(layout, featured.length),
                  onPageChanged: (index) {
                    if (featured.isEmpty) return;
                    setState(() => _current = index % featured.length);
                  },
                  itemBuilder: (context, index) => _FeaturedCard(
                    manga: featured[index % featured.length],
                    index: index % featured.length,
                    layout: layout,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildDotRow(featured.length),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDotRow(int count) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Both the width and the colour read [_current]. They used to read it
        // two different ways, which is how the selected dot came out the colour
        // of an unselected one.
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _current ? _featuredDotActive : _featuredDotIdle,
            height: _featuredDotSize,
            decoration: BoxDecoration(
              color: i == _current
                  ? Theme.of(context).colorScheme.primary
                  : (dark ? Colors.white24 : Colors.black26),
              borderRadius: BorderRadius.circular(_featuredDotSize / 2),
            ),
          ),
      ],
    );
  }
}

class _FeaturedCard extends ConsumerStatefulWidget {
  const _FeaturedCard({
    required this.manga,
    required this.index,
    required this.layout,
  });

  final Manga manga;
  final int index;
  final _FeaturedLayout layout;

  @override
  ConsumerState<_FeaturedCard> createState() => _FeaturedCardState();
}

class _FeaturedCardState extends ConsumerState<_FeaturedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3800),
  )..repeat();

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final schema = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    final accent = ref.watch(accentProvider);
    final manga = widget.manga;
    final sourceId = manga.sourceId.trim();
    final blurb = _blurbFor(manga);
    final titleColor = dark ? Colors.white : const Color(0xFF1C1B1F);
    final bodyColor = dark
        ? Colors.white.withValues(alpha: 0.66)
        : Colors.black.withValues(alpha: 0.55);
    final sourceColor = dark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);
    final sheenColor = dark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final watermarkColor = dark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);
    final topSheenColor = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.05);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _featuredCardGutter),
      // AppPress rather than a bare GestureDetector: this is the same press
      // feedback every other tappable card in Explore uses, and it is a scale
      // rather than a Material ripple, so it needs no Material underneath it to
      // paint on -- the card is a decorated Container, which is not one.
      child: AppPress(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MangaDetailScreen(
                mangaId: manga.id,
                title: manga.title,
                imageUrl: manga.coverUrl,
                sourceId: manga.sourceId,
              ),
            ),
          );
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_featuredRadius),
            gradient: dark
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.34),
                      const Color(0xFF26262A),
                      const Color(0xFF111114),
                    ],
                    stops: const [0, 0.42, 1],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.12),
                      const Color(0xFFFFFFFF),
                      const Color(0xFFF2F2F5),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.09)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // First, because a Stack paints in order and this is a watermark.
              // It was declared last, which put a 110pt grey number on top of
              // the title, the blurb and the cover -- at 5% alpha, so subtle
              // enough to look like dirt on the card rather than like a bug.
              Positioned(
                left: -layout.cardWidth * 0.024,
                bottom: -layout.height * 0.167,
                child: Text(
                  '${widget.index + 1}'.padLeft(2, '0'),
                  style: TextStyle(
                    color: watermarkColor,
                    fontSize: layout.watermarkSize,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 20,
                right: 16,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [topSheenColor, Colors.transparent],
                      stops: const [0, 0.7],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _featuredTextPadLeft,
                        _featuredCardPad,
                        _featuredTextPadRight,
                        _featuredCardPad,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: schema.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                l.featuredManga.toUpperCase(),
                                style: TextStyle(
                                  color: dark
                                      ? Colors.white.withValues(alpha: 0.78)
                                      : accent,
                                  fontSize: layout.eyebrowSize,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              if (sourceId.isNotEmpty &&
                                  sourceId != 'mock') ...[
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    sourceId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: sourceColor,
                                      fontSize: layout.eyebrowSize - 0.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: _featuredTitleGap),
                          Text(
                            manga.title,
                            maxLines: _featuredTitleLines,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: layout.titleSize,
                              fontWeight: FontWeight.w800,
                              height: _featuredTitleLineHeight,
                              letterSpacing: 0.1,
                            ),
                          ),
                          // Absent rather than invented. This
                          // used to fall back to a canned "Discover this
                          // pick from <source>" line, which said nothing
                          // about this manga while sitting exactly where a
                          // description of it should be. Most listing rows
                          // carry no description and no tags, so on a lot of
                          // cards the second line is simply not there.
                          if (blurb.isNotEmpty) ...[
                            const SizedBox(height: _featuredBlurbGap),
                            Text(
                              blurb,
                              maxLines: _featuredBlurbLines,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: bodyColor,
                                fontSize: layout.blurbSize,
                                height: _featuredBlurbLineHeight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: _featuredCoverGap),
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.02,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              layout.coverWidth * 0.16,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _BookCover(
                            imageUrl: manga.coverUrl,
                            dark: dark,
                            width: layout.coverWidth,
                            height: layout.coverHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: _sheen,
                      builder: (context, _) {
                        return Transform.translate(
                          offset: Offset(
                            (_sheen.value * 2 - 1) * layout.cardWidth * 0.5,
                            0,
                          ),
                          child: FractionallySizedBox(
                            widthFactor: 0.22,
                            heightFactor: 1.6,
                            child: Transform.rotate(
                              angle: -0.45,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      sheenColor,
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The line under the title, or nothing.
  ///
  /// The description when the source gave one on the listing row, otherwise the
  /// manga's own genres. There is no third option: a made-up sentence about the
  /// source is not a description of this series, and an empty slot is honest
  /// where a wrong one is not.
  String _blurbFor(Manga manga) {
    final description = (manga.description ?? '').trim();
    if (description.isNotEmpty) return description;
    return manga.tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .take(_featuredBlurbTags)
        .join(' · ');
  }
}

/// The framed book: a padded plate, the art inside it, a spine down the right
/// edge and the sheen that sells it as a printed object.
///
/// Every size inside is a share of [width], because the block it draws is sized
/// by the layout and a fixed 101x150 inside a 168px cover left a third of the
/// plate empty.
class _BookCover extends StatelessWidget {
  const _BookCover({
    required this.imageUrl,
    required this.dark,
    required this.width,
    required this.height,
  });

  final String imageUrl;
  final bool dark;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // The plate's padding and the spine both scale with the block, so the
    // proportion that reads as a book at 104px survives at 168px.
    final pad = (width * 0.038).clamp(3.0, 6.0);
    final spine = (width * 0.029).clamp(2.0, 4.0);
    final artWidth = width - pad * 2 - spine;
    final artHeight = height - pad * 2;
    final artRadius = (width * 0.14).clamp(8.0, 22.0);

    // Sized explicitly, because a Row hands its non-flex children an unbounded
    // main axis and a Stack under an unbounded width is an infinite width. The
    // old code got this from a hardcoded SizedBox(104, 150).
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.19),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0.08),
                  ]
                : [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.05),
                  ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(artRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The art keeps clear of the spine rather than running under it.
              // It did overlap before, and the overlap is invisible at
              // 104px and a visible 4px band of lost art at 168px.
              Padding(
                padding: EdgeInsets.only(right: spine),
                child: CachedMangaImage(
                  imageUrl: imageUrl,
                  width: artWidth,
                  height: artHeight,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: dark
                        ? const Color(0xFF2A2A2C)
                        : const Color(0xFFDDD8D0),
                    alignment: Alignment.center,
                    child: Icon(
                      RemixIcons.book_open_fill,
                      color: dark ? Colors.white38 : Colors.black26,
                      size: artWidth * 0.24,
                    ),
                  ),
                ),
              ),
              // The spine, down the strip the art left it.
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: spine,
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF3B3B3E)
                        : const Color(0xFFEDE9E2),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: artWidth * 0.18,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.38),
                        Colors.black.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 1,
                  color: Colors.black.withValues(alpha: 0.25),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the carousel shows when the feed it rides fails.
///
/// It used to show nothing at all: `else if (featured.isNotEmpty)`. A failed
/// feed was indistinguishable from a feed that had not loaded, so Explore just
/// had no hero and no way to ask for one. Same shape as the other feed errors
/// in the app -- the reason, then a retry.
class _CarouselError extends StatelessWidget {
  const _CarouselError({
    required this.layout,
    required this.error,
    required this.onRetry,
  });

  final _FeaturedLayout layout;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    // The failed hero keeps its footprint, so a feed that errors leaves the
    // quick buttons and the sources wall where they were instead of pulling the
    // whole page up under the user's thumb.
    return SizedBox(
      height: layout.height,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.failedToLoadSuggestions,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dark ? Colors.white70 : const Color(0xFF49454F),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  error,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark ? Colors.white38 : Colors.black38,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(RemixIcons.refresh_line, size: 18),
                label: Text(l.retry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: dark ? Colors.white : scheme.onSurface,
                  side: BorderSide(
                    color: dark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarouselSkeleton extends StatefulWidget {
  const _CarouselSkeleton({required this.layout});

  final _FeaturedLayout layout;

  @override
  State<_CarouselSkeleton> createState() => _CarouselSkeletonState();
}

class _CarouselSkeletonState extends State<_CarouselSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final layout = widget.layout;
    final base = dark ? const Color(0xFF2C2C2E) : const Color(0xFFEDEDEF);
    final fill = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final fillStrong = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.12);
    // Proportioned off the same layout the real card uses, so the placeholder
    // is the card's shape rather than a 204px-tall guess that jumped when the
    // feed arrived.
    final bar = (layout.textWidth * 0.26).clamp(60.0, 120.0);
    return SizedBox(
      height: layout.height,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.55, end: 1).animate(_controller),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _featuredCardGutter),
          child: Container(
            padding: const EdgeInsets.all(_featuredCardPad),
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(_featuredRadius),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: bar,
                        height: 10,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: bar * 2,
                        height: layout.titleSize * 1.2,
                        decoration: BoxDecoration(
                          color: fillStrong,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: bar * 1.3,
                        height: 12,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: _featuredCoverGap),
                Container(
                  width: layout.coverWidth,
                  height: layout.coverHeight,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(
                      layout.coverWidth * 0.14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How many manga the carousel carries.
///
/// Twelve is what twelve dots fit across a 360dp phone without the dot row
/// becoming the widest thing in the section, and it is what the hero showed
/// before the count was named.
const int _featuredCount = 12;

/// Card width the carousel aims for, which is what decides how many it shows.
///
/// Derived rather than broken into one/two/three at fixed window widths, for
/// the reason the manga grids derive their columns: a breakpoint table has to
/// be right about a size nobody tested, and every width it does not name is
/// either a stretched strip or a shrunken card. A target width means an
/// unlisted window gets the count that keeps a card near this size, which is
/// 420 -- roughly where a three-line title, a two-line description and a
/// legible cover all fit at once with room to spare.
const double _featuredTargetCardWidth = 420;

/// Ceiling on cards at once.
///
/// Three. A fourth would put the covers below the floor where they stop reading
/// as covers, and the extra width is better spent on the sources wall below.
const int _featuredMaxCards = 3;

/// Air on each side of a card. Two of these is the gap between neighbours, so
/// the page extent in [_FeaturedLayout.resolve] counts the pair once.
const double _featuredCardGutter = 8;

/// Sliver of the next card left showing, so the row reads as scrollable.
///
/// A fixed number of pixels rather than a fraction of the window. 0.94 was a
/// 21px peek on a phone and a 70px one on a desktop, which showed a readable
/// slice of the next card's title before the user had swiped anything.
const double _featuredPeek = 24;

/// Share of the card the cover takes.
const double _featuredCoverShare = 0.33;

/// Cover aspect, 104:150 including the spine drawn down its right edge.
const double _featuredCoverAspect = 150 / 104;

/// Floor and ceiling on the cover.
///
/// The floor is the size the app already shipped, and it is the floor on
/// purpose: a derived number that came out smaller than what the hero has
/// always shown on a phone would be a regression dressed up as a fix. The
/// ceiling is where the plate stops reading as a book and starts reading as
/// a poster, and it is what stops a very wide card turning into one.
const double _featuredCoverMin = 104;
const double _featuredCoverMax = 168;

/// Space between the cover and the edge of the card.
const double _featuredCoverGap = 18;

/// Card padding, and the text column's own left and right insets.
const double _featuredCardPad = 16;
const double _featuredTextPadLeft = 20;
const double _featuredTextPadRight = 10;

/// Card corner radius.
const double _featuredRadius = 24;

/// Gaps and line counts inside the text column. The height in
/// [_FeaturedLayout.resolve] is measured from these, so they are not free.
const double _featuredTitleGap = 9;
const int _featuredTitleLines = 3;
const double _featuredTitleLineHeight = 1.18;
const double _featuredBlurbGap = 8;
const int _featuredBlurbLines = 2;
const double _featuredBlurbLineHeight = 1.35;

/// Genres to name when there is no description.
const int _featuredBlurbTags = 3;

/// Type shares of the text column, each with the band it stops at.
///
/// Shares rather than fixed sizes because the text column is what actually
/// varies: it is the card minus the cover, so it tracks the card's width. The
/// ceiling on the title is 20 rather than something larger on purpose -- a
/// bigger title is not a better title here, it is fewer characters per line in
/// a three-line allowance, and long manga names are what ellipsize.
const double _featuredTitleShare = 0.096;
const double _featuredTitleMin = 16;
const double _featuredTitleMax = 20;
const double _featuredBlurbShare = 0.062;
const double _featuredBlurbMin = 11;
const double _featuredBlurbMax = 14;
const double _featuredEyebrowShare = 0.037;
const double _featuredEyebrowMin = 10.5;
const double _featuredEyebrowMax = 12.5;

/// Shortest a card may be, as a share of its width.
///
/// Neither half of the card needs this on its own -- a 104px cover and three
/// title lines ask for about 148px -- and without it the hero came out as a
/// shallow band. It is a floor, not a target: whichever half needs more still
/// wins. 0.6 is what keeps the card's proportion at about 1.7:1, which is the
/// shape it has always had on a phone, at every other width too.
const double _featuredMinHeightRatio = 0.6;

/// Ceiling on the card's height, as a backstop.
///
/// The proportion floor alone would take a card past this in one place: just
/// below the width at which two cards fit, the section still has only the one,
/// and it is nearly twice the target width. Without the ceiling that card is
/// 494 tall on a window that has room for it and reads as a wall rather than a
/// hero. Everywhere else the floor wins and this is never reached -- which is
/// the sign it is doing the job it is here for and not setting the shape.
const double _featuredMaxHeight = 380;

/// Dot row.
const double _featuredDotSize = 6;
const double _featuredDotIdle = 6;
const double _featuredDotActive = 20;

/// How many cards the carousel shows at [width].
///
/// Derived from the target card width rather than a table of breakpoints, for
/// the reason the manga grids derive their columns: a breakpoint table has to
/// be right about a size nobody tested, and every width it does not name is
/// either a stretched strip or a shrunken card. A page is the card plus the
/// pair of gutters its edges keep, and the next card's sliver is measured from
/// its painted edge, so what is available is the window less one gutter and one
/// sliver -- see [_FeaturedLayout.resolve].
int _cardsFor(double width) =>
    ((width - _featuredPeek - _featuredCardGutter) / _featuredTargetCardWidth)
        .floor()
        .clamp(1, _featuredMaxCards);

/// The numbers a featured card's geometry resolves to.
class _FeaturedLayout {
  const _FeaturedLayout({
    required this.cardWidth,
    required this.viewportFraction,
    required this.height,
    required this.coverWidth,
    required this.coverHeight,
    required this.textWidth,
    required this.titleSize,
    required this.blurbSize,
    required this.eyebrowSize,
    required this.watermarkSize,
  });

  /// Resolves the carousel's geometry from the width it was actually given.
  ///
  /// The whole point is that nothing here is a constant that has to be right
  /// for one screen size and merely tolerable at the others. The card, the
  /// cover, the type and the height are derived together from one measurement,
  /// and the height is then measured from the type it is drawn with -- the same
  /// rule as `mangaCellAspectRatio`, for the same reason.
  factory _FeaturedLayout.resolve(double width) {
    // How many cards fit at the target width, on the same derivation the manga
    // grids use for their columns.
    final cards = _cardsFor(width);

    // A page is one card plus the pair of gutters its edges keep, and the
    // sliver of the next card is measured from the start of its *painted* edge
    // rather than the start of its page, because the next page's leading gutter
    // comes off it first. The window is therefore pages and a gutter, not
    // pages and a sliver.
    final pageWidth = (width - _featuredPeek - _featuredCardGutter) / cards;
    final cardWidth = pageWidth - _featuredCardGutter * 2;

    final coverWidth = (cardWidth * _featuredCoverShare).clamp(
      _featuredCoverMin,
      _featuredCoverMax,
    );
    final coverHeight = coverWidth * _featuredCoverAspect;

    final textWidth =
        cardWidth -
        _featuredTextPadLeft -
        _featuredTextPadRight -
        _featuredCoverGap -
        coverWidth;

    final titleSize = (textWidth * _featuredTitleShare).clamp(
      _featuredTitleMin,
      _featuredTitleMax,
    );
    final blurbSize = (textWidth * _featuredBlurbShare).clamp(
      _featuredBlurbMin,
      _featuredBlurbMax,
    );
    final eyebrowSize = (textWidth * _featuredEyebrowShare).clamp(
      _featuredEyebrowMin,
      _featuredEyebrowMax,
    );

    // Whichever half asks for more, then the proportion floor, then the
    // ceiling.
    final textHeight =
        eyebrowSize * 1.2 +
        _featuredTitleGap +
        _featuredTitleLines * titleSize * _featuredTitleLineHeight +
        _featuredBlurbGap +
        _featuredBlurbLines * blurbSize * _featuredBlurbLineHeight;
    final height = math.min(
      math.max(
        math.max(coverHeight, textHeight + _featuredCardPad * 2),
        cardWidth * _featuredMinHeightRatio,
      ),
      _featuredMaxHeight,
    );

    return _FeaturedLayout(
      cardWidth: cardWidth,
      viewportFraction: pageWidth / width,
      height: height,
      coverWidth: coverWidth,
      coverHeight: coverHeight,
      textWidth: textWidth,
      titleSize: titleSize,
      blurbSize: blurbSize,
      eyebrowSize: eyebrowSize,
      // Off the height, because the number is anchored to the card's bottom
      // edge and its size is only ever read against that.
      watermarkSize: (height * 0.54).clamp(80.0, 160.0),
    );
  }

  /// Width of the painted card, inside its page.
  final double cardWidth;

  /// Page extent as a fraction of the section, for [PageController].
  final double viewportFraction;

  /// Height of the whole card: whichever half needs more, the proportion floor,
  /// then the backstop.
  final double height;

  /// The framed cover: its plate, its art, its spine.
  final double coverWidth;
  final double coverHeight;

  /// What is left for the title and the description, after the card's own
  /// insets and the cover block.
  final double textWidth;

  /// Type, in shares of the text column, clamped to a legible band each.
  final double titleSize;
  final double blurbSize;
  final double eyebrowSize;

  /// The index number in the corner.
  final double watermarkSize;
}
