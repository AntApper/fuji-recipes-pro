# PTP Probe Results — Session 4 Phase 1

**Date:** 2026-07-03  
**Camera:** Fujifilm X100VI (USB-C connected, PTP mode)  
**SDK:** macOS 26.5 (CommandLineTools), Swift 6.3.3  
**Framework:** ImageCaptureCore

## Test Results

### ✅ Passed

| Test | Result |
|------|--------|
| Device detection | X100VI found via ICDeviceBrowser |
| USB connection | VID:0x4CB0 PID:0x3050 (byte-swapped from standard 0x04CB:0x0305) |
| Session open | `requestOpenSession` succeeded, `hasOpenSession: true` |
| PTP capable | `ICCameraDeviceCanAcceptPTPCommands` in capabilities |
| PTP command send | `requestSendPTPCommand` accepts raw PTP requests |

### ⚠️ Partial / Limited

| Test | Result |
|------|--------|
| Raw PTP GetDeviceInfo | Response: 12 bytes, code 0x2000 (not standard 0x2001) |
| Content enumeration | 0 storage items (Fuji doesn't expose storage via ICDevice) |
| Media files | 0 files detected |
| Battery level | `batteryLevelAvailable: false` |

### ❌ Not Working

| Test | Result |
|------|--------|
| Full GetDeviceInfo parsing | Response too short (12 bytes vs 18+ expected) |
| Device property probes (D001, D034C, etc.) | Requires working PTP — blocked |
| Slot write test | Requires working PTP — blocked |

## Key Findings

### 1. VID/PID Byte-Swapping

macOS `ICDevice.usbVendorID` and `ICDevice.usbProductID` return values in a different byte order than the standard USB VID/PID:

| Source | Vendor ID | Product ID |
|--------|-----------|------------|
| Standard USB | `0x04CB` | `0x0305` |
| `ioreg` (decimal) | 1227 | 773 |
| macOS `ICDevice` | `0x4CB0` | `0x3050` |

**Fix:** Match on multiple byte-order variants or by camera name.

### 2. Raw PTP Response Format

The raw PTP response from `requestSendPTPCommand` is **not** in standard PTP/USB format:

```
Sent:  18 bytes → 01 10 00 00 00 00 00 00 00 00 00 00 00 00 12 00 00 00
Recv:  12 bytes → 02 00 00 00 01 00 00 10 02 00 00 10
Code:  0x2000 (not 0x2001 as expected for GetDeviceInfo)
```

The response appears to be framework-transformed rather than raw PTP. This is consistent with ImageCaptureCore's design on macOS — it abstracts away the raw PTP protocol for most cameras.

### 3. Fuji X100VI Specific Limitations

Fuji cameras have known limitations with ImageCaptureCore:
- Storage is not accessible via `ICCameraDevice.contents`
- Media files are not exposed via `ICCameraDevice.mediaFiles`
- Battery status is not available via ImageCaptureCore
- Raw PTP commands may not return standard PTP responses

## Next Steps

### Option A: Full Xcode Project (Recommended)

Create a proper Xcode project with the full SDK to:
1. Use `ICCameraDevice` with proper entitlements
2. Test `requestSendPTPCommand` with the full SDK types
3. Implement proper PTP command construction using `ICPTPCommand` (if available)

### Option B: IOKit/IOUSBHost Raw USB

Bypass ImageCaptureCore and use IOKit directly:
1. Open the USB device via `IOUSBDeviceInterface`
2. Find bulk IN/OUT endpoints
3. Send raw PTP commands via bulk transfers
4. Parse standard PTP responses

### Option C: libgphoto2 via FFI

Use the mature libgphoto2 library (already has X100VI support):
1. Link against libgphoto2
2. Use its PTP/USB abstraction
3. Access Fuji-specific device properties

### Immediate Action Items

1. ✅ Device enumeration — done
2. ✅ Session open — done
3. ⬜ PTP probe with full SDK → **needs full Xcode**
4. ⬜ Property dump (D001, D34C, D18E-D1A5) → blocked by PTP
5. ⬜ Slot write test → blocked by PTP
6. ⬜ RAW conversion test → blocked by PTP
