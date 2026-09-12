@preconcurrency import Foundation
@preconcurrency import ImageCaptureCore

// MARK: - Device Finder

final class DeviceFinderDelegate: NSObject {
    var cameras: [ICCameraDevice] = []
    var done = false

    func enumerate() -> [ICCameraDevice] {
        print("[ENUM] Starting device enumeration...")
        let browser = ICDeviceBrowser()
        browser.browsedDeviceTypeMask = ICDeviceTypeMask.camera
        browser.delegate = self
        browser.start()
        print("[ENUM] Browser started, waiting...")

        let start = Date()
        while !done && Date().timeIntervalSince(start) < 30 {
            let until = Date().addingTimeInterval(0.2)
            // Run all common modes so delegate callbacks fire
            RunLoop.main.run(mode: .default, before: until)
        }

        print("[ENUM] Found \(cameras.count) camera(s)")
        return cameras
    }
}

extension DeviceFinderDelegate: ICDeviceBrowserDelegate {
    func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        if let camera = device as? ICCameraDevice {
            cameras.append(camera)
        }
        // When no more devices are coming, we're done
        if !moreComing {
            done = true
        }
    }

    func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {}

    func deviceBrowserDidEnumerateLocalDevices(_ browser: ICDeviceBrowser) {
        // Also mark done if this fires (may not for all macOS versions)
        done = true
    }
}

// MARK: - PTP Response Parser

extension Data {
    func ptpUInt16(at offset: Int) -> UInt16 {
        self.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self) }
    }

    func ptpUInt32(at offset: Int) -> UInt32 {
        self.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
    }

    func ptpString(at offset: Int) -> (string: String, newOffset: Int) {
        var end = offset
        while end + 1 < count, ptpUInt16(at: end) != 0 {
            end += 2
        }
        let s = String(data: subdata(in: offset..<end), encoding: .utf16LittleEndian) ?? "<decode-error>"
        return (s, end + 2)
    }
}

func parsePTPGetDeviceInfo(data: Data) {
    guard data.count >= 18 else {
        print("  Response too short for device info (\(data.count) bytes)")
        return
    }
    let version = data.ptpUInt16(at: 2)
    let vendorExt = data.ptpUInt32(at: 4)
    print("  PTP Version:   0x\(String(version, radix: 16))")
    print("  Vendor Ext ID: 0x\(String(vendorExt, radix: 16).uppercased().padding(toLength: 8, withPad: "0", startingAt: 0))")
    var offset = 8
    let funcMode = data.ptpUInt16(at: offset); offset += 2
    print("  Func Mode:     \(funcMode)")

    let opsLen = data.ptpUInt32(at: offset); offset += 4
    let opsCount = Int(opsLen / 2)
    print("  Operations:    \(opsCount)")
    if opsCount > 0 && opsCount <= 50 {
        var ops: [UInt16] = []
        for _ in 0..<opsCount {
            if offset + 2 <= data.count { ops.append(data.ptpUInt16(at: offset)); offset += 2 }
        }
        print("    0x\(ops.map { String(format: "%04X", $0) }.joined(separator: ", 0x"))")
    }

    let evtLen = data.ptpUInt32(at: offset); offset += 4
    print("  Events:        \(Int(evtLen / 2))")
    let propLen = data.ptpUInt32(at: offset); offset += 4
    print("  Properties:    \(Int(propLen / 2))")

    let devCount = data.ptpUInt16(at: offset); offset += 2
    print("  Devices:       \(devCount)")
    for _ in 0..<devCount {
        let (s, next) = data.ptpString(at: offset)
        print("    \"\(s)\"")
        offset = next
    }

    let (manuf, next1) = data.ptpString(at: offset)
    print("  Manufacturer:  \(manuf)")
    offset = next1
    let (model, next2) = data.ptpString(at: offset)
    print("  Model:         \(model)")
    offset = next2
    let (ver, next3) = data.ptpString(at: offset)
    print("  Device Ver:    \(ver)")
    offset = next3
    let (vi, _) = data.ptpString(at: offset)
    print("  Vendor Info:   \(vi)")
}

// MARK: - Probe

