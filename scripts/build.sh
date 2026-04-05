#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/../MindScript"
BUILD_DIR="$PACKAGE_DIR/.build/release"
APP_NAME="MindScript"

echo "==> Building $APP_NAME (release)"

cd "$PACKAGE_DIR"
swift build -c release

echo "  Binary: $BUILD_DIR/$APP_NAME"
echo ""
echo "==> Creating .app bundle"

APP_BUNDLE="$SCRIPT_DIR/../dist/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "$PACKAGE_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy Assets if they were compiled into the binary resources
# (In a real Xcode project, xcassets are compiled automatically)

echo "  App bundle: $APP_BUNDLE"
echo ""
echo "==> Done. Run with: open $APP_BUNDLE"
