#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "== Swift tests =="
swift test

echo "== Release build =="
swift build -c release

echo "== App bundle =="
bash Scripts/build-app.sh release

echo "== Disk image =="
bash Scripts/build-dmg.sh
