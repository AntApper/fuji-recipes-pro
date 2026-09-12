# FujiRecipes — Comprehensive Test Plan

> **How to use:** Follow this plan during QA sessions. Mark each test as ✅ Pass, ❌ Fail, or ⏸️ Skipped (hardware needed).
> 
> See `QA-METHODOLOGY.md` for the testing process and `QA-ISSUE-CHECKLIST.md` for issue tracking.

---

## 1. App Lifecycle

### 1.1 Launch & Startup
| # | Test | Expected | Status |
|---|------|----------|--------|
| 1.1.1 | Launch app from Xcode debug build | App opens without crash, shows "Recipes" tab | |
| 1.1.2 | Launch app from built .app | Same as 1.1.1 | |
| 1.1.3 | Verify 4 tabs present | Recipes, Loadouts, Camera, Darkroom visible | |
| 1.1.4 | Verify default tab | "Recipes" tab shown on launch | |
| 1.1.5 | Verify app info in Debug HUD | App shows correct version, build, bundle ID | |
| 1.1.6 | Verify device info in Debug HUD | Shows macOS version, CPU, RAM | |

### 1.2 Termination & Persistence
| # | Test | Expected | Status |
|---|------|----------|--------|
| 1.2.1 | Quit app, reopen | App state restored (last tab, filters) | |
| 1.2.2 | Force quit, reopen | Same as 1.2.1 | |
| 1.2.3 | Change favorite, quit, reopen | Favorite persists across sessions | |
| 1.2.4 | Change loadout name, quit, reopen | Loadout changes persist | |

---

## 2. Recipe Browser

### 2.1 Recipe Data
| # | Test | Expected | Status |
|---|------|----------|--------|
| 2.1.1 | Verify 86 recipes loaded | List shows all recipes | |
| 2.1.2 | Verify recipe data in bundle | `recipes-data.json` present in app bundle | |
| 2.1.3 | Open recipe detail view | All settings displayed (active + preset) | |
| 2.1.4 | Verify PTP codes shown | Active settings show PTP property codes | |

### 2.2 Search & Filter
| # | Test | Expected | Status |
|---|------|----------|--------|
| 2.2.1 | Search by recipe name | Filters list in real time | |
| 2.2.2 | Search by film simulation | Filters list in real time | |
| 2.2.3 | Empty search text | Shows all recipes again | |
| 2.2.4 | Filter by film simulation | Sidebar filter shows only matching | |
| 2.2.5 | Filter by dynamic range | Filters list by DR | |
| 2.2.6 | Filter by grain effect | Filters list by grain | |
| 2.2.7 | Filter by white balance | Filters list by WB | |
| 2.2.8 | Clear all filters | Shows all recipes | |
| 2.2.9 | Combine multiple filters | Intersection of all filters applied | |
| 2.2.10 | Sort by name | Alphabetical order | |
| 2.2.11 | Sort by film sim | Grouped by film sim | |
| 2.2.12 | Sort by date | Chronological | |

### 2.3 Recipe Detail View
| # | Test | Expected | Status |
|---|------|----------|--------|
| 2.3.1 | Film simulation badge shown | Shows film sim name + color | |
| 2.3.2 | Active settings section | Shows all active PTP settings | |
| 2.3.3 | Preset settings section | Shows C1-C7 preset settings | |
| 2.3.4 | Notes & Tips section | Shows ISO, exposure comp, tips | |
| 2.3.5 | Source link opens browser | Opens Fuji X Weekly article | |
| 2.3.6 | Settings with PTP codes shown | Each setting shows its PTP property code | |
| 2.3.7 | Recipe without EC handled gracefully | Shows "absent" or "no exposure comp" | |

---

## 3. Favorites

### 3.1 Core Functionality
| # | Test | Expected | Status |
|---|------|----------|--------|
| 3.1.1 | Star/unstar recipe in detail view | Toggle works, star appears/disappears | |
| 3.1.2 | Star/unstar recipe in list view | Toggle works from list | |
| 3.1.3 | ⭐ Favorites filter | Shows only favorited recipes | |
| 3.1.4 | Favorites persist after quit | Still favorited when reopened | |
| 3.1.5 | Favorite indicator in loadouts | Slots showing favorited recipes show star | |
| 3.1.6 | Favorite count correct | Count matches number of starred recipes | |

---

## 4. Loadouts (C1-C7)

