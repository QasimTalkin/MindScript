#!/usr/bin/env bash
# Apple notarization script for MindScript distribution.
# Requires:
#   - Apple Developer account ($99/yr)
#   - Developer ID Application certificate in Keychain
#   - App-specific password: https://appleid.apple.com -> Security -> App-Specific Passwords
#
# Usage:
#   APPLE_ID="you@example.com" TEAM_ID="XXXXXXXXXX" APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" ./notarize.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$SCRIPT_DIR/../dist/MindScript.app"
DMG_PATH="$SCRIPT_DIR/../dist/MindScript.dmg"

: "${APPLE_ID:?Set APPLE_ID env var}"
: "${TEAM_ID:?Set TEAM_ID env var}"
: "${APP_PASSWORD:?Set APP_PASSWORD env var}"
DEVELOPER_ID="Developer ID Application: Your Name ($TEAM_ID)"

echo "==> Code signing"
codesign \
    --deep \
    --force \
    --options runtime \
    --sign "$DEVELOPER_ID" \
    --entitlements "$SCRIPT_DIR/entitlements.plist" \
    "$APP_BUNDLE"

echo "==> Verifying signature"
codesign --verify --verbose "$APP_BUNDLE"
spctl --assess --verbose "$APP_BUNDLE"

echo "==> Creating DMG"
hdiutil create \
    -volname "MindScript" \
    -srcfolder "$APP_BUNDLE" \
    -ov -format UDZO \
    "$DMG_PATH"

echo "==> Submitting for notarization"
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"

echo ""
echo "==> Done. Distributable: $DMG_PATH"
