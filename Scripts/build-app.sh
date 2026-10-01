#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

BIN_PATH="$(swift build --show-bin-path -c "$CONFIGURATION")"
EXECUTABLE="$BIN_PATH/GoldenRetrieverApp"
APP_DIR="$ROOT_DIR/dist/goldenrave.app"

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "error: expected executable was not built: $EXECUTABLE" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/GoldenRetrieverApp"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"

RESOURCE_BUNDLE="$(find "$BIN_PATH" -maxdepth 1 -type d \( -name '*.resources' -o -name '*.bundle' \) -print -quit)"
if [[ -z "$RESOURCE_BUNDLE" ]]; then
    echo "error: expected SwiftPM resource bundle was not built in: $BIN_PATH" >&2
    exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"

# Finder, the install window and Launchpad show AppIcon.icns, built from the
# 1024px master at every size macOS asks for.
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ROOT_DIR/Packaging/AppIcon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ROOT_DIR/Packaging/AppIcon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"

# SwiftPM's executable carries a linker ad-hoc signature, but the assembled
# app bundle needs its own resource seal before it is distributed.
# An ad-hoc signature's default designated requirement is the build's cdhash,
# so an Accessibility grant stops matching after every rebuild; pin it to the
# bundle identifier so the grant survives updates.
codesign --force --deep --sign - \
    --requirements '=designated => identifier "com.rachelchen.GoldenRetriever"' \
    "$APP_DIR"
bash "$ROOT_DIR/Scripts/verify-app-bundle.sh" "$APP_DIR"

echo "$APP_DIR"
