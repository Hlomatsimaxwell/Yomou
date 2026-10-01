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

/// The range the grid-density sliders move over, in columns.
///
/// This is a different thing from [kMangaGridMaxColumns] and the two used to be
/// written as bare numbers in each screen, which is how a ceiling ended up in
/// three places with only one of them sharing the constant. The slider is what
/// a user may *choose* for a narrow layout; the ceiling is what a *derived*
/// count is held to on a wide one. A stored choice above the ceiling is
/// impossible here because the range tops out below it.
///
/// The slider reads right-to-left -- dragging towards "more columns" moves the
/// thumb left -- so positions are counted back from
/// [kMangaGridSliderMaxColumns].
const int kMangaGridSliderMinColumns = 1;
const int kMangaGridSliderMaxColumns = 6;

/// The slider position that stands for [columns].
///
/// And [mangaGridColumnsForSliderPosition] for the other direction. Both are
/// here because a slider is a double while the setting it edits is an int, and
/// every screen had been doing the same `7 - value` and `max + 1 - value` by
/// hand -- which is how a range could drift from the constant that describes it.
double mangaGridSliderPositionForColumns(double columns) =>
    kMangaGridSliderMaxColumns + 1 - columns;

/// Columns a slider position stands for.
///
/// The position is counted from the far end, hence the `+ 1 - position`: at
/// [kMangaGridSliderMaxColumns] on the track this is one column, and at
/// [kMangaGridSliderMinColumns] it is the maximum.
int mangaGridColumnsForSliderPosition(double position) =>
    (kMangaGridSliderMaxColumns + 1 - position).round();

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
  double? availableWidth,
}) {
  // Defaults to the viewport, which is right for a grid that has the screen to
  // itself. A grid sharing the row with a side pane must pass the width it
  // actually got, or it derives columns for space it does not have and paints
  // cells narrower than the target.
  final base = availableWidth ?? MediaQuery.sizeOf(context).width;
  final available = base - horizontalPadding * 2;
  // The spacing is added to the available width because only the gaps between
  // columns exist -- without the +1 term the last column is counted as having
  // a gap it does not, and the count comes out one short at some widths.
  final fit =
      ((available + crossSpacing) / (targetCellWidth + crossSpacing)).floor();
  return fit.clamp(minColumns, maxColumns);
}

/// Columns for a grid whose density the user chose themselves.
///
/// The choice was made for the screen it was made on, so anywhere short of a
/// wide layout it is honoured exactly as-is and nothing about the phone
/// changes at any angle -- including landscape, which is wide but is still a
/// phone. In a wide window it becomes a floor rather than a value: a tablet
/// gets at least what was asked for, and more when the width affords it.
///
/// The asymmetry is deliberate. Ignoring the setting outright on a tablet
/// would strand anyone who deliberately wants a dense grid, while obeying it
/// as a value would turn a 3-column phone choice into three enormous covers on
/// a 12" display -- and width only ever adds density here, so the setting can
/// never end up coarser than what was requested.
int mangaGridColumnsFor(
  BuildContext context, {
  required int userColumns,
  double? availableWidth,
}) {
  if (!usesWideLayout(context)) return userColumns;
  final derived = mangaGridColumns(context, availableWidth: availableWidth);
  return derived > userColumns ? derived : userColumns;
}

/// Columns at which a card's title drops to the smaller size.
///
/// One definition for both halves of the arrangement: the grid measures each
/// cell with it and the card paints with it, and when the two disagree a
/// two-line title is measured at one size and drawn at another, which is what
/// pushes the second line out of the cell.
const int kMangaCardCompactColumns = 4;

/// Title font size for a grid of [columns] columns.
double mangaCardTitleFontSize(int columns) =>
    columns >= kMangaCardCompactColumns ? 10 : 12;

/// Spare height added below a card's title, in logical pixels.
///
/// Without it a cell is sized to fit its title to the last fraction of a
/// pixel, because [mangaCellAspectRatio] derives the cell height from the same
/// font size and line height the title is drawn with. That makes the fit
/// exact on paper and short in practice: the grid rounds its cell height, the
/// paragraph rounds its own, and the two land a fraction apart often enough
/// that a two-line title loses its descenders to the cell edge. A few extra
/// pixels are invisible under the title and make the fit unconditional. Two
/// is enough to absorb the rounding; anything more is dead space below the
/// last line of every card, which is most of them.
///
/// This does not survive a large system font scale - the title grows with the
/// user's setting and no fixed slack can track it - which is why the card's
/// title is also [Flexible], so a scale the slack cannot absorb ellipsises
/// instead of overflowing.
const double kMangaCardTitleSlack = 2.0;

/// Cell aspect ratio that makes a card sit flush with its content:
/// a 2:3 cover, [titleGap] px gap, a [titleLines]-line title at
/// [titleFontSize] with [titleLineHeight] line height, and
/// [kMangaCardTitleSlack] spare so the title is not flush against the edge.
///
/// Pass the same values used by the card's own widgets so the cell is as tall
/// as its content. Using a flat constant instead leaves empty space at the
/// bottom of every row.
///
/// [titleFontSize] must come from [mangaCardTitleFontSize] with the same
/// [columns] the grid resolves to. A cell measured at one font size and drawn
/// at another is the single most common cause of a clipped second title line,
/// because the error lands in whichever direction the measurement was wrong.
double mangaCellAspectRatio(
  BuildContext context, {
  required int columns,
  double horizontalPadding = kMangaGridHorizontalPadding,
  double crossSpacing = kMangaGridCrossSpacing,
  double titleGap = kMangaCardTitleGap,
  int titleLines = 2,
  double titleFontSize = 12,
  double titleLineHeight = 1.2,
  double titleSlack = kMangaCardTitleSlack,
  double? availableWidth,
}) {
  // See [mangaGridColumns]: a grid beside a side pane passes the width it
  // actually has, so the cell it is measured at is the cell it is given.
  final base = availableWidth ?? MediaQuery.sizeOf(context).width;
  final gridWidth = base - horizontalPadding * 2;
  final cellWidth = (gridWidth - (columns - 1) * crossSpacing) / columns;
  final contentHeight =
      cellWidth * 3 / 2 +
      titleGap +
      titleLines * titleFontSize * titleLineHeight +
      titleSlack;
  return cellWidth / contentHeight;
}
