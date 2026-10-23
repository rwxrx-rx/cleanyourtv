#!/usr/bin/env bash
# One-time setup of CleanYourTV's tools in Termux (Android). Run it from anywhere:
#   bash tools/termux-setup.sh
#
# Why not the plain `pip install -r tools/requirements.txt`? `cryptography` has no wheel for Termux and
# pip would compile it with Rust, which is slow and often fails. Termux ships it as a package, so this
# installs that and builds the venv with --system-site-packages; the rest is pure Python.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${TERMUX_VERSION:-}" ] && [ ! -d /data/data/com.termux ]; then
  echo "This script is for Termux. On a computer use: python3 -m venv tools/venv && tools/venv/bin/pip install -r tools/requirements.txt" >&2
  exit 1
fi

echo "==> Installing Termux packages (python, python-cryptography, unzip)"
pkg update -y
pkg install -y python python-cryptography unzip

echo "==> Creating tools/venv"
rm -rf tools/venv
python3 -m venv --system-site-packages tools/venv

echo "==> Installing adb-shell, rsa, pyasn1 (cryptography comes from the Termux package)"
tools/venv/bin/pip install --no-deps 'adb-shell==0.4.4' 'rsa==4.9.1' pyasn1

echo "==> Checking the imports tools/tv.py needs"
tools/venv/bin/python -I - <<'PY'
from adb_shell.adb_device import AdbDeviceTcp
from adb_shell.auth.keygen import keygen
from adb_shell.auth.sign_pythonrsa import PythonRSASigner
import cryptography
print("ok: cryptography", cryptography.__version__)
PY

if [ ! -d "$HOME/storage" ]; then
  echo "==> Tip: run 'termux-setup-storage' once so Termux can read your Downloads folder (for the launcher APK)."
fi

cat <<'MSG'

Done. Next:
  export TV_HOST=192.168.1.50          # your TV's IP address
  tools/venv/bin/python -I tools/tv.py --probe
  bash tools/disable.sh examples/<your tv>/debloat.txt
  bash launcher/install-apk.sh         # installs the launcher APK (see docs/TERMUX.md)
MSG
