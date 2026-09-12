# Agents.md — FujiRecipes Research

## Project Overview
FujiRecipes is a cross-platform app (macOS + iOS) that connects to Fujifilm X100VI cameras via USB-C PTP to read/write camera settings, apply recipes, and convert RAF files.

## Architecture
- **FujiRecipesCore** — Shared Swift module (models, stores, utilities)
- **FujiPTPClient** — PTP client library
  - **GPhoto2CLI** — gphoto2 CLI wrapper
  - **GPhoto2PTPClient** — PTPClientProtocol implementation using GPhoto2CLI
  - **X100VIHelper** — Standalone C helper via libusb

## Session 2026-07-07 — Codebase hardening & architecture cleanup

A systematic audit and cleanup pass was performed across `FujiRecipesCore`,
`FujiPTPClient`, `FujiRecipesMac`, and the iOS app sources.  No camera was
connected for this pass; changes are compile-verified only.

### Critical fixes

1. **`TimeoutHelper` double-resume crash.**  Replaced the continuation-based
   race with `withThrowingTaskGroup`, cancelling the loser and avoiding any
   possibility of resuming a continuation twice.

2. **`X100VIHelperClient` hung forever on the second command.**  The code used
   `readDataToEndOfFile()` on a long-lived helper's stdout.  Replaced with a
   line-delimited `AsyncThrowingStream` reader and a serial request-processor
   that guarantees request/response ordering.

3. **`FujiPTPHelper` stdin/protocol fixes.**  `main.swift` now reads stdin
   line-by-line instead of `readDataToEndOfFile()`, and JSON numeric casts
   no longer assume Swift unsigned types bridge from `JSONSerialization`.

4. **`MacOS+PTPBridge` dispatch-source read blocked.**  The `DispatchSourceRead`
   handler used `readDataToEndOfFile()`; switched to `availableData` so the
   bridge actually processes incremental responses.

5. **`DebugLogger` deadlock + MainActor violations.**  Listeners are now held
   weakly and notified without holding the lock, dispatched to the main actor
   so SwiftUI view models can safely update `@Published` state.

6. **Signal-unsafe crash handler removed.**  `CrashReportHelper.setup()` no
   longer installs `SIGSEGV`/`SIGABRT` handlers; capturing a full JSON report
   from a signal context is async-signal-unsafe.  The `NSException` handler
   remains.

7. **`CameraManager` concurrency/protocol mismatches.**
   - Removed unsafe `withUnsafeThrowingContinuation` + `Task.detached` from
     `convertRAF`.
   - `disconnect()` is sync; removed erroneous `await` calls.
   - `readCStates()` no longer fabricates empty preset data on read errors.
   - `importRecipeToCState()` and `writeLoadout()` write full field sets and
     use `WhiteBalanceMode.actualPTPValue` for writes.

8. **`PTPClientProtocol.writeProperty` signed-value API.**  Changed from
   `UInt32` to `Int32` so negative tone/shift settings (highlight/shadow/color,
   WB shifts, sharpness, clarity) can be written correctly.  Updated all
   implementations (`X100VIHelperClient`, `MacOSSession`, `GPhoto2PTPClient`,
   `IOSSession`, `FujiPTPHelper`).

### Architecture / duplication cleanup

9. **Removed duplicate `GPhoto2CLI`/`X100VIHelper` targets from `FujiRecipesMac`.**
   The macOS app now depends on the canonical `FujiPTPClient` package products,
   and `X100VIHelper` was promoted to a proper library product.

10. **Removed shadowed iOS `FavoritesStore`.**  The iOS app target had an
    internal `FavoritesStore` identical to the one in `FujiRecipesCore`; it has
    been deleted so the shared store is used consistently.

### Other notable fixes

11. **`WhiteBalanceMode` write collision.**  `CameraManager` now writes the WB
    mode via `actualPTPValue` (e.g. tungsten → 6) instead of the enum `rawValue`.

12. **`GPhoto2Wrapper` config-widget leaks.**  `gphoto2_get_config_value` and
    `gphoto2_set_config_value` now call `gp_widget_unref(config)` on every path.

13. **`GPhoto2CLI` no longer hard-codes `/opt/homebrew/bin/gphoto2`.**  It now
    searches common Homebrew locations and falls back to `PATH`.

