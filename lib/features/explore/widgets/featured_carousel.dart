import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/data/models/manga.dart';
import 'package:yomou/features/library/screens/manga_detail_screen.dart';
import 'package:yomou/features/settings/providers/appearance_provider.dart';
import 'package:yomou/features/suggestions/providers/suggestions_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// Kotatsu-style featured hero at the top of Explore: a horizontal carousel
/// of taste-based suggestions in large "story" cards with a framing cover and
/// a dot indicator underneath. Rides the shared suggestions feed so it costs
/// no extra network work.
class FeaturedCarousel extends ConsumerStatefulWidget {
  const FeaturedCarousel({super.key});

  @override
  ConsumerState<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends ConsumerState<FeaturedCarousel> {
  static const double _height = 204;
  PageController? _pageController;
  int _current = 0;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = ref.watch(suggestionsProvider(null));
    final featured = (suggestions.value ?? const <Manga>[]).take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suggestions.isLoading) ...[
          const SizedBox(
            height: _height,
            child: _CarouselSkeleton(),
          ),
        ] else if (featured.isNotEmpty) ...[
          SizedBox(
            height: _height,
            child: PageView.builder(
              controller: _pageController ??= PageController(
                viewportFraction: 0.94,
                initialPage: featured.length * 400,
              ),
              onPageChanged: (index) => setState(() => _current = index),
              itemBuilder: (context, index) => _FeaturedCard(
                manga: featured[index % featured.length],
                index: index % featured.length,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < featured.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _current % featured.length ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _current
                        ? Theme.of(context).colorScheme.primary
                        : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white24
                              : Colors.black26),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FeaturedCard extends ConsumerStatefulWidget {
  const _FeaturedCard({required this.manga, required this.index});

  final Manga manga;
  final int index;

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
    final schema = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    final accent = ref.watch(accentProvider);
    final manga = widget.manga;
    final sourceId = manga.sourceId.trim();
    final description = (manga.description ?? '').trim();
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
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
            borderRadius: BorderRadius.circular(24),
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
              Positioned(
                top: 0,
                left: 20,
                right: 16,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        topSheenColor,
                        Colors.transparent,
                      ],
                      stops: const [0, 0.7],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 10, 16),
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
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              if (sourceId.isNotEmpty && sourceId != 'mock') ...[
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    sourceId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: sourceColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 9),
                          Text(
                            manga.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.18,
                              letterSpacing: 0.1,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: bodyColor,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ] else if (sourceId.isNotEmpty &&
                              sourceId != 'mock') ...[
                            const SizedBox(height: 8),
                            Text(
                              l.discoverPick(sourceId),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: bodyColor,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.02,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
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
                              borderRadius: BorderRadius.circular(14),
                              child: _BookCover(
                                imageUrl: manga.coverUrl,
                                dark: dark,
                                
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: -8,
                bottom: -34,
                child: Text(
                  '${widget.index + 1}'.padLeft(2, '0'),
                  style: TextStyle(
                    color: watermarkColor,
                    fontSize: 110,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: _sheen,
                      builder: (context, _) {
                        return Transform.translate(
                          offset: Offset((_sheen.value * 2 - 1) * 170, 0),
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
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.imageUrl, required this.dark});

  final String imageUrl;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0016)
        ..rotateY(0.18),
      child: SizedBox(
        width: 104,
        height: 150,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              top: 2,
              bottom: 2,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF3B3B3E) : const Color(0xFFEDE9E2),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.only(right: 3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedMangaImage(
                        imageUrl: imageUrl,
                        width: 101,
                        height: 150,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: dark ? const Color(0xFF2A2A2C) : const Color(0xFFDDD8D0),
                          alignment: Alignment.center,
                          child: Icon(
                            RemixIcons.book_open_fill,
                            color: dark ? Colors.white38 : Colors.black26,
                            size: 24,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 18,
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
            ),
          ],
        ),
      ),
    );
  }
}
  class _CarouselSkeleton extends StatefulWidget {
  const _CarouselSkeleton();

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
    final base = dark ? const Color(0xFF2C2C2E) : const Color(0xFFEDEDEF);
    final radius = BorderRadius.circular(24);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.55, end: 1).animate(_controller),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: base,
            borderRadius: radius,
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
                      width: 90,
                      height: 10,
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 180,
                      height: 16,
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 82,
                height: 118,
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}