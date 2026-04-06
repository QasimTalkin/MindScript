#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MindScript"
BUILD_DIR="$SCRIPT_DIR/.build/release"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
INSTALL_PATH="/Applications/$APP_NAME.app"

echo "Building $APP_NAME..."
cd "$SCRIPT_DIR"
swift build -c release

echo "Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"
mkdir -p "$CONTENTS/Frameworks"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"

# Copy Info.plist
cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"

# Copy app icon
if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi

# Copy dynamic frameworks (Sparkle must be bundled or dyld can't find it)
if [ -d "$BUILD_DIR/Sparkle.framework" ]; then
    cp -R "$BUILD_DIR/Sparkle.framework" "$CONTENTS/Frameworks/"
fi

# Add rpath so dyld finds frameworks in Contents/Frameworks/
install_name_tool -add_rpath "@loader_path/../Frameworks" "$CONTENTS/MacOS/$APP_NAME" 2>/dev/null || true

# Ad-hoc code sign (required for accessibility + microphone permissions)
echo "Signing bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Installing to /Applications..."
if [ -d "$INSTALL_PATH" ]; then
    echo "Removing existing installation..."
    rm -rf "$INSTALL_PATH"
fi

cp -r "$APP_BUNDLE" "$INSTALL_PATH"

# Reset the Accessibility TCC entry so macOS re-links it to the new binary.
# Without this, the old binary hash stays trusted and the new one is always rejected.
echo "Resetting Accessibility permission (will need one-time re-grant)..."
tccutil reset Accessibility com.mindscript.app 2>/dev/null || true

echo ""
echo "✓ MindScript installed to /Applications"
echo ""
echo "Next steps:"
echo "  1. Open /Applications/MindScript.app"
echo "  2. Click the mic icon → 'Open System Settings' → enable MindScript in Accessibility"
echo "  3. Press Ctrl+0 to start recording"
