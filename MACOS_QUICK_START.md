# macOS App Quick Start Guide

## 30-Second Setup

### 1. Build the App
```bash
cd FujiRecipesMac/macos
swift build -c release
```

### 2. Connect Camera
```bash
# Stop macOS PTP daemon
sudo pkill ptpcamerad

# Connect X100VI via USB-C with USB RAW mode enabled
# Open the app
.build/release/FujiRecipesMac
```

### 3. Try It Out
1. Go to **Camera** tab → **Connect Camera**
2. Wait for auto-sync (C1-C7 loadouts appear)
3. Browse **Recipes** tab
4. Try **Darkroom** → Select RAF → **Start Conversion**

## Tab Guide

### 📋 Recipes
**What it does:** Browse camera recipes (Acros, Pro Neg Std, etc.)

```
Left sidebar: Filter by category + search
Right panel: Recipe details (all settings)
⭐ Star icon: Mark as favorite
✓ Checkmark: Fully PTP-mapped
```

**Pro Tips:**
- Search by film simulation type
- Filter by dynamic range (100%, 200%, 400%)
- Favorite frequently-used recipes

### 🎛️ C1-C7 Loadouts
**What it does:** View camera preset slots C1 through C7

```
Color-coded 3x3 grid (7 slots)
- Blue = C1
- Green = C2
- Orange = C3
- Purple = C4
- Pink = C5
- Cyan = C6
- Indigo = C7
```

**Shows:**
- Configured settings per slot (Film Sim, DR, Grain, etc.)
- Empty slots ready for new loadouts
- Setting count (5/8 means 5 of 8 possible settings)

### 📷 Camera Connection
**What it does:** Connect/sync camera, view preset status

```
Status Icon & Text
├─ Red X: Disconnected
├─ Orange ↻: Connecting...
├─ Green ✓: Connected
└─ Yellow ⚠: Error

When disconnected:
├─ Connection requirements checklist
├─ "Known Limitations" link
└─ Connect button (green)

When connected:
├─ C1-C7 grid (auto-synced from camera)
├─ Setting count per slot
├─ Disconnect button (orange)
└─ Troubleshooting link
```

**Status Messages:**
- ✅ "Camera connected. Loadouts synced from camera."
- ❌ "x100vi_helper not found" → Rebuild or install
- ❌ "DeviceBusy" → Power cycle camera + reconnect

### 🌙 Darkroom (RAF Conversion)
**What it does:** Convert camera RAF files to JPEG with custom settings

```
Step 1: Choose RAF File
  └─ Click "Select RAF File"
     └─ Choose a .RAF from your library
  
Step 2: Choose Recipe (Optional)
  └─ "Use Camera Settings" selected by default
     └─ (Future: select custom recipe)
  
Step 3: Convert
  └─ Disabled until RAF selected
  └─ Progress bar + status text during conversion
  └─ Result appears on camera LCD/SD card
```

**Process:**
```
Upload RAF (45-60s for 80MB file)
  ↓
Set camera profile (optional)
  ↓
Trigger conversion on camera
  ↓
Poll for results (2-30s, may find nothing)
  ↓
Check camera LCD/SD card
```

**Expected Times:**
- Small RAF (40MB): ~30 seconds
- Medium RAF (80MB): ~60 seconds
- Large RAF (120MB+): ~90+ seconds

## Troubleshooting Flow

### Camera Won't Connect
**Step 1: Check Mode**
```bash
# On camera: Setup → USB Mode → USB RAW Mode
# (not standard PTP mode)
```

**Step 2: Kill PTP Daemon**
```bash
sudo pkill ptpcamerad
```

**Step 3: Check Cable**
- Try different USB-C port
- Try different USB-C cable
- Confirm camera sees USB (check LCD)

**Step 4: Hard Reset**
```bash
# Disconnect USB
# Power off camera
# Wait 10 seconds
# Power on → USB RAW mode
# Reconnect USB
# Re-run app
```

### Connection Hangs on "Connecting…"
**Likely cause:** PTP daemon running or wrong mode

```bash
# Kill everything
sudo pkill ptpcamerad
killall FujiRecipesMac

# Rebuild
cd FujiRecipesMac/macos && swift build -c release

# Retry
.build/release/FujiRecipesMac
```

### Conversion Stalls or Shows "Error"
**Step 1: Check Camera LCD**
- JPEG may already be there!
- Check SD card contents

**Step 2: Recovery**
```bash
# Disconnect USB
# Power cycle camera
# Switch to USB RAW mode
# Reconnect
# Try "Troubleshooting" in app for more steps
```

### RAF File Picker Doesn't Work
- File type must be `.RAF` (case-insensitive)
- Try with full path: `/path/to/photo.RAF`
- Try restarting app

