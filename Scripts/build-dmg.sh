#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/GoldenRetriever.app}"
DMG_PATH="${2:-$ROOT_DIR/dist/GoldenRetriever.dmg}"

if [[ ! -d "$APP_PATH" ]]; then
    echo "error: app bundle not found: $APP_PATH" >&2
    exit 1
fi

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

# The Applications symlink next to the app is what makes Finder show the
# drag-to-install layout when the disk image is opened.
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "Golden Retriever" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG_PATH"

hdiutil verify "$DMG_PATH"
echo "$DMG_PATH"
