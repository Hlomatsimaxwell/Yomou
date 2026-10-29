# Changelog

All notable changes to Yomou are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **92 more sources, bundled** — a config-driven Madara engine now ships a validated catalogue of Madara sites (English, Spanish, Portuguese, Turkish, Arabic, Thai, Vietnamese and more) as ordinary sources. Each one was checked end to end before it was bundled: listing, series page, chapter list and reader all answered. They arrive **disabled**, so nothing joins global search or the updates refresh until you switch one on in Manage sources.

### Changed
- **A new source no longer arrives switched on** — a source the app has never seen keeps the default it ships with, so a bundled catalogue cannot quietly turn itself on after an update.

### Fixed
- **Source listings scroll past the first page** — pagination now continues whenever a page returned any results, instead of assuming a full page of 20. Sites whose archive serves 12 cards per page (the bundled Madara catalogue) were stuck on those 12 no matter what was searched.
- **Bundled sources wear their own logo** — icon discovery now scrapes the source's homepage rather than the CDN that hosts the bundled icon file, so a Madara source no longer shows jsDelivr's badge instead of its favicon.

## [1.1.8] - 2026-10-27

### Added
- **New sources** — DatgarScanlation, InManga, InfraFandub and the Spanish family (AnzMangasHd, ApollComics, AsiaLotuss), plus search support for InfraFandub and DatgarScanlation.
- **Long-press selection menus on every main tab** — History, Favorites, Suggestions and Explore now open a Kotatsu-style action bar matching the reference: full-bleed toolbar under the status bar, icon + label that appear only when there is room (ifRoom|withText), right-aligned actions with the overflow (three-dot) menu on phones and everything promoted into the bar on wide windows, all-caps tracked labels, and theme-derived colors (the theme's primary over the surface, title at full strength, actions at medium emphasis). The floating nav pill slides away for the whole selection, as Kotatsu does.
- **Favorites pinned mangas** — pin/unpin from the selection menu, pinned titles sort to the top and wear a theme-aware pin badge on their cover.
- **Clear updates feed** — the Updates three-dot menu gains "Clear updates" with a dialog (clear all update history, optionally clear new-chapters counters), ported from Kotatsu-Redo's clear-feed action.
- **Three-dot menus everywhere** — Favorites (List options, Incognito mode, Settings), Explore (+ Source presets ahead of Manage sources), Updates (Refresh, Clear updates, Incognito mode, Settings).
- **Source presets entry point on Explore** — jumps straight to the Manage presets screen.
- **Mark as completed** in History/Favorites selection (marks every chapter of the chosen manga read).

### Changed
- **Source sort order defaults to Name** on a fresh install.
- **Suggestions genre chips** adopt the History/Favorites chip style; Adult/NSFW genre tags are no longer offered as genre chips.
- **Fixed (wide) headers** sit closer to the status bar.

### Fixed
- **Mark as completed** now fetches the series details/chapters when the local row has no chapter count, so it works on a fresh install and in incognito.

## [1.1.7] - 2026-10-24

### Added
- **Source icons are the sites' own logos now** — a port of Kotatsu-Redo's favicon pipeline. Every source icon is discovered from the site's homepage itself (PWA manifest, icon links, apple-touch icons), tried smallest-fitting first with each failure falling through to the next candidate, and cached for 30 days so a homepage is scraped once and every later launch starts from disk. Tiles whose site offers nothing loadable keep the letter plate, as the reference does.

### Changed
- **The Continue button carries the reference's glyph** — the reader-over-open-book icon Kotatsu-Redo's own continue button uses, in the frosted and solid looks alike.
- **In tablet view the Continue button lives in the navigation rail** — parked above the tab items at the rail's head, the way the reference's railFab sits, instead of floating over the covers in a corner.
- **Dark mode paints the scheme's own surfaces** — outside the Black toggle, surfaces take the shade the colour scheme's seed decides (a dark grey that varies per preset) the way the reference's dark mode does; Black still flattens everything to black, and the appearance screen's swatches draw what the theme actually paints.
- **The reader's seek-bar label follows the theme** — the floating page bubble no longer sits on Material's fixed inverse-grey pill; it takes its colours from the scheme in both light and dark modes.

### Fixed
- **Titles and summaries no longer arrive as mojibake** — wherever a site serves UTF-8 without a charset header, the fetch layer read its HTML one character per byte and every multi-byte character fell apart. Both fetch paths now decode the bytes properly, so 'â€'-style garbage stops appearing.
- **The Disable NSFW switch finally takes** — a flip made while the app was still loading its saved settings was silently overwritten by that load, leaving the switch false after a restart. Setters now wait for the load, and the flagging matches the reference's rule: regular catalogues that merely carry some adult titles are not flagged whole.
- **Source logos survived Cloudflare** — logo downloads ride a browser user agent and referer, so gated sites such as WeebCentral no longer 403 their own icons.

## [1.1.6] - 2026-10-14

### Added
- **Source sorting works now** — Settings → Manga sources → Sorting order used to change nothing. Explore honours five orders (Name, Popular, Manual, Last used, and Popular & reliable), the manual order survives a restart, and long-press dragging in Manage sources reorders a source within its pinned or unpinned zone.
- **Source-grid search actually searches** — typing in a source's search box now queries the source itself (debounced at 450ms, with real pagination) instead of filtering only the page already loaded, so a title that isn't on screen still turns up.
- **The source row on a manga opens its catalogue** — tapping the source on the detail card goes straight to that source's listing, the same screen Explore opens. It stays inert when the source has since been removed, rather than opening the wrong catalogue.

### Changed
- **Manga detail screen** reworked against Kotatsu-Redo: a 420dp art plate that scrolls away with the header under a soft vignette wash, an opaque filled info card, a tonal favourite chip split so the chevron is a real control, and firmer label-versus-value contrast.
- **The reader and detail trays are dragged by their own bars**, the way Kotatsu moves its sheet: the chapter list can be dragged open or shut from the bar whatever the list is scrolled to, the halfway stop is back as a proper step rather than a toll gate, and the floating jump button's arrow follows the direction you're reading.
- **Every Settings picker is now the same bottom sheet** — a plain tick on the current choice, applied the moment you tap it, and no Cancel button. Source sorting and the NSFW incognito mode move from centre-aligned dialogs into these sheets, and the "check for new chapters" frequency sheet drops its circled tick.
- **Picking languages on the welcome sheet no longer invents a preset** — a fresh install keeps the built-in "all" preset, and editing the chips while it is active just moves the filter.

### Fixed
- **Tapping outside a sheet now dismisses it**, on every sheet. Several sheets sized their surface to the whole window, so the tap landed on the sheet itself and only the drag handle could close it.
- **Toasts no longer show a yellow double underline** under their text, and the Undo label follows the chosen accent. The underline was Flutter's "no Material here" fallback style leaking into the root overlay the toasts live in.
- **The accent colour now reaches the Continue pill** on the detail screen and the reader's reading-mode selector, which were painted with fixed blues.
- **ComicK, Komga and Toonily removed** — ComicK's search was unreliable and Komga needs per-user server setup. Their Explore rows, id resolvers and backup mappings go with them; a backup entry for one now falls through to the title scan like any other source Yomou does not carry.
- **Search pagination fixed** for Arenascan, MangaKatana, Asura Scans and Flame Scans, whose searches either repeated page one or re-downloaded the whole catalogue on every keystroke.
- **Chapter-list spacing tightened** — a two-line chapter tile no longer reserves more air between one chapter and the next than it uses.

## [1.1.5] - 2026-10-12

### Added
- **Import from Kotatsu** — Settings → Backup and restore now restores a Kotatsu `.bk.zip` (the backup format Kotatsu itself writes: a zip of one JSON array per table). Favorites, reading history and bookmarks come across; land the whole library from a Kotatsu backup without re-adding titles one by one.
- **Export to Kotatsu** — Settings → Backup and restore now exports favorites and history as a real Kotatsu `.bk.zip`, so a Yomou library can be restored *into* Kotatsu. Only sources Kotatsu carries are written; the rest are counted in the done toast.
- **Result notifications** — exporting or importing a backup now posts a system notification ("Backup saved", "Import complete"/"Restore complete") on a silent channel, the same pattern as Kotatsu's own backup-restore notification. The import scan can outlive the screen that started it, so the notification is what reports the result once you've left the app — and while it runs, a live progress notification ("Looking for missing titles… 12/18") keeps the scan moving in the shade.
- Restoration keeps working no matter what a picked file actually is: a `.json` Yomou backup, a Tachiyomi/Mihon `.tachibk`, or a Kotatsu `.bk.zip` are sniffed from the contents, never the extension.

### Notes
- Kotatsu backups carry no chapter *numbers*, so imported reading history keeps its real last-read timestamp but seeds progress at chapter 0, and exported progress becomes a chapter placeholder Kotatsu can show without a number.

## [1.1.4] - 2026-10-12

### Changed
- Android release builds are now signed with Yomou's own release key instead of the Android debug key, so everyday updates install cleanly over an existing app going forward. Because the signing key changed, this one update needs the currently installed app uninstalled first — after that, updates are seamless.

## [1.1.3] - 2026-10-11

### Added
- **Share sheet on the manga detail screen** — the share icon now offers two links: "Link to manga in Yomou" and "Link to manga on <source>" (the manga's page on the source's website, e.g. `asurascans.com/comics/…`). Tapping a row opens the Android system share sheet with that link pre-filled, so it can be sent straight to WhatsApp, email, or anywhere else.
- **`yomou://` deep links** — Android now listens for `yomou://` links and opens the named manga directly, both when the app is cold-started by the link and when it is tapped while the app is already running.
- **Tappable share links** — chat apps (WhatsApp, SMS, Gmail) only linkify http(s), so "Link to manga in Yomou" shares an https URL rather than the raw `yomou://` string. It lands on a tiny landing page (`docs/yomou.html`) with an "Open in Yomou" button that hands the link back to Android, plus a fallback that opens the manga on the source website when Yomou isn't installed.

### Changed
- The Tachiyomi/Mihon import rescue now prefers re-binding a title to a source in one of your content languages, and only falls back to another language when none of your languages carries it.
- The import scan progress now shows as a small floating pill with a circular progress ring instead of a blocking dialog, so the app stays usable while sources are searched. The pill matches the app's theme (same surface and radius as the bottom navigation pill, accent-colored ring), floats above the bottom bar, and never swallows taps.
- A toast now confirms when an import finishes ("N manga imported from Tachiyomi/Mihon · M not imported"), in addition to the per-manga results screen.
- App toasts (e.g. exit confirmation and "refreshed") now float above the bottom navigation bar instead of sitting on top of it and blocking the tabs.
- Every remaining in-app message now uses the same floating toast (reader, library, explore, sources, storage, notifications and settings screens), so no snackbar ever lands under or on top of the bottom bar.
- Toasts are now compact pills styled like the floating navigation pill (content-width, rounded 28, subtle border + soft shadow, fade-and-scale entrance) instead of full-width bars with an outline.
- The import scan pill now just says "Looking for missing titles" — the longer title overflowed the pill on smaller screens.
- A fresh install now pre-loads reader pages only on Wi-Fi by default instead of always (a stored choice or an in-app reset wins over the default).

### Fixed
- **iOS builds no longer quit on launch.** The periodic new-chapter check was being scheduled before iOS had registered its background-task handler, which made iOS abort the app the instant it opened. iOS now skips that scheduling so the app launches reliably; Android is unaffected. (Background new-chapter checks will return to iOS once the registration is reworked.)
- Content on the settings screens and the manga detail screen no longer passes behind the device's swipe/gesture bar. Settings lists now reserve the bottom safe-area inset (plus a floor on skins like EMUI that draw the strip without reporting an inset), and the detail screen's tray, jump button and chapter lists hold the same minimum clearance, so nothing scrolls or sits under the gesture bar when it is shown.
- Sources that talk to a dedicated API host (Asura Scans, MangaDex) now open their real website for "Open in browser" and "Sign in" instead of the API host, which answered 404 at its root (e.g. `asurascans.com`, not `api.asurascans.com`). Requests still go to the API host, so nothing about fetching changes.
- "Open in browser" on a manga's detail screen now opens that manga's own page on the source's website (e.g. MangaDex → `mangadex.org/title/…`, MangaBat → `…/manga/<slug>`) instead of the website root. Sources whose per-manga URLs cannot be reconstructed (Asura Scans' site appends a changing slug hash) fall back to the website root.
- Asura Scans' "Open in browser" now opens the manga's real page (`asurascans.com/comics/<slug>-<hash>`) using the canonical `public_url` its API reports per series, instead of the website root.
- Restoring from a backup on the first-run welcome sheet now finishes onboarding and closes the sheet instead of leaving it sitting over the app.
- On iOS, `.tachibk` backups no longer appear greyed out and unselectable in the backup/restore and Tachiyomi import pickers (the extension filter was resolved through UTIs and dropped unrecognized extensions).
- The Tachiyomi/Mihon import rescue now prefers the source publishing the most chapters, so reading progress from a backup no longer lands past a shorter copy of the series (e.g. "chapter 256 of 100").
- Leaving the import or restore screen while the scan runs no longer swallows the rest of the flow: the import summary still appears and the library/history still refresh right away, instead of showing nothing until the app is restarted.

