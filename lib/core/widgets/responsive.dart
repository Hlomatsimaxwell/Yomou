import 'package:flutter/widgets.dart';

/// Window width breakpoints, in logical pixels.
///
/// These are the standard Material window-size-class cuts, kept as plain
/// constants rather than pulled from a package: the app needs three decisions
/// made from width (navigation shape, content width cap, grid density) and
/// nothing more.
const double kCompactWidth = 600;
const double kExpandedWidth = 840;

/// Where the current window falls on the Material width scale.
enum ScreenWidthClass {
  /// Phones in portrait, and phones in landscape on the larger handsets.
  compact,

  /// Small tablets, or a phone held in landscape on a short screen.
  medium,

  /// Large tablets in either orientation.
  expanded;

  /// True when there is room for a side rail next to the content.
  bool get hasSideNavigation => this != ScreenWidthClass.compact;

  /// The width content should be capped at before it stops reading well.
  double get contentMaxWidth => switch (this) {
        ScreenWidthClass.compact => double.infinity,
        ScreenWidthClass.medium => 720,
        ScreenWidthClass.expanded => 960,
      };
}

ScreenWidthClass widthClassOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= kExpandedWidth) return ScreenWidthClass.expanded;
  if (width >= kCompactWidth) return ScreenWidthClass.medium;
  return ScreenWidthClass.compact;
}

/// Whether this window should use a side navigation rail instead of a bottom
/// bar. Narrower than [kExpandedWidth] keeps a bottom bar even on a large
/// tablet, because a rail plus a wide grid reads better than a rail plus a
/// stretched one.
bool hasSideNavigation(BuildContext context) =>
    widthClassOf(context).hasSideNavigation;

/// Constrains [child] to the class's content width and centres it, so a form
/// or a settings list on a 12" tablet stays a readable column instead of
/// stretching lines to the full width of the panel.
class CappedContentWidth extends StatelessWidget {
  const CappedContentWidth({super.key, required this.child, this.maxWidth});

  final Widget child;

  /// Overrides [ScreenWidthClass.contentMaxWidth] for the few places that need
  /// a specific measure, such as a two-pane settings layout.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final cap = maxWidth ?? widthClassOf(context).contentMaxWidth;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: child,
      ),
    );
  }
}