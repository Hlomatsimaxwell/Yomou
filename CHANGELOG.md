# Changelog

All notable changes to Yomou are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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