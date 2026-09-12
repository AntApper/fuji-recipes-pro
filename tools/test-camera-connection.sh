#!/bin/bash
# test-camera-connection.sh
# Comprehensive test script for connecting to a Fuji X100VI via USB-C on macOS.
#
# This script:
# 1. Checks if a Fuji camera is connected via USB
# 2. Kills the macOS PTPCamera daemon if it's blocking
# 3. Tests libgphoto2 communication
# 4. Reads preset slots C1-C7 if possible
#
# Usage: bash tools/test-camera-connection.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "🔌 Fuji X100VI PTP Connection Test"
echo "===================================="
echo ""

# Step 1: Check if camera is connected
echo "📷 Step 1: Checking for Fuji camera..."
CAMERA_FOUND=false
if system_profiler SPUSBDataType 2>/dev/null | grep -qi "fuji\|fujifilm"; then
    CAMERA_FOUND=true
    echo "✅ Fuji camera detected via USB"
else
    echo "❌ No Fuji camera found"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Power on the camera"
    echo "  2. Connect via USB-C data cable"
    echo "  3. On camera: Settings → USB Connection → PTP"
    echo "  4. Disconnect and reconnect the cable"
    echo "  5. Quit Photos, Image Capture, Preview"
    echo "  6. Run: sudo killall PTPCamera"
    exit 1
fi

echo ""

# Step 2: Check and kill PTPCamera
echo "🧹 Step 2: Checking for PTPCamera daemon..."
PTPCAM_PIDS=$(pgrep -f "[p]tpcamera" 2>/dev/null || true)
if [ -n "$PTPCAM_PIDS" ]; then
    echo "⚠️  PTPCamera is running (PIDs: $PTPCAM_PIDS)"
    echo "   Killing PTPCamera..."
    pkill -9 -f "[p]tpcamera" 2>/dev/null || true
    sleep 2
    echo "✅ PTPCamera killed"
else
    echo "ℹ️  No PTPCamera daemon running"
fi

echo ""

# Step 3: Test libgphoto2
echo "📦 Step 3: Testing libgphoto2..."
if [ -f "$PROJECT_ROOT/FujiPTPClient/Resources/libgphoto2/libgphoto2.6.dylib" ]; then
    echo "✅ Bundled libgphoto2 found"
else
    echo "⚠️  Bundled libgphoto2 not found. Running bundle script..."
    bash "$PROJECT_ROOT/tools/bundle-libgphoto2.sh"
fi

if [ -f "/opt/homebrew/lib/libgphoto2.6.dylib" ]; then
    echo "✅ Homebrew libgphoto2 also available"
fi

echo ""

# Step 4: Test gphoto2 command line
echo "🔧 Step 4: Testing gphoto2 CLI..."
if command -v gphoto2 &> /dev/null; then
    echo "📷 Trying gphoto2 --auto-detect..."
    gphoto2 --auto-detect 2>&1 || echo "   gphoto2 detected no camera (may need PTPCamera killed first)"
else
    echo "ℹ️  gphoto2 CLI not installed (brew install gphoto2)"
    echo "   Skipping CLI test"
fi

echo ""

# Step 5: Check camera details
echo "📋 Step 5: Camera details..."
echo ""
echo "Connected Fuji cameras:"
system_profiler SPUSBDataType 2>/dev/null | grep -A5 -i "fuji\|fujifilm" | head -20

echo ""
echo "===================================="
echo "✅ Camera connection test complete"
echo ""
echo "Next steps:"
echo "  1. Open FujiRecipes.xcworkspace in Xcode"
echo "  2. Build and run FujiRecipesMac"
echo "  3. Go to the Camera tab"
echo "  4. Click 'Connect Camera'"
echo ""
echo "To read C1-C7 preset slots programmatically:"
echo "  The app uses raw PTP commands (0xD18C for slot selection)"
echo "  Properties 0xD18D-0xD1A5 contain preset slot data"
