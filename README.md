# Yomou

> Yomou — formerly *Manga Reader* — a Kotatsu-style manga reader for iOS & Android, built with Flutter.

A dark, native-feeling reader with per-manga sources, progressive chapter tracking, offline downloads, and a Kotatsu-inspired UI.

## Features

- **5-tab experience** — History, Favorites, Suggestions, Explore, and an Updates feed with unread-new-chapter badges
- **Modern navigation** — floating rounded bar with animated Remix icons that swap from outline to filled (fade + scale) on the active tab, with the accent-colored label
- **Continue Reading FAB** — one tap on the History tab resumes the latest chapter *exactly* where you left off
- **Multiple sources** — MangaDex, Manganato, Mangakatana, WeebCentral, and more
- **Full reader** — horizontal & vertical paging, progress tracking, chapter navigation
- **Offline downloads** — download chapters and read them with no connection (sqflite + Isar caches)
- **Library & History tools** — search, filters (downloaded / new chapters / completed), sorting, date-grouped lists, progress rings
- **iOS-first design language** — native sheets, toggles, and press animations (Cupertino-style components)
- **Global blue accent theme** — per-tab accent states and source identity colors

## Screenshots

_TODO: add screenshots here._

## Getting Started

Requirements: [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `^3.11.5`).

```bash
# install dependencies
flutter pub get

# run on a connected device / desktop
flutter run

# run tests
flutter test
```

Code generation for Isar, if model files changed:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Building

### Android

`pubspec.yaml` is the single source of truth: `version: 1.1.0+18` is
`versionName + build`. Bump `+N` on every build/install; bump the semver part
only for a user-facing release — the in-app **What's new** sheet is keyed on it
(see `CHANGELOG.md`).

```bash
# build + install on the connected device (clean versionCode, one ABI)
tool/install.sh
tool/install.sh --bump                 # increment +N in pubspec.yaml first

# or by hand
flutter build apk --release            # universal
flutter build apk --release --target-platform android-arm64
flutter build apk --debug              # quick local test builds
```

> Avoid `--split-per-abi` for phone installs: it adds an ABI offset to the
> versionCode (arm64 `+2000`), so a `+18` build reports as `2018` and no longer
> updates over the universal APK without an uninstall.

### iOS (sideloading)

This project ships an **unsigned** build via GitHub Actions (`.github/workflows/build_ios.yml`), for personal sideloading. Rebuild it from the repo's *Actions* tab, then import the produced `manga_reader_unsigned.ipa` into **LiveContainer** (or sign it yourself and install with a tool like SideStore).

> Note: Yomou's in-app content is fetched from third-party sources; keep builds personal/dev-only.

## Tech Stack

- [Flutter](https://flutter.dev/) + Dart
- `flutter_riverpod` — state management
- `sqflite` / `sqflite_common_ffi` — history & library storage
- `isar` / `isar_flutter_libs` — source & chapter caches
- `dio` + `html` — source scraping
- `cached_network_image` — cover caching
- `flutter_material_design_icons` — icon set
- `flutter_inappwebview` — embedded web content where needed

## Project Structure

```
lib/
├── core/                  # theme (accent colors), database, iOS widgets
│   ├── theme/colors.dart  # kAccentColor & friends
│   └── ios/               # Cupertino-ish sheet/menu/press components
├── data/
│   └── sources/           # MangaDex, Manganato, WeebCentral, etc.
├── features/
│   ├── explore/           # source list + global search
│   ├── feed/              # Updates feed + unread badge provider
│   ├── history/           # reading history (filters, sorting, groups)
│   ├── library/           # favorites, downloads, manga detail
│   ├── reader/            # paging reader + progress
│   ├── settings/
│   └── suggestions/
└── main.dart              # shell: 5-tab nav + Continue FAB
```

## Acknowledgments

- Icons: [Material Design Icons](https://materialdesignicons.com/) (Pictogrammers), plus glyphs ported from Kotatsu-Redo
- Design inspiration: [Kotatsu](https://github.com/KotatsuApp/Kotatsu), [Kotatsu-Redo](https://github.com/Kotatsu-Redo/Kotatsu-Redo)
- iOS sideloading inspiration: [LiveContainer](https://github.com/LiveContainer/LiveContainer), [SideStore](https://github.com/SideStore/SideStore)