## [1.1.0] - 2026-10-11

### Added
- **Full-screen cover viewer** — tap a cover in the detail screen to open it; pinch to zoom, tap anywhere to dismiss, and save the cover straight to your gallery (`Pictures/Yomou`).
- **Backup restore** — restore history, favorites and bookmarks from a Yomou backup or a Tachiyomi/Mihon `.tachibk`/`.json` file. The format is sniffed from the file, and restoring never rewinds progress that is already further along.
- **Tachiyomi/Mihon import rescue** — entries from sources Yomou doesn't carry are no longer dropped: the import searches the sources you *do* have for the same title and re-binds them (keeping favorite status and last-read chapter). Anything it can't find is listed on the import-results screen.
- **Source presets** — save and switch between source/language presets from the Explore screen.
- **First-run welcome sheet** — choose content filters on first launch; shown as a right-side panel on wide windows.
- **More sources** — ManhuaPlus, Mangago, Atsumaru and SeiManga.
- **Haptics**, with an on/off setting.
- **Re-tap the active tab to scroll back to the top.**
- **"What's new" sheet** — the release notes appear once after an update, and can be reopened any time from Settings → About.

### Changed
- A tapped cover flies into the detail header and the viewer with a Hero transition; the viewer decodes the full-size artwork while grids keep the light thumbnail.
- New-chapter notifications are on by default; setup asks for the notification permission right after the welcome sheet, so the switch in settings always matches what the OS allows.
- Explore opens with sources in a grid.
- Removed unused `liquid_glass_bar` / `liquid_glass_renderer` dependencies.

