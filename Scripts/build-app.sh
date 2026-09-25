#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

BIN_PATH="$(swift build --show-bin-path -c "$CONFIGURATION")"
EXECUTABLE="$BIN_PATH/GoldenRetrieverApp"
APP_DIR="$ROOT_DIR/dist/GoldenRetriever.app"

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "error: expected executable was not built: $EXECUTABLE" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/GoldenRetrieverApp"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"

RESOURCE_BUNDLE="$(find "$BIN_PATH" -maxdepth 1 -type d -name '*.resources' -print -quit)"
if [[ -z "$RESOURCE_BUNDLE" ]]; then
    echo "error: expected SwiftPM resource bundle was not built in: $BIN_PATH" >&2
    exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"

echo "$APP_DIR"
