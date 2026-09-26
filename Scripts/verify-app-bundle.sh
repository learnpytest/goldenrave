#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "usage: $0 /path/to/GoldenRetriever.app" >&2
    exit 2
fi

EXECUTABLE="$APP_PATH/Contents/MacOS/GoldenRetrieverApp"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
RESOURCE_BUNDLE="$APP_PATH/Contents/Resources/GoldenRetriever_GoldenRetrieverApp.bundle"

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "error: app executable is missing or not executable: $EXECUTABLE" >&2
    exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
    echo "error: app Info.plist is missing: $INFO_PLIST" >&2
    exit 1
fi

if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    echo "error: SwiftPM resource bundle is missing from app resources: $RESOURCE_BUNDLE" >&2
    exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
if ! codesign -d -r- "$APP_PATH" 2>&1 | grep -q 'designated => identifier "com.rachelchen.GoldenRetriever"'; then
    echo "error: designated requirement is not pinned to the bundle identifier; Accessibility grants would reset on every build" >&2
    exit 1
fi
echo "app bundle verification passed: $APP_PATH"