14. **`FujiPTPClient/Package.swift` libgphoto2 paths.**  Linker/library search
    paths now use the version-agnostic `/opt/homebrew/lib` and `/usr/local/lib`
    symlinks instead of a pinned Cellar version, with `/usr/local` fallback.

15. **macOS darkroom progress is no longer fake.**  The simulated 5 s loop was
    replaced by an indeterminate progress indicator while the real
    `CameraManager.convertRAF` runs.

16. **iOS recipe-list modifier placement fixed.**  `.searchable`,
    `.navigationTitle`, and `.onAppear` are now attached to the `List` rather
    than inside the `ForEach`.

17. **iOS "Load to slot" confirmation dialog now applies the recipe.**  The
    action was previously wired to `.onSubmit` on a `ScrollView` and rarely
    fired.

18. **iOS entitlements and Info.plist cleaned up.**  Removed the incorrect
    `com.apple.security.device.camera` entitlement and added photo-library
    usage strings for saving converted JPEGs.

19. **Shared `RecipeLoader` extracted into `FujiRecipesCore`.**  The macOS and
    iOS app targets no longer duplicate the JSON parsing structs and mapping
    logic; both call the shared loader and now surface load failures via a
    published error property.

20. **Dead iOS views removed.**  Unused `RecipeListView`, `RAFDarkroomView`,
    and `CameraSettingsView` were deleted from the iOS target.

21. **FFI function-pointer loading fixed.**  `FFI+Types.swift` now uses
    `unsafeBitCast` instead of `assumingMemoryBound(to:).pointee` when loading
    libgphoto2 symbols.

22. **`GPhoto2PTPClient.convertRAF` no longer pretends to work.**  It now
    throws a clear unsupported-backend error instead of invoking the
    non-existent `gphoto2 --upload` command.

## Session 2026-07-05 — Real Protocol Bugs Found & Fixed (camera-verified live)

**Camera connected live via USB-C, tested directly against `poc-x100vi-reader/x100vi_helper`.**

### 🎯 Two real bugs found and fixed in `x100vi_helper.c`

1. **`write_prop()` sent a malformed PTP DATA container.** It reserved 4 extra
   bytes in the header as if a parameter belonged in the DATA phase
   (`headerLen = 12 + 1*4`), but PTP DATA containers carry **no parameters**
   — only a 12-byte header (length+type+code+transid) followed directly by
   the payload. This shifted the actual value out of what the camera parses.
   **Effect after fix:** D18C (preset slot) write went from `0x2019
   DeviceBusy` → `0x2001 OK`. This bug affected every property write in the
   helper (`write_prop_u16`/`write_prop_u32`), not just D18C.

2. **`read_prop()` only extracted a value when the DATA payload was ≥4 bytes**
   (`if (len >= 16)`), but most Fuji vendor properties (D18C–D1A5 etc.) are
   **UINT16 (2-byte)** values — actual DATA container length is 14 bytes
   (12-byte header + 2-byte payload). Every 2-byte property therefore always
   read back as `0`, regardless of what was actually stored on the camera.
   This is why **all preset-slot reads always showed zeros** even after
   successful-looking writes. Fixed to size the extraction to the actual
   payload length (1/2/4 bytes).

3. **D18C also required a 4-byte write**, not the 2-byte write the
   `read_preset_slot`/`write_preset_slot` handlers were using — the 2-byte
   write was silently rejected (`0x201C InvalidDevicePropValue`) for most
   values. Switched both call sites to `write_prop_u32` and now surface the
   slot-select return code as `slot_select_rc` in the JSON response.

### ✅ Confirmed working now (previously appeared totally broken)
- Property writes for the preset range (D190–D1A5) now **persist and
  read back correctly** with real, non-zero values (film simulation,
  dynamic range, grain effect, white balance, WB shift, sharpness, etc. all
  round-tripped correctly in live testing).
- D18C slot-select write no longer errors (`0x2001 OK` for values 0–10+).

### ❌ New blocker discovered — presets are NOT independently stored per slot
Writing `write_preset_slot(index=1, film_simulation=3)` then
`write_preset_slot(index=2, film_simulation=7)` and reading back **slot 1**
afterward shows `film_simulation=7` — the value from the slot-2 write. All
slots read back **identical, whatever was written last**, regardless of the
D18C value. This means:
- D190–D1A5 behave like a single shared "live/staging" register mirroring
  current settings, not 7 independently addressable preset stores, OR
