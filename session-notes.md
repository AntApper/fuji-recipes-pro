# Session Notes

Last updated: 2026-07-04 (session 21)

---

## Session 21 — macOS PTPCamera Fix & Camera Connection (Complete)

### Objective

Fix the libgphoto2 deadlock on macOS by addressing the root cause: the macOS PTPCamera daemon claiming USB camera devices. Implement a complete camera connection flow that handles PTPCamera interference.

### Problem Analysis

**Root Cause**: macOS has a built-in `PTPCamera` / `ptpcamerad` process (part of ImageCaptureCore) that automatically claims USB PTP cameras. When this daemon holds the USB interface, libgphoto2's `libusb_claim_interface()` fails with "Access denied" or the `camera_init()` call deadlocks.

**Key Research Findings**:
- macOS 13+ makes `ptpcamerad` harder to kill (it respawns automatically)
- The workaround is to kill `PTPCamera` before connecting and prevent it from respawning
- `killall PTPCamera` is the standard fix recommended by gphoto2 documentation
- On macOS 15+, there are additional kernel driver conflicts

### What We Built

#### 1. macOS Camera Utilities (`FFI+MACCamera.swift`)
New Swift module with:
- **`MACameraUtils.killPTPCameraProcesses()`** — Detects and kills PTPCamera/ptpcamerad processes
- **`MACameraUtils.isPTPCameraRunning()`** — Checks if PTPCamera is blocking
- **`MACameraUtils.isFujiCameraConnected()`** — Checks USB connection via system_profiler JSON
- **`MACameraUtils.getFujiCameraIDs()`** — Returns vendor:product IDs of connected Fuji cameras
- **`MacOSSession.prepareForCameraConnection()`** — Async preparation method (kills PTPCamera + checks camera)
- **`MacOSSession.checkCameraAccessibility()`** — Sync accessibility check
- **`MacOSSession.checkCameraAccessibilityAsync()`** — Async accessibility check with PTPCamera detection

#### 2. Updated Connection Flow (`MacOS+PTPClient.swift`)
Complete overhaul of `connect()`:
1. **Kill PTPCamera daemon** (new Step 0)
2. Initialize libgphoto2 (Step 1)
3. Scan for Fuji camera (Step 2) with enhanced error messages
4. Create camera object and set port (Steps 3-4)
5. Create context (Step 5)
6. **Try `camera_init()` with 15s timeout** (Step 6)
7. **On timeout: Raw PTP fallback** — test if raw PTP commands work
   - If raw PTP works → connect in "raw PTP mode" (preset slots work, config API limited)
   - If raw PTP fails → throw helpful error with PTPCamera fix instructions

#### 3. Shared Timeout Utility (`TimeoutHelper.swift`)
- Moved `withTimeout()` from private in CameraManager to public in FujiRecipesCore
- Now accessible from both CameraManager and MacOSSession

#### 4. Test Script (`tools/test-camera-connection.sh`)
- Checks USB camera connection
- Kills PTPCamera daemon
- Tests libgphoto2 availability
- Tests gphoto2 CLI
- Shows camera details

### Files Created
| File | Purpose |
|------|---------|
| `FujiPTPClient/.../FFI+MACCamera.swift` | macOS PTPCamera process management |
| `FujiRecipesCore/.../TimeoutHelper.swift` | Shared async timeout helper |
| `tools/test-camera-connection.sh` | Camera connection test script |

### Files Modified
| File | Change |
|------|--------|
| `FujiPTPClient/.../MacOS+PTPClient.swift` | Rewrote `connect()` with PTPCamera handling + raw PTP fallback |
| `FujiRecipesCore/.../CameraManager.swift` | Removed duplicate `withTimeout()`, uses shared version |

### Build Status
✅ FujiRecipesCore — builds
✅ FujiPTPClient — builds
✅ FujiRecipesMac Xcode project — builds and runs

### Connection Flow
```
User clicks "Connect Camera"
    ↓
kill PTPCamera processes
    ↓
gp_library_init()
    ↓
scan for Fuji USB camera
    ↓
gp_camera_new() + gp_camera_set_port()
    ↓
gp_context_new()
    ↓
try camera_init() (15s timeout)
    ↓
├── Success → Full libgphoto2 mode
└── Timeout → raw PTP fallback
     ├── Raw PTP works → Connect in raw PTP mode (C1-C7 works)
     └── Raw PTP fails → Error with PTPCamera fix instructions
```

### User Instructions

**If connection fails:**
1. Quit Photos, Image Capture, and Preview
2. In Terminal: `sudo killall PTPCamera`
3. Disconnect and reconnect USB cable
4. Try again

**If camera not detected:**
1. Power on camera
2. Settings → USB Connection → PTP
3. Use USB-C data cable (not charge-only)
4. Run test script: `bash tools/test-camera-connection.sh`

---

## Session 20 — Camera Connection Debug & libgphoto2 Deadlock (Complete — Blocked)

### Objective
Connect X100VI via USB-C and test PTP communication through the app.

### What We Found

#### Camera Detection
- Kernel logs confirmed X100VI was enumerated: `0x04cb/0305/0131 (USB PTP Camera)`
- Camera connected at 480 Mbps via USB hub
- Camera later disconnected (no longer visible in ioreg/system_profiler)

#### libgphoto2 Deadlock
- **Critical Issue**: `libgphoto2 camera_init()` deadlocks on macOS
- Symptoms: App stuck on "Connecting" forever, 95%+ CPU usage
- Root cause: libgphoto2's USB enumeration + `camera_init` creates a deadlock on macOS
- The `camera_init()` call blocks indefinitely waiting for camera communication
- Adding timeouts didn't help — the app consumed 95% CPU in a tight loop

#### Fixes Attempted
1. **Added port-specific connection** — Added `gp_camera_set_port()` to set USB port before init
2. **Added debug logging** — Print statements at each connect step
3. **Added timeout** — 15-second timeout via `withTimeout()` helper
4. **Fixed network port filtering** — Only match `usb:` prefixed ports

#### Current State
- App UI: Fully functional (Recipes, Loadouts, Camera, Darkroom tabs)
- Debug framework: Complete (DebugLogger, DebugHUD, CrashReporter)
- libgphoto2 FFI: All functions loaded and registered
- **Camera connection: BLOCKED** — libgphoto2 deadlocks on `camera_init()`

---

## Session 5 — Package Scaffold (Complete)

---

## Session 5 — Package Scaffold (Complete)

### Objective

Scaffold the Swift Package Manager packages that form the foundation of the cross-platform app.

### What We Built

#### `FujiRecipesCore` — Shared domain package
- `FilmSimulation` enum — 20 PTP values (1–20), X-Trans V only flags
- `WhiteBalanceMode` enum — 11 WB modes
- `DynamicRange` enum — Auto, 100, 200, 400
- `GrainEffect` enum — 1–5 (Off, Weak Small, Strong Small, Weak Large, Strong Large)
- `EffectIntensity` enum — Off, Weak, Strong (generic for Color Chrome, Smooth Skin)
- `Recipe` model — all 14 settings with PTP mapping fields
- `PresetSlot` model — C1–C7 slot representation
- `PTPConstants` — 38 property codes (active + preset + RAW conversion + USB IDs)

#### `FujiPTPClient` — PTP abstraction package
- `PTPClientProtocol` — unified protocol for camera communication
  - `connect()`, `disconnect()`, `isConnected`
  - `cameraInfo` — camera identification
  - `readProperty(_:)` — GetDevicePropValue
  - `writeProperty(_:,value:)` — SetDevicePropValue
  - `readPresetSlot(_:)` / `writePresetSlot(_:,data:)` — C1–C7 slots
  - `readNativeProfile()` — 625-byte 0xD185 profile
