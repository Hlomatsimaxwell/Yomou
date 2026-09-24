import 'package:flutter/widgets.dart';

const double kBottomBarHeight = 60;

const double kBottomBarSideMargin = 16;

const double kBottomBarBottomMargin = 8;

/// Cap on the floating pill's width so spacing stays tight and consistent on
/// wide screens (and on all tabs, with or without the Continue FAB beside it).
const double kFloatingPillMaxWidth = 330;

/// Extra breathing room below a list/grid so the floating bar never
/// permanently covers the last row once the user scrolls to the end.
/// = safe area + small gap. Kept minimal on purpose so content scrolls
/// underneath and around the floating pill instead of leaving a dead
/// background band at the bottom.
double bottomBarClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 36;

/// Top edge of the floating nav pill (measured from the screen bottom),
/// accounting for the safe area. The Continue FAB anchors just above this.
double bottomBarTopEdge(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom +
        kBottomBarBottomMargin +
        kBottomBarHeight;