#!/usr/bin/env bash
set -euo pipefail

# CI Build Script for MindScript
# Uses ad-hoc signing (no Apple Developer ID required)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/../MindScript"
APP_NAME="MindScript"
DIST_DIR="$SCRIPT_DIR/../dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "==> Building $APP_NAME (release)"
cd "$PACKAGE_DIR"
swift build -c release --arch arm64 --arch x86_64

BUILD_DIR="$PACKAGE_DIR/.build/apple/Products/Release" # Standard path for multi-arch build

echo "==> Creating .app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "$PACKAGE_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# App Icon
ICON_SRC="$PACKAGE_DIR/Resources/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APP_BUNDLE/Contents/Resources/"
fi

# Sparkle Framework (SPM path)
# We find it dynamically because the exact path can vary slightly
SPARKLE_PATH=$(find "$PACKAGE_DIR/.build" -name "Sparkle.framework" -type d | head -1)
if [ -n "$SPARKLE_PATH" ]; then
    cp -R "$SPARKLE_PATH" "$APP_BUNDLE/Contents/Frameworks/"
    install_name_tool -add_rpath @executable_path/../Frameworks \
        "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
fi

echo "==> Ad-hoc signing"
ENTITLEMENTS="$PACKAGE_DIR/Resources/MindScript.entitlements"
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
