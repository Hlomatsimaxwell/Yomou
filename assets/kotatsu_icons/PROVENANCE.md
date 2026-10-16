# Icon provenance

Every file in this directory is artwork we did **not** draw. They are copied
from [Kotatsu-Redo](https://github.com/Kotatsu-Redo/Kotatsu-Redo), which is
licensed GPL-3.0, so these files stay under that licence rather than this
project's.

`ic_*.svg` are mechanical conversions of the matching Kotatsu-Redo vector
drawable (`app/src/main/res/drawable/ic_*.xml`): the viewport becomes the
`viewBox`, `android:pathData` becomes the `<path d>` verbatim, `fillType`
becomes `fill-rule` and `clip-path` elements become `<clipPath>`. No geometry
was redrawn. The exceptions are the rows Kotatsu-Redo has no counterpart for:
`ic_blur`, `ic_motion_pause` and `ic_vibrate` (Frosted glass, Reduce motion,
Haptics), `ic_badges` (its `ic_new` is an 8dp status dot, which reads as a
stray bullet at row size) and `ic_restore` (our row restores settings to their
defaults, where Kotatsu-Redo's delete-sweep wipes stored data). Those five come
straight from the Material Design Icons community set, which is the same set
most of Kotatsu-Redo's own icons are drawn from.

Provenance was established by canonicalising each path (absolute commands,
smooth commands expanded, coordinates rounded) and comparing it against the
full MDI, Google Material Icons and Remix Icon sets. 91 of Kotatsu-Redo's 156
path-bearing drawables match MDI exactly and 35 match Google Material exactly;
none match Remix.

| our asset | source | upstream identity |
| --- | --- | --- |
| `ic_add.svg` | Kotatsu-Redo `res/drawable/ic_add.xml` | MDI `mdiPlus` |
| `ic_alert_outline.svg` | Kotatsu-Redo `res/drawable/ic_alert_outline.xml` | MDI `mdiAlertOutline` |
| `ic_appearance.svg` | Kotatsu-Redo `res/drawable/ic_appearance.xml` | MDI `mdiPaletteOutline` |
| `ic_backup_restore.svg` | Kotatsu-Redo `res/drawable/ic_backup_restore.xml` | MDI `mdiBackupRestore` |
| `ic_book_page.svg` | Kotatsu-Redo `res/drawable/ic_book_page.xml` | MDI `mdiBookOpenPageVariantOutline` |
| `ic_dark_mode.svg` | Kotatsu-Redo `res/drawable/ic_dark_mode.xml` | ? `hand-drawn crescent` |
| `ic_data_privacy.svg` | Kotatsu-Redo `res/drawable/ic_data_privacy.xml` | MDI `mdiShieldAccountVariantOutline` |
| `ic_download.svg` | Kotatsu-Redo `res/drawable/ic_download.xml` | MDI `mdiDownloadOutline` |
| `ic_drawer_menu.svg` | Kotatsu-Redo `res/drawable/ic_drawer_menu.xml` | Material `outlined/menu` |
| `ic_expand_more.svg` | Kotatsu-Redo `res/drawable/ic_expand_more.xml` | Material `filled/arrow_drop_down` |
| `ic_feed.svg` | Kotatsu-Redo `res/drawable/ic_feed.xml` | Material `rss_feed` |
| `ic_filter_menu.svg` | Kotatsu-Redo `res/drawable/ic_filter_menu.xml` | MDI `mdiFilterMenuOutline` |
| `ic_grid.svg` | Kotatsu-Redo `res/drawable/ic_grid.xml` | MDI `mdiViewGridOutline` |
| `ic_images.svg` | Kotatsu-Redo `res/drawable/ic_images.xml` | MDI `mdiImageMultipleOutline` |
| `ic_info_outline.svg` | Kotatsu-Redo `res/drawable/ic_info_outline.xml` | Material `outlined/info` |
| `ic_language.svg` | Kotatsu-Redo `res/drawable/ic_language.xml` | MDI `mdiTranslate` |
| `ic_list.svg` | Kotatsu-Redo `res/drawable/ic_list.xml` | MDI `mdiFormatListBulletedSquare` |
| `ic_list_detailed.svg` | Kotatsu-Redo `res/drawable/ic_list_detailed.xml` | MDI `mdiFormatListText` |
| `ic_lock.svg` | Kotatsu-Redo `res/drawable/ic_lock.xml` | Material `outlined/https` |
| `ic_manga_source.svg` | Kotatsu-Redo `res/drawable/ic_manga_source.xml` | MDI `mdiBookmarkBoxMultipleOutline` |
| `ic_nav_bar.svg` | Kotatsu-Redo `res/drawable/ic_nav_bar.xml` | ? `app artwork` |
| `ic_new.svg` | Kotatsu-Redo `res/drawable/ic_new.xml` | Material `filled/circle` |
| `ic_pin.svg` | Kotatsu-Redo `res/drawable/ic_pin.xml` | MDI `mdiPinOutline` |
| `ic_services.svg` | Kotatsu-Redo `res/drawable/ic_services.xml` | MDI `mdiPuzzleOutline` |
| `ic_sfw.svg` | Kotatsu-Redo `res/drawable/ic_sfw.xml` | ? `app artwork` |
| `ic_shortcut.svg` | Kotatsu-Redo `res/drawable/ic_shortcut.xml` | MDI `mdiDirections` |
| `ic_suggestion.svg` | Kotatsu-Redo `res/drawable/ic_suggestion.xml` | MDI `mdiLightbulbOutline` |
| `ic_tag.svg` | Kotatsu-Redo `res/drawable/ic_tag.xml` | MDI `mdiTagOutline` |
| `ic_theme_mode.svg` | Kotatsu-Redo `res/drawable/ic_theme_mode.xml` | MDI `mdiCheckboxBlankCircleOutline` |
| `ic_timelapse.svg` | Kotatsu-Redo `res/drawable/ic_timelapse.xml` | Material `timelapse` |
| `ic_usage.svg` | Kotatsu-Redo `res/drawable/ic_usage.xml` | MDI `mdiChartDonut` |
| `ic_badges.svg` | Material Design Icons | `mdiCircleMultipleOutline` |
| `ic_blur.svg` | Material Design Icons | `mdiBlur` |
| `ic_motion_pause.svg` | Material Design Icons | `mdiMotionPauseOutline` |
| `ic_restore.svg` | Material Design Icons | `mdiRestore` |
| `ic_vibrate.svg` | Material Design Icons | `mdiVibrate` |
