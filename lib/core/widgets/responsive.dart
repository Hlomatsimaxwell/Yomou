import 'package:flutter/widgets.dart';

/// Window width breakpoints, in logical pixels.
///
/// These are the standard Material window-size-class cuts, kept as plain
/// constants rather than pulled from a package: the app needs three decisions
/// (navigation shape, content width cap, grid density) and nothing more.
const double kCompactWidth = 600;
const double kExpandedWidth = 840;

/// The single threshold at which the app stops behaving like a phone.
///
/// Everything width-adaptive reads this one value: the side rail, the two-pane
/// settings layout, and derived grid density. They were separate checks at
/// separate thresholds and drifted apart, which is how the rail and the covers
/// ended up disagreeing about which windows were tablets. One value, one
/// decision, no way for the three to disagree.
///
/// The rule is the reference's `w600dp-land` resource qualifier -- width *and*
/// orientation together -- because that single qualifier is what Kotatsu hangs
/// all three off: its rail is `layout-w600dp-land/activity_main.xml`, its
/// two-pane settings is `layout-w600dp-land/activity_settings.xml`, and its own
/// `is_tablet` flag is `values-w600dp-land/bools.xml`. Matching the qualifier
/// rather than approximating it is what keeps the two apps agreeing on which
/// window is a tablet at all.
///
/// The landscape half is not a detail. A 1080p display split side by side hands
/// each half a 948x1035dp pane: that clears any width-only cut there is, and a
/// rail and two panes is exactly what a window shaped like a portrait phone
/// should not get. It is also the rule the cover grids read for their cell
/// size, so a window can no longer be a tablet for the rail and a phone for the
/// covers.
const double kWideLayoutWidth = 600;

/// Whether this window is a tablet: at least [kWideLayoutWidth] wide and wider
/// than it is tall, which is the reference's `w600dp-land` rule.
///
/// Per the window rather than the device, so a window that is resized -- split
/// screen, a desktop drag -- is judged on the size it has now instead of the
/// size the screen had at launch. That is what makes the phone layout arrive
/// when a display is split in two.
bool usesWideLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width >= kWideLayoutWidth && size.width > size.height;
}

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
///
/// A container that has already bounded the column says so with
/// [ContentWidthCap] instead of every screen it hosts passing its own
/// [maxWidth], because those screens cannot know which pane they landed in.
class CappedContentWidth extends StatelessWidget {
  const CappedContentWidth({super.key, required this.child, this.maxWidth});

  final Widget child;

  /// Overrides [ScreenWidthClass.contentMaxWidth] for the few places that need
  /// a specific measure, such as a two-pane settings layout.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final cap = maxWidth ??
        ContentWidthCap.maybeOf(context) ??
        widthClassOf(context).contentMaxWidth;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: child,
      ),
    );
  }
}

/// The width content under it may reach, in place of the width class's cap.
///
/// [double.infinity] opts out of the cap, which is what a two-pane settings
/// pane wants: the pane is already the measure, and capping a second time
/// inside it centres that cap in the pane and leaves every trailing switch --
/// and the track of a slider that ends on the same edge -- floating in the
/// dead space beside the edge they belong on.
class ContentWidthCap extends InheritedWidget {
  const ContentWidthCap({super.key, required this.cap, required super.child});

  /// The width descendants may reach; [double.infinity] means no cap.
  final double cap;

  /// The cap in force for [context], or null when the width class decides.
  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ContentWidthCap>()?.cap;

  @override
  bool updateShouldNotify(ContentWidthCap oldWidget) => cap != oldWidget.cap;
}