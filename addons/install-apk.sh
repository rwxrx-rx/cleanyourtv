#!/usr/bin/env bash
# Install prebuilt add-on APKs on the TV without building anything. Built for Termux, where gradle and the
# Android SDK do not run, but it works anywhere.
#
#   TV_HOST=192.168.1.50 bash addons/install-apk.sh sleep-timer weather prayer-times
#   SRC=~/storage/downloads/cleanyourtv-addons.zip TV_HOST=... bash addons/install-apk.sh weather
#
# The APKs come from .github/workflows/build-addons.yml: its artifact "cleanyourtv-addons" is a zip holding
# <name>.apk for each add-on. Without SRC the newest cleanyourtv-addons*.zip in ~/storage/downloads (or
# ~/storage/shared/Download, or the current directory) is used.
# Sleep Timer also needs its accessibility service and a few app-ops, which its own script sets up
# (addons/sleep-timer/build-and-install.sh, run here with APK_FILE so it skips the build). Weather and Prayer
# Times need nothing more than the install. Press Home afterwards and answer "Show card" on the launcher.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TOOLS="$HERE/../tools"
: "${TV_HOST:?set TV_HOST to the TV IP address, e.g. TV_HOST=192.168.1.50 bash $0 weather}"
[ "$#" -ge 1 ] || { echo "usage: TV_HOST=<tv ip> bash $0 <add-on name> [more names]   (sleep-timer weather prayer-times)" >&2; exit 2; }
PY="$TOOLS/venv/bin/python"
[ -x "$PY" ] || PY="$TOOLS/venv/Scripts/python.exe"
[ -x "$PY" ] || { echo "run: bash tools/termux-setup.sh (Termux) or python3 -m venv tools/venv && tools/venv/bin/pip install -r tools/requirements.txt" >&2; exit 1; }
export MSYS_NO_PATHCONV=1

SRC="${SRC:-}"
if [ -z "$SRC" ]; then
  for d in "$HOME/storage/downloads" "$HOME/storage/shared/Download" "$PWD"; do
    [ -d "$d" ] || continue
    # shellcheck disable=SC2012
    SRC="$(ls -t "$d"/cleanyourtv-addons*.zip 2>/dev/null | head -n 1 || true)"
    [ -n "$SRC" ] && break
  done
fi
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
  echo "ERROR: no cleanyourtv-addons zip found. Run the 'Build add-on APKs' workflow, download its artifact" >&2
  echo "(docs/TERMUX.md), run 'termux-setup-storage' once, or pass SRC=<file>." >&2
  exit 1
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q -o "$SRC" -d "$TMP"

for n in "$@"; do
  [[ "$n" =~ ^[a-z][a-z-]*$ ]] || { echo "ERROR: not an add-on name: $n" >&2; exit 2; }
  APK="$(find "$TMP" -name "$n.apk" | head -n 1)"
  [ -n "$APK" ] || { echo "ERROR: $n.apk is not in $SRC (was $n in the workflow's add-on list?)" >&2; exit 1; }
  echo "==> $n ($(( $(wc -c < "$APK") / 1024 )) KB)"
  case "$n" in
    sleep-timer)
      APK_FILE="$APK" bash "$HERE/sleep-timer/build-and-install.sh" ;;
    *)
      REMOTE="/data/local/tmp/addon-$n.apk"
      "$PY" -I "$TOOLS/b64push.py" "$APK" "$REMOTE" >/dev/null
      OUT="$("$PY" -I "$TOOLS/tv.py" "pm install -r $REMOTE; rm -f $REMOTE")"
      echo "$OUT"
      case "$OUT" in *Success*) ;; *) echo "ERROR: pm install failed for $n" >&2; exit 1 ;; esac
      echo "Installed $n. Check addons/$n/README.md for anything else it needs." ;;
  esac
done
echo "Done. Press Home on the remote and answer 'Show card' for each add-on."
