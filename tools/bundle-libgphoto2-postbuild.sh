#!/bin/bash
# bundle-libgphoto2-postbuild.sh
# Post-build script: rewrites install_names in the compiled binary
# to use @loader_path-relative paths, pointing to the bundled dylibs.
#
# Run as an Xcode "Run Script" build phase (after "Compile Sources"),
# or run manually after building:
#   bash tools/bundle-libgphoto2-postbuild.sh <product_path>
#
# This script:
# 1. Finds the app/bundle's Resources directory
# 2. Rewrites libgphoto2's install_name from Homebrew path to @loader_path
# 3. Adds @loader_path to the binary's rpath

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path_to_app_or_framework>"
    echo "  Example: $0 build/Release/FujiRecipesMac.app"
    exit 1
fi

BINARY_PATH="$1"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Determine the bundle
if [[ "$BINARY_PATH" == *.app ]]; then
    BUNDLE="$BINARY_PATH"
    CONTENTS="$BUNDLE/Contents"
elif [[ "$BINARY_PATH" == *.framework ]]; then
    BUNDLE="$BINARY_PATH"
    CONTENTS="$BUNDLE"
else
    # It's a raw binary
    BUNDLE=$(dirname "$BINARY_PATH")
    CONTENTS="$BUNDLE"
fi

RESOURCES_DIR="$CONTENTS/Resources"
LIBGPHOTO2_DIR="$RESOURCES_DIR/libgphoto2"

# Check if resources directory exists
if [ ! -d "$LIBGPHOTO2_DIR" ]; then
    echo "⚠️  No libgphoto2 resources found at $LIBGPHOTO2_DIR"
    echo "   Make sure the SPM Resources are included in the build."
    echo ""
    echo "   To bundle, run: bash tools/bundle-libgphoto2.sh"
    exit 0
fi

echo "🔧 Rewriting install_names for $BINARY_PATH..."

# Find the actual binary inside the app
if [[ "$BINARY_PATH" == *.app ]]; then
    APP_BINARY="$CONTENTS/MacOS/$(basename "$BINARY_PATH" .app)"
elif [[ "$BINARY_PATH" == *.framework ]]; then
    APP_BINARY="$BINARY_PATH/$(basename "$BINARY_PATH" .framework)"
else
    APP_BINARY="$BINARY_PATH"
fi

if [ ! -f "$APP_BINARY" ]; then
    echo "⚠️  Binary not found at $APP_BINARY"
    exit 1
fi

# Rewrite libgphoto2.6.dylib install_name
install_name_tool -id "@loader_path/libgphoto2/libgphoto2.6.dylib" "$LIBGPHOTO2_DIR/libgphoto2.6.dylib" 2>/dev/null
install_name_tool -change "/opt/homebrew/opt/libgphoto2/lib/libgphoto2.6.dylib" \
    "@loader_path/libgphoto2/libgphoto2.6.dylib" "$APP_BINARY" 2>/dev/null || true
install_name_tool -change "/opt/homebrew/Cellar/libgphoto2/2.5.34/lib/libgphoto2.6.dylib" \
    "@loader_path/libgphoto2/libgphoto2.6.dylib" "$APP_BINARY" 2>/dev/null || true

# Rewrite libgphoto2_port
install_name_tool -id "@loader_path/libgphoto2/libgphoto2_port.12.dylib" "$LIBGPHOTO2_DIR/libgphoto2_port.12.dylib" 2>/dev/null
install_name_tool -change "/opt/homebrew/Cellar/libgphoto2/2.5.34/lib/libgphoto2_port.12.dylib" \
    "@loader_path/libgphoto2/libgphoto2_port.12.dylib" "$APP_BINARY" 2>/dev/null || true

# Rewrite libltdl
install_name_tool -id "@loader_path/libgphoto2/libltdl.7.dylib" "$LIBGPHOTO2_DIR/libltdl.7.dylib" 2>/dev/null
install_name_tool -change "/opt/homebrew/opt/libtool/lib/libltdl.7.dylib" \
    "@loader_path/libgphoto2/libltdl.7.dylib" "$APP_BINARY" 2>/dev/null || true

# Rewrite libexif
install_name_tool -id "@loader_path/libgphoto2/libexif.12.dylib" "$LIBGPHOTO2_DIR/libexif.12.dylib" 2>/dev/null
install_name_tool -change "/opt/homebrew/opt/libexif/lib/libexif.12.dylib" \
    "@loader_path/libgphoto2/libexif.12.dylib" "$APP_BINARY" 2>/dev/null || true

# Rewrite gettext libs
for f in libasprintf.0.dylib libgettextlib-1.0.dylib libgettextpo.0.dylib libintl.8.dylib; do
    old_id=$(otool -L "$LIBGPHOTO2_DIR/$f" 2>/dev/null | grep -E "/opt/homebrew" | head -1 | awk '{print $1}')
    if [ -n "$old_id" ]; then
        install_name_tool -id "@loader_path/libgphoto2/$f" "$LIBGPHOTO2_DIR/$f" 2>/dev/null
        install_name_tool -change "$old_id" "@loader_path/libgphoto2/$f" "$APP_BINARY" 2>/dev/null || true
    fi
done

# Rewrite libunistring
install_name_tool -id "@loader_path/libgphoto2/libunistring.5.dylib" "$LIBGPHOTO2_DIR/libunistring.5.dylib" 2>/dev/null
install_name_tool -change "/opt/homebrew/opt/libunistring/lib/libunistring.5.dylib" \
    "@loader_path/libgphoto2/libunistring.5.dylib" "$APP_BINARY" 2>/dev/null || true

# Rewrite libusb
install_name_tool -id "@loader_path/libgphoto2/libusb-1.0.0.dylib" "$LIBGPHOTO2_DIR/libusb-1.0.0.dylib" 2>/dev/null
install_name_tool -change "/opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib" \
    "@loader_path/libgphoto2/libusb-1.0.0.dylib" "$APP_BINARY" 2>/dev/null || true
install_name_tool -change "/opt/homebrew/Cellar/libusb-compat/0.1.9/lib/libusb-0.1.4.dylib" \
    "@loader_path/libgphoto2/libusb-0.1.4.dylib" "$APP_BINARY" 2>/dev/null || true

# Remove any existing rpath to /opt/homebrew and add @loader_path
# First, remove old rpaths
existing_rpaths=$(otool -l "$APP_BINARY" 2>/dev/null | grep -A2 "rpath" | grep path | awk '{print $2}')
for rpath in $existing_rpaths; do
    if [[ "$rpath" == *"/opt/homebrew"* ]]; then
        echo "   Removing rpath: $rpath"
        install_name_tool -delete_rpath "$rpath" "$APP_BINARY" 2>/dev/null || true
    fi
done

# Add @loader_path rpath (resolves relative to the binary's location)
install_name_tool -add_rpath "@loader_path/libgphoto2" "$APP_BINARY" 2>/dev/null || true

echo "✅ Done! Binary will load bundled dylibs at runtime."
echo "   Resources: $LIBGPHOTO2_DIR"