### 4.1 Loadout Cards
| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.1.1 | 7 slot cards visible | C1 through C7 shown with colors | |
| 4.1.2 | Empty slots show "+icon" | Unconfigured slots show empty state | |
| 4.1.3 | Configured slots show all 8 settings | Film sim, DR, grain, WB, highlight, shadow, color, sharpness | |
| 4.1.4 | Progress indicator shown | "N/8 configured" badge | |
| 4.1.5 | Slot colors distinct | Each slot has unique accent color | |

### 4.2 Load Recipe to Slot
| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.2.1 | "Load to Slot" button in recipe detail | Button visible, shows C1-C7 picker | |
| 4.2.2 | Select a slot → recipe applied | All settings loaded into slot | |
| 4.2.3 | Slot card updates immediately | Visual update after loading | |
| 4.2.4 | Loadout persists after quit | Slot still has recipe when reopened | |
| 4.2.5 | Overwrite existing slot | Existing settings replaced | |
| 4.2.6 | Cancel loadout dialog | No changes made | |

### 4.3 Edit Loadout
| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.3.1 | Change slot name | Name updates in card | |
| 4.3.2 | Change film sim in slot | Film sim badge updates | |
| 4.3.3 | Change DR in slot | DR value updates | |
| 4.3.4 | Change grain in slot | Grain value updates | |
| 4.3.5 | Change WB mode in slot | WB mode updates | |
| 4.3.6 | Change highlight/shadow/color | Values update in slot | |
| 4.3.7 | Change sharpness/clarity in slot | Values update in slot | |

### 4.4 Clear Loadout
| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.4.1 | Clear a slot | Slot returns to empty state | |
| 4.4.2 | Clear all slots | All 7 return to empty | |
| 4.4.3 | Clear slot in list view | Slot card updates | |

---

## 5. Debug HUD

### 5.1 Access
| # | Test | Expected | Status |
|---|------|----------|--------|
| 5.1.1 | 5-finger tap on macOS | Debug HUD panel appears | |
| 5.1.2 | 3-finger tap on iOS | Debug HUD panel appears | |
| 5.1.3 | Debug HUD absent in release builds | No debug panel in non-debug builds | |

### 5.2 Log Stream
| # | Test | Expected | Status |
|---|------|----------|--------|
| 5.2.1 | Logs appear in real time | Log entries visible as app runs | |
| 5.2.2 | Filter by text | Only matching logs shown | |
| 5.2.3 | Filter by level | Only selected level shown | |
| 5.2.4 | Clear logs | Log stream empties | |
| 5.2.5 | Copy filtered logs | Logs copied to clipboard | |
| 5.2.6 | Logs show correct categories | Category emoji and name shown | |

### 5.3 App Info
| # | Test | Expected | Status |
|---|------|----------|--------|
| 5.3.1 | App name, version, build shown | Correct values from Info.plist | |
| 5.3.2 | Device OS, CPU, RAM shown | Accurate system info | |
| 5.3.3 | Favorites count shown | Matches actual favorites | |
| 5.3.4 | Loadout count shown | Shows N/7 configured | |
| 5.3.5 | Copy diagnostic report | Full report copied to clipboard | |

### 5.4 Performance
| # | Test | Expected | Status |
|---|------|----------|--------|
| 5.4.1 | Memory usage displayed | Shows current memory in MB | |
| 5.4.2 | Memory updates periodically | Refreshes every ~2 seconds | |

### 5.5 PTP Status
| # | Test | Expected | Status |
|---|------|----------|--------|
| 5.5.1 | Connection status indicator | Green/red/yellow dot | |
| 5.5.2 | Camera name shown | When connected | |

---

## 6. Camera & PTP (Requires X100VI Hardware)

### 6.1 Connection
| # | Test | Expected | Status |
|---|------|----------|--------|
| 6.1.1 | Connect X100VI via USB-C | Camera detected | |
| 6.1.2 | Connect status shows "connecting" | Status updates during connection | |
| 6.1.3 | Connect succeeds | Status shows "connected", green dot | |
| 6.1.4 | Camera info displayed | Product name, model shown | |
| 6.1.5 | Disconnect | Clean disconnect, status updates | |
| 6.1.6 | Disconnect button | Button available when connected | |
| 6.1.7 | Disconnect while reading settings | Handled gracefully (no crash) | |

