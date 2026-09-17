import 'package:flutter/material.dart';

import 'package:remixicon/remixicon.dart';
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

  const IosNavBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions = const [],
    this.showBack = false,
    this.onBack,
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
                    RemixIcons.arrow_left_s_line,
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

    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
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
            Expanded(
              child:
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
                  ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
