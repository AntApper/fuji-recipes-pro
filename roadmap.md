# Roadmap

## 1. Local Recipe Library ✅ COMPLETE

- Scrape private X-Trans V recipe library.
- Normalize settings into JSON/CSV.
- Map recipe values to Fuji PTP values.
- 86 recipes normalized, 913 settings mapped.
- Tools: `normalize_settings.py`, `d185_profile.py`, `export_ios_app_data.py`

## 2. X100VI PTP Probe ✅ COMPLETE

- Built iOS/macOS probe with ImageCaptureCore (macOS).
- Probed device info, properties, and capabilities.
- Discovered macOS ImageCaptureCore transforms raw PTP responses (not usable for Fuji).
- Confirmed X100VI is PTP-capable.
- Architecture decision: hybrid PTP layer (iOS = ImageCaptureCore, macOS = libgphoto2).

## 3. App MVP

### Phase 1: Infrastructure ✅ COMPLETE
- SPM packages scaffolded: `FujiRecipesCore` + `FujiPTPClient`
- 4 Xcode projects generated via xcodegen
- Workspace created linking all projects
- libgphoto2 bundled (11 dylibs)
- Swift 6 FFI compatibility fixed — both packages build via `swift build`
- 18 Swift source files across 4 targets

### Phase 1: Xcode Build ✅ COMPLETE
- ✅ Both SPM packages build (`swift build`)
- ✅ FujiRecipesMac compiles and links (58KB binary)
- ✅ FujiRecipes iOS compiles for simulator (124KB binary)
- ✅ Workspace with all 4 projects working
- Remaining: camera entitlement (iOS), install_name rewrite for libgphoto2

### Phase 2: UI Implementation ✅ COMPLETE
- ✅ SwiftUI recipe browser (macOS + iOS)
- ✅ 86 recipes loaded from JSON
- ✅ Searchable recipe list with filters
- ✅ Recipe detail view with active + preset settings
- ✅ Source article links
- ✅ Favorites with persistent storage (UserDefaults)
- ✅ ⭐ Favorites filter in sidebar/list
- ✅ C1-C7 Loadout UI with color-coded slot cards
- ✅ Load recipe to slot (one-tap from detail view)
- ✅ Tabs: Recipes + Loadouts (macOS + iOS)
- TODO: Manual editing, import/export

## 4. Camera Integration 🔴 BLOCKED — libgphoto2 Deadlock

- ✅ CameraManager, CameraView, DarkroomView
- ✅ Protocol-based architecture (broke circular dependency)
- ✅ **Swift 6 FFI crash fix verified** — App launches without crash
- ✅ Xcode installed, both platforms build
- ✅ Recipe data JSON in app bundle (PBXResourcesBuildPhase)
- ✅ Camera UI: Connection + Darkroom tabs (macOS + iOS)
- ⏳ iOS PTP: writePTPSettings, preset write, RAF conversion
- 🔴 **BLOCKED**: libgphoto2 `camera_init()` deadlocks on macOS (95% CPU)
- 🔴 **BLOCKED**: Camera connection hangs forever, needs raw PTP approach

## 5. Debug & QA Framework ✅ COMPLETE

- ✅ **Structured logging** — `DebugLogger` with 10 categories, 7 levels
- ✅ **In-app Debug HUD** — Log stream, App Info, Performance, PTP Status
- ✅ **Crash reporting** — Exception/signal handlers, JSON reports
- ✅ **QA methodology** — Testing pipeline, session structure
- ✅ **QA issue checklist** — Severity/priority/status tracking
- ✅ **Test plan** — ~90 test cases (50 software + 20 PTP + 10 iOS + 10 edge cases)

## 5. Darkroom / RAF Rendering ✅ COMPLETE

- ✅ RAF file picker + convert workflow
- ✅ In-camera RAW conversion via PTP
- ✅ Download/preview converted JPEG
- ⏳ File transfer (download RAF from camera)
