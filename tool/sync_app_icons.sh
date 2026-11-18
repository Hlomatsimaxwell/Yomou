#!/usr/bin/env bash
#
# Sync the Icon Kitchen exports in icons/ into the app.
#
# Icon Kitchen writes one folder per variant, each containing:
#   android/res/mipmap-*/          <- adaptive icon layers + legacy PNGs
#   android/play_store_512.png     <- 512x512 preview used by the picker
#   ios/AppIcon~ios-marketing.png  <- 1024x1024 iOS master
#
# Two destinations:
#   1. assets/app_icons/variant_<id>.png  preview shown in
#      Settings -> Appearance -> App Icon.
#   2. android/app/src/main/res/          launcher resources. Gold is the
#      default icon (plain ic_launcher*), the rest are renamed
#      ic_launcher_<id>* so the activity-alias declarations can point at them.
#
# Usage:
#   tool/sync_app_icons.sh            sync every variant
#   tool/sync_app_icons.sh gold blue  sync only these
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/icons"
ASSETS="$ROOT/assets/app_icons"
RES="$ROOT/android/app/src/main/res"

# Order matters only for readability: gold is the default launcher icon.
VARIANTS=(gold blue white bw white_blue)

variants=("$@")
if [[ ${#variants[@]} -eq 0 ]]; then
  variants=("${VARIANTS[@]}")
fi

mkdir -p "$ASSETS"

for v in "${variants[@]}"; do
  vres="$SRC/$v/android/res"
  if [[ ! -d "$vres" ]]; then
    echo "skip $v: $vres not found" >&2
    continue
  fi

  # --- Picker preview -------------------------------------------------------
  preview="$SRC/$v/android/play_store_512.png"
  if [[ -f "$preview" ]]; then
    cp "$preview" "$ASSETS/variant_$v.png"
  fi

  # --- Launcher resources ---------------------------------------------------
  # Gold keeps the canonical names; every other variant is suffixed.
  suffix=""
  [[ "$v" != "gold" ]] && suffix="_$v"

  for d in "$vres"/mipmap-*dpi; do
    [[ -d "$d" ]] || continue
    out="$RES/$(basename "$d")"
    mkdir -p "$out"
    for f in "$d"/ic_launcher*.png; do
      [[ -f "$f" ]] || continue
      base="$(basename "$f")"
      cp "$f" "$out/${base/ic_launcher/ic_launcher$suffix}"
    done
  done

  xml="$vres/mipmap-anydpi-v26/ic_launcher.xml"
  if [[ -f "$xml" ]]; then
    mkdir -p "$RES/mipmap-anydpi-v26"
    sed "s|@mipmap/ic_launcher|@mipmap/ic_launcher$suffix|g" "$xml" \
      >"$RES/mipmap-anydpi-v26/ic_launcher$suffix.xml"
  fi

  echo "synced $v"
done

# The old dark/light picker's light icon is retired (the white variant replaces
# it), so drop the orphaned PNGs instead of shipping dead resources.
rm -f "$RES"/mipmap-*/ic_launcher_light.png
# flutter_launcher_icons' generated foreground layer is replaced by Icon
# Kitchen's adaptive layers above.
rm -f "$RES"/drawable-*/ic_launcher_foreground.png

echo "done: ${variants[*]}"
