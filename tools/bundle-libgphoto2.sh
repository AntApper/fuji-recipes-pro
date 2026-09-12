#!/bin/bash
# bundle-libgphoto2.sh
# Copies Homebrew libgphoto2 and all dependencies into the SPM Resources
# directory, rewrites install_names to use @loader_path-relative paths.
#
# Usage: from project root
#   bash tools/bundle-libgphoto2.sh
#
# This script is a one-time setup. After Homebrew updates libgphoto2,
# re-run to get the latest version.

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES_DIR="$PROJECT_ROOT/FujiPTPClient/Resources/libgphoto2"
HOMEBREW_PREFIX="/opt/homebrew"

echo "📦 Bundling libgphoto2 for SPM..."
echo "   Resources: $RESOURCES_DIR"
echo ""

# Clean previous bundle
rm -rf "$RESOURCES_DIR"
mkdir -p "$RESOURCES_DIR"

# --- Helper function to copy and fix a dylib ---
copy_dylib() {
    local src="$1"
    local dst="$2"
    local new_id="$3"
    local changes=("$@")
    
    cp "$src" "$dst"
    
    # Rewrite the install_name to @loader_path
    install_name_tool -id "$new_id" "$dst" 2>/dev/null || true
    
    # Rewrite all Homebrew absolute paths to @loader_path
    local old_ids=$(otool -L "$dst" 2>/dev/null | grep -E "^\s*/opt/homebrew" | awk '{print $1}')
    for old_id in $old_ids; do
        local basename=$(basename "$old_id")
        install_name_tool -change "$old_id" "@loader_path/$basename" "$dst" 2>/dev/null || true
    done
}

# --- libgphoto2 core ---
LIBGPHOTO2_DIR="$HOMEBREW_PREFIX/Cellar/libgphoto2/2.5.34/lib"
copy_dylib "$LIBGPHOTO2_DIR/libgphoto2.6.dylib" "$RESOURCES_DIR/libgphoto2.6.dylib" "@loader_path/libgphoto2.6.dylib"
copy_dylib "$LIBGPHOTO2_DIR/libgphoto2_port.12.dylib" "$RESOURCES_DIR/libgphoto2_port.12.dylib" "@loader_path/libgphoto2_port.12.dylib"

# --- libtool (libltdl) ---
LIBTOOL_DIR="$HOMEBREW_PREFIX/Cellar/libtool/2.5.4/lib"
copy_dylib "$LIBTOOL_DIR/libltdl.7.dylib" "$RESOURCES_DIR/libltdl.7.dylib" "@loader_path/libltdl.7.dylib"

# --- libexif ---
LIBEXIF_DIR="$HOMEBREW_PREFIX/Cellar/libexif/0.6.26/lib"
copy_dylib "$LIBEXIF_DIR/libexif.12.dylib" "$RESOURCES_DIR/libexif.12.dylib" "@loader_path/libexif.12.dylib"

# --- gettext ---
GETTEXT_DIR="$HOMEBREW_PREFIX/Cellar/gettext/1.0/lib"
for f in libasprintf.0.dylib libgettextlib-1.0.dylib libgettextpo.0.dylib libintl.8.dylib; do
    copy_dylib "$GETTEXT_DIR/$f" "$RESOURCES_DIR/$f" "@loader_path/$f"
done

# --- libunistring ---
LIBUNISTRING_DIR="$HOMEBREW_PREFIX/Cellar/libunistring/1.4.2/lib"
copy_dylib "$LIBUNISTRING_DIR/libunistring.5.dylib" "$RESOURCES_DIR/libunistring.5.dylib" "@loader_path/libunistring.5.dylib"

# --- libusb ---
LIBUSB_COMPAT_DIR="$HOMEBREW_PREFIX/Cellar/libusb-compat/0.1.9/lib"
copy_dylib "$LIBUSB_COMPAT_DIR/libusb-0.1.4.dylib" "$RESOURCES_DIR/libusb-0.1.4.dylib" "@loader_path/libusb-0.1.4.dylib"

LIBUSB_DIR="$HOMEBREW_PREFIX/Cellar/libusb/1.0.30/lib"
copy_dylib "$LIBUSB_DIR/libusb-1.0.0.dylib" "$RESOURCES_DIR/libusb-1.0.0.dylib" "@loader_path/libusb-1.0.0.dylib"

echo "✅ Copied $(ls "$RESOURCES_DIR"/*.dylib 2>/dev/null | wc -l | tr -d ' ') dylibs"
echo ""

# --- Verify ---
echo "🔍 Verifying all dependencies resolved..."
all_ok=true
for dylib in "$RESOURCES_DIR"/*.dylib; do
    name=$(basename "$dylib")
    unresolved=$(otool -L "$dylib" 2>/dev/null | grep -cE "^\s+/opt/homebrew|^\s+/usr/local" || true)
    if [ "$unresolved" != "0" ]; then
        echo "   ❌ $name: $unresolved unresolved refs"
        all_ok=false
    else
        echo "   ✅ $name"
    fi
done

if $all_ok; then
    echo ""
    echo "🎉 All dependencies resolved!"
    echo ""
    echo "Bundle size: $(du -sh "$RESOURCES_DIR" | cut -f1)"
    echo ""
    echo "Next: Open the workspace and build FujiRecipesMac."
    echo "      The post-build script rewrites install_names automatically."
else
    echo ""
    echo "⚠️  Some dependencies still need manual fixing."
    exit 1
fi