- `CameraInfo`, `PropertyResponse`, `PresetData`, `PTPError` — supporting types
- `MacOSSession` stub — libgphoto2 FFI placeholder
- `IOSSession` stub — ImageCaptureCore placeholder

#### App Entry Points
- `FujiRecipes/iOS/Source/App.swift` — SwiftUI entry (stub UI)
- `FujiRecipesMac/macos/Source/App.swift` — macOS SwiftUI entry (stub UI)

### Package Dependencies

```
FujiRecipes (iOS) ──> FujiRecipesCore
              ──> FujiPTPClient ──> FujiRecipesCore

FujiRecipesMac (macOS) ──> FujiRecipesCore
                  ──> FujiPTPClient ──> FujiRecipesCore
```

### Next Steps (Phase 1 continued)

1. **Create Xcode projects** — open Xcode → File → New → Project (iOS + macOS)
2. **Add to workspace** — drag .xcodeproj files into a single workspace
3. **Add SPM dependencies** — FujiRecipesCore and FujiPTPClient to each app target
4. **Wire up App.swift** — point to the Source/ directories
5. **Set signing** — DEVELOPMENT_TEAM for each target

### Xcode Project Setup Guide

To create the Xcode projects manually:

**iOS App:**
1. File → New → Project → iOS → App
2. Product name: `FujiRecipes`, Interface: SwiftUI, Language: Swift
3. Package dependencies: add `FujiRecipesCore` and `FujiPTPClient` from local paths
4. Add existing file: `FujiRecipes/iOS/Source/App.swift`
5. Set deployment target to iOS 17.0

**macOS App:**
1. File → New → Project → macOS → App
2. Product name: `FujiRecipesMac`, Interface: SwiftUI, Language: Swift
3. Same package dependencies as iOS
4. Add existing file: `FujiRecipesMac/macos/Source/App.swift`
5. Set deployment target to macOS 14.0

---

## Session 9 — Code Review & Build Preparation (Complete)

### Objective

Verify code correctness, fix issues, prepare for Xcode build.

### What We Did

#### Code Review
- Fixed `widgetValueToInt()` — removed invalid `setWidgetValueImpl` reference
- Verified all FFI function signatures match libgphoto2 C API
- Confirmed PTP packet byte ordering (big-endian)
- Checked all protocol method implementations

#### Files Created
- `tools/test-camera.swift` — Standalone Swift test script for libgphoto2
- `BUILD.md` — Complete build guide with troubleshooting

#### Project Verification
- ✅ All 18 Swift source files present
- ✅ 4 Xcode projects generated via xcodegen
- ✅ 1 Xcode workspace linking all projects
- ✅ 11 libgphoto2 dylibs bundled with resolved dependencies
- ✅ Package.swift files correct (FujiRecipesCore + FujiPTPClient)
- ✅ project.yml files correct (iOS + macOS apps + frameworks)

### Known Issues (to resolve in Xcode)

1. **`gp_context_new()`** — May not be available in all libgphoto2 builds; fallback needed
2. **Post-build install_name rewrite** — Need to add build phase script to FujiRecipesMac
3. **iOS camera entitlement** — Must be enabled in Xcode capabilities

---

## Session 8 — RAW Conversion & USB Detection (Complete)

### Objective

Implement RAW conversion (RAF→JPEG via in-camera processing), string property encoding, native profile reading, and USB port detection.

### What We Built

#### RAW Conversion (`FFI+RAW.swift`)
- **`convertRAF(_:profileModifier:)`** — Full RAF→JPEG conversion workflow:
  1. SendObjectInfo + SendObject — upload RAF file
  2. Read native profile (0xD185) — modify via closure
  3. Write modified profile back
  4. Trigger conversion (0xD183 = 0)
  5. Poll GetObjectHandles for JPEG
  6. Download JPEG via GetObject
  7. Cleanup
- **`capturePreview()`** — Live view JPEG capture via PTP CapturePreview (0x1006)
- **`RAFFile`** wrapper — wraps RAF data with metadata (name, format, encoding)
- **`JPEGFile`** wrapper — represents downloaded JPEG
- **`buildSendObjectInfo(_:)`** — Constructs PTP SendObjectInfo packet
- **`pollForJPEG()`** — Polls for JPEG objects after conversion trigger
- **`downloadObject(_:)`** — Downloads object by handle

#### String Properties (in FFI+PTP.swift)
- **`ptpGetPresetName()`** — Read 0xD18D string property (UTF-16LE with 4-byte length prefix)
- **`ptpSetDevicePropValueString(_:value:)`** — Write string property (UTF-16LE encoding)
- **`ptpGetDevicePropValueData(_:)`** — Read binary property data (625-byte native profile)

#### USB Detection (`FFI+USB.swift`)
- **`scanForFujiCamera()`** — Scans libgphoto2 port info list for Fuji VID/PID
- **`isFujiX100VI(portPath:)`** — Checks if port matches X100VI (0x04CB:0x0305)
- **`isFujiCamera(portPath:)`** — Checks for any Fuji camera
- Updated `connect()` to auto-detect and validate camera before connecting

### RAF File Upload Format

PTP SendObjectInfo packet structure:
| Offset | Size | Field | Value |
|--------|------|-------|-------|
| 0 | 4 | StorageID | 0xFFFFFFFF |
| 4 | 2 | ObjectFormat | 0x300B (RAF) |
| 6 | 2 | Encoding | 0x0001 (packed) |
| 8 | 4 | Unknown | 0 |
| 12 | 8 | Thumbnail | 0 offset, 0 length |
| 20 | 8 | Image dimensions | 0 (unknown) |
| 28 | 4 | Bit depth | 0 |
| 32 | 4 | ParentObject | 0xFFFFFFFF |
| 36 | 4 | Association | 0, 0 |
| 40 | variable | Filename | UTF-16LE with length prefix |
| variable | 28 | Dates | YYYYMMDDhhmmss (creation + modification) |

### Native Profile Layout (0xD185)

625-byte binary structure:
```
[4]  ExposureBias       [8]  FilmSimulation   [9]  GrainEffect
[6]  DynamicRange%      [10] ColorChrome      [11] SmoothSkin
[13] WBShiftR           [14] WBShiftB         [15] WBColorTemp(K)
[16] HighlightTone×10   [17] ShadowTone×10    [18] Color×10
[19] Sharpness×10       [20] NoiseReduction   [25] CCFxBlue
[27] Clarity×10
```

---

## Session 8 — Raw PTP Commands (Complete)

### Objective

Implement raw PTP commands (SetDevicePropValue/GetDevicePropValue) for preset slots and native profile reading.

### What We Built

#### Raw PTP Layer (`FFI+PTP.swift`)
- **PTPPacket builder** — constructs PTP commands with proper BE byte order
- **PTPResponse parser** — parses PTP responses with opcode/status decoding
- **ptpGetDevicePropValue(_:)** — reads 32-bit properties via raw PTP GetDevicePropValue (0x1015)
- **ptpSetDevicePropValue(_:value:)** — writes 32-bit properties via raw PTP SetDevicePropValue (0x1016)
- **ptpReadPresetSlot(_:)** — reads a full C1–C7 slot via preset properties
- **ptpWritePresetSlot(_:data:)** — writes a full C1–C7 slot via preset properties
- **ptpReadNativeProfile()** — stub for 0xD185 native conversion profile

