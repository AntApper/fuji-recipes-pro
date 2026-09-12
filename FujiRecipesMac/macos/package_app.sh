#!/bin/bash
# Packages the SwiftPM build product into a proper macOS .app bundle,
# complete with the Fujifilm X100VI app icon and bundled resources.
#
# Usage: ./package_app.sh [debug|release]   (default: release)
set -euo pipefail

CONFIG="${1:-release}"
cd "$(dirname "$0")"

APP_NAME="Fuji Recipes"
BUNDLE_ID="com.ant.fuji-recipes-mac"
ARCH_DIR=".build/arm64-apple-macosx/${CONFIG}"

echo "▶ Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$ARCH_DIR/FujiRecipesMac"
RES_BUNDLE="$ARCH_DIR/FujiRecipesMac_FujiRecipesMac.bundle"
[ -x "$BIN" ] || { echo "✗ binary not found: $BIN"; exit 1; }

APP="build/${APP_NAME}.app"
echo "Assembling ${APP} ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/FujiRecipesMac"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Copy the SwiftPM resource bundle so Bundle.module keeps working inside the .app.
[ -d "$RES_BUNDLE" ] && cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>FujiRecipesMac</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
	<key>CFBundleName</key><string>${APP_NAME}</string>
	<key>CFBundleDisplayName</key><string>${APP_NAME}</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "▶ Ad-hoc code signing…"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (codesign skipped)"

# Refresh the icon cache so Finder shows the new icon immediately.
touch "$APP"

echo "✓ Built $APP"