- there's a missing "commit to slot N" step (a distinct vendor command) that
  actually persists the staged values into custom slot storage, which we
  have not yet identified.
- `0xD185` (native profile blob) still returns `0x2002 GeneralError` when
  read without a RAF loaded first (matches prior finding) — has not yet been
  tried as the possible actual per-slot storage format.

### Also re-confirmed (with camera live)
- **libgphoto2 exposes almost nothing for this camera in this mode** — only
  `/main/actions/*` and `/main/status/*` (8 config entries total), no
  `/main/settings/*` tree at all. The previously-written "Option A"
  (`LIBGPHOTO2_PRESET_FIX.md`) config-path approach **cannot work** as
  designed: confirmed via `gphoto2 --list-all-config` against the live
  camera. Root cause: libgphoto2's camera list registers X100VI with
  capability flags `0` (no `PTP_CAP`), and the device's own `GetDeviceInfo`
  doesn't advertise the Fuji vendor settings properties in the current mode,
  so `have_prop()` gates them out of the config tree entirely. The raw-PTP
  `x100vi_helper` (libusb) approach remains the only viable path for preset
  access; libgphoto2 is fine for basic connect/summary but not presets.
- `0xD15D` (SetUSBMode) write still returns `0x200A` — confirmed via
  `gphoto2 --list-all-config`/summary that it's genuinely absent from the
  camera's supported-properties list in this mode (not a helper bug).
- Camera enumerates and connects **without sudo** via both gphoto2 CLI and
  the libusb helper on this machine (USB PTP Camera @ usb:005,003).
- `ptpcamerad` (macOS PTP LaunchAgent) auto-respawns on device (re)attach
  and grabs the USB interface; `sudo launchctl bootout` is blocked by SIP.
  Workaround: `killall -9 ptpcamerad` immediately before each gphoto2/helper
  invocation (there's a short window before it reclaims the device).

### 📋 Recommended next step
Guessing further at the slot-commit mechanism by trial and error has
diminishing returns. The highest-leverage next action is a **USB packet
capture of a known-working app** (FilmKit via a browser's WebUSB debug
tools, or the native Fuji Recipes iOS/Android app via a USB proxy) against
this exact camera to see the literal byte sequence used to persist a named
preset into C1–C7, then replay that exact sequence in `x100vi_helper`.
macOS Wireshark can capture raw USB traffic on the `XHC*`/`USB*` pseudo-
interfaces (`tshark -D` to list) without needing a kernel extension beyond
what ships in recent macOS.

## Current Status (Updated 2026-07-04 ~23:45 UTC, camera-tested)

### ✅ Working (camera-verified on X100VI)
- **OpenSession** — Returns OK (0x2001) or SessionAlreadyOpen (0x201D)
- **Property reads** — Preset props (0xD18C–0xD1A5) read OK in USB RAW mode
  - Active props (0xD001, 0xD007) return 0x200A (DevicePropNotSupported) in USB RAW mode
- **Property writes** — No device stall for valid writes (D18E-D1A5)
- **PTP container format** — FilmKit-compatible (little-endian), verified byte-by-byte
- **RAF loading (vendor commands)** — ✅ FULLY WORKING
  - SendObjectInfo (0x900C): OK (0x2001) — **82-byte ObjectInfo** (fixed from 78, missing ImageBitDepth)
  - SendObject2 (0x900D): OK (0x2001) — 87.4MB in 167 chunks, zero stalls
  - Foreign RAF rejected with 0x2015 (correct behavior)
  - Protocol matches FilmKit (WebUSB) and rawji (PyUSB) exactly
- **Reconnect workaround** — ✅ WORKS (close→2s→open→endpoint clear→OpenSession)
  - Restores IN endpoint after large vendor transfer (macOS libusb limitation)
  - Small reads work after reconnect (property reads, GetObjectHandles)
  - **Large DATA reads FAIL** (profile 0xD185 returns LIBUSB_ERROR_IO -2)
- **Conversion trigger (0xD183)** — Returns OK (0x2001) — value=0 (FilmKit) and value=1 (rawji) both accepted
- **Set profile (0xD185)** — Accepts 632-byte rawji-standard-format profile (0x2001)
- **Swift integration** — All pipeline methods implemented in X100VIHelperClient

### 🔧 Fixes Applied (camera-verified)
1. **Conversion trigger value** — value=0 (FilmKit) and value=1 (rawji) both return OK on X100VI
2. **Post-upload delay** — 1s delay + no clear_endpoint_halt prevents stuck state ✅ VERIFIED
3. **Pre-poll delay** — 2s delay after trigger before first GetObjectHandles poll
4. **D18C slot delay** — 100ms after slot selection (matches FilmKit)
5. **ObjectInfo fix** — Added missing ImageBitDepth field (78→82 bytes) ✅ VERIFIED
6. **Reconnect delay** — Increased to 2s close→open + 2s settle after OpenSession

### ❌ Confirmed Blockers (macOS libusb)
1. **D185 profile read after RAF upload** — IN endpoint breaks for large DATA reads
   - Small reads work (property reads, GetObjectHandles)
   - Large reads fail with LIBUSB_ERROR_IO (-2) regardless of delay (tested up to 185s)
   - Profile read BEFORE upload returns 0x2002 (WrongParameters — no RAF loaded)
   - FilmKit/rawji don't have this issue (WebUSB/PyUSB don't break IN endpoint)
