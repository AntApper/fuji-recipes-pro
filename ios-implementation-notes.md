# iOS Implementation Notes

## Likely Framework

Use `ImageCaptureCore` for USB camera discovery and PTP command transport.

Relevant `ICCameraDevice` APIs:

- `requestOpenSession`
- `requestCloseSession`
- `requestSendPTPCommand`
- `ptpEventHandler`
- `requestReadDataFromFile`
- `requestDownloadFile`

## PTP Command Encoding

`requestSendPTPCommand` takes a PTP command container as `NSData` and optional outgoing data as `NSData`.

The first prototype should implement helpers for:

- Little-endian command packing
- Operation code
- Transaction ID
- Up to five parameters
- Data phase send/receive handling
- Response code parsing

## Initial Probe Flow

1. Discover USB camera.
2. Confirm vendor/product IDs are `0x04cb:0x0305` or model string reports X100VI.
3. Open PTP session.
4. Call `GetDeviceInfo`.
5. Call Fuji `0x902B` if advertised/supported.
6. Dump available operations, events, and device properties.
7. Read safe properties, including battery, film simulation, highlight, shadow, and custom setting.
8. Attempt reversible writes only after values are known.

## App Store Considerations

- Use public Apple APIs only.
- Avoid private USB APIs.
- Explain camera USB access clearly in app UI.
- Keep error handling conservative: never write without explicit user confirmation.
