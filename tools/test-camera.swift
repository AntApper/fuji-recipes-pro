#!/usr/bin/env swift
// test-camera.swift
// Quick test script for X100VI PTP communication.
// Run from the project root:
//   swift -I FujiRecipesCore/Sources -I FujiPTPClient/Sources \
//         -L FujiPTPClient/Resources/libgphoto2 \
//         --warn-concurrency test-camera.swift
//
// Or better: Build the FujiRecipesMac target in Xcode and run from there.

import Foundation

print("📷 Fuji X100VI PTP Test Script")
print("================================")
print("")

// Step 1: Check if libgphoto2 is available
print("1. Checking libgphoto2...")
let candidates = [
    "/opt/homebrew/lib/libgphoto2.6.dylib",
    "/opt/homebrew/opt/libgphoto2/lib/libgphoto2.6.dylib",
    "/usr/local/lib/libgphoto2.6.dylib",
]

var handle: UnsafeMutableRawPointer? = nil
for path in candidates {
    if FileManager.default.fileExists(atPath: path) {
        handle = dlopen(path, RTLD_LAZY)
        if handle != nil {
            print("   ✅ Found libgphoto2 at: \(path)")
            break
        }
    }
}

if handle == nil {
    print("   ❌ libgphoto2 not found. Install via: brew install libgphoto2")
    exit(1)
}

// Step 2: Try to load key functions
print("\n2. Loading libgphoto2 functions...")
let functions = [
    "gp_library_init",
    "gp_library_exit",
    "gp_camera_new",
    "gp_camera_free",
    "gp_camera_init",
    "gp_camera_exit",
    "gp_camera_get_config",
    "gp_camera_set_config",
    "gp_port_info_list_new",
    "gp_port_info_list_count",
    "gp_port_info_list_get_info",
]

for funcName in functions {
    let sym = dlsym(handle, funcName)
    if sym != nil {
        print("   ✅ \(funcName)")
    } else {
        print("   ❌ \(funcName) — \(String(cString: dlerror()))")
    }
}

// Step 3: Initialize library
print("\n3. Initializing libgphoto2...")
guard let initFunc = dlsym(handle, "gp_library_init") else { exit(1) }
let initFuncTyped = unsafeBitCast(initFunc, to: (() -> Int32).self)
let initResult = initFuncTyped()
if initResult == 0 {
    print("   ✅ Library initialized")
} else {
    print("   ❌ Failed: \(initResult)")
    exit(1)
}

// Step 4: Enumerate ports
print("\n4. Scanning for Fuji cameras...")
guard let portListNew = dlsym(handle, "gp_port_info_list_new") else { exit(1) }
let portListNewTyped = unsafeBitCast(portListNew, to: (() -> UnsafeMutableRawPointer).self)
let portList = portListNewTyped()

guard let portListCount = dlsym(handle, "gp_port_info_list_count") else { exit(1) }
let portListCountTyped = unsafeBitCast(portListCount, to: ((UnsafeRawPointer) -> Int32).self)
let count = portListCountTyped(UnsafeRawPointer(portList))

print("   Found \(count) ports")

guard let getInfo = dlsym(handle, "gp_port_info_list_get_info") else { exit(1) }
let getInfoTyped = unsafeBitCast(getInfo, to: ((UnsafeRawPointer, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?).() -> Int32).self)

for i in 0..<Int(count) {
    var info: UnsafeMutableRawPointer? = nil
    _ = getInfoTyped(UnsafeRawPointer(portList), Int32(i), &info)
    if let info = info {
        // Try to get the note/description
        guard let noteFunc = dlsym(handle, "gp_port_info_get_note") else { continue }
        let noteFuncTyped = unsafeBitCast(noteFunc, to: ((UnsafeRawPointer?) -> UnsafePointer<Int8>?).self)
        if let note = noteFuncTyped(info), !note.equalTo(nil) {
            let noteStr = String(cString: note)
            if noteStr.contains("04cb", options: .caseInsensitive) || noteStr.contains("fuji", options: .caseInsensitive) {
                print("   📷 Found Fuji camera: \(noteStr)")
            } else {
                print("   🔌 \(noteStr)")
            }
        }
    }
}

// Cleanup
if let exitFunc = dlsym(handle, "gp_library_exit") {
    let exitFuncTyped = unsafeBitCast(exitFunc, to: (() -> Void).self)
    exitFuncTyped()
}

print("\n✅ Test complete!")
print("")
print("Next steps:")
print("1. Open FujiRecipes.xcworkspace in Xcode")
print("2. Build FujiRecipesMac target")
print("3. Connect X100VI via USB-C")
print("4. Run the app and test camera connection")