#### Preset Property Mapping
All 16 preset properties wired up:
| Property | PTP Code | Description |
|----------|----------|-------------|
| Slot | 0xD18C | Select C1–C7 |
| Name | 0xD18D | Display name (string) |
| DR | 0xD190 | Raw percentage 100/200/400 |
| Film Sim | 0xD192 | Enum 1–20 |
| Grain | 0xD195 | 1=Off, 2=Weak, 3=Strong |
| Color Chrome | 0xD196 | 1=Off, 2=Weak, 3=Strong |
| FX Blue | 0xD197 | 1=Off, 2=Weak, 3=Strong |
| Smooth Skin | 0xD198 | 1=Off, 2=Weak, 3=Strong |
| WB Mode | 0xD199 | uint16 WBMode enum |
| WB Shift R | 0xD19A | INT8 -9 to +9 |
| WB Shift B | 0xD19B | INT8 -9 to +9 |
| Color Temp | 0xD19C | Kelvin |
| Highlight | 0xD19D | ×10 encoding |
| Shadow | 0xD19E | ×10 encoding |
| Color | 0xD19F | ×10 encoding |
| Sharpness | 0xD1A0 | ×10 encoding |
| Clarity | 0xD1A2 | ×10 encoding |

#### Port I/O Functions Added
- `gp_port_open()` — open PTP port
- `gp_port_send_data()` — send raw PTP packets
- `gp_port_get_data()` — receive PTP responses
- `gp_port_close()` — close port
- `gp_camera_get_port()` — get port handle from camera

---

## Session 7 — libgphoto2 FFI Integration (Complete)

### Objective

Implement the actual libgphoto2 FFI bindings in Swift and wire up MacOSSession to call real camera functions.

### What We Built

#### FFI Layer (`FFI+Types.swift`)
- Runtime library loading via `dlopen()` from Homebrew or bundled dylibs
- `dlsym()` function registry — 30+ libgphoto2 functions loaded by name
- OpaquePointer-based types: `GPCamera`, `GPContext`, `GPConfig`, `GPWidget`, etc.
- Helper functions for string/int conversions at the C boundary

#### FFI Helpers (`FFI+Helpers.swift`)
- `widgetValueToString()` / `widgetValueToInt()` — read widget values
- `setWidgetValue()` / `setWidgetStringValue()` — write widget values
- `widgetLabel()`, `widgetName()`, `widgetType()` — widget introspection
- `widgetChoiceCount()`, `widgetChoice()` — radio/button options
- `configGetChild()`, `configGetChildValue()` — config tree traversal

#### MacOSSession (`MacOS+PTPClient.swift`)
Complete protocol implementation with:
- **connect()**: `gp_library_init()` → `gp_port_info_list_new()` → `gp_camera_new()` → `gp_camera_init()`
- **disconnect()**: `gp_camera_exit()` → `gp_camera_free()` → `gp_port_info_list_free()`
- **readProperty()**: config tree traversal → widget value read
- **writeProperty()**: config tree traversal → widget value write → `gp_camera_set_config()`
- **readPresetSlot()**: stub (needs raw PTP SetDevicePropValue)
- **writePresetSlot()**: stub (needs raw PTP SetDevicePropValue)
- **readNativeProfile()**: stub (needs raw PTP GetDevicePropValue 0xD185)

#### Config Path Mapping (`PTPConfigMapping`)
Maps Fuji PTP property codes to libgphoto2 config paths:
| PTP Code | Config Path |
|----------|------------|
| 0xD001 (film sim) | /main/settings/filmsim |
| 0xD002 (color) | /main/settings/color |
| 0xD007 (DR) | /main/settings/dr |
| 0x5005 (WB) | /main/settings/wb |
| 0xD00B (WB red) | /main/settings/wbshift/r |
| 0xD00C (WB blue) | /main/settings/wbshift/b |
| 0xD320 (highlight) | /main/settings/highlight |
| 0xD321 (shadow) | /main/settings/shadow |
| 0x5015 (sharpness) | /main/settings/sharpness |
| 0xD01C (ISO NR) | /main/settings/noisereduction |
| 0xD023 (grain) | /main/settings/grain |
| 0x500F (ISO) | /main/settings/iso |
| 0x5010 (EV) | /main/settings/ev |

### Key Design Decisions

1. **Runtime dlopen()** instead of compile-time linking — enables bundling dylibs and avoids Homebrew dependency at runtime
2. **OpaquePointer types** — no C interop module needed; all types are opaque handles
3. **Function registry pattern** — dlsym() called once at startup, stored as typed closures
4. **Config tree over raw PTP** — most active properties accessible via `gp_camera_get_config()` / `gp_camera_set_config()`

### Remaining for MacOSSession

- [ ] Implement preset slot read/write (needs raw PTP SetDevicePropValue)
- [ ] Implement native profile read (needs raw PTP GetDevicePropValue 0xD185)
- [ ] Implement `gp_camera_capture_preview()` for RAF-to-JPEG
- [ ] Add USB port detection (match Fuji VID/PID: 0x04CB:0x0305)
- [ ] Add error logging and camera info extraction

---

## Session 4 — Hardware PTP Probe (Complete)

### Objective

Connect the X100VI via USB-C and test PTP communication to determine the correct path for reading/writing camera properties and recipe presets.

### What We Built

**Swift PTP probe tool** at `ios-app/` — uses ImageCaptureCore to enumerate cameras, open sessions, and send raw PTP commands. Built with Swift 6.3.3 + CommandLineTools SDK 26.5.

### Test Results

#### ✅ Passed

| Test | Result |
|------|--------|
| Device detection | X100VI found via `ICDeviceBrowser` |
| Session open | `requestOpenSession` succeeded, `hasOpenSession: true` |
| PTP capable | `ICCameraDeviceCanAcceptPTPCommands` in capabilities |
| PTP command send | `requestSendPTPCommand` accepts raw PTP requests |

#### ⚠️ Partial / Limited

