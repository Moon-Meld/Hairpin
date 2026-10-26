#!/bin/bash
# build_app.sh — Builds Hairpin as a proper macOS .app bundle using SPM
#
# Usage:
#   ./build_app.sh           # debug build
#   ./build_app.sh release   # release build (optimised)
#   ./build_app.sh dmg       # release build + DMG installer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_MODE="${1:-debug}"
APP_NAME="Hairpin"
BUNDLE_ID="com.hairpin.app"
VERSION="1.0.0"

# Resolve build mode
SWIFT_BUILD_CONFIG="debug"
if [ "$BUILD_MODE" = "release" ] || [ "$BUILD_MODE" = "dmg" ]; then
    SWIFT_BUILD_CONFIG="release"
fi

echo ""
echo "  ╭──────────────────────────────────╮"
echo "  │  🔨  Building $APP_NAME ($SWIFT_BUILD_CONFIG)      │"
echo "  ╰──────────────────────────────────╯"
echo ""

swift build -c "$SWIFT_BUILD_CONFIG"
BINARY_PATH=".build/$SWIFT_BUILD_CONFIG/$APP_NAME"

# ── Create .app bundle ──────────────────────────────────────────────

APP_DIR="$SCRIPT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Binary
cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"

# Info.plist — resolve build variables
cp "$SCRIPT_DIR/Hairpin/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
sed -i '' "s/\$(EXECUTABLE_NAME)/$APP_NAME/g"                   "$CONTENTS_DIR/Info.plist"
sed -i '' "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$BUNDLE_ID/g"        "$CONTENTS_DIR/Info.plist"
sed -i '' "s/\$(MACOSX_DEPLOYMENT_TARGET)/13.0/g"               "$CONTENTS_DIR/Info.plist"

# Add CFBundleIconFile entry if not present
if ! grep -q "CFBundleIconFile" "$CONTENTS_DIR/Info.plist"; then
    sed -i '' 's|<key>CFBundleName</key>|<key>CFBundleIconFile</key>\
    <string>AppIcon</string>\
    <key>CFBundleName</key>|' "$CONTENTS_DIR/Info.plist"
fi

# PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Resources
cp "$SCRIPT_DIR/Hairpin/Resources/Hairpin.entitlements"     "$RESOURCES_DIR/"  2>/dev/null || true
cp "$SCRIPT_DIR/Hairpin/Resources/PrivacyInfo.xcprivacy"    "$RESOURCES_DIR/"  2>/dev/null || true
cp "$SCRIPT_DIR/Hairpin/Resources/AppIcon.icns"             "$RESOURCES_DIR/"  2>/dev/null || true

echo ""
echo "  ✅  $APP_NAME.app built successfully"
echo "      $APP_DIR"
echo ""

# ── DMG creation (optional) ─────────────────────────────────────────

if [ "$BUILD_MODE" = "dmg" ]; then
    DMG_DIR="$SCRIPT_DIR/build/dmg_staging"
    DMG_PATH="$SCRIPT_DIR/build/$APP_NAME-$VERSION.dmg"

    echo "  📀  Creating DMG installer..."

    rm -rf "$DMG_DIR" "$DMG_PATH"
    mkdir -p "$DMG_DIR"
    cp -R "$APP_DIR" "$DMG_DIR/"

    # Symlink to /Applications for drag-to-install
    ln -s /Applications "$DMG_DIR/Applications"

    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_DIR" \
        -ov -format UDZO \
        "$DMG_PATH" \
        > /dev/null 2>&1

    rm -rf "$DMG_DIR"

    echo ""
    echo "  ✅  DMG created: $DMG_PATH"
    echo ""
fi

# ── Usage hints ──────────────────────────────────────────────────────

echo "  Commands:"
echo "    open build/$APP_NAME.app              # Run"
echo "    cp -R build/$APP_NAME.app /Applications/   # Install"
if [ "$BUILD_MODE" != "dmg" ]; then
    echo "    ./build_app.sh dmg                     # Create DMG"
fi
echo ""
