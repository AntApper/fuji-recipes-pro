# X100VI / Fuji Recipe App Research

## Goal

Build a private iOS-first Fujifilm recipe manager for the X100VI that can store recipes, organize loadouts, and eventually write settings to camera custom slots over USB-C.

## Current Findings

- Fujifilm cameras use PTP over USB with vendor extension ID `0x0000000E`.
- Public `libgphoto2` data lists the X100VI as USB vendor/product `0x04cb:0x0305`.
- iOS exposes camera PTP command sending through `ImageCaptureCore.ICCameraDevice.requestSendPTPCommand`.
- `ImageCaptureCore` also exposes a PTP event handler path through `ptpEventHandler`.
- Recipe management UI and local storage are straightforward; direct camera slot writes need protocol proof.

## Supported Camera Target

- First target: Fujifilm X100VI
- Sensor generation: X-Trans V
- Initial recipe source: Fuji X Weekly X-Trans V index

## Current Local Data

- X-Trans V source index: `https://fujixweekly.com/fujifilm-x-trans-v-recipes/`
- Scraper: `tools/scrape_fujixweekly_xtransv.py`
- JSON output: `data/fujixweekly/x-trans-v-recipes.json`
- CSV output: `data/fujixweekly/x-trans-v-recipes.csv`
- Scrape report: `data/fujixweekly/scrape-report.md`

## Known Caveat

Fuji X Weekly recipe content is third-party copyrighted content. Keep scraped outputs private/personal unless permission or licensing is obtained.
