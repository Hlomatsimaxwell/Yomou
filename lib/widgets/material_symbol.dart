import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One of the bundled Material Symbols glyphs, drawn as an SVG asset.
///
/// The icon set covers the action glyphs the rest of the toolkit's fonts
/// don't carry: chapter select-all (`selectAll`) and the tray-and-arrow
/// download (`download`). Swapping the `select_all`/`download` constants for
/// [Mdi]-style icons elsewhere stays legal, but these match what Kotatsu-Redo
/// wires onto the same affordances, so the two apps' UI lines up.
class MaterialSymbol extends StatelessWidget {
  const MaterialSymbol(
    this.symbol, {
    super.key,
    this.size,
    this.color,
  });

  /// The framework's actionModeSelectAllDrawable: the dashed frame with the
  /// inner square that selects every chapter in the list.
  static const String selectAll = 'select_all';

  /// The tray-and-arrow download glyph (`ic_download` in Kotatsu-Redo).
  static const String download = 'download';

  /// Asset name under `assets/material_symbols/`.
  final String symbol;

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? 24.0;
    final effectiveColor =
        color ?? IconTheme.of(context).color ?? Theme.of(context).iconTheme.color ?? Colors.black;
    return SvgPicture.asset(
      'assets/material_symbols/$symbol.svg',
      width: effectiveSize,
      height: effectiveSize,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
    );
  }
}
