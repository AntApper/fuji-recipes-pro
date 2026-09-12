# Camera Connection Guide for macOS

## How to Connect Your Fuji X100VI

### Prerequisites
- Fuji X100VI (or X100V, X-T5, X-T30, X-T4)
- USB-C data cable (not charge-only)
- macOS 14+ with FujiRecipesMac app installed

### Step-by-Step Connection

#### 1. Prepare Your Camera
1. Turn on the camera
2. Go to **Menu → Setup → USB Connection → PTP** (not Mass Storage)
3. Set **USB Mass Storage** to **OFF** (if present)

#### 2. Kill macOS PTPCamera Daemon (Required)
macOS automatically grabs USB cameras through its PTPCamera service. You need to release it:

```bash
# In Terminal
sudo killall PTPCamera
```

Then **quit Photos, Image Capture, and Preview** if they're running.

#### 3. Connect USB Cable
1. Plug USB-C cable into camera and Mac
2. Wait ~3 seconds for connection

#### 3. Launch FujiRecipesMac
1. Open the FujiRecipesMac app
2. Go to the **Camera** tab (📷)
3. Click **"Connect Camera"**
4. Wait for connection (should take 1-3 seconds)

### What You'll See

#### If Connected Successfully:
- Green "Connected" status
- Camera model name displayed
- Live settings preview (Film Sim, DR, Highlight, Shadow)
- "Disconnect Camera" button

#### If Connection Fails:
- Red "Error" status with detailed error message
- The error will tell you exactly what went wrong and how to fix it

### Reading C1-C7 Preset Slots

Once connected, the app can read preset slots C1-C7 from the camera. This uses raw PTP commands:

1. Go to the **C1-C7** tab (🎛️)
2. The app displays current slot configurations
3. Click **"Load to Slot"** on any recipe to write it to a C1-C7 slot

### Troubleshooting

#### "No Fuji camera found"
- Ensure camera is powered ON
- Use a USB-C **data** cable (not charge-only)
- Camera USB mode must be set to PTP
- Quit Photos, Image Capture, Preview
- Run: `sudo killall PTPCamera`
- Disconnect and reconnect USB cable

#### "Camera connecting forever" or "Connection timed out"
- This is the PTPCamera daemon issue
- Run: `sudo killall PTPCamera`
- Quit all camera-related apps (Photos, Image Capture, Preview, Adobe Bridge)
- Wait 5 seconds
- Try again

#### "Failed to communicate with camera"
- PTPCamera is still blocking
- Check: `pgrep -a PTPCamera` — if any process shows, kill it
- On macOS 15+: May need to disable PTPCamera more aggressively
- Run the test script: `bash tools/test-camera-connection.sh`

#### Camera not showing in system_profiler
```bash
system_profiler SPUSBDataType | grep -i "fuji\|ptp\|x100"
```
If nothing shows, the USB connection isn't working. Try:
- Different USB-C cable
- Different USB port on Mac
- Different USB hub (if using one)

### Test Script
```bash
# Run the comprehensive camera connection test
bash tools/test-camera-connection.sh
```

This script will:
1. Check if a Fuji camera is connected
2. Kill PTPCamera if running
3. Verify libgphoto2 availability
4. Test gphoto2 CLI
5. Show camera details

### Supported Cameras

| Camera | USB VID:PID | PTP Code |
|--------|------------|----------|
| X100VI | 0x04CB:0x0305 | Supported |
| X100V  | 0x04CB:0x02E5 | Supported |
| X-T5   | 0x04CB:0x02E3 | Supported |
| X-T30  | 0x04CB:0x02E3 | Supported |
| X-T4   | 0x04CB:0x02E7 | Supported |

### Technical Details

The connection flow:
1. Kill macOS PTPCamera daemon
2. Initialize libgphoto2
3. Scan USB for Fuji camera (VID 0x04CB)
4. Create camera object + set USB port
5. Try `camera_init()` with 15s timeout
6. **Fallback**: If `camera_init()` times out, use raw PTP mode
   - Raw PTP mode supports C1-C7 preset slot read/write
   - Live settings reading has limited functionality in raw PTP mode

For raw PTP communication, we use:
- `GetDevicePropValue` (0x1015) — read property values
- `SetDevicePropValue` (0x1016) — write property values
- Properties 0xD18C-0xD1A5 for preset slots C1-C7
