import 'package:flutter/material.dart';
import 'package:yomou/core/widgets/hide_on_scroll.dart';

/// How a tab's header is arranged.
///
/// A phone has to earn every row of height, so its search bar collapses on
/// scroll and carries no title -- the bottom bar already names the tab. A
/// window with a side rail has height to spare, so its header is fixed and
/// names the tab in full, the way a desktop application does.
enum TabHeaderMode {
  /// Phone: search bar only, collapsing on scroll-down.
  collapsing,

  /// Wide: a fixed title on the left, search on the right, never collapsing.
  fixed,
}

/// The header above a tab's content, in whichever shape the window calls for.
///
/// One widget rather than a per-screen choice, so the four tabs cannot drift
/// into four different answers about where the title goes or how wide the
/// search field is.
///
/// [title] is only drawn in [TabHeaderMode.fixed]. A phone's collapsing header
/// has no room for it and does not need it, but the argument stays required so
/// that every call site names its tab whatever shape it gets -- which is also
/// what makes switching a screen to a fixed header a one-word change.
///
/// [leading] takes the header's place for a screen that has something more
/// urgent to put there. History passes its selection bar: you do not search
/// while choosing which chapters to download. It replaces the search bar
/// outright rather than sharing the row with it, because a search field
/// sitting next to a selection bar would be a control that cannot do anything
/// until the selection ends -- and on a phone, where there is no title to
/// make room, it has to be the whole header.
class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.mode,
    required this.title,
    required this.searchBar,
    required this.body,
    this.leading,
  });

  final TabHeaderMode mode;
  final String title;
  final Widget searchBar;
  final Widget? leading;

  /// The scrolling content, which fills whatever the header leaves.
  final Widget body;

  /// Width of the search field in the fixed layout. Enough to be a real search
  /// box without becoming a letterbox across a wide window -- a field spanning
  /// 1160px beside a title reads as a stray element rather than a control.
  static const double fixedSearchWidth = 640;

  @override
  Widget build(BuildContext context) {
    // The app is edge-to-edge, so the status bar sits over the window and each
    // screen is on its own to clear it: the settings' app bar does it by being
    // primary, and the side rail does it with its own SafeArea. This header was
    // the one that did not, which put the tab's name and its search field at
    // y=0 -- under the clock and the battery rather than below them.
    final topInset = MediaQuery.paddingOf(context).top;

    if (mode == TabHeaderMode.collapsing) {
      // The strip takes the inset with it as it hides. The collapse is what
      // frees the height, so leaving the inset behind would pin a band of
      // background above a list that is meant to reach the window's top edge.
      return HideOnScroll(
        header: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              if (leading != null)
                FractionallySizedBox(widthFactor: 1, child: leading!)
              else
                searchBar,
            ],
          ),
        ),
        body: body,
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // 14 stays the header's own gap under the bar; the inset goes above
          // it rather than joining it, so the number still means what it said.
          padding: EdgeInsets.fromLTRB(20, 14 + topInset, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: leading ??
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: dark
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
              ),
              const SizedBox(width: 20),
              SizedBox(width: fixedSearchWidth, child: searchBar),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
