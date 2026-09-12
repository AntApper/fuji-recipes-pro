# FujiRecipes — QA Testing Methodology

## Overview

This document describes the structured QA testing process for FujiRecipes. Each QA session follows a repeatable workflow: plan → execute → capture → analyze → document → fix → verify.

---

## The Testing Pipeline

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  PRE-TEST   │───▶│  EXECUTION  │───▶│ CAPTURE     │───▶│ ANALYSIS    │
│  CHECK      │    │  & LOGGING  │    │ ISSUES      │    │ & PRIORITIZE│
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                                                       │
       │                                                       ▼
┌──────┴─────────┐                              ┌─────────────────────┐
│  VERIFY FIXES  │◀───────┐                     │ DOCUMENT & TRACK    │
│  (RETEST)      │        │                     │ ISSUES              │
└────────────────┘        │                     └─────────────────────┘
                          │                           │
                          └───────────────────────────┘
                                        │
                                        ▼
                              ┌─────────────────────┐
                              │  IMPLEMENT FIX      │
                              └─────────────────────┘
```

---

## QA Session Structure

### Phase 1: Pre-Test Checklist (5 min)

Before starting any QA session, verify:

- [ ] **App builds successfully** — no compiler errors
- [ ] **App launches without crash** — clean start
- [ ] **All tabs load** — Recipes, Loadouts, Camera, Darkroom
- [ ] **Recipe data present** — 86 recipes load
- [ ] **Favorites/loadouts persistence** — UserDefaults working
- [ ] **Debug HUD accessible** — tap gesture triggers debug panel
- [ ] **Console log level** — set to `.debug` or lower
- [ ] **No pending fix branches** — working on main/HEAD

### Phase 2: Test Execution (variable)

Follow the **Test Plan** (`test-plan.md`) systematically. For each test case:

1. **Execute the test** — follow the steps
2. **Observe the result** — what happened?
3. **Log it** — if something went wrong, note it immediately
4. **Capture context** — what were you doing? what led up to it?

**Testing order:**
1. Happy path — core features work as expected
2. Edge cases — boundary values, unusual inputs
3. Error paths — invalid states, offline, missing data
4. Regression — verify previously fixed issues still work

### Phase 3: Issue Capture

When an issue is found:

1. **Note the symptom** — what did you see? (crash, wrong output, UI glitch)
2. **Record steps to reproduce** — exact actions that lead to the issue
3. **Capture diagnostics** — use the Debug HUD to copy logs
4. **Screenshot/record** — visual evidence of the problem
5. **Log to session notes** — immediate entry in `session-notes.md`

### Phase 4: Analysis & Prioritization

After capturing an issue, classify it:

| Severity | Criteria | Example |
|----------|----------|---------|
| 🔴 **Critical** | App crash, data loss, core feature broken | Crash on launch, recipes not loading |
| 🟠 **Major** | Feature broken but no crash | Wrong recipe settings applied |
| 🟡 **Medium** | Visual glitch, minor functionality issue | Misaligned UI element |
| 🟢 **Minor** | Cosmetic, typo, enhancement | Spelling mistake, color suggestion |

| Priority | Action |
|----------|--------|
| **P0** | Fix before continuing |
| **P1** | Fix soon, but unblocks other work |
| **P2** | Fix when convenient |
| **P3** | Nice to have, low effort |

### Phase 5: Documentation

Update these documents after each session:

1. **`session-notes.md`** — add new session with findings
2. **`QA-ISSUE-CHECKLIST.md`** — add new issues, update status
3. **`roadmap.md`** — update progress indicators

### Phase 6: Fix & Verify

After issues are documented and prioritized:

1. **Fix the issue** — in code
2. **Rebuild** — verify compilation
3. **Re-test** — confirm the fix works
4. **Test adjacent areas** — ensure no regression
5. **Close the issue** — update `QA-ISSUE-CHECKLIST.md` to ✅

---

## Debug Tools

### Debug HUD (Debug Builds Only)

**How to trigger:**
- macOS: 5-finger tap
- iOS: 3-finger tap

**What it shows:**
- **Log Stream** — real-time structured log output (filterable by text, level, category)
- **App Info** — version, build, device info, app state
- **Performance** — memory usage (live-refreshing)
- **PTP Status** — camera connection state

**Actions available:**
- Clear logs
- Copy filtered logs to clipboard
- Copy diagnostic report
- Close

### Structured Logging

All logging uses `DebugLogger` with categories and log levels:

```swift
DebugLogger.info("Loaded \(recipes.count) recipes", category: .recipes)
DebugLogger.error("Failed to connect camera: \(error)", category: .camera)
DebugLogger.warning("Recipe missing exposure compensation", category: .recipes)
```

**Categories:** App, Recipes, Loadout, Favorites, Camera, PTP, RAF, UI, Storage, Debug

**Log Levels:** TRACE → DEBUG → INFO → WARN → ERROR → FAULT

**To change log level:** Use the Debug HUD or call `DebugLogger.setMinimumLevel(.trace)`

### Crash Reports

- Automatically saved to `~/Library/Application Support/FujiRecipes/`
- JSON format with full diagnostics, stack trace, app state
- Accessible via Debug HUD → App Info → "Copy Diagnostic Report"
- Crash dialogs appear on unhandled exceptions (macOS)

---

## Session Notes Format

When adding a new QA session to `session-notes.md`, use this template:

```markdown
## Session [N] — [Brief Description] ([Date])

### Objective
What we're testing today.

### Test Plan
Reference `test-plan.md` section or custom test sequence.

### Findings

#### ✅ Passed
- Test case 1
- Test case 2

#### ❌ Failed
| # | Severity | Priority | Description | Steps | Category |
|---|----------|----------|-------------|-------|----------|
| 1 | 🔴 | P0 | App crashes on launch | Launch app → immediate crash | App |

### Diagnostics
- Crash report hash: abc123
- Log excerpt: "..."
- Screenshot: [link/path]

### Actions Taken
- Fix applied: ...
- Rebuild result: ✅/❌
- Retest result: ✅/❌

### Session Summary
Brief summary of what was accomplished.
```

---

## Testing Scope Matrix

| Feature | Unit Tests | UI Tests | Manual QA |
|---------|-----------|----------|-----------|
| Recipe loading & display | ✅ | ✅ | ✅ |
| Favorites | ✅ | ✅ | ✅ |
| Loadout (C1-C7) | ✅ | ✅ | ✅ |
| Camera connection | ⏸️ | ⏸️ | ✅ (hardware needed) |
| PTP communication | ⏸️ | ⏸️ | ✅ (hardware needed) |
| RAF conversion | ⏸️ | ⏸️ | ✅ (hardware needed) |
| Debug HUD | ✅ | — | ✅ |
| Log stream | ✅ | — | ✅ |
| Crash handling | ✅ | — | ✅ |

---

## Best Practices

1. **Test one thing at a time** — isolate issues before reporting
2. **Reproduce consistently** — if it only happens once, note it as "intermittent"
3. **Capture context** — what version, what data, what steps led to the issue
4. **Use the Debug HUD** — logs are the most valuable diagnostic tool
5. **Document everything** — even "worked as expected" entries
6. **Close the loop** — every issue gets a fix and a retest
7. **Retain test data** — don't clear favorites/loadouts between sessions
8. **Track regression** — mark previously-passing tests that now fail