enum FujiPTPProbe {
    static func probe(_ camera: ICCameraDevice) async throws {
        print("╔══════════════════════════════════════════════════════════╗")
        print("║        Fuji X100VI PTP Probe — Session 4 Phase 1        ║")
        print("╚══════════════════════════════════════════════════════════╝")
        print()

        // Step 0: Device overview
        print("── Step 0: Device Overview ─────────────────────────────")
        print("  Name:        \(camera.name ?? "N/A")")
        print("  USB Vendor:  0x\(String(camera.usbVendorID, radix: 16).uppercased().padding(toLength: 4, withPad: "0", startingAt: 0))")
        print("  USB Product: 0x\(String(camera.usbProductID, radix: 16).uppercased().padding(toLength: 4, withPad: "0", startingAt: 0))")
        print("  USB Location:0x\(String(camera.usbLocationID, radix: 16).uppercased().padding(toLength: 4, withPad: "0", startingAt: 0))")
        print("  Transport:   \(camera.transportType ?? "N/A")")
        print("  Serial:      \(camera.serialNumberString ?? "N/A")")
        print("  PTP Capable: \(camera.capabilities.contains("ICCameraDeviceCanAcceptPTPCommands"))")
        print()

        // Step 1: Open session via framework
        print("── Step 1: Open Session ────────────────────────────────")
        camera.requestOpenSession { error in
            if let error = error {
                print("  Session open failed: \(error.localizedDescription)")
            } else {
                print("  ✅ Session opened")
            }
            print("  hasOpenSession: \(camera.hasOpenSession)")
            print()

            // Step 2: Content enumeration
            print("── Step 2: Camera Contents ────────────────────────────")
            if let contents = camera.contents {
                print("  Contents: \(contents.count) storage items")
                for item in contents.prefix(10) {
                    print("    - \(item.name ?? "unnamed")")
                }
                if contents.count > 10 {
                    print("    ... and \(contents.count - 10) more")
                }
            } else {
                print("  ⚠️  No contents available")
            }
            print()

            // Step 3: Media files
            print("── Step 3: Media Files ────────────────────────────────")
            if let mediaFiles = camera.mediaFiles {
                print("  Media files: \(mediaFiles.count)")
                for file in mediaFiles.prefix(10) {
                    print("    - \(file.name ?? "unnamed")")
                }
                if mediaFiles.count > 10 {
                    print("    ... and \(mediaFiles.count - 10) more")
                }
            } else {
                print("  No media files detected")
            }
            print()

            // Step 4: Capabilities
            print("── Step 4: Capabilities ───────────────────────────────")
            for cap in camera.capabilities {
                let desc = capabilityDescription(cap)
                print("  • \(cap) — \(desc)")
            }
            print()

            // Step 5: Raw PTP command test
            print("── Step 5: Raw PTP Command Test ───────────────────────")
            sendGetDeviceInfo(camera)
            print()

            // Step 6: Battery & status
            print("── Step 6: Camera Status ──────────────────────────────")
            print("  Battery available: \(camera.batteryLevelAvailable)")
            if camera.batteryLevelAvailable {
                print("  Battery level:     \(camera.batteryLevel)%")
            }
            print("  Remote:            \(camera.isRemote)")
            if let modVer = camera.moduleVersion {
                print("  Module version:    \(modVer)")
            }
            print()

            // Step 7: Summary
            print("── Summary ─────────────────────────────────────────────")
            print("  The X100VI is recognized and connected via ImageCaptureCore.")
            print("  Raw PTP command support on macOS ImageCaptureCore for")
            print("  non-Apple cameras appears limited. We'll need:")
            print("    1. Full Xcode (not CLI tools) for proper SDK headers")
            print("    2. Or use IOKit/IOUSBHost for raw USB PTP")
            print("    3. Or libgphoto2 via FFI")
        }
    }

