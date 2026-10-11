#!/usr/bin/env bash
#
# Build and install the release APK on the connected device.
#
# Uses a single-ABI build (--target-platform, not --split-per-abi) so the APK's
# versionCode is the plain build number from pubspec.yaml. --split-per-abi adds
# an ABI offset (armeabi +1000, arm64 +2000, x86_64 +4000), which is why a
# "+18" build reports as 2018 on the phone.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$ROOT/pubspec.yaml"
APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
PKG="com.hlomatsi.yomou"

BUMP=0
FRESH=0
ABI="android-arm64"

usage() {
  cat <<'EOF'
Build and install the release APK on the connected device.

  tool/install.sh            build + install the current version
  tool/install.sh --bump     increment the +build in pubspec.yaml first
  tool/install.sh --fresh    uninstall first (wipes app data) -- use once when
                             switching off an old --split-per-abi build
  tool/install.sh --abi NAME build for another ABI (default android-arm64)

A single-ABI build is used (--target-platform, not --split-per-abi) so the
APK's versionCode is the plain build number from pubspec.yaml. --split-per-abi
adds an ABI offset (arm64 +2000), which is why a "+18" build reports as 2018.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--bump) BUMP=1; shift ;;
    -f|--fresh) FRESH=1; shift ;;
    --abi) ABI="${2:?--abi needs a value}"; shift 2 ;;
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

echo "Building $name ($code) for $ABI ..."
(cd "$ROOT" && flutter build apk --release --target-platform "$ABI")

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
