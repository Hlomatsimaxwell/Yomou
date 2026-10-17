import 'package:flutter/material.dart';

/// The app's hairline: the 1px rule that separates a column, or one group of
/// rows from the next.
///
/// A translucent ink rather than a scheme role. The roles that could stand in
/// for it are all either too heavy (`outline` is a border, `outlineVariant` a
/// card edge) or absent -- the theme's own `dividerColor` is transparent on
/// purpose, so nothing paints a divider by accident. 12% of the foreground is
/// the weight Material's own preference lists use (`#1f000000`), and naming it
/// by brightness is also what keeps one rule reading the same on a white
/// sidebar, a light grey pane and the black reader.
///
/// One definition, so the two-pane column rule and a settings group rule cannot
/// drift into two different greys.
Color hairlineColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white12
        : Colors.black12;
