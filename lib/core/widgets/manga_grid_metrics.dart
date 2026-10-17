import 'package:flutter/widgets.dart';
import 'package:yomou/core/widgets/responsive.dart';

/// Shared geometry for the manga-cover grids used across the app
/// (2:3 cover + title). Keeps every grid's row density identical and
/// computed from the actual viewport so cells never carry dead space.
const double kMangaGridHorizontalPadding = 16;

/// Gap between covers across a row, and between rows.
///
/// Tightened from 10 to 6 against the Kotatsu-style reference the grids are
/// being matched to: the gutters should recede and let the wall of covers read
/// as one block, and the width they free is width the covers get, which is what
/// fits more of them on screen at a given column count. Applies to every cover
/// grid, so the whole app tightens together rather than one screen drifting.
const double kMangaGridCrossSpacing = 6;
const double kMangaGridRowSpacing = 6;

/// Gap between a cover's bottom edge and its title.
///
/// Two, so the title reads as a caption fused to the artwork rather than a line
/// floating below it. It is also the vertical half of the same tightening as
/// [kMangaGridCrossSpacing] above.
const double kMangaCardTitleGap = 2;

/// Width:height of a manga cover cell.
///
/// Slightly taller than the traditional 2:3 (0.667) the grids used to hard
/// code, to match the slimmer covers of the reference. Every cover cell draws
/// at this ratio and [mangaCellAspectRatio] measures its row against it, so the
/// two can never disagree and leave dead space under a row.
const double kMangaCoverAspectRatio = 0.62;

/// Cover width a grid aims for at 100% grid size, in logical pixels.
///
/// This is the reference the grids are matched to, and it sizes a *cover*
/// rather than a column count: 120dp on a phone or a portrait tablet, more on a
/// landscape one (see [kMangaGridBaseCellWidthLandscape]). The reader scales it
/// between [kMangaGridSizeMin] and [kMangaGridSizeMax] percent, and the column
/// count is whatever fits at that size -- so the density control is a size
/// control, which is what makes "fewer, bigger covers" reachable at all.
const double kMangaGridBaseCellWidth = 120;

/// Cover width aimed for at 100% on a landscape window of tablet width.
///
/// The reference raises its base cell on a landscape tablet, and this matches
/// it, so the same percentage reads as the same size whichever way round the
/// screen is held: 140dp of cover is 140dp of cover. "Tablet" here is
/// [usesWideLayout]'s decision, not a second one of the grid's.
const double kMangaGridBaseCellWidthLandscape = 140;

/// The range the grid-size sliders move over, in percent of the base cell.
///
/// One setting for every manga grid, so a reader who wants bigger covers says
/// so once rather than in four separate sheets. Whole numbers because the sheet
/// prints the value back ("Grid size: 125%") and a slider resting between two
/// of those has no way to say where it is.
const int kMangaGridSizeMin = 50;
const int kMangaGridSizeMax = 150;

/// Gap between two positions on a grid-size slider.
const int kMangaGridSizeStep = 5;

/// Positions a grid-size slider divides its track into.
const int kMangaGridSizeDivisions =
    (kMangaGridSizeMax - kMangaGridSizeMin) ~/ kMangaGridSizeStep;

/// Grid size a reader who has never moved a slider gets.
const double kMangaGridSizeDefault = 100;

/// Fewest columns a grid resolves to, whatever the size setting says.
///
/// At 150% on a narrow phone the arithmetic bottoms out below two columns, and
/// one cover per row is a list that has stopped being a grid: the last position
/// on the slider is "two enormous covers", not one.
const int kMangaGridMinColumns = 2;

/// Cover width a grid aims for at 100% on this window.
///
/// Reads the window rather than the grid's own width, because which base cell
/// applies is a property of the screen the reader is holding and not of how
/// much of it this particular grid was given. Which windows count as tablets is
/// [usesWideLayout]'s single decision, so the rail cannot call a window a
/// tablet that the grid calls a phone.
double mangaGridBaseCellWidth(BuildContext context) => usesWideLayout(context)
    ? kMangaGridBaseCellWidthLandscape
    : kMangaGridBaseCellWidth;

/// How many columns a manga grid should have.
///
/// Derived from the width the grid got and the reader's [gridSize], rather than
/// from a stored column count: the setting says how big a cover is and the
/// count is what fits. That is why a wide window shows *more* covers at the
/// same setting instead of the same count at a bigger size, and why there is no
/// ceiling here -- a reader who wants tiny covers on a big screen can have
/// them, and one who wants huge covers on a small screen can have those. Only
/// [minColumns] bounds the count, and only so the grid stays a grid.
///
/// [availableWidth] is the width the grid was given, which is not the window's
/// when a nav rail or a side pane shares the row. Defaults to the viewport,
/// which is right for a grid that has the screen to itself.
int mangaGridColumns(
  BuildContext context, {
  required double gridSize,
  double horizontalPadding = kMangaGridHorizontalPadding,
  double crossSpacing = kMangaGridCrossSpacing,
  int minColumns = kMangaGridMinColumns,
  double? availableWidth,
}) {
  final base = availableWidth ?? MediaQuery.sizeOf(context).width;
  final available = base - horizontalPadding * 2;
  final cell = mangaGridBaseCellWidth(context) * gridSize / 100;
  // The spacing is added to the available width because only the gaps between
  // columns exist -- without the +1 term the last column is counted as having
  // a gap it does not, and the count comes out one short at some widths.
  //
  // Rounded rather than floored, so the count is the one nearest the size the
  // reader asked for. Flooring always spends the leftover width on covers
  // bigger than the setting says, and at 150% on a phone that is the difference
  // between the two covers it promised and one enormous one.
  final fit = ((available + crossSpacing) / (cell + crossSpacing)).round();
  return fit < minColumns ? minColumns : fit;
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
/// a [kMangaCoverAspectRatio] cover, [titleGap] px gap, a [titleLines]-line
/// title at
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
      cellWidth / kMangaCoverAspectRatio +
      titleGap +
      titleLines * titleFontSize * titleLineHeight +
      titleSlack;
  return cellWidth / contentHeight;
}
