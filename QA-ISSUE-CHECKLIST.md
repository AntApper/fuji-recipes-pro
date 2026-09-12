# FujiRecipes — QA Issue Checklist

> **How to use:** Add new issues as you encounter them. Update status as they're fixed.
> 
> **Statuses:** 🟡 Open | 🔧 In Progress | ✅ Fixed | 📋 Verified | ❌ Deferred | ⏸️ Needs Hardware

---

## Session 19 — Debug Framework & QA Infrastructure (2026-07-04)

### New Infrastructure Created

| # | Severity | Priority | Status | Description | Session | Fix |
|---|----------|----------|--------|-------------|---------|-----|
| 1 | 🟢 | P3 | ✅ Done | Structured logging framework (`DebugLogger`) | 19 | Created `DebugLogger.swift` |
| 2 | 🟢 | P3 | ✅ Done | In-app Debug HUD panel (`DebugHUDView`) | 19 | Created `DebugHUD.swift` with 4 tabs |
| 3 | 🟢 | P3 | ✅ Done | Crash report helper (`CrashReportHelper`) | 19 | Created `CrashReportHelper.swift` |
| 4 | 🟢 | P3 | ✅ Done | QA testing methodology documentation | 19 | Created `QA-METHODOLOGY.md` |
| 5 | 🟢 | P3 | ✅ Done | QA issue checklist template | 19 | Created `QA-ISSUE-CHECKLIST.md` |
| 6 | 🟢 | P3 | ✅ Done | Comprehensive test plan (~90 test cases) | 19 | Updated `test-plan.md` |
| 7 | 🟡 | P2 | ⏳ TODO | Debug HUD gesture not verified visually | 19 | 5-finger tap on macOS | |

### Build Fixes During Implementation

| # | Severity | Priority | Status | Description | Session |
|---|----------|----------|--------|-------------|---------|
| 1 | 🟠 | P1 | ✅ Fixed | `[String: Any]` not Codable → changed to `[String: String]` | 19 |
| 2 | 🟠 | P1 | ✅ Fixed | `deinit` not allowed in Swift 6 structs → used `onDisappear` | 19 |
| 3 | 🟠 | P1 | ✅ Fixed | Signal handlers can't capture context → global functions | 19 |
| 4 | 🟡 | P2 | ✅ Fixed | `_enabled` private access → made internal | 19 |
| 5 | 🟡 | P2 | ✅ Fixed | `Section(title:)` → `Section("title")` | 19 |
| 6 | 🟡 | P2 | ✅ Fixed | `VStack(spaced:)` → `VStack(spacing:)` | 19 |
| 7 | 🟡 | P2 | ✅ Fixed | `VStack(aligned:)` → `VStack(alignment:)` | 19 |
| 8 | 🟡 | P2 | ✅ Fixed | iOS `List` API differs from macOS | 19 |

---

## Session 21 — macOS PTPCamera Fix & Camera Connection (2026-07-04)

### Issues Found

| # | Severity | Priority | Status | Description | Session | Fix |
|---|----------|----------|--------|-------------|---------|-----|
| 1 | 🔴 | P0 | ✅ Fixed | **libgphoto2 `camera_init()` deadlocks on macOS** — app stuck at 95% CPU | 21 | Kill PTPCamera daemon + raw PTP fallback |

### Root Cause
macOS has a built-in `PTPCamera`/`ptpcamerad` daemon (ImageCaptureCore) that automatically claims USB PTP cameras. When this daemon holds the USB interface, libgphoto2's `libusb_claim_interface()` fails with "Access denied" and `camera_init()` deadlocks.

### Fixes Applied
| # | Fix | File |
|---|-----|------|
| 1 | Created `MACameraUtils` for PTPCamera process management | `FFI+MACCamera.swift` |
| 2 | Rewrote `connect()` with PTPCamera killing + raw PTP fallback | `MacOS+PTPClient.swift` |
| 3 | Moved `withTimeout()` to shared utility | `TimeoutHelper.swift` |
| 4 | Created comprehensive test script | `tools/test-camera-connection.sh` |
| 5 | Created camera connection guide | `docs/camera-connection-guide.md` |

