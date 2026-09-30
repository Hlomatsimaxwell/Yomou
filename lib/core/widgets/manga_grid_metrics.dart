import 'package:flutter/widgets.dart';

import 'responsive.dart';

/// Shared geometry for the manga-cover grids used across the app
/// (2:3 cover + title). Keeps every grid's row density identical and
/// computed from the actual viewport so cells never carry dead space.
const double kMangaGridHorizontalPadding = 16;
const double kMangaGridCrossSpacing = 10;
const double kMangaGridRowSpacing = 10;
const double kMangaCardTitleGap = 4;

/// Cover width a grid cell aims for, which is what decides how many columns
/// fit. 100 rather than the more usual 120 because that is what the grids
/// already resolved to on a 360dp phone: 3 columns of ~103dp. Picking 120
/// would have quietly dropped phones to 2 columns and made every cover
/// noticeably larger.
const double kMangaGridTargetCellWidth = 100;

/// Ceiling on derived columns. Past about eight covers across, the covers get
/// small enough to be unidentifiable and the browsing stops being useful, so a
/// very wide display spends the extra space on a capped grid plus a side rail
/// rather than on more columns.
const int kMangaGridMaxColumns = 8;

/// How many columns a manga grid should have at the current width.
///
/// Derived from the actual viewport rather than picked from breakpoints, so
/// density changes continuously with screen size instead of jumping at each
/// one: a 360dp phone gets 3, a 800dp tablet gets 7, and there is no width at
/// which the layout reflows to a fixed choice.
int mangaGridColumns(
  BuildContext context, {
  double horizontalPadding = kMangaGridHorizontalPadding,
  double crossSpacing = kMangaGridCrossSpacing,
  double targetCellWidth = kMangaGridTargetCellWidth,
  int minColumns = 2,
  int maxColumns = kMangaGridMaxColumns,
}) {
  final available = MediaQuery.sizeOf(context).width - horizontalPadding * 2;
  // The spacing is added to the available width because only the gaps between
  // columns exist -- without the +1 term the last column is counted as having
  // a gap it does not, and the count comes out one short at some widths.
  final fit =
      ((available + crossSpacing) / (targetCellWidth + crossSpacing)).floor();
  return fit.clamp(minColumns, maxColumns);
}

/// Columns for a grid whose density the user chose themselves.
///
/// The choice was made for the screen it was made on, so in a compact window
/// it is honoured exactly as-is and nothing about the phone changes. In a
/// wider window it becomes a floor rather than a value: a tablet gets at least
/// what was asked for, and more when the width affords it.
///
/// The asymmetry is deliberate. Ignoring the setting outright on a tablet
/// would strand anyone who deliberately wants a dense grid, while obeying it
/// as a value would turn a 3-column phone choice into three enormous covers on
/// a 12" display -- and width only ever adds density here, so the setting can
/// never end up coarser than what was requested.
int mangaGridColumnsFor(
  BuildContext context, {
  required int userColumns,
}) {
  if (widthClassOf(context) == ScreenWidthClass.compact) return userColumns;
  final derived = mangaGridColumns(context);
  return derived > userColumns ? derived : userColumns;
}

/// Cell aspect ratio that makes a card sit flush with its content:
/// a 2:3 cover, [titleGap] px gap, and a [titleLines]-line title at
/// [titleFontSize] with [lineHeight] line height.
///
/// Pass the same values used by the card's own widgets so the cell is
/// exactly as tall as its content. Using a flat constant instead leaves
/// empty space at the bottom of every row.
double mangaCellAspectRatio(
  BuildContext context, {
  required int columns,
  double horizontalPadding = kMangaGridHorizontalPadding,
  double crossSpacing = kMangaGridCrossSpacing,
  double titleGap = kMangaCardTitleGap,
  int titleLines = 2,
  double titleFontSize = 12,
  double titleLineHeight = 1.2,
}) {
  final gridWidth = MediaQuery.sizeOf(context).width - horizontalPadding * 2;
  final cellWidth = (gridWidth - (columns - 1) * crossSpacing) / columns;
  final contentHeight =
      cellWidth * 3 / 2 + titleGap + titleLines * titleFontSize * titleLineHeight;
  return cellWidth / contentHeight;
}