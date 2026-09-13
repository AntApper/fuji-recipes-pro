# Building Fuji Recipes

## Prerequisites

### Required
- **Xcode 16+** (Swift 6.0)
- **Homebrew** with libgphoto2:
  ```bash
  brew install libgphoto2 xcodegen
  ```
- **Apple Developer Account** (for iOS signing)

### macOS helper runtime

The X100VI helper and its libusb runtime are rebuilt only through the
provenance script:

```bash
# Requires a libusb dylib containing every requested architecture.
scripts/build-macos-helper.sh

# Local Apple Silicon development with the installed Homebrew libusb.
scripts/build-macos-helper.sh --architectures arm64
```

The first command intentionally fails when the supplied `LIBUSB_DYLIB` (or
Homebrew's libusb) does not contain both `arm64` and `x86_64`. It copies the
matching runtime into the app resources, changes the helper load command to
`@rpath/libusb-1.0.0.dylib`, adds `@loader_path`, and writes SHA-256 hashes to
`x100vi_helper.provenance.json`. It also copies the libusb license text.

For a release candidate, the runtime must additionally have a macOS deployment
target no newer than the app's 14.0 target:

```bash
scripts/verify-macos-release-foundation.sh
```

Do not bypass this gate. The locally installed Homebrew libusb on a newer
macOS may be arm64-only and built for a newer macOS version; in that case it
is valid for local inspection only, not a distributable macOS artifact.

### Optional
- **Physical X100VI** for camera testing
- **iPad/iPhone + USB-C** for iOS PTP testing

## Quick Start

### 1. Bundle libgphoto2

```bash
# One-time setup — copies and rewrites dylibs
bash tools/bundle-libgphoto2.sh
```

This creates `FujiPTPClient/Resources/libgphoto2/` with 11 dylibs.

### 2. Open the generated Xcode workspace

```bash
open FujiRecipes.xcworkspace
```

`FujiRecipes.xcworkspace` is the authoritative Xcode entry point. Validate it
after regeneration with:

```bash
xcodebuild -list -workspace FujiRecipes.xcworkspace
```

### 3. Set Signing

In Xcode, for each target:
1. Select target → Signing & Capabilities
2. Check "Automatically manage signing"
3. Select your team

**iOS**: Also add `com.apple.security.device.camera` entitlement (pre-configured in project.yml)

### 4. Build

- **macOS**: Select `FujiRecipesMac` scheme → Product → Build
- **iOS**: Select `FujiRecipes` scheme → Build (requires connected iOS device)

## Project Structure

```
FujiRecipes.xcworkspace
├── FujiRecipesCore/          ← Shared models & PTP constants
│   ├── Package.swift
│   └── Sources/
│       └── FujiRecipesCore/
│           ├── Enums/        (FilmSim, WBMode, DR, Grain, EffectIntensity)
│           ├── Models/       (Recipe, PresetSlot)
│           └── Mapping/      (PTPConstants — 38 property codes)
│
├── FujiPTPClient/            ← Camera communication layer
│   ├── Package.swift
│   ├── Resources/
│   │   └── libgphoto2/       ← 11 bundled dylibs (4.0MB)
│   └── Sources/
│       ├── PTPClient/        ← Protocol + types
│       ├── PTPClientMacOS/   ← macOS implementation
│       │   ├── FFI+Types.swift       ← dlopen/dlsym registry
│       │   ├── FFI+Helpers.swift     ← Widget helpers
│       │   ├── FFI+PTP.swift         ← Raw PTP commands
│       │   ├── FFI+RAW.swift         ← RAF→JPEG conversion
│       │   ├── FFI+USB.swift         ← USB detection
│       │   └── MacOS+PTPClient.swift ← Full protocol impl
│       └── PTPClientiOS/   ← iOS stub (ImageCaptureCore)
│
├── FujiRecipes/              ← iOS app
│   ├── iOS/
│   │   ├── FujiRecipes.xcodeproj/
│   │   ├── project.yml
│   │   └── Source/
│   │       ├── App.swift
│   │       ├── Info.plist
│   │       └── FujiRecipes.entitlements
│
└── FujiRecipesMac/           ← macOS app
    ├── macos/
    │   ├── FujiRecipesMac.xcodeproj/
    │   ├── project.yml
    │   └── Source/
    │       ├── App.swift
    │       └── Info.plist
```

## Testing with Camera

### macOS Testing

1. Connect X100VI via USB-C
2. Build and run `FujiRecipesMac`
3. Click "Connect Camera"
4. Verify:
   - `connect()` succeeds
   - `readProperty(0xD001)` returns film sim value
   - `readPresetSlot(1)` returns C1 settings

### iOS Testing

1. Connect X100VI to iPad via USB-C
2. Build and run `FujiRecipes` on device
3. Test `IOSSession` with `requestSendPTPCommand`

### RAW Conversion Test

```swift
let raf = RAFFile(name: "DSCF0001.RAF", data: rafData)
if let jpeg = try await session.convertRAF(raf) {
    print("Converted \(jpeg.name) (\(jpeg.data.count) bytes)")
}
```

## Regenerating Xcode Projects

If you modify `project.yml` files:

```bash
cd FujiRecipesCore && xcodegen generate
cd ../FujiPTPClient && xcodegen generate
cd ../FujiRecipes/iOS && xcodegen generate
cd ../FujiRecipesMac/macos && xcodegen generate
```

## Credential-free release checks

These checks intentionally do not contact Apple or a camera:

```bash
scripts/verify-macos-release-foundation.sh

# Build a locally signed (ad-hoc) universal bundle and verify it.
cd FujiRecipesMac/macos
./package_app.sh release --version 1.0.0 --build-number 1
```

The check validates helper source/resource hashes, the bundled libusb license,
`@rpath`/`@loader_path` linkage, architecture coverage, and the minimum macOS
version of both Mach-O files. A release build requires universal `arm64` and
`x86_64` artifacts with a macOS 14.0-or-earlier runtime.

The finished-app check additionally validates bundle versioning, required
resources, nested signatures, sealed resources, and the absence of developer
library paths. The default ad-hoc signature is useful only for structural
validation; it is not a Developer ID signature and cannot be notarized.

For a Developer ID candidate, supply the certificate identity only from the
release environment:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Organization (TEAMID)" \
  ./package_app.sh release --version 1.0.0 --build-number 1
```

This repository neither stores credentials nor submits to Apple's notarization
service. See `docs/MACOS_RELEASE_BOUNDARIES.md` for the required external
Developer ID, hardened runtime, notarization, raw-libUSB, and `ptpcamerad`
steps.

## Troubleshooting

### "libgphoto2 not found"
```bash
brew install libgphoto2
bash tools/bundle-libgphoto2.sh
```

### "No Fuji X100VI found"
- Ensure camera is powered on and connected via USB-C
- Camera should show as "PTP" or "Camera" in System Information
- Check: Apple Menu → About This Mac → System Report → USB → list all devices

### Build failures
- Clean build folder: Product → Clean Build Folder (⇧⌘K)
- Delete derived data: ~/Library/Developer/Xcode/DerivedData
- Check Swift version: swift --version (should be 6.0+)

### PTP communication errors
- Enable camera debugging in Xcode console
- Check that camera is in PTP mode (not Mass Storage)
- Try disconnecting and reconnecting USB cable
