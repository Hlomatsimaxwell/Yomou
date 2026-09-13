import 'package:flutter/widgets.dart';

/// Shared geometry for the manga-cover grids used across the app
/// (2:3 cover + title). Keeps every grid's row density identical and
/// computed from the actual viewport so cells never carry dead space.
const double kMangaGridHorizontalPadding = 16;
const double kMangaGridCrossSpacing = 10;
const double kMangaGridRowSpacing = 10;
const double kMangaCardTitleGap = 4;

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