2. **D18C slot selector write** — Always returns 0x2019 (DeviceBusy) on libusb
   - Fuji Recipes (native iOS/Android app) works with D18C on X100VI
   - FilmKit (WebUSB) works with D18C on X100VI
   - Root cause: macOS libusb incompatibility with D18C (transaction ID? session state? timing?)
3. **Conversion result delivery** — GetObjectHandles never returns results on X100VI
   - Tested with: value=0 (FilmKit), value=1 (rawji), with/without profile write
   - Profile write accepted (0x2001) but no result via GetObjectHandles
   - **X100VI may use different result delivery** (LCD display, PTP events, SD card)
   - Camera LCD not checked during tests (need physical inspection)

### ✅ C Helper Commands
| Command | Purpose | Status |
|---------|---------|--------|
| `connect` / `disconnect` | USB + OpenSession | ✅ |
| `reconnect` | Close→open→OpenSession (macOS fix) | ✅ |
| `read_property` | Read device property | ✅ |
| `write_property` | Write device property (uint32) | ✅ |
| `read_preset_slot` | Read all preset props for a slot | ⚠️ D18C write fails (0x2019) |
| `write_preset_slot` | Write preset props to a slot | ⚠️ D18C write fails (0x2019) |
| `load_raf` | Upload RAF via vendor commands | ✅ |
| `get_profile` | Read 0xD185 native profile | ❌ LIBUSB_ERROR_IO after upload |
| `set_profile` | Write 0xD185 native profile | ✅ |
| `trigger_conversion` | Set 0xD183 to start conversion | ✅ |
| `wait_result` | Poll GetObjectHandles→GetObject→DeleteObject | ✅ (polling works, no results) |
| `convert_raf` | Full pipeline with auto-reconnect | ❌ fails at profile read |

### ⚠️ X100VI-Specific Issues (camera-tested)

**Conversion result delivery — X100VI does not return results via GetObjectHandles:**
- RAF upload: ✅ OK (0x2001)
- Reconnect: ✅ OK (small reads work)
- Profile write (from-scratch 632-byte rawji format): ✅ OK (0x2001)
- trigger_conversion: ✅ OK (both value=0 and value=1)
- GetObjectHandles polling: ❌ Never returns results (30s tested, 0 handles)
- **Camera LCD not checked** — may display JPEG instead of exposing via PTP
- **SD card not checked** — may save JPEG directly to card

**D18C slot selector — 0x2019 DeviceBusy on libusb:**
- Write with uint16 returns 0x2019 (DeviceBusy)
- Write with uint32 returns 0x200A (NotSupported) — wrong data size
- Fuji Recipes (native iOS/Android) works — uses platform-native USB APIs
- FilmKit (WebUSB) works — browser USB API
- All preset slots return identical data (all zeros on empty camera)
- D18D (PresetName) reads as 41-byte PTP string

