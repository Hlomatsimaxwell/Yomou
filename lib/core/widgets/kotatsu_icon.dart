import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Where the ported Kotatsu-Redo glyphs live.
const String kKotatsuIconDir = 'assets/kotatsu_icons';

/// Every glyph in the ported set, by asset name.
///
/// Kept as data so tests can assert that each one is actually bundled, and so
/// a caller that wants to warm the cache can walk the whole set.
const List<String> kKotatsuIconNames = <String>[
  // Appearance screen rows, mirroring Kotatsu-Redo's pref_appearance.xml.
  'ic_appearance',
  'ic_theme_mode',
  'ic_dark_mode',
  'ic_language',
  'ic_list',
  'ic_grid',
  'ic_filter_menu',
  'ic_timelapse',
  'ic_new',
  'ic_expand_more',
  'ic_images',
  'ic_list_detailed',
  'ic_suggestion',
  'ic_drawer_menu',
  'ic_add',
  'ic_tag',
  'ic_nav_bar',
  'ic_pin',
  'ic_alert_outline',
  'ic_shortcut',
  'ic_sfw',
  'ic_lock',
  'ic_data_privacy',
  // Rows Kotatsu-Redo has no counterpart for.
  'ic_blur',
  'ic_motion_pause',
  'ic_vibrate',
  // Stands in for Kotatsu-Redo's `ic_new`, an 8dp status dot that reads as a
  // stray bullet at row size.
  'ic_badges',
  // Root settings categories, mirroring Kotatsu-Redo's pref_root.xml.
  'ic_manga_source',
  'ic_book_page',
  'ic_usage',
  'ic_download',
  'ic_feed',
  'ic_services',
  'ic_backup_restore',
  'ic_info_outline',
];

/// A settings glyph from the set ported out of Kotatsu-Redo.
///
/// Kotatsu-Redo draws its settings icons as Android vector drawables. Rather
/// than approximate them with the nearest Material glyph, the same geometry
/// ships here as SVG (see `assets/kotatsu_icons/PROVENANCE.md`), so a row reads
/// identically in both apps. That is why this is not an [Icon]: the shapes are
/// not in any icon font the app carries.
///
/// It sizes and tints itself like an [Icon] does -- the colour comes from the
/// surrounding [IconTheme] unless [color] overrides it -- so a `ListTile`
/// leading slot needs nothing passed to it.
class KotatsuIcon extends StatelessWidget {
  const KotatsuIcon(this.name, {super.key, this.size = 24, this.color});

  /// File stem under `assets/kotatsu_icons`, e.g. `ic_dark_mode`.
  final String name;

  final double size;

  /// Overrides the [IconTheme] colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    return SvgPicture.asset(
      '$kKotatsuIconDir/$name.svg',
      width: size,
      height: size,
      // The artwork is a single-colour stencil, so it is always recoloured
      // rather than drawn in its own (black) ink.
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
    );
  }
}
