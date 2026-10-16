import 'package:flutter/material.dart';

/// Carries the reader's "Black" (AMOLED) choice on the theme itself, so any
/// `build` can consult it through [Theme.of] without reaching for the settings
/// provider.
///
/// Dark chrome in this app is a table of near-black greys written where each
/// one is drawn -- a #2C2C2E search field here, a #1C1C1E sheet there -- rather
/// than a set of theme roles, so there is nothing to re-tint in one place.
/// Threading the flag through the theme is what lets those sites ask, in one
/// line, whether to collapse to pure black.
@immutable
class AmoledMode extends ThemeExtension<AmoledMode> {
  const AmoledMode({required this.enabled});

  /// Whether dark surfaces should be pure black. Always false in light mode,
  /// where the setting has no background to act on.
  final bool enabled;

  /// The flag for [context], or false when no theme carries it. A widget
  /// pumped under a bare `MaterialApp` -- a test, or a preview -- must not
  /// throw for the want of the extension.
  static bool of(BuildContext context) =>
      Theme.of(context).extension<AmoledMode>()?.enabled ?? false;

  @override
  AmoledMode copyWith({bool? enabled}) =>
      AmoledMode(enabled: enabled ?? this.enabled);

  @override
  AmoledMode lerp(AmoledMode? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// The dark chrome tone [rgb] -- written the way the widget has always written
/// it, `0xFF2C2C2E` or `0xFF1C1C1E` -- unless the reader turned on "Black", in
/// which case every one of those tones collapses to pure black.
///
/// Takes the ARGB value rather than a [Color] so a call site stays inside the
/// line width the rest of the file keeps to. The hex itself is still in the
/// code, so grepping a tone finds every place that paints it.
///
/// Light mode is never touched: the flag is false whenever the app is light,
/// and the tone is only ever asked for from the dark branch.
Color amoled(BuildContext context, int rgb) =>
    AmoledMode.of(context) ? Colors.black : Color(rgb);
