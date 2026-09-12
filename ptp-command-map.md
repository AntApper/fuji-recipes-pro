# Fuji PTP Command Map

## Standard PTP Operations

- `0x1001` `GetDeviceInfo`
- `0x1002` `OpenSession`
- `0x1003` `CloseSession`
- `0x1014` `GetDevicePropDesc`
- `0x1015` `GetDevicePropValue`
- `0x1016` `SetDevicePropValue`

## Fuji Vendor Operations Found In Public Sources

- `0x9020` `FUJI_InitiateMovieCapture`
- `0x9021` `FUJI_TerminateMovieCapture`
- `0x9022` `FUJI_GetCapturePreview`
- `0x9026` `FUJI_SetFocusPoint`
- `0x9027` `FUJI_ResetFocusPoint`
- `0x902B` `FUJI_GetDeviceInfo`
- `0x902C` `FUJI_SetShutterSpeed`
- `0x902D` `FUJI_SetAperture`
- `0x902E` `FUJI_SetExposureCompensation`
- `0x9030` `FUJI_CancelInitiateCapture`
- `0x9040` `FUJI_FmSendObjectInfo`
- `0x9041` `FUJI_FmSendObject`
- `0x9042` `FUJI_FmSendPartialObject`

Some public source comments suggest certain Fuji operations may be WiFi-only, so all need validation on the X100VI over USB-C.

## Recipe-Relevant Fuji Device Properties

- `0xD001` Film Simulation
- `0xD002` Film Simulation Tune
- `0xD007` Dynamic Range Mode
- `0xD008` Color Mode
- `0xD00A` Color Space
- `0xD00B` White Balance Tune 1
- `0xD00C` White Balance Tune 2
- `0xD017` Color Temperature
- `0xD018` Quality
- `0xD01C` Noise Reduction
- `0xD023` Grain Effect
- `0xD029` Shadowing
- `0xD02E` Wide Dynamic Range
- `0xD200` Light Tune
- `0xD207` Priority Mode
- `0xD320` Highlight Tone
- `0xD321` Shadow Tone
- `0xD34C` Custom Setting

## Known Film Simulation Values From `libgphoto2`

- `1` PROVIA/Standard
- `2` Velvia/Vivid
- `3` ASTIA/Soft
- `4` PRO Neg.Hi
- `5` PRO Neg.Std
- `6` Black & White
- `7` Black & White + Yellow Filter
- `8` Black & White + Red Filter
- `9` Black & White + Green Filter
- `10` Sepia
- `11` Classic Chrome
- `12` ACROS
- `13` ACROS + Yellow Filter
- `14` ACROS + Red Filter
- `15` ACROS + Green Filter
- `16` ETERNA/Cinema
- `17` Classic Negative
- `18` ETERNA Bleach Bypass

## Open Mapping Work

- Confirm X100VI values for Reala Ace and Nostalgic Negative.
- Confirm exact data types and allowed ranges for X100VI recipe properties.
- Determine whether `0xD34C` selects, reads, or commits C1-C7 custom settings.
- Determine if slot writes require a separate commit operation after setting properties.