### App Crashes
**Check Debug HUD:**
- 5-finger tap anywhere in app
- Shows latest errors + USB state
- Take screenshot for debugging

## Command Line Alternative

### If UI Doesn't Work
```bash
# Use x100vi_helper directly
cd poc-x100vi-reader

# Upload RAF and trigger conversion
echo '{
  "id": "1",
  "command": "convert_raf",
  "path": "/path/to/photo.RAF"
}' | ./x100vi_helper

# Read camera property (e.g., Film Simulation = 0xD001)
echo '{
  "id": "1",
  "command": "read_property",
  "code": 0xD001
}' | ./x100vi_helper
```

## Performance Tips

### Faster Syncing
- Keep app running → no reconnect overhead
- Loadouts cache automatically

### Faster Conversions
- Use camera settings (default) vs. uploading profiles
- Convert multiple RAFs in sequence (queue feature planned)

### Better Stability
- Keep camera powered for entire session
- Avoid USB hub → connect directly to Mac
- Check USB cable for damage

## Advanced: Debug Mode

### Enable Debug Logging
```swift
// In App.swift, already enabled:
DebugLogger.setMinimumLevel(.debug)

// Open Debug HUD in app:
// 5-finger tap (debug builds only)
```

### View Helper Output
```bash
# Run helper directly to see raw JSON
cd /Users/ant/Documents/project/fuji-recipes-research/poc-x100vi-reader

# Try connection
echo '{"id":"1","command":"ping"}' | ./x100vi_helper

# Should output: {"id":"1","success":true}
```

### Monitor USB Activity
```bash
# In another terminal:
tail -f /var/log/usb.log

# Or use USB Prober (in Xcode → Additional Tools)
```

## File Locations

### Application
```
.build/release/FujiRecipesMac
```

### Resources (bundled)
```
.build/release/FujiRecipesMac.build/Debug/FujiRecipesMac.build/DerivedSources/
  ├─ x100vi_helper      ← USB helper binary
  └─ recipes-data.json  ← Recipe library
```

### User Data
```
~/Library/Application Support/com.fujirecipes.macos/
  ├─ loadouts.json     ← C1-C7 state
  └─ favorites.json    ← Starred recipes
```

### Temporary
```
/tmp/
  ├─ input.RAF         ← Uploaded file
  ├─ output.jpg        ← Result
  └─ native_profile.dat ← Profile data
```

## Pro Workflow

### Daily Usage
```
1. Launch app
2. Connect camera (auto-syncs)
3. Shoot RAW
4. Convert in Darkroom tab
5. Check camera LCD
6. Disconnect
```

### Recipe Testing
```
1. Recipes tab → Create/edit recipe
2. Mark as favorite
3. Camera tab → Connect
4. Darkroom tab → Test conversion
5. Check results on camera
6. Refine recipe
7. Repeat
```

### Batch Processing
```
# Coming in future version:
1. Darkroom → Upload multiple RAF files
2. Select recipe
3. Convert all in queue
4. Auto-check results
```

## Keyboard Shortcuts

### App-Wide
- `Cmd+R` — Refresh recipes
- `Cmd+W` — Close window
- `Cmd+Q` — Quit app

### Camera Tab
- `Cmd+C` — Connect/Disconnect toggle
- `Cmd+T` — Open Troubleshooting

### Darkroom
- `Cmd+O` — Open file picker
- `Cmd+E` — Start conversion (if RAF selected)

*(More shortcuts coming in future releases)*

## Getting Help

### In-App Resources
1. **Camera Tab → Known Limitations** — Explains X100VI quirks
2. **Camera Tab → Troubleshooting** — Step-by-step recovery
3. **Debug HUD** — 5-finger tap for error logs
4. **Error Messages** — Hover for detailed explanations

### External Resources
1. **MACOS_DEPLOYMENT_GUIDE.md** — Technical deep-dive
2. **AGENTS.md** — All testing results + blockers
3. **poc-x100vi-reader/** — C helper source code
4. **FujiRecipesCore/** — Shared model definitions

## Common Questions

**Q: Why does conversion take so long?**
A: RAF files are 80-120MB. USB 2.0 → ~2 MB/s = 40-60s. Plus camera processing time.

**Q: Can I write to C1-C7 slots?**
A: Not on macOS (libusb limitation). Use in-app recipes instead. iOS/Android work fine.

**Q: Where's my converted JPEG?**
A: Check camera LCD screen or SD card. X100VI doesn't return it via USB.

**Q: Can I use this without a Mac later?**
A: iOS app coming soon! Same features, no libusb limitations.

**Q: How do I uninstall?**
A: Delete `.build/release/FujiRecipesMac`. That's it!

---
**Version:** 1.0  
**Last Updated:** 2026-07-05  
**Compatible With:** X100VI in USB RAW mode  
**Platform:** macOS 14+ (arm64 + x86_64)