### Connection Flow (New)
```
Kill PTPCamera → libgphoto2 init → scan USB → create camera → try camera_init() (15s)
    ↓ success                          ↓ timeout
Full libgphoto2 mode               Raw PTP fallback
                                     ↓ success
                               Raw PTP mode (C1-C7 works)
```

### Key Findings
- macOS PTPCamera daemon is the root cause of all camera connection failures
- `killall PTPCamera` is the required workaround
- Raw PTP mode (via port I/O) works independently of `camera_init()`
- Raw PTP mode supports preset slot read/write (0xD18C-0xD1A5)
- Build: ✅ All targets compile and app launches

---

## Session 20 — Camera Connection Debug & libgphoto2 Deadlock (2026-07-04)

### Issues Found

| # | Severity | Priority | Status | Description | Session | Fix |
|---|----------|----------|--------|-------------|---------|-----||
| 1 | 🔴 | P0 | ✅ Moved to 21 | libgphoto2 `camera_init()` deadlocks on macOS | 20 | Fixed in Session 21 |
| 2 | 🟡 | P2 | ✅ Verified | Camera not showing in ioreg/system_profiler — likely disconnected | 20 | Check USB-C cable |
| 3 | 🟡 | P2 | ✅ Fixed | Port scan returning network ports — fixed to USB-only | 20 | Filter `usb:` prefix |
| 4 | 🟢 | P3 | ✅ Fixed | Added timeout to connect function | 20 | `withTimeout()` helper |
| 5 | 🟢 | P3 | ✅ Fixed | Added debug logging at each connect step | 20 | Print statements |
| 6 | 🟢 | P3 | ✅ Fixed | Added `gp_camera_set_port()` call before init | 20 | FFI + code |

### Key Findings (moved to Session 21)
- Kernel logs confirmed X100VI was enumerated (`0x04cb/0305/0131`) at 480 Mbps
- libgphoto2's `camera_init()` call hangs indefinitely on macOS
- App consumes 95%+ CPU when stuck — not sleeping, actively spinning
- Root cause: macOS PTPCamera daemon blocking USB access
- Solution: Kill PTPCamera + raw PTP fallback mode

---

## Session 18 — Xcode Build & App Launch (2026-07-04)

### Issues Found

| # | Severity | Priority | Status | Description | Session | Fix |
|---|----------|----------|--------|-------------|---------|-----|
| 1 | 🔴 | P0 | ✅ Verified | Swift 6 FFI crash — `sym.load(as:)` alignment failure | 17 | `UnsafeRawPointer(sym).assumingMemoryBound(to: T.self).pointee` |
| 2 | 🟠 | P1 | ✅ Verified | Recipe data JSON not found in app bundle | 18 | Added PBXResourcesBuildPhase to both projects |
| 3 | 🟡 | P2 | ✅ Verified | Workspace couldn't load (xcodebuild path issue) | 18 | Built individual projects directly |

---

## Session [N] — [Description] ([Date])

> Add new sessions here. See `QA-METHODOLOGY.md` for format.

### Issues Found

| # | Severity | Priority | Status | Description | Session | Fix |
|---|----------|----------|--------|-------------|---------|-----|
| | | | | | | |

---

## Historical Issues (Closed)

| # | Severity | Priority | Description | Fixed In Session | Resolution |
|---|----------|----------|-------------|-----------------|------------|
| — | — | — | — | — | — |

---

## Summary

| Status | Count |
|--------|-------|
| 🟡 Open | 1 |
| 🔧 In Progress | 0 |
| ✅ Fixed | 6 |
| 📋 Verified | 3 |
| ❌ Deferred | 0 |
| ⏸️ Needs Hardware | 0 |

---

*Last updated: Session 21 (2026-07-04)*