### Fixed
- SeiManga covers not loading (the CDN requires a referer).
- MangaBat titles reporting no chapters because every URL was doubled.
- MangaPill listing titles without covers.
- Notification action buttons being dropped instead of routed.
- Madara sources showing the wrong detail cover and status.
- Settings icons staying black in dark mode.
- Eight parsers stamping a manga's slug into its `sourceId`, which made library entries look like they came from a source that was never installed.
- Repairing the library table leaving the grids reporting slugs.

### Performance
- Lower idle drain, bounded image decodes, a lazily-built Explore screen, and reduced-motion support.

### Removed
- The dead Reaper Scans and the dev-only Mock source.

## [1.0.0+1] - 2026-09-06

### Added
- **Yomou branding** — renamed *Manga Reader* → *Yomou* across the app, bundle IDs (`com.hlomatsi.yomou`) and package imports.
- **Kotatsu-inspired tab navigation** — floating rounded bottom bar (72px) with animated Remix icons:
  - Outline → filled glyph + 5% scale + accent label on the active tab (fade/scale swap via `AnimatedSwitcher`).
  - Always-visible labels on all five tabs (History, Favorites, Suggestions, Explore, Updates).
  - Updates tab keeps its live unread-new-chapters badge.
- **Continue Reading FAB** — floating circular accent button on the History tab that resumes the latest chapter at the exact last-read page; cross-fades away on other tabs; spinner state while resolving.
- **Global accent theme** — `lib/core/theme/colors.dart` with `kAccentColor`, `kAccentLight`, `kAccentDark`, `kAccentSurface`.
- **Remix Icon dependency** (`remixicon: ^4.9.3`) powering the new nav glyphs.

