#!/usr/bin/env bash
# Install a prebuilt launcher APK on the TV and make it Home, without building anything.
# Built for Termux, where gradle and the Android SDK do not run, but it works anywhere.
#
#   TV_HOST=192.168.1.50 bash launcher/install-apk.sh [path/to/app-release.apk | path/to/artifact.zip]
#
# With no argument it looks for the newest app-release*.apk, cleanyourtv-launcher-apk*.zip or
# cleanyourtv*.apk in ~/storage/downloads (and ~/storage/shared/Download), and in the current directory.
# A zip is what GitHub Actions hands out for an artifact: it is unpacked and the APK inside is used.
# Every other option of build-and-install.sh still applies (STOCK_LAUNCHER, INPUT_KEY_SERVICE, ...).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${TV_HOST:?set TV_HOST to the TV IP address, e.g. TV_HOST=192.168.1.50 bash $0}"

SRC="${1:-}"
if [ -z "$SRC" ]; then
  for d in "$HOME/storage/downloads" "$HOME/storage/shared/Download" "$PWD"; do
    [ -d "$d" ] || continue
    # shellcheck disable=SC2012
    SRC="$(ls -t "$d"/app-release*.apk "$d"/cleanyourtv*.apk "$d"/cleanyourtv-launcher-apk*.zip 2>/dev/null | head -n 1 || true)"
    [ -n "$SRC" ] && break
  done
fi
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
  echo "ERROR: no launcher APK found. Download the artifact from the GitHub Actions run (docs/TERMUX.md)," >&2
  echo "run 'termux-setup-storage' once so Termux can see Downloads, or pass the path: bash $0 <file>" >&2
  exit 1
fi

case "$SRC" in
  *.zip)
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    unzip -q -o "$SRC" -d "$TMP"
    APK="$(find "$TMP" -name '*.apk' | head -n 1)"
    [ -n "$APK" ] || { echo "ERROR: no .apk inside $SRC" >&2; exit 1; }
    ;;
  *.apk) APK="$SRC" ;;
  *) echo "ERROR: $SRC is neither an .apk nor a .zip" >&2; exit 1 ;;
esac

echo "APK: $APK ($(( $(wc -c < "$APK") / 1024 )) KB)"
# No exec: the trap above must still run to remove the unpacked zip.
APK_FILE="$APK" bash "$HERE/build-and-install.sh"