    static func sendGetDeviceInfo(_ camera: ICCameraDevice) {
        // Build PTP GetDeviceInfo request: Code(2) + 3 params(12) + Length(4) = 18 bytes
        var msg = Data()
        msg.append(contentsOf: withUnsafeBytes(of: UInt16(0x1001).littleEndian) { $0 })
        msg.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian) { $0 })
        msg.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian) { $0 })
        msg.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian) { $0 })
        let length: UInt32 = 18
        msg.append(contentsOf: withUnsafeBytes(of: length.littleEndian) { $0 })

        print("  Request: \(msg.count) bytes: \(msg.map { String(format: "%02X ", $0) }.joined())")
        print("  Sending via requestSendPTPCommand...")

        camera.requestSendPTPCommand(msg, outData: nil) { responseData, _, error in
            if let error = error {
                print("  ❌ Error: \(error.localizedDescription)")
            } else {
                print("  Response: \(responseData.count) bytes")
                print("  \(responseData.map { String(format: "%02X ", $0) }.joined())")
                if responseData.count >= 2 {
                    let code = responseData.ptpUInt16(at: 0)
                    print("  Response code: 0x\(String(code, radix: 16).uppercased().padding(toLength: 4, withPad: "0", startingAt: 0))")
                    switch code {
                    case 0x2001:
                        print("  ✅ GetDeviceInfo successful!")
                        parsePTPGetDeviceInfo(data: responseData)
                    case 0x2002:
                        print("  ❌ GeneralError")
                    default:
                        print("  ⚠️  Unexpected code: 0x\(String(code, radix: 16).uppercased().padding(toLength: 4, withPad: "0", startingAt: 0))")
                    }
                } else {
                    print("  ⚠️  Response too short for PTP parsing")
                }
            }
        }
    }
}

// MARK: - Helpers

func capabilityDescription(_ cap: String) -> String {
    switch cap {
    case "ICCameraDeviceCanTakePicture": return "Can take pictures"
    case "ICCameraDeviceCanAcceptPTPCommands": return "Accepts raw PTP commands"
    case "ICCameraDeviceCanSyncClock": return "Can sync clock"
    case "ICCameraDeviceCanDeleteAllFiles": return "Can delete all files"
    case "ICCameraDeviceCanDeleteOneFile": return "Can delete one file"
    case "ICCameraDeviceCanReceiveFile": return "Can receive files"
    case "ICCameraDeviceSupportsHEIF": return "Supports HEIF"
    default: return cap
    }
}

// MARK: - Entry Point

@main
struct Main {
    static func main() {
        let finder = DeviceFinderDelegate()
        let cameras = finder.enumerate()

        if cameras.isEmpty {
            print("❌ No USB cameras found!")
            print("Make sure your X100VI is connected via USB-C in PTP/MTP mode.")
            exit(1)
        }

        print("📷 Found \(cameras.count) camera(s):")
        for cam in cameras {
            print("  • \(cam.name ?? "Unknown model")")
            print("    VID:0x\(String(cam.usbVendorID, radix: 16).uppercased().padding(toLength: 4, withPad: "0", startingAt: 0)) " +
                  "PID:0x\(String(cam.usbProductID, radix: 16).uppercased().padding(toLength: 4, withPad: "0", startingAt: 0))")
            print("    PTP capable: \(cam.capabilities.contains("ICCameraDeviceCanAcceptPTPCommands"))")
        }
        print()

        guard let x100vi = cameras.first(where: { cam in
            // macOS reports USB VID/PID in byte-swapped order vs. standard USB
            let vid = cam.usbVendorID
            let pid = cam.usbProductID
            return (vid == 0x04CB && pid == 0x0305) ||
                   (vid == 0x4CB0 && pid == 0x3050) ||
                   (vid == 0xC04B && pid == 0x5030)
        }) else {
            print("⚠️  X100VI not found by VID:PID (0x04CB:0x0305)")
            if let cam = cameras.first(where: { c in
                c.name?.lowercased().contains("x100") ?? false
            }) {
                print("   Using camera by name: \(cam.name ?? "unknown")")
                runProbe(cam)
            } else {
                print("❌ No suitable camera found!")
                exit(1)
            }
            return
        }

        print("✅ X100VI identified: \(x100vi.name ?? "Unknown")")
        print()
        runProbe(x100vi)
    }

    static func runProbe(_ camera: ICCameraDevice) {
        Task {
            do {
                try await FujiPTPProbe.probe(camera)
            } catch {
                print("❌ Probe failed: \(error.localizedDescription)")
            }
        }
        RunLoop.main.run()
    }
}
