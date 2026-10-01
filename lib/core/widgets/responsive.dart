import 'package:flutter/widgets.dart';

/// Window width breakpoints, in logical pixels.
///
/// These are the standard Material window-size-class cuts, kept as plain
/// constants rather than pulled from a package: the app needs three decisions
/// made from width (navigation shape, content width cap, grid density) and
/// nothing more.
const double kCompactWidth = 600;
const double kExpandedWidth = 840;

/// The single threshold at which the app stops behaving like a phone.
///
/// Everything width-adaptive reads this one value: the side rail, the two-pane
/// settings layout, and derived grid density. They were separate checks at
/// separate thresholds and drifted apart, which is how a phone held in
/// landscape ended up with a navigation rail -- 760dp is a wide phone, not a
/// tablet. One value, one decision, no way for the three to disagree.
const double kWideLayoutWidth = 840;

/// Whether this window is wide enough for the tablet layout: a side rail
/// instead of a bottom bar, settings in two panes, and grid density derived
/// from width rather than taken from the user's setting.
bool usesWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideLayoutWidth;

/// Where the current window falls on the Material width scale.
enum ScreenWidthClass {
  /// Phones in portrait, and phones in landscape on the larger handsets.
  compact,

  /// Small tablets, or a phone held in landscape on a short screen.
  medium,

  /// Large tablets in either orientation.
  expanded;

  /// The width content should be capped at before it stops reading well.
  /// Used for measure only -- navigation shape keys off [usesWideLayout].
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