**USBMode (0xD16E):**
- Reports value 0, not 6 (RAW Conv) or 5 (Tether Shoot)
- 0xD15D (SetUSBMode) returns 0x200A (NotSupported) — can't switch modes programmatically
- 0xD184 (IOPCodes) returns 0x200A (NotSupported)
- 0xD186 (FirmwareVersion) returns 0x200A (NotSupported)

### 📋 Verified Properties (X100VI, USB RAW mode)
| Property | Name | Read | Write | Notes |
|----------|------|------|-------|-------|
| 0xD001 | FilmSimulation | ❌ 0x200A | — | Not supported in RAW mode |
| 0xD007 | ColorTemperature | ❌ 0x200A | — | Not supported in RAW mode |
| 0xD15D | SetUSBMode | — | ❌ 0x200A | Not supported on X100VI |
| 0xD16E | USBMode | ✅ reports 0 | — | Should be 6 for RAW Conv; X100VI reports 0 |
| 0xD184 | IOPCodes | ❌ 0x200A | — | Not supported |
| 0xD185 | NativeProfile | ❌ -2 after upload | ✅ 0x2001 | LIBUSB_ERROR_IO after RAF upload |
| 0xD183 | StartRawConversion | — | ✅ 0x2001 | Both value=0 and value=1 accepted |
| 0xD18C | PresetSlot | ✅ always 0 | ❌ 0x2019 | DeviceBusy on libusb |
| 0xD18D | PresetName | ✅ 41-byte string | — | PTP string format |
| 0xD18E–0xD1A5 | Preset props | ✅ all read OK | ✅ writes OK | All zeros on empty slots |

### 🔧 Bugs Fixed
1. **Separate transfers** — COMMAND and DATA sent as distinct USB transfers
2. **Clean DATA container** — DATA has NO params, just 12-byte header + raw data
3. **512KB chunking** — Large RAF uploads chunked like FilmKit
4. **Stall recovery** — `libusb_clear_halt()` + retry on IN endpoint stalls
5. **Correct container length** — `ptp_send` sends actual size (was always 24 bytes)
6. **ObjectInfo AssociationType** — Fixed uint32→uint16 (was 86 bytes, now 82)
7. **ObjectInfo ImageBitDepth** — Added missing field in convert_raf pipeline (was 78 bytes)
8. **D18C write format** — uint32→0x200A, uint16→0x2019 (both fail on libusb)
9. **Reconnect endpoint clear** — Added `clear_endpoint_halt()` after fresh connection
10. **Response retry** — Vendor commands retry RESPONSE read once after IN stall
11. **Conversion trigger value** — value=0 (FilmKit) and value=1 (rawji) both accepted
12. **Post-upload timing** — Removed immediate `clear_endpoint_halt`, added 1s delay
13. **Pre-poll delay** — 2s delay after trigger before first GetObjectHandles poll
14. **D18C slot delay** — 100ms (matches FilmKit, was 50ms)
15. **Default d185 profile** — Built 632-byte rawji-standard-format profile from scratch

### 📋 Verified Properties (X100VI, USB RAW mode)
| Property | Name | Read | Write | Notes |
|----------|------|------|-------|-------|
| 0xD001 | FilmSimulation | ❌ 0x200A | — | Not supported in RAW mode |
| 0xD007 | ColorTemperature | ❌ 0x200A | — | Not supported in RAW mode |
| 0xD15D | SetUSBMode | — | — | fudge uses to set mode |
| 0xD16E | USBMode | ✅ reports 0 | — | Should be 6 for RAW Conv; X100VI reports 0 |
| 0xD185 | NativeProfile | ⚠️ 0x2019 | — | DeviceBusy after RAF upload |
| 0xD183 | StartRawConversion | — | ✅ 0x2001 | Trigger works, result delivery unclear |
| 0xD18C | PresetSlot | ✅ always 0 | ✅ OK but no effect | Slot never changes |
| 0xD18D | PresetName | ✅ 41-byte string | — | PTP string format |
| 0xD18E–0xD1A5 | Preset props | ✅ all read OK | ✅ writes OK | All zeros on empty slots |