### 6.2 Read Active Settings
| # | Test | Expected | Status |
|---|------|----------|--------|
| 6.2.1 | Read film simulation | Matches camera UI | |
| 6.2.2 | Read dynamic range | Matches camera UI | |
| 6.2.3 | Read highlight tone | Matches camera UI | |
| 6.2.4 | Read shadow tone | Matches camera UI | |
| 6.2.5 | Read grain effect | Matches camera UI | |
| 6.2.6 | Read color chrome | Matches camera UI | |
| 6.2.7 | Read smooth skin | Matches camera UI | |
| 6.2.8 | Read WB mode | Matches camera UI | |
| 6.2.9 | Read color temperature | Matches camera UI | |
| 6.2.10 | Read WB shifts | Matches camera UI | |
| 6.2.11 | Read sharpness | Matches camera UI | |
| 6.2.12 | Read ISO NR | Matches camera UI | |

### 6.3 Write Recipe to Camera
| # | Test | Expected | Status |
|---|------|----------|--------|
| 6.3.1 | Apply recipe to camera | Settings appear on camera UI | |
| 6.3.2 | Apply recipe with all 12 settings | All settings written successfully | |
| 6.3.3 | Partial recipe (missing some settings) | Written without error, absent settings ignored | |
| 6.3.4 | Write fails gracefully | Error message shown, no crash | |

### 6.4 Write Preset Slot
| # | Test | Expected | Status |
|---|------|----------|--------|
| 6.4.1 | Write recipe to C1 slot | Slot saved on camera | |
| 6.4.2 | Verify slot on camera | Switch to C1, values match | |
| 6.4.3 | Write to all C1-C7 slots | All 7 saved successfully | |
| 6.4.4 | Overwrite existing slot | Values replaced without error | |

### 6.5 RAF Darkroom
| # | Test | Expected | Status |
|---|------|----------|--------|
| 6.5.1 | Select RAF file | File picker opens | |
| 6.5.2 | Convert RAF to JPEG | In-camera conversion succeeds | |
| 6.5.3 | Download converted JPEG | JPEG appears in app | |
| 6.5.4 | Convert with profile modifier | Profile settings applied | |
| 6.5.5 | Capture preview | Live view JPEG captured | |
| 6.5.6 | Conversion error | Error message shown, no crash | |

---

## 7. iOS-Specific Tests

### 7.1 Platform Differences
| # | Test | Expected | Status |
|---|------|----------|--------|
| 7.1.1 | Build for iOS simulator | Compiles without errors | |
| 7.1.2 | Launch on iPad simulator | All tabs present | |
| 7.1.3 | Launch on iPhone simulator | Layout adapts correctly | |
| 7.1.4 | iOS tab navigation | Tab bar works (Recipes + Loadouts + Camera) | |
| 7.1.5 | macOS tab bar | Tab bar works (Recipes + Loadouts + Camera + Darkroom) | |
| 7.1.6 | Dark mode support | UI adapts to dark/light mode | |
| 7.1.7 | Touch targets | Buttons/taps usable on touch | |

---

## 8. Edge Cases & Error Handling

| # | Test | Expected | Status |
|---|------|----------|--------|
| 8.1 | Corrupt recipes-data.json | Graceful error, no crash | |
| 8.2 | Empty recipes-data.json | Shows empty list, no crash | |
| 8.3 | UserDefaults corrupted | Handles gracefully | |
| 8.4 | No USB camera connected | Camera tab shows "not connected" | |
| 8.5 | USB camera disconnected mid-use | Graceful disconnect, no crash | |
| 8.6 | Rapid tab switching | No crash, smooth transitions | |
| 8.7 | Multiple favorite toggles in quick succession | All toggles register | |
| 8.8 | Load recipe to all 7 slots | All slots fill correctly | |
| 8.9 | Debug HUD opened 10 times rapidly | No crash, works each time | |
| 8.10 | App launch with existing crash reports | Launches, doesn't hang | |

---

## 9. Regression Checklist

> After each fix, verify these previously-working items still work:

- [ ] App launches without crash
- [ ] All 86 recipes load
- [ ] Favorites toggle and persist
- [ ] Loadouts save and load
- [ ] Debug HUD opens
- [ ] Recipe search works
- [ ] Filter works
- [ ] Tab navigation works
- [ ] Recipe detail view shows all settings
- [ ] Load to slot works
- [ ] No console errors

---

*Last updated: Session 18 (2026-07-04)*
*Total test cases: ~90 (50 software + 20 PTP/hardware + 10 iOS + 10 edge cases)*
