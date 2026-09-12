# macOS Release Boundaries

This repository can build and validate a development macOS application, but it
is not currently ready for Developer ID distribution or the Mac App Store.

## Current development boundary

- The macOS app launches a bundled `x100vi_helper` executable that uses raw
  libusb access to communicate with an X100VI.
- `ptpcamerad` may claim the USB PTP interface. Development testing currently
  requires stopping that service before the helper can claim the device.
- The helper now loads a bundled `libusb-1.0.0.dylib` through
  `@rpath/libusb-1.0.0.dylib` with an `@loader_path` rpath. Its source,
  helper, and runtime SHA-256 values are recorded in the app resource
  provenance manifest, and the bundled license text is checked.
- A release still requires a verified universal helper and libusb runtime.
  `scripts/verify-macos-release-foundation.sh` rejects missing `arm64` or
  `x86_64` slices and any Mach-O whose minimum macOS version is later than
  14.0. A locally installed Homebrew libusb can be arm64-only and built for a
  newer macOS; that input is intentionally rejected by the release gate.

## Distribution status

- **Local development:** Supported for engineering validation when a compatible
  helper, libusb runtime, and direct USB access are available.
- **Developer ID:** Not supported yet. It requires a signed distribution design
  for the helper and dependencies, plus Developer ID credentials and
  notarization.
- **Mac App Store:** Not supported. The raw libusb/helper process and
  `ptpcamerad` conflict have not been shown to work within the App Sandbox or
  its entitlement model.
- **iOS:** A separate workstream. Its transport, signing, privacy disclosures,
  and device testing are independent of this macOS helper path.

## Notarization

Notarization is intentionally outside repository CI. It requires an Apple
Developer account, a Developer ID Application certificate, an App Store
Connect API key or app-specific password, and a signed, archiveable release
artifact. Do not add those credentials to this repository or its workflows.

## Required evidence before a public macOS release

1. Supply a redistributable universal libusb dylib built for macOS 14.0 or
   earlier, then rebuild the helper with `scripts/build-macos-helper.sh`.
2. Verify the helper's architecture coverage and camera behavior on supported
   Intel and Apple Silicon machines.
3. Define and test a signed, sandbox-compatible distribution design, or
   explicitly limit distribution to a non-App-Store channel.
4. Validate camera behavior without relying on manually killing
   `ptpcamerad`.
5. Complete notarized release testing using externally managed Apple
   credentials.
