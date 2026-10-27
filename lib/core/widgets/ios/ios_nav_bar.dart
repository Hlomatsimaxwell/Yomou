import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';

import 'ios_menu.dart';

/// iOS-style navigation bar: leading button close to the screen edge, centered
/// large title, and a right-aligned actions group. No elevation or shadows.
class IosNavBar extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  /// Flat header: nothing painted of its own, so the row reads as sitting
  /// straight on the screen the way the reference's `MaterialToolbar` does
  /// -- there is no band, no hairline, nothing separating the nav row from
  /// the page it belongs to.
  final bool flat;

  /// Whether to apply the window's safe-area insets.
  ///
  /// When this bar is hosted by a parent that has already consumed the top
  /// inset (e.g. [TabHeader] adding the status bar padding), leaving this on
  /// doubles the gap and pushes the bar lower than the reference. Pass false
  /// there so the host's inset is the only one that applies.
  final bool safeArea;

  /// Spread the actions evenly across the width instead of clustering them at
  /// the far right. Matches Kotatsu-Redo's action bar, where the action group
  /// fills the space between the title and the overflow menu.
  final bool spreadActions;

  const IosNavBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions = const [],
    this.showBack = false,
    this.onBack,
    this.flat = false,
    this.safeArea = true,
    this.spreadActions = false,
  }) : assert(
         title != null || titleWidget != null,
         'IosNavBar requires either [title] or [titleWidget]',
       ),
       assert(
         !showBack || leading == null,
         'Pass [leading] instead of [showBack] for custom leading widgets',
       );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Widget leadingWidget =
        leading ??
        (showBack
            ? AppSheetPress(
                onTap: onBack ?? () => Navigator.maybePop(context),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    MdiIcons.chevronLeft,
                    size: 32,
                    color:
                        (dark
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface)
                            .withValues(alpha: 0.9),
                  ),
                ),
              )
            : const SizedBox(width: 44));

    final titleResolved =
        titleWidget ??
        Text(
          title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: dark
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        );

    return SafeArea(
      top: safeArea,
      bottom: false,
      left: safeArea,
      right: safeArea,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: flat
            ? null
            : BoxDecoration(
                color: dark ? Colors.black : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: dark ? const Color(0xFF1F1F23) : Colors.black12,
                    width: 0.5,
                  ),
                ),
              ),
        child: Row(
          children: [
            SizedBox(width: 44, child: Center(child: leadingWidget)),
            if (spreadActions) ...[
              titleResolved,
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: actions,
                ),
              ),
            ] else ...[
              Expanded(child: titleResolved),
              Row(mainAxisSize: MainAxisSize.min, children: actions),
            ],
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
