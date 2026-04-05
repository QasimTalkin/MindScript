#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/../MindScript"
BUILD_DIR="$PACKAGE_DIR/.build/release"
APP_NAME="MindScript"
CERT_NAME="MindScript Dev"
APP_BUNDLE="$SCRIPT_DIR/../dist/$APP_NAME.app"

# ── Step 0: One-time cert creation (never resets TCC on regular builds) ────────
FIRST_RUN=false
if ! security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    FIRST_RUN=true
    echo "==> Creating stable dev signing certificate (one-time setup)"
    TMPDIR_CERT=$(mktemp -d)

    openssl req -x509 -newkey rsa:2048 \
        -keyout "$TMPDIR_CERT/key.pem" \
        -out    "$TMPDIR_CERT/cert.pem" \
        -days 3650 -nodes \
        -subj "/CN=$CERT_NAME/O=MindScript/C=US" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=codeSigning" \
        2>/dev/null

    security add-trusted-cert \
        -r trustRoot \
        -k ~/Library/Keychains/login.keychain-db \
        "$TMPDIR_CERT/cert.pem" 2>/dev/null

    openssl pkcs12 -legacy -export \
        -out    "$TMPDIR_CERT/dev.p12" \
        -inkey  "$TMPDIR_CERT/key.pem" \
        -in     "$TMPDIR_CERT/cert.pem" \
        -passout pass:mindscript 2>/dev/null

    security import "$TMPDIR_CERT/dev.p12" \
        -k ~/Library/Keychains/login.keychain-db \
        -T /usr/bin/codesign \
        -P "mindscript" 2>/dev/null

    rm -rf "$TMPDIR_CERT"
    echo "  Certificate created."
fi

# ── Step 1: Generate app icon (skipped if AppIcon.icns already exists) ─────────
ICON_SRC="$PACKAGE_DIR/Resources/AppIcon.icns"
if [ ! -f "$ICON_SRC" ]; then
    echo "==> Generating app icon"
    ICONSET=$(mktemp -d)/MindScript.iconset
    mkdir -p "$ICONSET"
    swift "$SCRIPT_DIR/make_icon.swift" "$ICONSET" 2>&1

    PROPER=$(mktemp -d)/MindScript_proper.iconset
    mkdir -p "$PROPER"
    cp "$ICONSET/icon_16x16.png"    "$PROPER/icon_16x16.png"
    cp "$ICONSET/icon_32x32.png"    "$PROPER/icon_16x16@2x.png"
    cp "$ICONSET/icon_32x32.png"    "$PROPER/icon_32x32.png"
    cp "$ICONSET/icon_64x64.png"    "$PROPER/icon_32x32@2x.png"
    cp "$ICONSET/icon_128x128.png"  "$PROPER/icon_128x128.png"
    cp "$ICONSET/icon_256x256.png"  "$PROPER/icon_128x128@2x.png"
    cp "$ICONSET/icon_256x256.png"  "$PROPER/icon_256x256.png"
    cp "$ICONSET/icon_512x512.png"  "$PROPER/icon_256x256@2x.png"
    cp "$ICONSET/icon_512x512.png"  "$PROPER/icon_512x512.png"
    cp "$ICONSET/icon_1024x1024.png" "$PROPER/icon_512x512@2x.png"
    iconutil -c icns "$PROPER" -o "$ICON_SRC"
    echo "  Icon generated: $ICON_SRC"
fi

# ── Step 2: Build ──────────────────────────────────────────────────────────────
echo "==> Building $APP_NAME (release)"
cd "$PACKAGE_DIR"
swift build -c release 2>&1

# ── Step 3: Bundle ─────────────────────────────────────────────────────────────
echo "==> Creating .app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "$PACKAGE_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy app icon
[ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

SPARKLE_SRC="$PACKAGE_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ -d "$SPARKLE_SRC" ]; then
    cp -R "$SPARKLE_SRC" "$APP_BUNDLE/Contents/Frameworks/"
    install_name_tool -add_rpath @executable_path/../Frameworks \
        "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
fi

# ── Step 3: Sign with stable cert (same identity every build = TCC survives) ──
echo "==> Signing"
CERT_HASH=$(security find-identity -v -p codesigning | grep "$CERT_NAME" | awk '{print $2}' | head -1)
ENTITLEMENTS="$PACKAGE_DIR/Resources/MindScript.entitlements"

codesign --force --deep \
    --sign "$CERT_HASH" \
    --entitlements "$ENTITLEMENTS" \
    "$APP_BUNDLE" 2>&1

# ── Step 4: Reset TCC only on first-ever cert creation ─────────────────────────
if [ "$FIRST_RUN" = true ]; then
    tccutil reset Accessibility com.mindscript.app 2>/dev/null || true
    echo ""
    echo "  First run: Accessibility TCC cleared."
    echo "  After launch → click orange banner → grant Accessibility once."
    echo "  All future builds will KEEP that permission."
fi

echo ""
echo "==> Done — open $APP_BUNDLE"