### 🔧 Bugs Fixed
1. **Separate transfers** — COMMAND and DATA sent as distinct USB transfers
2. **Clean DATA container** — DATA has NO params, just 12-byte header + raw data
3. **512KB chunking** — Large RAF uploads chunked like FilmKit
4. **Stall recovery** — `libusb_clear_halt()` + retry on IN endpoint stalls
5. **Correct container length** — `ptp_send` sends actual size (was always 24 bytes)
6. **ObjectInfo AssociationType** — Fixed uint32→uint16 in `convert_raf` pipeline (was 86 bytes, now 82)
7. **D18C write format** — Changed from uint32 to uint16 (camera expects INT16)
8. **Reconnect endpoint clear** — Added `clear_endpoint_halt()` after fresh connection
9. **Response retry** — Vendor commands retry RESPONSE read once after IN stall (macOS quirk)
10. **Conversion trigger value** — Changed to `0` (FilmKit/X100VI protocol, was `1`)
11. **Post-upload timing** — Removed immediate `clear_endpoint_halt` after RAF upload, added 1s delay
12. **Pre-poll delay** — Added 2s delay after trigger before first GetObjectHandles poll
13. **D18C slot delay** — Increased to 100ms (matches FilmKit, was 50ms)

## Key Files
- `poc-x100vi-reader/x100vi_helper.c` — C helper (libusb), ~1750 lines
- `poc-x100vi-reader/VENDOR_COMMAND_DEBUG.md` — Full debugging analysis
- `FujiPTPClient/Sources/X100VIHelper/X100VIHelperClient.swift` — Swift integration
- `FujiRecipesCore/Sources/FujiRecipesCore/Models/` — Swift models

## Build
```bash
# C helper
cd poc-x100vi-reader
gcc -O2 -o x100vi_helper x100vi_helper.c -I/opt/homebrew/include -L/opt/homebrew/lib -lusb-1.0

# Swift package
cd FujiPTPClient
swift build -c release
```

## Testing
```bash
# Requires: camera in USB RAW mode, sudo pkill ptpcamerad, root for USB access
# Full camera power cycle needed between tests (camera gets stuck after upload)
cd poc-x100vi-reader
sudo bash -c 'echo "{\"id\":\"1\",\"command\":\"load_raf\",\"path\":\"/path/to/photo.RAF\"}" | ./x100vi_helper'
```

## PTP Protocol (Confirmed Working)
```
Container: length(4 LE) + type(2 LE) + code(2 LE) + trans_id(4 LE) + params/data
Types: 1=COMMAND, 2=DATA, 3=RESPONSE
PTP Strings: 1-byte char count + UCS-2LE chars (incl. null terminator)
Ops: OpenSession=0x1002, GetProp=0x1015, SetProp=0x1016
Vendor: SendObjectInfo=0x900C, SendObject2=0x900D
```

## Critical Findings

### 1. macOS libusb IN Endpoint Limitation
After large vendor transfer (83MB RAF upload), the IN endpoint (0x81) breaks.
- Standard PTP reads fail with short responses or stalls
- GetObjectHandles works fine after reconnect
- **Workaround:** `reconnect` command (close→200ms→open→endpoint clear→OpenSession)
- Works on Linux (rawji) and WebUSB (FilmKit) — macOS-specific

### 2. Transaction ID Management
- Starts at 0, increments per command (first command = 1)
- COMMAND and DATA share same transaction ID

### 3. Vendor Commands — ✅ FIXED AND VERIFIED
- 0x900C (SendObjectInfo) — ✅ OK (0x2001), 82-byte ObjectInfo accepted
- 0x900D (SendObject2) — ✅ OK (0x2001), 83.4MB uploaded, 167 chunks
- 0x902B (TetherOpen) — ⚠️ Still stalls (may not need DATA phase)
- Same-camera RAF accepted; foreign RAF → 0x2015 (ObjectNotValid)

### 4. X100VI Conversion Result Delivery (BLOCKER → NEEDS RETEST)
- RAF upload: ✅ works
- Conversion trigger: ✅ returns OK
- **Result retrieval: ❌ GetObjectHandles never returns results (with value=1 trigger)**
- X-T30/X-T4 (rawji tested) return results via GetObjectHandles with value=1 trigger
- **FilmKit (X100VI tested) uses value=0 trigger** — we may have been sending wrong value
- **Fix applied:** Changed trigger to value=0 (FilmKit protocol)
- **Fix applied:** Added 2s delay after trigger before polling (camera processing time)
- **If value=0 doesn't work:** X100VI may use PTP events, LCD display, or different mechanism
- Need to check: camera LCD for converted JPEG, PTP event endpoint, different polling

