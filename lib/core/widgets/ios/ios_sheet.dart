import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

Color iosSheetBackground(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? const Color(0xFF1C1C1E) : Colors.white;
}

Color iosSheetGrabber(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? const Color(0xFF6E6E73) : Colors.black26;
}

/// Width bounds for a sheet presented as a panel on a wide window.
///
/// A third of the window, within limits. The lower bound is what a list row
/// needs for its leading and title to sit on one line; the upper bound stops
/// the panel from becoming a column of stretched text on a 2560px monitor. A
/// window narrower than three times the upper bound simply gets a proportionally
/// narrower panel.
const double kSheetPanelMinWidth = 360;
const double kSheetPanelMaxWidth = 460;

/// How a sheet is presented on a window too wide for a bottom sheet to read
/// well.
enum IosSheetStyle {
  /// A panel anchored to the right edge on a wide window, a bottom sheet on a
  /// phone. The default, because it is what every list- or options-shaped
  /// sheet wants.
  auto,

  /// Always a bottom sheet, however wide the window.
  ///
  /// For sheets that are a handful of transient choices -- a time range, a
  /// share target, a PIN prompt. Those read as an action offered over the page
  /// rather than as a place you are in, and a full-height panel says the
  /// opposite.
  bottom,
}

/// Presents an iOS-style bottom sheet, or -- on a wide window -- the same
/// content as a panel on the right edge.
///
/// The two are different presentations of one content set, not two content
/// sets. A bottom sheet stretched across a 1280px window leaves the app as a
/// strip above a very wide row of controls; anchoring to the right keeps the
/// app visible and puts the controls in the column a side panel is expected to
/// occupy. On a phone this is always the bottom sheet, with its grabber and its
/// top-only rounding, because a panel the width of the screen is a full-screen
/// page with extra steps.
///
/// [title] is shown in the panel's own header, alongside a close button, when
/// the content does not carry a header of its own. [IosSheetStyle.bottom]
/// opts a sheet out of the panel entirely.
Future<T?> showIosSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  double maxWidth = 520,
  bool isDismissible = true,
  bool enableDrag = true,
  IosSheetStyle style = IosSheetStyle.auto,
  String? title,
}) {
  if (style == IosSheetStyle.auto && usesWideLayout(context)) {
    return _showIosEndSheet<T>(
      context,
      builder: builder,
      title: title,
      isDismissible: isDismissible,
    );
  }
  return _showIosBottomSheet<T>(
    context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    maxWidth: maxWidth,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
  );
}

Future<T?> _showIosBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required bool isScrollControlled,
  required double maxWidth,
  required bool isDismissible,
  required bool enableDrag,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    clipBehavior: Clip.none,
    useSafeArea: true,
    builder: (sheetContext) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: maxWidth,
          child: Material(
            // A [Material], not a coloured [Container]. A ListTile paints its
            // background and its ink splash on the nearest Material ancestor, so
            // anything coloured sitting between the tile and that Material hides
            // both -- which is exactly what a BoxDecoration behind the sheet's
            // content did. Every sheet with a row in it lost its press
            // feedback, and debug builds reported it on every tap.
            color: iosSheetBackground(sheetContext),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            // The corners are rounded, so the splash has to be clipped to them
            // or it washes over the sheet's outline.
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: isScrollControlled
                  ? BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.92,
                    )
                  : const BoxConstraints(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 10, bottom: 6),
                    child: _IosGrabber(),
                  ),
                  Flexible(child: Builder(builder: builder)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<T?> _showIosEndSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required String? title,
  required bool isDismissible,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierDismissible: isDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    // Long enough to read as the panel arriving rather than appearing, short
    // enough not to be in the way of a control someone is reaching for.
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (sheetContext, _, _) {
      return _IosEndSheetShell(
        title: title,
        child: Builder(builder: builder),
      );
    },
    // Slides in from the right edge, which is the edge it is anchored to, and
    // fades rather than scaling: the panel's width does not change, only its
    // position, so a scale would imply a resize that never happens.
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// The panel itself. Anchored right, rounded on the left, and no taller than
/// its content.
class _IosEndSheetShell extends StatelessWidget {
  const _IosEndSheetShell({required this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final panelWidth = (media.width / 3).clamp(
      kSheetPanelMinWidth,
      kSheetPanelMaxWidth,
    );

    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: panelWidth,
          // A ceiling, not a height. The panel takes the height of what is in
          // it -- the reader's overflow menu is a handful of rows, and
          // stretching that to the window leaves a column of empty surface
          // below them -- and only reaches the window's height when the content
          // outgrows it.
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: media.height),
            child: Material(
              color: iosSheetBackground(context),
              // The panel sits over a page, so it needs to read as a layer above
              // it rather than as part of the same plane.
              elevation: 16,
              shadowColor: Colors.black54,
              // Rounded on the left only: the right edge is the screen edge, so
              // a corner there would be a radius around nothing.
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) _IosEndSheetHeader(title!),
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: title == null ? 8 : 0,
                        bottom: 8,
                      ),
                      // The scroll is the fallback for content taller than the
                      // window, not the layout: short content lays out at its
                      // own height and the panel ends where the content does.
                      child: SingleChildScrollView(child: child),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IosEndSheetHeader extends StatelessWidget {
  const _IosEndSheetHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 20, right: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(RemixIcons.close_line, size: 22),
            color: scheme.onSurfaceVariant,
            tooltip: AppLocalizations.of(context).close,
            // A sheet the reader cannot dismiss still has to be closable from
            // inside: on first launch the welcome sheet hides the scrim tap and
            // the drag, and losing both plus the header button would leave the
            // only exit at the bottom of the scroll.
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _IosGrabber extends StatelessWidget {
  const _IosGrabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: iosSheetGrabber(context),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
