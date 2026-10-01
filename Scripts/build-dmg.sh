#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/goldenrave.app}"
DMG_PATH="${2:-$ROOT_DIR/dist/goldenrave.dmg}"

if [[ ! -d "$APP_PATH" ]]; then
    echo "error: app bundle not found: $APP_PATH" >&2
    exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'hdiutil detach "$WORK_DIR/mnt" >/dev/null 2>&1 || true; rm -rf "$WORK_DIR"' EXIT

# dmgbuild writes the window layout (.DS_Store) itself, so the install window
# gets its background and icon positions without driving Finder, which a CI
# runner cannot do reliably. The system Python is used because Homebrew's
# Python could not create a venv with pip on the author's Mac.
/usr/bin/python3 -m venv "$WORK_DIR/venv"
"$WORK_DIR/venv/bin/pip" install --quiet "dmgbuild==1.6.5"

"$WORK_DIR/venv/bin/dmgbuild" \
    -s "$ROOT_DIR/Packaging/dmg-settings.py" \
    -D app="$APP_PATH" \
    -D background="$ROOT_DIR/Packaging/dmg-background.png" \
    "goldenrave" \
    "$WORK_DIR/rw.dmg"

# Finder on macOS 26 ignored the background while dmgbuild's pBBk bookmark was
# present (measured 2026-10-01); with only the alias left, as in Ghostty's dmg,
# it shows.
hdiutil attach -nobrowse -mountpoint "$WORK_DIR/mnt" "$WORK_DIR/rw.dmg" >/dev/null
"$WORK_DIR/venv/bin/python" - "$WORK_DIR/mnt/.DS_Store" <<'PY'
import sys
from ds_store import DSStore
with DSStore.open(sys.argv[1], "r+") as store:
    store.delete(".", b"pBBk")
PY
hdiutil detach "$WORK_DIR/mnt" >/dev/null

rm -f "$DMG_PATH"
hdiutil convert "$WORK_DIR/rw.dmg" -format UDZO -o "$DMG_PATH" >/dev/null
hdiutil verify "$DMG_PATH"
echo "$DMG_PATH"
