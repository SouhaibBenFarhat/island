#!/bin/bash
# Builds dist/Island.app and dist/Island-arm64.zip for release.
# Usage: scripts/build-app.sh [version]   (default: 0.1.0)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
APP="dist/Island.app"
ZIP="dist/Island-arm64.zip"

if [ ! -f packaging/AppIcon.icns ]; then
  echo "==> Generating app icon"
  swift scripts/make-icon.swift
fi

echo "==> Building release binary (arm64)"
swift build -c release --arch arm64

echo "==> Assembling ${APP} (v${VERSION})"
rm -rf "$APP" "$ZIP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/Island "$APP/Contents/MacOS/Island"
sed "s/__VERSION__/$VERSION/g" packaging/Info.plist > "$APP/Contents/Info.plist"
cp packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP"

echo "==> Zipping"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Done"
shasum -a 256 "$ZIP"
