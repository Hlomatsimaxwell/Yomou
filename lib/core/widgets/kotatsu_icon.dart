import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Where the ported Kotatsu-Redo glyphs live.
const String kKotatsuIconDir = 'assets/kotatsu_icons';

/// Every glyph in the ported set, by asset name.
///
/// Kept as data so tests can assert that each one is actually bundled, and so
/// a caller that wants to warm the cache can walk the whole set.
const List<String> kKotatsuIconNames = <String>[
  // The root settings categories, mirroring Kotatsu-Redo's pref_root.xml. Two
  // of our root rows are not in that list: Content preferences reuses
  // `ic_language`, since what it sets is the languages and formats you read,
  // and Reset takes its own glyph from MDI (see `ic_restore` below).
  'ic_appearance',
  'ic_manga_source',
  'ic_book_page',
  'ic_usage',
  'ic_download',
  'ic_feed',
  'ic_services',
  'ic_backup_restore',
  'ic_info_outline',
  // Our own root row: Kotatsu-Redo has no Reset category.
  'ic_restore',
  // Rows on our Appearance screen, mirroring its pref_appearance.xml.
  'ic_theme_mode',
  'ic_dark_mode',
  'ic_language',
  'ic_list',
  'ic_grid',
  'ic_filter_menu',
  'ic_timelapse',
  'ic_expand_more',
  // Our preview pane's break-out button. Kotatsu-Redo's own preview carries the
  // same glyph (`ic_expand`); it is not on a settings row of ours, so it is
  // listed here only to be bundled and checked like the rest.
  'ic_expand',
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
  // One row on our Manga sources pane, mirroring its pref_sources.xml. That
  // pane's other rows reuse `ic_grid`, `ic_manga_source`, `ic_list` and
  // `ic_sfw` above, or the identical MDI glyph where the inspo's file has no
  // match in any icon font the app carries.
  'ic_replace',
  // One row on our Storage and network pane, mirroring its
  // pref_network_storage.xml. That pane's other rows reuse `ic_usage`,
  // `ic_download` and `ic_book_page` above, or the identical MDI glyph where
  // the inspo's file has no match in any icon font the app carries.
  'ic_clear_all',
  // Ported but not drawn on a settings row of ours yet: the "new" marker
  // Kotatsu-Redo uses elsewhere.
  'ic_new',
  'ic_images',
  // Rows Kotatsu-Redo has no counterpart for.
  'ic_blur',
  'ic_motion_pause',
  'ic_vibrate',
  // Stands in for Kotatsu-Redo's `ic_new`, an 8dp status dot that reads as a
  // stray bullet at row size.
  'ic_badges',
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
