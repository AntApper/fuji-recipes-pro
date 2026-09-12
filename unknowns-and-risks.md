# Unknowns And Risks

## C1-C7 Slot Writes

The biggest unknown is how Fujifilm stores and commits custom recipe slots. `0xD34C` is labeled `CustomSetting`, but public sources do not prove whether it selects active custom slot, reads a slot, writes a slot, or only reports state.

Expected research path:

- Read `0xD34C` while manually switching C1-C7 on camera.
- Change active recipe values and observe whether C slot values change.
- Look for event/property changes after manually saving a recipe on the camera.
- Try writing only to safe, reversible values first.

## RAF Rendering

Public source confirms Fuji RAF object format `0xB103`, but not the full in-camera RAW conversion command sequence.

Possible leads:

- `0x9040` `FUJI_FmSendObjectInfo`
- `0x9041` `FUJI_FmSendObject`
- `0x9042` `FUJI_FmSendPartialObject`

Need real-device testing or USB trace comparison.

## Recipe Data Quality

The current scraper captures recipe-page records and flags multi-recipe pages. Pages that contain multiple recipes in one article need either manual splitting or a more advanced block parser.

Current flagged pages are listed in `data/fujixweekly/scrape-report.md`.

## Licensing

Fuji X Weekly content should remain private unless permission/licensing is obtained.
