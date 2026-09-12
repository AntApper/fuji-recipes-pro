# Next Steps — Camera Testing & Validation

## 🎯 Current Status

✅ **Implementation Complete**
- All code written and integrated
- Compiles without errors
- FujiPTPHelper executable built successfully

⏳ **Ready for Camera Testing**
- Need X100VI connected via USB-C in PTP mode
- Tests require physical camera inspection

## 🧪 Phase 1: Basic Camera Connection Test

### Prerequisites
```bash
# Ensure camera is:
# 1. Connected via USB-C cable
# 2. Powered on
# 3. In USB PTP mode (Settings → USB Connection → PTP)
# 4. In RAW mode (USB RAW mode in settings)

# Verify libgphoto2 is installed:
brew list libgphoto2  # Should show libgphoto2/2.5.34

# Kill macOS PTPCamera daemon:
killall -9 ptpcamerad PTPCamera 2>/dev/null || true
```

### Run Connection Test
```bash
# From project root
cd FujiPTPClient
swift build -c debug
cd ..

# Test basic connection
echo '{"id":"1","command":{"connect":{}}}' | ./.build/debug/FujiPTPHelper
# Expected: {"id":"1","success":true,"result":"ok","error":null}
```

## 🔍 Phase 2: Preset Slot Read Test

### Test Reading C1
```bash
# Use the test script
./test_preset_slots.sh connect
./test_preset_slots.sh read 1
./test_preset_slots.sh disconnect
```

### Expected Output (JSON)
```json
{
  "slot": 1,
  "name": "C1",
  "imageQuality": null,
  "dynamicRange": 0,
  "filmSimulation": 1,
  "grainEffect": null,
  "colorChrome": null,
  "colorChromeFxBlue": null,
  "smoothSkin": null,
  "whiteBalance": 0,
  "wbShiftRed": 0,
  "wbShiftBlue": 0,
  "colorTemp": 0,
  "highlight": 0,
  "shadow": 0,
  "color": 0,
  "sharpness": 0,
  "clarity": 0,
  "longExpNr": null,
  "colorSpace": null
}
```

### Troubleshooting If Read Fails
- ❌ **"error:not_connected"** → Camera not detected by libgphoto2
  - Solution: Verify USB cable, camera power, PTP mode
  - Check: `gphoto2 --summary`
  
- ❌ **"error:slot_select_failed"** → D18C selection failed
  - Solution: May need to check config path differences
  - Check: `gphoto2 --get-config /main/settings/preset_slot`
  
- ❌ **"error:slot_name_read_failed"** → Couldn't read preset name
  - Solution: Config path may be different on this camera
  - Check: `gphoto2 --list-all-config | grep -i preset`

## ✍️ Phase 3: Preset Slot Write Test

### Test Writing to C1
```bash
./test_preset_slots.sh write 1 "TestPreset" 1 2 0
# Args: slot, name, filmSim, dynamicRange, grainEffect
```

### Verification Steps
```bash
# 1. Check camera LCD - should show "TestPreset" in slot C1
# (Physical inspection required)

# 2. Read it back to verify
./test_preset_slots.sh read 1

# 3. Check if name was preserved
# Expected output should have "name": "TestPreset"
```

### 🚨 Critical Check: Camera LCD
After writing, **physically look at camera LCD**:
1. Press Menu
2. Go to Settings → Presets
3. Check Slot C1 - does it show "TestPreset"?

⚠️ **This is crucial!** If LCD doesn't show the name, the write might have failed.

## 🔄 Phase 4: Multi-Slot Write Test

```bash
# Write to multiple slots
./test_preset_slots.sh write 1 "Slide Film" 2 1 1
./test_preset_slots.sh write 2 "B&W" 3 2 0
./test_preset_slots.sh write 3 "Vivid" 1 3 2

# Read them all back
./test_preset_slots.sh list

# Check camera LCD for all three presets
```

## 📊 Phase 5: Error Recovery Test

### Test 1: Disconnecting and Reconnecting
```bash
./test_preset_slots.sh connect
./test_preset_slots.sh read 1
./test_preset_slots.sh disconnect

# Physically disconnect USB
sleep 3
# Reconnect USB

./test_preset_slots.sh connect
./test_preset_slots.sh read 1
```

Expected: Should work fine after reconnect (no errors)

### Test 2: Invalid Slot
```bash
./test_preset_slots.sh read 99
```

Expected: Graceful error (not crash)

## 📝 Test Results Template

Copy and fill out this template when testing:

```markdown
## Test Results — Date: YYYY-MM-DD

### Environment
- Camera: X100VI / X-T30 / (other)
- macOS Version: 
- libgphoto2 Version: 2.5.34
- Firmware: 

### Phase 1: Connection
- [ ] Connect works: YES / NO / ERROR
- Error (if any): 
- FujiPTPHelper stderr output:
  ```
  (paste stderr here)
  ```

### Phase 2: Read Test
- [ ] Read C1 works: YES / NO / ERROR
- Returned data:
  ```json
  (paste output here)
  ```

### Phase 3: Write Test
- [ ] Write works: YES / NO / ERROR
- LCD shows "TestPreset": YES / NO / (not checked)
- Read back matches write: YES / NO / ERROR

### Phase 4: Multi-Slot
- [ ] Write C1: YES / NO / ERROR
- [ ] Write C2: YES / NO / ERROR
- [ ] Write C3: YES / NO / ERROR
- LCD shows all three: YES / NO

### Phase 5: Error Recovery
- [ ] Reconnect works: YES / NO
- [ ] Invalid slot handled gracefully: YES / NO

### Overall Assessment
- [ ] ✅ WORKING — D18C preset slots functional
- [ ] ⚠️ PARTIAL — Works sometimes
- [ ] ❌ BROKEN — Same errors as before
- [ ] ❌ NEW ERRORS — Different problems

### Issues Found (if any)
1. Issue: (describe)
   Workaround: (if known)
   
### Additional Notes
(any other observations)
```

## 🐛 Debugging If Tests Fail

### 1. Enable Verbose Output
```bash
# Add debug flags to helper
echo '{"id":"1","command":{"connect":{}}}' | \
  FujiPTPClient/.build/debug/FujiPTPHelper 2>&1 | tee helper.log
```

### 2. Use gphoto2 CLI Directly
```bash
# Test if libgphoto2 can access presets
gphoto2 --list-all-config | grep -i preset

# Try reading a config directly
gphoto2 --get-config "/main/settings/filmsim"

# Try writing
gphoto2 --set-config "/main/settings/preset_slot=1"
```

### 3. Check Helper Process Logs
```bash
# Run helper in foreground with stderr visible
./.build/debug/FujiPTPHelper 2>&1

# Then send commands from another terminal
echo '{"id":"1","command":{"readPresetSlot":{"index":1}}}' | \
  cat > /tmp/cmd.json && cat /tmp/cmd.json
```

## 📋 Success Criteria

### ✅ Full Success
- [ ] D18C no longer returns 0x2019 (DeviceBusy)
- [ ] Preset names are readable and writable
- [ ] All 18 preset properties can be set
- [ ] Slots 1-7 all work correctly
- [ ] Camera LCD shows saved presets
- [ ] Presets can actually be used on camera
- [ ] Works after USB reconnect

### ⚠️ Partial Success
- Some config paths work, others don't
- Some cameras have different path names
- Works but with occasional errors

### ❌ Failure
- Still get 0x2019 error (libusb issue still present)
- Config paths don't exist on this camera model
- New different errors appear

## 🔗 If Tests Fail: Next Options

### Option B: Fallback to Mixed Approach
- Use libgphoto2 for what works
- Use libusb for properties that don't work
- More complex but might handle camera variations

### Option C: Check Different Config Paths
Some Fuji cameras might use:
- `/main/settings/fuji_preset_slot` (instead of `preset_slot`)
- `/main/settings/scene` (alternative)
- Enumerate all paths: `gphoto2 --list-all-config`

### Option D: Raw PTP Through libgphoto2
Use libgphoto2's USB port interface to send raw PTP commands
- More complex than current approach
- But avoids libusb issues

### Option E: iOS Path Only
If macOS libgphoto2 still doesn't work:
- Skip macOS for now (use X100VIHelper libusb for RAF)
- Implement iOS ImageCaptureCore (likely works)
- Support macOS later when static libs are ready

## 📞 If All Else Fails

Document:
1. Exact error messages
2. Camera model and firmware
3. gphoto2 output: `gphoto2 --list-all-config | head -50`
4. FujiPTPHelper stderr output
5. libgphoto2 debug: `G_DEBUG=all gphoto2 --list-config`

Then reassess which of these is the actual issue:
1. Camera doesn't support libgphoto2 presets (X100VI specific?)
2. Config paths are different
3. libgphoto2 widget type detection failure
4. macOS libgphoto2 build/linking issue

## 🎓 Learning Outcomes from This Test

Successfully testing will teach us:
1. ✅ Whether libgphoto2 truly fixes the D18C issue on X100VI
2. ✅ What config paths are actually available
3. ✅ Whether type conversion logic works for all widgets
4. ✅ Camera behavior after preset writes
5. ✅ Stability of libgphoto2 approach vs raw libusb

## 📅 Timeline

- **Immediately**: Run Phase 1 & 2 (read tests) — 15 min
- **If Phase 2 passes**: Run Phase 3 (write test) — 10 min
- **If Phase 3 passes**: Run Phase 4 & 5 (advanced tests) — 20 min
- **Total test time**: ~45 minutes if all pass

## ✅ Completion Checklist

When testing is complete, update AGENTS.md with:
- [ ] Date and test results
- [ ] Camera model verified
- [ ] libgphoto2 version used
- [ ] Any camera-specific quirks discovered
- [ ] Status: WORKING / PARTIAL / BROKEN

---

**Status**: Ready for camera testing
**Last Updated**: 2026-07-05
**Next Action**: Connect camera and run Phase 1 test
