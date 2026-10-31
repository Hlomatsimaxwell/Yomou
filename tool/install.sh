#!/usr/bin/env bash
#
# Build and install the release APK on the connected device.
#
# By default builds a universal APK for all supported ABIs (arm64, armeabi-v7a,
# x86_64) so it works on both physical devices and emulators without rebuilding.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$ROOT/pubspec.yaml"
APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
PKG="com.hlomatsi.yomou"

BUMP=0
FRESH=0
ABI=""
UNIVERSAL=1

usage() {
  cat <<'EOF'
Build and install the release APK on the connected device.

  tool/install.sh            build + install universal APK (all ABIs)
  tool/install.sh --bump     increment the +build in pubspec.yaml first
  tool/install.sh --fresh    uninstall first (wipes app data)
  tool/install.sh --abi NAME build for a single ABI (e.g., android-arm64, android-x64)
  tool/install.sh --split   build split per ABI (legacy behavior)

Universal build is default for convenience across devices.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--bump) BUMP=1; shift ;;
    -f|--fresh) FRESH=1; shift ;;
    --abi) ABI="${2:?--abi needs a value}"; UNIVERSAL=0; shift 2 ;;
    --split) UNIVERSAL=0; ABI=""; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# version: 1.1.0+18 -> name "1.1.0", code "18"
line="$(grep -E '^version:[[:space:]]*' "$PUBSPEC" | head -n1)"
version="${line#version:}"
version="${version//[[:space:]]/}"
name="${version%%+*}"
code="${version##*+}"
[[ "$code" == "$version" ]] && code="0"

if [[ "$BUMP" == 1 ]]; then
  if [[ "$version" != *+* ]]; then
    echo "pubspec version '$version' has no +build to bump" >&2
    exit 1
  fi
  code=$((code + 1))
  version="$name+$code"
  sed -i "s/^version:.*/version: $version/" "$PUBSPEC"
  echo "Bumped to $version"
fi

if [[ "$UNIVERSAL" == 1 ]]; then
  echo "Building $name ($code) universal (all ABIs) ..."
  (cd "$ROOT" && flutter build apk --release)
else
  if [[ -n "$ABI" ]]; then
    echo "Building $name ($code) for $ABI ..."
    (cd "$ROOT" && flutter build apk --release --target-platform "$ABI")
  else
    echo "Building $name ($code) split per ABI ..."
    (cd "$ROOT" && flutter build apk --release --split-per-abi)
    # With split-per-abi, pick arm64 if available (most common), else fallback
    if [[ -f "$ROOT/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" ]]; then
      APK="$ROOT/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
    elif [[ -f "$ROOT/build/app/outputs/flutter-apk/app-x86_64-release.apk" ]]; then
      APK="$ROOT/build/app/outputs/flutter-apk/app-x86_64-release.apk"
    elif [[ -f "$ROOT/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk" ]]; then
      APK="$ROOT/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
    fi
  fi
fi

if [[ "$FRESH" == 1 ]]; then
  echo "Uninstalling $PKG (wipes app data) ..."
  adb uninstall "$PKG" >/dev/null 2>&1 || true
fi

# An old --split-per-abi build carries a higher versionCode (arm64 +2000), so
# installing the clean build over it is a downgrade that some OEM installers
# (Huawei/EMUI) refuse even with adb's -d. Retry once with -d, then point at
# --fresh rather than failing with a bare adb error.
if ! out="$(adb install -r "$APK" 2>&1)"; then
  if grep -q "INSTALL_FAILED_VERSION_DOWNGRADE" <<<"$out"; then
    echo "Installed build has a higher versionCode; retrying as a downgrade ..."
    if ! out="$(adb install -r -d "$APK" 2>&1)"; then
      echo "$out" >&2
      echo "" >&2
      echo "This device blocks downgrades. Re-run with --fresh to uninstall once" >&2
      echo "(wipes app data; restore from a backup afterwards)." >&2
      exit 1
    fi
  else
    echo "$out" >&2
    exit 1
  fi
fi

echo "Installed $name ($code)"