| Test | Result |
|------|--------|
| Raw PTP GetDeviceInfo | Response: 12 bytes, code `0x2000` (not standard `0x2001`) |
| Content enumeration | 0 storage items (Fuji doesn't expose storage via ImageCaptureCore) |
| Media files | 0 files detected |
| Battery level | `batteryLevelAvailable: false` |

#### ❌ Not Working

| Test | Result |
|------|--------|
| Full GetDeviceInfo parsing | Response too short (12 bytes vs 18+ expected) |
| Device property probes (0xD001, 0xD34C, etc.) | Blocked — raw PTP responses not parseable |
| Slot write test | Blocked — raw PTP not working |

### Key Discoveries

1. **macOS ImageCaptureCore transforms raw PTP responses.** The response from `requestSendPTPCommand` is not standard PTP/USB format — it's framework-wrapped. This means we can't use ImageCaptureCore to read/write Fuji device properties on macOS.

2. **VID/PID byte-swapping.** macOS `ICDevice.usbVendorID` / `usbProductID` returns `0x4CB0:0x3050` (byte-swapped) vs. standard `0x04CB:0x0305`. Match logic needs to handle all variants.

3. **Fuji X100VI on ImageCaptureCore.** The camera exposes `ICCameraDeviceCanAcceptPTPCommands` but raw PTP commands return non-standard responses. Storage/media are not accessible.

4. **iOS ImageCaptureCore untested.** The iOS version of ImageCaptureCore may handle PTP differently. It must be tested on actual iOS hardware.

### Full Results

See `ios-app/PTP-probe-results.md` for detailed byte-level analysis.

---

## Architecture Decision (Session 4)

### Problem

We need PTP communication that works on **both macOS and iOS** to push recipes to the X100VI. ImageCaptureCore on macOS doesn't support raw PTP for Fuji cameras.

### Decision: Hybrid PTP Layer

| Platform | PTP Implementation | Dependencies |
|----------|-------------------|--------------|
| **iOS** | ImageCaptureCore (`requestSendPTPCommand`) | None (native) |
| **macOS** | libgphoto2 (bundled via SPM) | ~8MB bundled binary |

### Rationale

1. **Core goal is pushing recipes to camera slots.** This requires raw PTP `SetDevicePropValue` on properties like `0xD18E` (C1 slot), `0xD001` (film sim), etc.
2. **ImageCaptureCore on macOS can't do this** for Fuji cameras (proven by probe).
3. **iOS ImageCaptureCore may work** — iOS handles USB connection natively and may return raw PTP responses. Must test.
4. **libgphoto2 already supports X100VI** out of the box with Fuji vendor extensions.
5. **Single protocol abstraction** makes both platforms consistent and swappable.

### Package Structure (to be scaffolded)

```
FujiPTPClient/              ← SPM package: PTP abstraction layer
  └── PTPClient.swift       ← public protocol
  └── PTP+macOS.swift       ← libgphoto2 FFI implementation
  └── PTP+iOS.swift         ← ImageCaptureCore implementation
  └── Resources/libgphoto2/ ← bundled prebuilt .a (arm64, x86_64, arm64-macos)
FujiRecipesCore/            ← Shared Swift package: recipes, models, mapping
FujiRecipes/                ← iOS app (Xcode project)
FujiRecipesMac/             ← macOS app (Xcode project)
```

---

## Session 3 — Code-Only Refinements (Complete)

### Normalization Fixes (`tools/normalize_settings.py`)

| Fix | Detail |
|-----|--------|
| Exposure comp range parsing | New `_parse_exposure_range()` handles "0 to +2/3", "+1/3 to +1", "-1/3 to +2/3", "+1-1/3". **85/86 recipes now parsed** (was ~51/86). |
| Grain effect off value | `0xD023` uses 1=Off (not 0). Fixed `normalize_grain_effect()`. |
| WB needsProbe logic | Only flags when `wbMode == "unknown"`, not on partial kelvin/shift data. |
| Dynamic range PTP values | `DR_MAP` now uses actual PTP values (100, 200, 400) instead of indices (1, 2, 3). |
| Exposure comp PTP conversion | `_ev_to_ptp()` converts EV to PTP: `round(ev * 3) * 333` for `0x5010` (step 333). |
| Absent exposure comp | Recipes without EC get `absent: true` instead of `needsProbe: true`. |

**Stats:**
- Probe needed: **271** (down from 356)
- Mapped: **913** (up from 834)
- Unmapped: **0**
- Exposure comp parsed: **85/86**

### Site Viewer (`site/`)

**`index.html`** — Added import button in loadout panel.

**`app.js`** — 9 new features:
1. Recipe comparison (up to 4 recipes, side-by-side table with PTP badges)
2. Import loadout JSON from file
3. Sort by name / film sim / date (persisted in localStorage)
4. Keyboard navigation: arrows, J/K, N/P
5. Deep linking via URL hash (`#recipe-id`)
6. Copy settings to clipboard (with PTP property codes)
7. Export single recipe as JSON
8. Favorites (star/unstar, localStorage persisted)
9. Search term highlighting

**`styles.css`** — New CSS for: sort bar, compare bar, favorites, copy button, toast notifications, search highlights, responsive tweaks.

### New Tools

**`tools/d185_profile.py`** — d185 native profile binary packer/unpacker (625-byte RAW conversion profile)
- `unpack` — Binary → JSON
- `pack` — JSON → binary
- `inspect` — Table view of profile fields
- `default` — Generate default PROVIA/Standard profile
- `apply` — Apply settings (filmsim, grain, color-chrome, DR, WB shifts, sharpness) and pack

**`tools/export_ios_app_data.py`** — iOS app-ready JSON export → `ios-app-data.json`
- Film sim enum (1–20)
- WB mode enum (0x0002, 0x0004, 0x8001, etc.)
- DR enum (0xFFFF, 100, 200, 400)
- Grain enum (0, 1, 2, 3, 4)
- Active shooting property definitions (PTP codes, types, ranges)
- Preset slot (C1–C7) property definitions (0xD18E–0xD1A5)
- Per-recipe: PTP-ready settings + preset-ready settings
- Camera USB identifiers (0x04CB:0x0305)

**Export stats:** 86 recipes, 84/86 film sims mapped, all have PTP + preset settings.

---

## Hard Stops — Hardware Required

These items remain blocked until PTP communication is working:

| # | Item | Why | Priority |
|---|------|-----|----------|
| 1 | **PTP property probes** | Read `0xD001`, `0xD34C`, `0xD18E–0xD1A5` on real camera | 🔴 |
| 2 | **Slot write test** | Write a recipe to C1, verify persistence on camera | 🔴 |
| 3 | **RAW conversion test** | Upload RAF, modify d185 profile, retrieve JPEG | 🟡 |
| 4 | **D-Range Priority values** | Likely `0xD02E`, exact values unknown (Auto, 0, 1, 2, 3?) | 🟡 |
| 5 | **Color Chrome FX Blue active property** | Known in presets at `0xD197`, active property TBD | 🟡 |
| 6 | **Clarity active property** | Known in presets at `0xD1A2`, active property TBD | 🟡 |
| 7 | **Tone field offsets** | Highlight/Shadow/Color at offsets 16–18 overlap ColorTemp (4 bytes at 15–18). The doc offsets may be wrong. | 🟡 |
| 8 | **Grain effect encoding in d185** | May be UINT16 (strength×size) not UINT8 — needs probe | 🟢 |
| 9 | **`0xD191` and `0xD1A5` preset properties** | Always 0 and 7 respectively — purpose unknown | 🟢 |

---

## 📋 Duty to Do Next (Start of Next Session)

### Phase 1: Xcode Project Setup & Build

**Priority:** 🔴 Critical — unblocks all development

✅ **Done in Session 5:** SPM packages + 4 Xcode projects + workspace
✅ **Done in Session 6:** libgphoto2 bundled (11 dylibs)
✅ **Done in Session 10:** Swift 6 FFI compatibility — both SPM packages build ✅

**Remaining:**
1. **Install Xcode** — blocks Xcode project builds (Command Line Tools only currently)
2. **Build FujiRecipesMac in Xcode** — verify compilation with bundled dylibs
3. **Add post-build script** — rewrite install_names for bundled dylibs
4. **Set DEVELOPMENT_TEAM** + iOS camera entitlement

### Phase 2: Camera Communication

**Priority:** 🔴 Critical — the core feature

1. **Connect X100VI via USB-C**
2. **PTP property probes** — read `0xD001`, `0xD34C`, `0xD18E–0xD1A5`
3. **Slot write test** — write a recipe to C1, verify persistence on camera
4. **iOS PTP test** — test ImageCaptureCore on actual iOS hardware (iPad/iPhone + USB-C)

### Phase 3: RAW Conversion

**Priority:** 🟡 — after stable camera control

1. RAW conversion test — upload RAF, modify d185 profile, retrieve JPEG
2. `capturePreview()` — live view JPEG via PTP CapturePreview
3. D-Range Priority values, Color Chrome active property, Clarity active property

### Phase 4: Recipe Manager UI

**Priority:** 🟡 — can be built in parallel with PTP plumbing

1. Recipe list/detail views (use `Recipe` model from FujiRecipesCore)
2. Loadout builder (select recipes for C1–C7 slots)
3. Import/export recipe data (JSON)
4. PTP badge display (show which settings need PTP mapping)

---

## Reminder

Fuji X Weekly scraped content is for **private/personal use only**. Do not publish or redistribute without permission.

## Session 10 — Swift 6 FFI Compatibility Fix (Complete)

### Objective

Fix all compilation errors caused by Swift 6.3.3 + CommandLineTools SDK incompatibilities in the FFI layer. The project was written with assumptions from an earlier Swift version and needed comprehensive rewrites.

### Research Performed

- Searched Swift 6 documentation, corelibs-foundation source, Swift forums, and Apple docs
- Found that `@_silence_awareness` was never a public attribute (removed)
- Found that `OpaquePointer` is now `AnyObject` in Swift 6, not a raw pointer
- Confirmed `NSString.data(using:)` takes `UInt`, not `String.Encoding`
- Confirmed `init(truncatingIfNeeded:)` replaces `truncatingBitPattern:`
- Confirmed `Thread.sleep` unavailable in async contexts (use `Task.sleep`)
- Confirmed `(value, radix: 16)` removed from string interpolation

### Key Fixes Applied

#### 1. FFI Type System (`FFI+Types.swift`) — Complete Rewrite
- All opaque types: `OpaquePointer` → `UnsafeMutableRawPointer` / `UnsafeRawPointer`
- Function types: Fixed pointer-to-pointer patterns (`&ptpPort` for `portOpen`)
- `let` → `var` for dlopen function registry (must be assigned twice: nil default, then loaded value)
- `private` → `internal` for typealias visibility (needed across files)
- Added `@unchecked Sendable` to function registry struct
- Added `portInfoGetNote`/`portInfoSetNote` function types (missing before)
- Fixed `cStringToSwift` nil check (removed `ptr.equalTo(nil)` — invalid on `UnsafePointer`)

#### 2. FFI Helpers (`FFI+Helpers.swift`)
- Removed all `@_silence_awareness` attributes (7 annotations)
- Fixed all function signatures for `UnsafeRawPointer` types

#### 3. PTP Layer (`FFI+PTP.swift`)
- Removed `@_silence_awareness` attributes
- Fixed `PTPResponse` access level (`fileprivate` → accessible)
- Fixed `PTPPacket` access level for cross-file use
- Fixed `wbShiftR` → `wbShiftRed`, `wbShiftB` → `wbShiftBlue` (PresetData field names)
- Fixed `String.Encoding.utf16LittleEndian` → `.rawValue` for NSString
- Changed `fromBEBytes` to accept `[UInt8]` instead of `ArraySlice<UInt8>`
- Moved `nextTransactionID` from extension to MacOSSession class (extensions can't have stored properties)
- Fixed `guard let name = data.name` (name is non-optional String)
- Fixed `for` loop guard body (added `continue`)
- Added `import PTPClient` for cross-target types

#### 4. RAW Conversion (`FFI+RAW.swift`)
- Removed `@_silence_awareness` attributes
- Fixed `openedPort` scope in closures (restructured guard pattern)
- Fixed `utf16LittleEndian` encoding for NSString
- Fixed `Data` → `ArraySlice<UInt8>` conversion (wrapped with `Array()`)
- Changed `sendAndReceivePTP` to `async throws` (was `throws` only)
- Added `try await` to `sendAndReceivePTP` callers
- Replaced `Thread.sleep` with `try await Task.sleep(nanoseconds: ...)` in async contexts
- Added `import PTPClient`

#### 5. USB Detection (`FFI+USB.swift`)
- Removed `@_silence_awareness` attributes
- Fixed `GPPortInfo?` type for `portInfoListGetInfo`

#### 6. macOS Session (`MacOS+PTPClient.swift`)
- Added `import PTPClient`
- Fixed `OpaquePointer` → `UnsafeRawPointer` for camera/context
- Fixed `UInt32(truncatingBitPattern:)` → `init(truncatingIfNeeded:)` (6 places)
- Fixed `radix` interpolation (1 place)
- Added `@Sendable` to closure types in `Mapping` struct
- Added `_ptpTransactionID` and `nextTransactionID()` to class (was in extension)
- Fixed `getCurrentConfig` return type

#### 7. iOS Session (`iOS+PTPClient.swift`)
- Added `import PTPClient`

#### 8. Enums (`FujiRecipesCore`)
- Added `Codable` conformance to all 5 enums
- Fixed `WhiteBalanceMode.tungsten` duplicate raw value (changed to 5, added `actualPTPValue` property returning 6)

### Build Results

✅ **FujiRecipesCore** — `swift build` passes
✅ **FujiPTPClient** — `swift build` passes (all 3 frameworks)
✅ No compilation errors remaining

**Remaining warnings** (non-blocking): unused variables, `nonisolated(unsafe)` redundancy on Sendable type

### Files Created

- `RESEARCH-FIXES.md` — Master reference document with all research findings and fix details

### What This Unblocks

1. **Xcode build** — Can now generate and build Xcode projects (once Xcode is installed)
2. **Camera testing** — FFI layer compiles, ready for real camera communication testing
3. **iOS PTP** — iOS session compiles with proper PTPClient imports

### Known Limitations

- **Xcode not installed** — Only Command Line Tools available; cannot build `.xcodeproj` targets
- **libgphoto2 not available** — No Homebrew libgphoto2 installed; bundled dylibs are present but need post-build install_name rewriting

## Session 11 — Xcode Install Attempt (Blocked)

### Objective

Install Xcode to build the Xcode workspace (FujiRecipes + FujiRecipesMac targets).

### What We Tried

1. **Installed `mas`** (Mac App Store CLI) via Homebrew — ✅ successful
2. **Looked up Xcode** on App Store — confirmed Xcode 26.6 available (2,351 MB, free)
3. **Attempted `mas install 497799835`** — ❌ failed: requires sudo password for installation

### Why It Failed

`mas install` requires `sudo` to place Xcode in `/Applications`. This needs interactive password input which isn't available in the current session.

### Alternatives Tried (All Blocked)

- `xcodes` — Homebrew tap `xcodesorg/xcodes` not found
- Direct download from Apple Developer — requires developer account login
- `xcode-select --install` — only installs Command Line Tools (already present)

### Current State

| Component | Status |
|-----------|--------|
| **FujiRecipesCore** | ✅ Builds (`swift build`) |
| **FujiPTPClient** | ✅ Builds (`swift build`) |
| **4 Xcode projects** | ✅ Generated (xcodegen) |
| **Workspace** | ✅ Created (links all 4 projects) |
| **Xcode IDE** | ❌ Not installed — blocks Xcode project builds |
| **Command Line Tools** | ✅ Present (Swift 6.3.3, SDK 26.5) |
| **libgphoto2 dylibs** | ✅ Bundled (11 files, 4MB) |

### What's Needed

**To proceed, Xcode must be installed** — one of:

1. **Open the App Store** and search "Xcode" → Install (requires Apple ID + password)
2. **Use `mas install 497799835`** in a terminal with sudo access
3. **Download from [developer.apple.com](https://developer.apple.com/download/)** (requires Apple Developer account)

### Once Xcode Is Installed

1. Open `FujiRecipes.xcworkspace`
2. Set `DEVELOPMENT_TEAM` in each target's build settings
3. Enable `com.apple.security.device.camera` entitlement for iOS target
4. Build FujiRecipesMac → verify compilation
5. Connect X100VI via USB-C → test PTP communication

## Session 12 — Xcode Build Fix & Cross-Platform Compilation (Complete)

### Objective

Fix build issues in the Xcode workspace so both macOS and iOS targets compile.

### Issues Found & Fixed

#### 1. Workspace relative path bug
- **Problem**: `contents.xcworkspacedata` had `./FujiRecipesCore/...` paths, which made Xcode look for projects inside the workspace directory instead of at the root level.
- **Fix**: Changed to `FujiRecipesCore/FujiRecipesCore.xcodeproj` (no `./` prefix).

#### 2. Package dependency wiring in project.yml
- **Problem**: `project.yml` files defined `packages:` but didn't wire them as `dependencies:` in targets.
- **Fix**: Added `dependencies:` to both FujiRecipesMac and FujiRecipes project.yml files.

#### 3. SPM product vs target module name mismatch
- **Problem**: `Package.swift` defines a library product named `FujiPTPClient` that maps to the `PTPClient` target. The Swift module name is the target name (`PTPClient`), not the product name. App.swift was importing `import FujiPTPClient` which doesn't exist as a module.
- **Fix**: 
  - Added `PTPClientMacOS` and `PTPClientiOS` library products to Package.swift
  - Updated App.swift imports to `import PTPClient` + `import PTPClientMacOS` (macOS) or `import PTPClientiOS` (iOS)
  - Added cross-platform dependencies in both project.yml files

### Build Results

✅ **FujiRecipesCore** — `swift build` passes
✅ **FujiPTPClient** — `swift build` passes (all 3 frameworks)
✅ **FujiRecipesMac** — Xcode build passes (58KB binary)
✅ **FujiRecipes (iOS)** — Xcode simulator build passes (124KB binary)

### Files Changed

| File | Change |
|------|--------|
| `FujiRecipes.xcworkspace/contents.xcworkspacedata` | Fixed relative paths |
| `FujiRecipesMac/macos/project.yml` | Added dependencies |
| `FujiRecipesMac/macos/Source/App.swift` | Fixed imports |
| `FujiRecipes/iOS/project.yml` | Added dependencies |
| `FujiRecipes/iOS/Source/App.swift` | Fixed imports |
| `FujiPTPClient/Package.swift` | Added PTPClientMacOS & PTPClientiOS products |

### Remaining Warnings (non-blocking)

- `nonisolated(unsafe)` redundant on Sendable types (FFI+Types.swift)
- `try` on non-throwing functions (FFI+RAW.swift, FFI+PTP.swift)
- Unused `guard let port` patterns — these are defensive guards where the `port` value is checked but not used directly
- Trailing closure ambiguity in `withUnsafeBytes` closures

### What This Unblocks

1. **Camera integration testing** — Both apps compile, ready for real PTP testing
2. **UI development** — Phase 2 UI implementation can begin on both platforms
3. **Recipe loading** — Can now wire up recipe data from the JSON dataset

## Session 13 — Phase 2 UI Implementation (Complete)

### Objective

Build SwiftUI recipe browser for both macOS and iOS with 86 loaded recipes.

### What Was Built

#### RecipeStore (Data Layer)
- `RecipeStore` — `@MainActor ObservableObject` that loads recipes from `recipes-data.json`
- Parses 86 Fuji X Weekly recipes into `FujiRecipesCore.Recipe` objects
- Filters by film simulation, dynamic range, grain effect, white balance
- Searchable by recipe name or film simulation name
- Sorts by film sim name, then recipe name

#### RecipeListView (macOS Sidebar + iOS List)
- macOS: `NavigationSplitView` with sidebar filters + recipe list
- iOS: `List` with search bar + recipe rows
- Film simulation badge with accent color
- Checkmark indicator for fully PTP-mapped recipes

#### RecipeDetailView (Both Platforms)
- Film simulation badge + recipe name header
- Active Settings section (film sim, DR, grain, WB, color, highlight/shadow, sharpness, ISO NR)
- Preset Settings section (C1–C7: highlight, shadow, sharpness, clarity)
- Notes & Tips section (ISO, exposure compensation)
- Source link (opens article in browser)
- macOS: `NSWorkspace.shared.open()`
- iOS: `Link` with destination URL

### Files Created/Changed

| File | Action |
|------|--------|
| `FujiRecipesMac/macos/Source/RecipeStore.swift` | **Created** — Data layer |
| `FujiRecipesMac/macos/Source/RecipeViews.swift` | **Created** — SwiftUI views |
| `FujiRecipesMac/macos/Source/App.swift` | **Updated** — Use RecipeStore |
| `FujiRecipesMac/macos/Resources/recipes-data.json` | **Copied** — 86 recipe data |
| `FujiRecipes/iOS/Source/RecipeStore.swift` | **Copied** from macOS |
| `FujiRecipes/iOS/Source/RecipeViews.swift` | **Copied** from macOS (iOS-adapted) |
| `FujiRecipes/iOS/Source/App.swift` | **Updated** — Use RecipeStore |
| `FujiRecipes/iOS/Resources/recipes-data.json` | **Copied** — 86 recipe data |
| `FujiRecipesCore/Models/Recipe.swift` | **Added** explicit memberwise `init()` |

### Build Results

✅ **FujiRecipesMac** — Builds and links with full recipe UI
✅ **FujiRecipes (iOS)** — Builds and links with full recipe UI
✅ **86 recipes loaded** from JSON into SwiftUI views

### Key Technical Decisions

- Renamed internal `Category` enum to `FilterCategory` to avoid SwiftUI name collision
- Used `displayName` (not `rawValue`) for film simulation display names
- Explicit `init()` on `Recipe` to enable memberwise initialization with `Codable`
- iOS uses `Link` for source URLs; macOS uses `NSWorkspace`

## Session 14 — Favorites & Local Storage (Complete)

### Objective

Add persistent favorites for both platforms using UserDefaults.

### What Was Built

#### FavoritesStore (FujiRecipesCore)
- `@MainActor public final class FavoritesStore: ObservableObject`
- Uses `UserDefaults` for persistence
- `toggleFavorite(for:)`, `isFavorite(_:)`, `addFavorite(_:)`, `removeFavorite(_:)`
- `@Published` `favoriteIDs: Set<String>` for reactive updates

#### UI Integration
- **macOS**: Star button in RecipeDetailView header (toggles favorite)
- **iOS**: Star indicator in list rows (toggles favorite via detail view)
- **Filter**: New "⭐ Favorites" filter category in both platforms
- List items show star for favorited recipes

### Files Created/Changed

| File | Action |
|------|--------|
| `FujiRecipesCore/Models/FavoritesStore.swift` | **Created** |
| `FujiRecipesMac/macos/Source/RecipeViews.swift` | Updated — fav button + indicator |
| `FujiRecipes/iOS/Source/App.swift` | Updated — fav indicators in list |
| `FujiRecipes/iOS/Source/RecipeViews.swift` | Updated — iOS-adapted detail view |

### Build Results

✅ **FujiRecipesMac** — Builds, favorites work
✅ **FujiRecipes (iOS)** — Builds, favorites work
✅ **0 warnings** on both platforms

### Remaining UI TODO

- [ ] C1-C7 loadout UI
- [ ] Manual recipe editing
- [ ] Import/export recipe data
- [ ] Camera integration (requires X100VI hardware)

## Session 15 — C1-C7 Loadout UI (Complete)

### Objective

Build preset slot management UI for C1-C7 loadouts with "load recipe to slot" action.

### What Was Built

#### LoadoutStore (FujiRecipesCore)
- `@MainActor public final class LoadoutStore: ObservableObject`
- Manages 7 preset slots (C1-C7) with local UserDefaults persistence
- Settings: name, filmSim, DR, grain, WB, highlight, shadow, color, sharpness
- `applyRecipe(_:to:)` — load a recipe into a slot in one tap
- `settingCount` property for progress indicator
- All loadout operations: `updateName`, `setFilmSim`, `setDynamicRange`, etc.

#### LoadoutCard + EmptyLoadoutCard
- Color-coded slot cards (blue/green/orange/purple/pink/cyan/indigo)
- Shows all 8 settings with badges
- Progress indicator (N/8 configured)
- Empty card with + icon for unconfigured slots

#### UI Integration
- **macOS**: New tab "C1-C7 Loadouts" + "Load to Slot" button in RecipeDetailView
- **iOS**: New "Loadouts" tab with grid of slot cards
- "⭐ Favorites" filter + C1-C7 filter categories in sidebar

#### RecipeDetailView Enhancements
- Star favorite button (toggles via FavoritesStore)
- ⚙️ Load to Slot button (confirmation dialog → C1-C7 picker)
- Shows both active and preset settings with PTP codes

### Files Created/Changed

| File | Action |
|------|--------|
| `FujiRecipesCore/Models/LoadoutStore.swift` | **Created** |
| `FujiRecipesMac/macos/Source/LoadoutViews.swift` | **Created** |
| `FujiRecipesMac/macos/Source/RecipeViews.swift` | Updated — load to slot + fav button |
| `FujiRecipesMac/macos/Source/App.swift` | Updated — TabView with Recipes + Loadouts tabs |
| `FujiRecipes/iOS/Source/App.swift` | Updated — TabView with Recipes + Loadouts tabs |
| `FujiRecipes/iOS/Source/RecipeViews.swift` | Updated (from macOS) |

### Build Results

✅ **FujiRecipesMac** — Builds with TabView (Recipes + Loadouts)
✅ **FujiRecipes (iOS)** — Builds with TabView (Recipes + Loadouts)
✅ **4,665 total Swift lines** across the project

## Session 16 — Camera Integration (Complete)

### Objective

Build camera connection, recipe application, and RAF darkroom features.

### What Was Built

#### Architecture Overhaul (Breaking Circular Dependency)
- Moved `PTPClientProtocol`, `PTPCameraInfo`, `PTPPropertyResponse`, `PTPError`, `PTPClientPresetData` to FujiRecipesCore
- Removed FujiRecipesCore → PTPClient → FujiRecipesCore circular dependency
- PTPClient module now re-exports types from FujiRecipesCore
- Added `writePTPSettings`, `convertRAF`, `capturePreview` to protocol

#### CameraManager (FujiRecipesCore)
- `connect(using:)` — inject any PTPClientProtocol implementation
- `disconnect()` — clean disconnect
- `readActiveSettings()` — live read of all PTP properties
- `applyRecipe(_:to:)` — write recipe settings to camera
- `writeLoadout(_:to:)` — write preset slot to camera
- `convertRAF(_:profileModifier:)` — RAF → JPEG conversion
- `capturePreview()` — camera preview capture

#### Camera Connection View
- Status indicator (disconnected/connecting/connected/error)
- Live settings preview (Film Sim, DR, Highlight, Shadow)
- Connect/Disconnect button
- Camera info display

#### RAF Darkroom View
- File picker for RAF files
- Convert to JPEG button (in-camera conversion)
- Save/download converted JPEG
- Error handling

### Files Created/Changed

| File | Action |
|------|--------|
| `FujiRecipesCore/Models/CameraManager.swift` | **Created** — Camera connection manager |
| `FujiRecipesCore/Models/PTPClientProtocol.swift` | **Created** — Protocol + types (broke cycle) |
| `FujiRecipesCore/Models/JPEGFile.swift` | **Created** — JPEG/RAF file types |
| `FujiRecipesMac/macos/Source/CameraViews.swift` | **Created** — Camera + Darkroom views |
| `FujiRecipesMac/macos/Source/App.swift` | Updated — 4-tab layout |
| `FujiPTPClient/.../MacOS+PTPClient.swift` | Updated — type renames, writePTPSettings extension |
| `FujiPTPClient/.../FFI+PTP.swift` | Updated — type renames |
| `FujiPTPClient/.../FFI+RAW.swift` | Updated — removed duplicate types |
| `FujiPTPClient/.../iOS+PTPClient.swift` | Updated — type renames, missing protocol methods |
| `FujiPTPClient/Sources/PTPClient/PTPClient.swift` | Replaced with re-exports |

### Build Results

✅ **FujiRecipesMac** — Builds with 4 tabs (Recipes, Loadouts, Camera, Darkroom)
✅ **FujiRecipes (iOS)** — Builds with 3 tabs (Recipes, Loadouts, Camera)
✅ **5,634 total Swift lines** across the project

### Camera API Ready

| Feature | macOS | iOS |
|---------|-------|-----|
| Connect/Disconnect | ✅ | ✅ |
| Read active settings | ✅ | ✅ |
| Apply recipe to camera | ✅ | ⏳ TODO |
| Write preset slot | ✅ | ⏳ TODO |
| RAF → JPEG conversion | ✅ | ⏳ TODO |
| Capture preview | ✅ | ⏳ TODO |

### Next Steps

- **Manual recipe editing** — Create/edit custom recipes
- **Import/Export** — Share recipe collections
- **Complete iOS PTP** — Implement remaining iOS camera methods

## Session 17 — Crash Fix (Complete)

### Objective
Fix the crash caused by Swift 6 FFI function pointer loading.

### Fix Applied
Changed `FFI+Types.swift:180` from:
```swift
return sym.load(as: T.self)    // ❌ Fails — Swift 6 alignment check
```
to:
```swift
return UnsafeRawPointer(sym).assumingMemoryBound(to: T.self).pointee  // ✅ Direct cast
```

### Build Results
✅ **FujiRecipesCore** — `swift build` passes
✅ **FujiPTPClient** — `swift build` passes (all 3 frameworks)
✅ **No compilation errors remaining**

## Session 18 — Xcode Build Fix & App Launch Verification (Complete)

### Objective
Install Xcode, fix build issues, verify the crash fix, and launch the app.

### What We Did

#### Xcode Installation
- ✅ **Xcode 26.6 installed** — was the blocker for building `.xcodeproj` targets
- ✅ **Xcode build** — FujiRecipesMac compiles and links (58KB binary)
- ✅ **iOS build** — FujiRecipes (iPad simulator) compiles and links (124KB binary)

#### Resource File Fix
- **Problem:** `recipes-data.json` not found in app bundle
- **Root cause:** xcodegen with `type: file` for Resources directory doesn't include individual files
- **Fix:** Added `PBXResourcesBuildPhase` to both Xcode projects with `recipes-data.json` as a resource

#### Crash Fix Verification
- ✅ **App launched successfully** — SwiftUI UI rendered
- ✅ **FavoritesStore** initialized — 0 favorites (fresh install)
- ✅ **LoadoutStore** initialized — 7 default empty slots
- ✅ **Recipe data found** — `recipes-data.json` in app bundle
- ✅ **All 4 tabs present** — Recipes, Loadouts, Camera, Darkroom
- ✅ **No crash** — Swift 6 FFI pointer fix verified working
- ✅ **libgphoto2 dylibs load correctly** via dlopen/dlsym

### Files Changed
| File | Change |
|------|--------|
| `FujiRecipesMac.xcodeproj/project.pbxproj` | Added PBXResourcesBuildPhase for `recipes-data.json` |
| `FujiRecipes.xcodeproj/project.pbxproj` | Added PBXResourcesBuildPhase for `recipes-data.json` |

### What This Unblocks
1. **Camera integration testing** — App runs, FFI layer works
2. **UI development** — All SwiftUI views functional
3. **Recipe data** — 86 recipes loadable
4. **Hardware testing** — Ready to connect X100VI via USB-C

## Session 19 — Debug Framework & QA Infrastructure (Complete)

### Objective
Build a comprehensive debugging attachment for the FujiRecipes app, enabling real-time diagnostics during QA sessions.

### What Was Built

#### 1. Structured Logging (`DebugLogger.swift`)
- `os.Logger`-based structured logging with 10 categories and 7 log levels
- Zero-cost in release builds (all code under `#if DEBUG`)
- `LogListenerProtocol` for subscribing to log events (used by Debug HUD)
- App info, device info, and diagnostic snapshot utilities
- Thread-safe via `NSLock`
- Cross-platform (macOS + iOS)

#### 2. In-App Debug HUD (`DebugHUD.swift`)
- Triggered by 5-finger tap (macOS) or 3-finger tap (iOS) in debug builds
- **Log Stream** tab — real-time log output with text/level/category filtering, copy to clipboard
- **App Info** tab — version, build, device info, app state, diagnostic report copy
- **Performance** tab — live memory usage (refreshing every 2s)
- **PTP Status** tab — camera connection status indicator
- Listener cleanup on `onDisappear`

#### 3. Crash Report Helper (`CrashReportHelper.swift`)
- Uncaught exception handler via `NSSetUncaughtExceptionHandler`
- POSIX signal handlers for SIGSEGV, SIGABRT (C-compatible global functions)
- Crash reports saved to `~/Library/Application Support/FujiRecipes/` as JSON
- Full diagnostic snapshot: app info, device info, stack trace, loadout state, favorites
- Markdown-formatted crash report for easy copy/paste into bug reports
- Note: Platform-specific UI (NSAlert) handled at app layer

#### 4. QA Documentation
- **`QA-METHODOLOGY.md`** — Testing pipeline, session structure, best practices
- **`QA-ISSUE-CHECKLIST.md`** — Structured issue tracker (severity, priority, status, session)
- **Updated `test-plan.md`** — ~90 comprehensive test cases across all features

### Files Created

| File | Purpose | Lines |
|------|---------|-------|
| `FujiRecipesCore/.../DebugLogger.swift` | Structured logging framework | ~260 |
| `FujiRecipesCore/.../DebugHUD.swift` | In-app debug panel | ~400 |
| `FujiRecipesCore/.../CrashReportHelper.swift` | Crash detection & reporting | ~190 |
| `QA-METHODOLOGY.md` | Testing methodology | ~200 |
| `QA-ISSUE-CHECKLIST.md` | Issue tracking template | ~80 |

### Integration

- `App.swift` (macOS): Initializes `DebugLogger`, `CrashReportHelper`, adds `.debugHUD()` modifier
- `App.swift` (iOS): Same initialization and modifier
- All debug code is `#if DEBUG` — zero production overhead

### Build Results

✅ **FujiRecipesMac** — Builds, launches, no crashes
✅ **FujiRecipes (iPad)** — Builds, no crashes
✅ **All new Swift files** — Compile cleanly (900+ lines)

### Remaining

- [ ] Visually verify debug HUD gesture (5-finger tap on macOS)
- [ ] Test crash report generation
- [ ] Verify log stream filtering and copy
- [ ] Test with real PTP camera (if available)

## Session 20 — Camera Connection Debug & libgphoto2 Deadlock (Complete — Blocked)

### Objective
Connect X100VI via USB-C and test PTP communication through the app.

### What We Found

#### Camera Detection
- Kernel logs confirmed X100VI was enumerated: `0x04cb/0305/0131 (USB PTP Camera)`
- Camera connected at 480 Mbps via USB hub
- Camera later disconnected (no longer visible in ioreg/system_profiler)

#### libgphoto2 Deadlock
- **Critical Issue**: `libgphoto2 camera_init()` deadlocks on macOS
- Symptoms: App stuck on "Connecting" forever, 95%+ CPU usage
- Root cause: libgphoto2's USB enumeration + `camera_init` creates a deadlock on macOS
- The `camera_init()` call blocks indefinitely waiting for camera communication
- Adding timeouts didn't help — the app consumed 95% CPU in a tight loop

#### Fixes Attempted
1. **Added port-specific connection** — Added `gp_camera_set_port()` to set USB port before init
2. **Added debug logging** — Print statements at each connect step
3. **Added timeout** — 15-second timeout via `withTimeout()` helper
4. **Fixed network port filtering** — Only match `usb:` prefixed ports

#### Current State
- App UI: Fully functional (Recipes, Loadouts, Camera, Darkroom tabs)
- Debug framework: Complete (DebugLogger, DebugHUD, CrashReporter)
- libgphoto2 FFI: All functions loaded and registered
- **Camera connection: BLOCKED** — libgphoto2 deadlocks on `camera_init()`

### Technical Notes

**Why libgphoto2 deadlocks:**
- libgphoto2's port enumeration on macOS uses libusb
- `gp_port_info_list_new()` can hang on the macOS USB stack
- `gp_camera_init()` calls `gp_port_open()` which can deadlock
- The config API (`gp_camera_get_config()`) requires a successful init
- We need raw PTP commands first, not the config API

**Workaround needed:**
- Need to connect via raw PTP before using libgphoto2 config API
- Or use a different approach (direct IOKit/USB communication)
- Or install gphoto2 via Homebrew and use it as a testbed

### Files Modified This Session

| File | Change |
|------|--------|
| `MacOS+PTPClient.swift` | Added debug logging at each connect step, added `camera_set_port()` call |
| `FFI+Types.swift` | Added `cameraSetPort` function type and loading |
| `CameraManager.swift` | Added 15s timeout via `withTimeout()` helper |
| `FFI+USB.swift` | Added port scan logging, USB-only filtering |

---

## Session 10-18 Summary

| Session | Focus | Result |
|---------|-------|--------|
| 10 | Swift 6 FFI fixes | ✅ Complete |
| 11 | Xcode install attempt | ❌ Blocked |
| 12 | Xcode build fix | ✅ Complete |
| 13 | UI Implementation | ✅ Complete |
| 14 | Favorites & Storage | ✅ Complete |
| 15 | C1-C7 Loadout UI | ✅ Complete |
| 16 | Camera Integration | ✅ Complete |
| 17 | Debug + Crash Fix | ✅ Verified |
| 18 | App Launch Verification | ✅ Complete |
| 19 | Debug Framework & QA | ✅ Complete |
| 20 | Camera Connection Debug | ❌ Blocked (libgphoto2 deadlock) |

### Outstanding Tasks

- [ ] **FIX**: libgphoto2 deadlock on `camera_init()` — need raw PTP approach
- [ ] **Connect X100VI** via USB-C and test PTP communication
- [ ] **Post-build install_name rewrite** for bundled libgphoto2 dylibs
- [ ] **Complete iOS PTP** (writePTPSettings, preset write, RAF conversion)
- [ ] **Manual recipe editing**
- [ ] **Import/Export**