### 5. Camera State Management
- Camera enters DeviceBusy (0x2019) state after RAF upload
- **Hypothesis:** Immediate `clear_endpoint_halt(0x81)` after upload confuses camera's state machine
  - FilmKit (WebUSB) never has this issue — no endpoint clearing, natural latency provides delay
- **Fix applied:** Removed immediate clear, added 1s post-upload delay before reconnect
- **If fix doesn't work:** Requires full power cycle (USB reconnect not enough)
- Each conversion test requires: power off → power on → USB RAW mode → connect
- fudge library checks USBMode (0xD16E) == 6 before conversion; X100VI reports 0

## Next Steps

### Critical
1. **Check camera LCD / SD card after conversion** — Physical inspection needed
   - GetObjectHandles never returns results on X100VI via libusb
   - Camera may display JPEG on LCD or save to SD card instead
   - This will confirm if conversion actually happens but results use different delivery

2. **D18C slot selector — switch to libgphoto2 on macOS**
   - libusb: D18C write always returns 0x2019 (DeviceBusy)
   - libgphoto2 has Fuji vendor extension support, may handle D18C differently
   - FujiPTPClient already has MacOSSession stub with libgphoto2 FFI
   - Need: libgphoto2 static library bundling (arm64 + x86_64)

3. **iOS ImageCaptureCore PTP testing**
   - FujiPTPClient has IOSSession stub using `requestSendPTPCommand`
   - Untested on hardware — need iPhone/iPad + X100VI via USB-C
   - Fuji Recipes (native iOS app) works — may use ImageCaptureCore or private API

### Medium Priority
4. **macOS app permissions for production**
   - libusb requires `sudo`, won't work in App Store app
   - ImageCaptureCore on macOS confirmed broken for Fuji PTP (Session 4 probe)
   - Options: helper tool with privileged install, libgphoto2, or iOS-only for camera features

5. **USBMode detection** — X100VI reports 0 instead of expected 6
   - Camera accepts operations despite wrong mode — may be X100VI-specific

### Lower Priority
6. **TetherOpen (0x902B)** — Stalls on DATA phase
7. **Preset slot write verification** — Need camera with pre-configured presets

## Known Issues
1. **macOS libusb IN endpoint** — Breaks after large vendor transfers (87MB) ✅ workaround exists
2. **macOS libusb D185 read after upload** — Large DATA reads fail with LIBUSB_ERROR_IO (-2)
3. **macOS libusb D18C slot selector** — Write returns 0x2019 (DeviceBusy)
4. **X100VI conversion results** — Not delivered via GetObjectHandles (all trigger values tested)
5. **gphoto2 limitation** — No file upload API (can't do RAF upload)
6. **ptpcamerad conflict** — macOS PTP daemon grabs camera interface
7. **ImageCaptureCore on macOS** — Cannot send raw PTP to Fuji cameras (confirmed)

## Research Notes (2026-07-04 testing session)
- **FilmKit** (WebUSB, TypeScript): `eggricesoy/filmkit` — tested on X100VI, works
- **rawji** (PyUSB, Python): `pinpox/rawji` — tested on X-T30/X-T4, Linux
- **Fuji Recipes** (native iOS/Android): `fujirecipes.co` — works on X100VI, uses native USB APIs
- **fudge** (WiFi/TCP): `petabyt/fudge` — Android app, WiFi protocol
- **libfuji**: `petabyt/libfuji` — fudge's PTP library, mode detection logic
- **FujiPTPClient**: Our Swift package — libgphoto2 (macOS) + ImageCaptureCore (iOS, untested) + libusb C helper
- **Key insight**: Fuji Recipes works on iOS/Android with native USB APIs. D18C and profile reads work there. Our macOS libusb approach has fundamental limitations for D18C and large reads after vendor transfers. Production path should use libgphoto2 on macOS or native APIs on iOS.

## References
- VENDOR_COMMAND_DEBUG.md — Full debugging analysis with test results
