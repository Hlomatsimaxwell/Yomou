import 'package:flutter/material.dart';

/// A stable [Hero] tag for a title's cover.
///
/// Namespaced by source so two sources listing the same title do not collide,
/// and keyed by the id so a grid cell and the detail screen it opens compute
/// the same tag without threading state between them.
String mangaCoverHeroTag({String? sourceId, required String mangaId}) =>
    'manga-cover:${sourceId ?? ''}:$mangaId';

/// Wraps a cover so it flies into the detail screen's cover.
///
/// The child is only ever the cover artwork, never a whole screen: a budget
/// device cannot afford to rasterise a heavy page twice, and the flight stays
/// cheap when all it carries is one decoded bitmap. A null [tag] renders
/// [child] untouched, with no flight.
class MangaCoverHero extends StatelessWidget {
  const MangaCoverHero({super.key, required this.tag, required this.child});

  final String? tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final heroTag = tag;
    if (heroTag == null) return child;
    return Hero(tag: heroTag, child: child);
  }
}
