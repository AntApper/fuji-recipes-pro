# Fuji Recipes — Swift 6 Compatibility Research & Fixes

## Research Summary (2026-07-04)

### Key Findings from Web Research

#### 1. `@_silence_awareness` Attribute — REMOVED
- **Status**: This attribute was **never a public/standard Swift attribute**.
- **Impact**: All `@_silence_awareness(...)` annotations were removed from FFI files.
- **Source**: Swift compiler internal-only attributes, removed in Swift 6.3.x.

#### 2. `OpaquePointer` vs `UnsafeRawPointer` — SWITCHED
- **Status**: In Swift 6, `OpaquePointer` is `AnyObject` (Objective-C bridged type), **not** a raw pointer.
- **Fix**: All libgphoto2 FFI types now use `UnsafeMutableRawPointer` / `UnsafeRawPointer`.
- **Function types**: Changed from `UnsafeMutablePointer<GPPort>?` to proper patterns.

#### 3. `dlopen`/`dlsym` Pattern — VERIFIED CORRECT
- **Pattern**: Use `sym.load(as: FunctionType.self)` or `unsafeBitCast(sym, to: FunctionType.self)`.
- **Function types**: Use `@convention(c)` for C function pointers.
- **Source**: Swift Forums "Help with dynamic loading", Apple Swift docs.

#### 4. `NSString.data(using:)` Encoding — FIXED
- **Issue**: `NSString.data(using:)` takes `UInt` (raw value), NOT `String.Encoding`.
- **Fix**: Use `String.Encoding.utf16LittleEndian.rawValue` or use `String.data(using:)` instead.
- **Source**: Swift corelibs-foundation source code.

#### 5. `String.Encoding.utf16LittleEndian` — EXISTING
- **Confirmed**: `String.Encoding.utf16LittleEndian` exists and is valid.
- **For `String.data(using:)`**: Takes `String.Encoding` directly.
- **For `NSString.data(using:)`**: Takes `UInt` raw value.

#### 6. `Thread.sleep` in Async Contexts — REPLACED
- **Swift 6**: `Thread.sleep(forTimeInterval:)` unavailable in async contexts.
- **Fix**: Use `try await Task.sleep(nanoseconds: ...)` instead.
- **Non-async contexts**: `Thread.sleep` is still valid.

#### 7. `UInt32(truncatingBitPattern:)` → `init(truncatingIfNeeded:)` — UPDATED
- **Swift 6**: `truncatingBitPattern:` is removed; use `init(truncatingIfNeeded:)`.
- **Source**: Swift 6 migration guide.

#### 8. `radix` in String Interpolation — REMOVED
- **Swift 6**: `(value, radix: 16)` in string interpolation is removed.
- **Fix**: Use `String(value, radix: 16)` as a constructor, then interpolate.

#### 9. `fromBEBytes` — ACCEPTS `[UInt8]` NOT `ArraySlice<UInt8>`
- **Fix**: Wrap slice notation `[...]` with `Array(...)` when passing to `fromBEBytes`.

---

## Files Modified

### FujiRecipesCore
| File | Fix |
|------|-----|
| `Enums/WhiteBalanceMode.swift` | Added `Codable`; fixed duplicate raw value for `tungsten` (5→6 via `actualPTPValue`); added `actualPTPValue` property |
| `Enums/FilmSimulation.swift` | Added `Codable` conformance |
| `Enums/DynamicRange.swift` | Added `Codable` conformance |
| `Enums/GrainEffect.swift` | Added `Codable` conformance |
| `Enums/EffectIntensity.swift` | Added `Codable` conformance |

### FujiPTPClient
| File | Fix |
|------|-----|
| `Sources/PTPClient/PTPClient.swift` | Fixed `radix` in string interpolation (4 places) |
| `Sources/PTPClientMacOS/FFI+Types.swift` | Complete rewrite: `OpaquePointer`→`UnsafeRawPointer`; `let`→`var` for dlopen registry; `private`→`internal` for typealiases; removed `@_silence_awareness`; added `nonisolated(unsafe)`; fixed `cStringToSwift` nil check; added `portInfoGetNote`/`portInfoSetNote` function types; fixed pointer-to-pointer types for `portOpen`/`cameraNew` etc. |
| `Sources/PTPClientMacOS/FFI+Helpers.swift` | Removed `@_silence_awareness`; fixed function signatures for `UnsafeRawPointer` |
| `Sources/PTPClientMacOS/FFI+PTP.swift` | Removed `@_silence_awareness`; fixed `PTPResponse` access level; fixed `wbShiftR`→`wbShiftRed`; fixed `guard let name = data.name`; fixed `utf16LittleEndian` encoding; changed `fromBEBytes` to accept `[UInt8]`; fixed `PTPPacket` access level; fixed `toBEBytes`/`fromBEBytes` access levels; added `internal` visibility for cross-file access; moved `nextTransactionID` to MacOSSession class; fixed `Thread.sleep` in async → `Task.sleep` |
| `Sources/PTPClientMacOS/FFI+RAW.swift` | Removed `@_silence_awareness`; fixed `openedPort` scope in closures; fixed `utf16LittleEndian` encoding; fixed `Data`→`ArraySlice` conversion; changed `sendAndReceivePTP` to async; fixed `Task.sleep` calls; fixed `Thread.sleep` in async → `Task.sleep`; added `import PTPClient` |
| `Sources/PTPClientMacOS/FFI+USB.swift` | Removed `@_silence_awareness`; fixed `GPPortInfo?` type; fixed pointer types for `portInfoListGetInfo` |
| `Sources/PTPClientMacOS/MacOS+PTPClient.swift` | Added `import PTPClient`; fixed `OpaquePointer`→`UnsafeRawPointer`; fixed `UInt32(truncatingBitPattern:)`→`init(truncatingIfNeeded:)`; fixed `radix` in interpolation; fixed `@Sendable` on closure types in `Mapping`; fixed `var config`→`let config`; fixed `stringValue` unused; fixed `getCurrentConfig` return type; added `_ptpTransactionID`/`nextTransactionID` to class |
| `Sources/PTPClientiOS/iOS+PTPClient.swift` | Added `import PTPClient` |
| `Package.swift` | No changes needed |

---

## Build Status

✅ **FujiRecipesCore** — Builds successfully with `swift build`
✅ **FujiPTPClient** — Builds successfully with `swift build`
✅ **All 3 frameworks** (PTPClient, PTPClientMacOS, PTPClientiOS) compile

**Remaining warnings** (non-blocking): unused variables, `nonisolated(unsafe)` redundancy, `let`→`var` for unused values.

---

## Next Steps

1. **Xcode Build** — Install Xcode 16+ to build the full Xcode workspace (FujiRecipes + FujiRecipesMac)
2. **Camera Testing** — Connect X100VI and test PTP communication
3. **iOS PTP** — Test ImageCaptureCore on actual iOS hardware
4. **UI Implementation** — Build recipe browser and loadout UI