### Changed
- Navigation materials reworked over several iterations before settling on the final design (previous glass pill / compact pill / FAB designs removed).
- Accent color swept from pink/green tone to a consistent **blue** across the Updates badge, feed highlights, history counts, detail-page play button, reader marker/slider/gradient/chips, and iOS switch tracks. Red is retained only for destructive actions and the favorite heart.
- FAB styling: liquid glass → solid blue accent circle.
- History continue action now lives solely in the Continue FAB (was previously reachable via the old nav FAB).

### Fixed
- Bottom-bar overflow when the active pill expanded.
- Nav label truncation on narrow screens (Favo…/Expl… no longer clipped).
- Removed duplicate `remixicon` entry in `pubspec.yaml`.
- `_buildNavItem` referenced a non-existent `IconData.onlyOneGlyph()` placeholder — replaced with the correct line/fill swap; orphaned FAB/continue code from the refactor removed.

### Removed
- Liquid glass UI (dependency references cleaned up): nav bar and FAB no longer use glass rendering.
- Old nav variants (icon-only compact pill, Kotatsu pill+badge) superseded by the final bar.

## Footnote

Build & release tooling
- CI produces an unsigned `.ipa` via `.github/workflows/build_ios.yml` for personal sideloading (LiveContainer / SideStore).
- Android debug APK: `flutter build apk --debug`.