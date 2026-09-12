#!/usr/bin/env python3
"""Generate iOS app-ready JSON from normalized Fuji recipe data.

This script produces a single JSON file containing:
  1. All recipe data with PTP mappings pre-resolved
  2. Film simulation enum values
  3. White balance mode values
  4. Dynamic range values
  5. Grain effect values
  6. Preset slot (C1-C7) property definitions for the Swift app

Usage:
    python3 tools/export_ios_app_data.py
    python3 tools/export_ios_app_data.py --input data/fujixweekly/x-trans-v-recipes-normalized.json --output ios-app-data.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Film simulation enum (confirmed from FilmKit + libgphoto2)
# ---------------------------------------------------------------------------

FILM_SIM_ENUM = {
    "PROVIA": 1,
    "VELVIA": 2,
    "ASTIA": 3,
    "PRO_NEG_HI": 4,
    "PRO_NEG_STD": 5,
    "MONOCHROME": 6,
    "MONOCHROME_Y": 7,
    "MONOCHROME_R": 8,
    "MONOCHROME_G": 9,
    "SEPIA": 10,
    "CLASSIC_CHROME": 11,
    "ACROS": 12,
    "ACROS_Y": 13,
    "ACROS_R": 14,
    "ACROS_G": 15,
    "ETERNA": 16,
    "CLASSIC_NEGATIVE": 17,
    "ETERNA_BB": 18,
    "nostalgic_neg": 19,
    "reala_ace": 20,
}

# ---------------------------------------------------------------------------
# White balance mode enum (from FilmKit + libgphoto2)
# ---------------------------------------------------------------------------

WB_MODE_ENUM = {
    "as_shot": 0x0000,
    "auto": 0x0002,
    "daylight": 0x0004,
    "cloudy": 0x0006,
    "tungsten": 0x0006,  # Same as incandescent
    "fluorescent_1": 0x8001,
    "fluorescent_2": 0x8002,
    "fluorescent_3": 0x8003,
    "shade": 0x8006,
    "color_temperature": 0x8007,
    "ambience_priority": 0x8021,
    "underwater": 0x0008,
}

# ---------------------------------------------------------------------------
# Dynamic range values
# ---------------------------------------------------------------------------

DR_ENUM = {
    "auto": 0xFFFF,
    "100": 100,
    "200": 200,
    "400": 400,
}

# ---------------------------------------------------------------------------
# Grain effect values
# ---------------------------------------------------------------------------

GRAIN_ENUM = {
    "off": 0,
    "weak_small": 1,
    "strong_small": 2,
    "weak_large": 3,
    "strong_large": 4,
}

# ---------------------------------------------------------------------------
# Preset slot (C1-C7) PTP property definitions for Swift
# ---------------------------------------------------------------------------

PRESET_SLOT_PROPERTIES = {
    "slot": {"property": "0xD18C", "type": "uint32", "description": "Active preset slot (1-7)"},
    "name": {"property": "0xD18D", "type": "string", "description": "Preset display name"},
    "imageSize": {"property": "0xD18E", "type": "uint32", "description": "Image size index"},
    "imageQuality": {"property": "0xD18F", "type": "uint32", "description": "Image quality index"},
    "dynamicRange": {"property": "0xD190", "type": "uint32", "description": "DR raw percentage: 100, 200, 400"},
    "filmSimulation": {"property": "0xD192", "type": "uint32", "description": "Film sim enum 1-20"},
    "monoWarmCool": {"property": "0xD193", "type": "int32", "description": "Mono warm/cool ×10"},
    "monoMagentaGreen": {"property": "0xD194", "type": "int32", "description": "Mono mag/green ×10"},
    "grainEffect": {"property": "0xD195", "type": "uint32", "description": "Grain: 1=Off, 2=Weak, 3=Strong"},
    "colorChrome": {"property": "0xD196", "type": "uint32", "description": "Color Chrome: 1=Off, 2=Weak, 3=Strong"},
    "colorChromeFxBlue": {"property": "0xD197", "type": "uint32", "description": "Color Chrome FX Blue: 1=Off, 2=Weak, 3=Strong"},
    "smoothSkin": {"property": "0xD198", "type": "uint32", "description": "Smooth Skin: 1=Off, 2=Weak, 3=Strong"},
    "whiteBalance": {"property": "0xD199", "type": "uint32", "description": "WB mode enum"},
    "wbShiftRed": {"property": "0xD19A", "type": "int32", "description": "WB red shift -9 to +9"},
    "wbShiftBlue": {"property": "0xD19B", "type": "int32", "description": "WB blue shift -9 to +9"},
    "colorTemp": {"property": "0xD19C", "type": "uint32", "description": "Color temp Kelvin (0=auto)"},
    "highlightTone": {"property": "0xD19D", "type": "int32", "description": "Highlight tone ×10"},
    "shadowTone": {"property": "0xD19E", "type": "int32", "description": "Shadow tone ×10"},
    "color": {"property": "0xD19F", "type": "int32", "description": "Film sim tune ×10"},
    "sharpness": {"property": "0xD1A0", "type": "int32", "description": "Sharpness ×10"},
    "highIsoNr": {"property": "0xD1A1", "type": "uint32", "description": "High ISO NR sentinel (0x8000)"},
    "clarity": {"property": "0xD1A2", "type": "int32", "description": "Clarity ×10"},
    "longExpNr": {"property": "0xD1A3", "type": "uint32", "description": "Long exp NR: 0=Off, 1=On"},
    "colorSpace": {"property": "0xD1A4", "type": "uint32", "description": "Color space: 1=sRGB, 2=AdobeRGB"},
}

# ---------------------------------------------------------------------------
# Active shooting property definitions
# ---------------------------------------------------------------------------

ACTIVE_PROPERTIES = {
    "filmSimulation": {"property": "0xD001", "type": "uint32", "description": "Film Simulation"},
    "color": {"property": "0xD002", "type": "int32", "description": "Film Sim Tune (-40 to +40, step 10)"},
    "dynamicRange": {"property": "0xD007", "type": "uint32", "description": "DR Mode (0xFFFF=Auto, 100, 200, 400)"},
    "whiteBalance": {"property": "0x5005", "type": "uint32", "description": "WB mode"},
    "wbShiftRed": {"property": "0xD00B", "type": "int32", "description": "WB Tune 1 (-9 to +9)"},
    "wbShiftBlue": {"property": "0xD00C", "type": "int32", "description": "WB Tune 2 (-9 to +9)"},
    "colorTemp": {"property": "0xD017", "type": "uint32", "description": "Color Temp (K)"},
    "highIsoNr": {"property": "0xD01C", "type": "uint32", "description": "Noise Reduction (0 to 32768, step 4096)"},
    "grainEffect": {"property": "0xD023", "type": "uint32", "description": "Grain (1-5)"},
    "dRangePriority": {"property": "0xD02E", "type": "uint32", "description": "Wide Dynamic Range"},
    "highlight": {"property": "0xD320", "type": "int32", "description": "Highlight Tone (-20 to +40, step 5)"},
    "shadow": {"property": "0xD321", "type": "int32", "description": "Shadow Tone (-20 to +40, step 5)"},
    "iso": {"property": "0x500F", "type": "int32", "description": "ISO (64-51200, -1/-2/-3 auto)"},
    "sharpness": {"property": "0x5015", "type": "int32", "description": "Sharpness (-40 to +40, step 10)"},
    "exposureCompensation": {"property": "0x5010", "type": "int32", "description": "Exposure Bias (-5000 to +5000, step 333)"},
}

# ---------------------------------------------------------------------------
# Preset-to-active encoding conversion
# ---------------------------------------------------------------------------

def preset_to_active_encoding(setting: str, value: float | int) -> float | int:
    """Convert a preset property value to its active property encoding.

    Different settings use different encodings in presets vs active properties:
    - Color/Highlight/Shadow/Sharpness/Clarity: preset uses ×10, active uses raw values
    - Color Chrome: preset uses 1=Off/2=Weak/3=Strong, active uses -40 to +40 (step 10)
    - Grain: preset uses 1=Off/2=Weak/3=Strong, active uses 1-5 flat enum
    - Tone values: preset uses ×10, active uses step 5 (-20 to +40)
    """
    match setting:
        case "color":
            # Preset: ×10 encoding (e.g. +2 → 20) → Active: raw (-40 to +40, step 10)
            return int(value) // 10
        case "sharpness":
            return int(value) // 10
        case "clarity":
            return int(value) // 10
        case "highlightTone":
            return round(int(value) / 10 * 5)  # ×10 → step 5
        case "shadowTone":
            return round(int(value) / 10 * 5)
        case "colorChrome":
            # Preset: 1=Off, 2=Weak, 3=Strong → Active: -40 to +40 step 10
            mapping = {1: 0, 2: 10, 3: 30}
            return mapping.get(int(value), value)
        case "grainEffect":
            # Preset: 1=Off, 2=Weak, 3=Strong → Active: 1=Off, 2=WeakS, 3=StrongS, 4=WeakL, 5=StrongL
            return value  # Different encoding, keep as-is for now
        case _:
            return value


def normalize_recipe_for_ios(recipe: dict) -> dict:
    """Normalize a single recipe for iOS app consumption.

    Returns a recipe dict with:
    - filmSimEnum: integer film sim value (for PTP writes)
    - wbModeEnum: integer WB mode value
    - settings: original string settings
    - ptpSettings: pre-converted PTP values ready for camera writes
    - presetSettings: preset slot (C1-C7) ready values
    """
    settings = recipe.get("settings", {})
    normalized = recipe.get("normalizedSettings", {})

    # Extract film sim enum
    film_sim_raw = settings.get("filmSimulation", "")
    film_sim_norm = normalized.get("filmSimulation", {})
    film_sim_enum = film_sim_norm.get("ptpValue")

    # Extract WB info
    wb_raw = settings.get("whiteBalance", "")
    wb_norm = normalized.get("whiteBalance", {})
    wb_kelvin = wb_norm.get("kelvin")
    wb_shift_r = wb_norm.get("wbShiftRed")
    wb_shift_b = wb_norm.get("wbShiftBlue")

    # Extract DR
    dr_raw = settings.get("dynamicRange", "")
    dr_norm = normalized.get("dynamicRange", {})
    dr_enum = dr_norm.get("ptpValue")
    dr_slug = dr_norm.get("slug", "")

    # Extract grain
    grain_raw = settings.get("grainEffect", "")
    grain_norm = normalized.get("grainEffect", {})
    grain_enum = grain_norm.get("ptpValue")

    # Build PTP settings
    ptp_settings = {}
    preset_settings = {}

    # Film simulation
    if film_sim_enum is not None:
        ptp_settings["filmSimulation"] = film_sim_enum
        preset_settings["filmSimulation"] = film_sim_enum

    # Dynamic range — different encoding for active vs preset
    if dr_enum is not None:
        # Active: 0xFFFF (auto), 100, 200, 400
        dr_active_map = {1: 100, 2: 200, 3: 400, 4: 640}
        dr_active = dr_active_map.get(dr_enum, dr_enum)
        ptp_settings["dynamicRange"] = dr_active
        # Preset: raw percentage (100, 200, 400)
        preset_settings["dynamicRange"] = dr_active  # Same values

    # Grain effect — same value for both
    if grain_enum is not None:
        ptp_settings["grainEffect"] = grain_enum
        preset_settings["grainEffect"] = grain_enum

    # Color Chrome Effect
    cc_norm = normalized.get("colorChromeEffect", {})
    cc_val = cc_norm.get("ptpValue")
    if cc_val is not None:
        ptp_settings["colorChromeEffect"] = cc_val
        # Preset uses 1=Off, 2=Weak, 3=Strong (same as active for this field)
        preset_settings["colorChromeEffect"] = cc_val

    # Color Chrome FX Blue
    ccfb_norm = normalized.get("colorChromeFxBlue", {})
    ccfb_val = ccfb_norm.get("ptpValue")
    if ccfb_val is not None:
        ptp_settings["colorChromeFxBlue"] = ccfb_val
        preset_settings["colorChromeFxBlue"] = ccfb_val

    # Color (Film Sim Tune)
    color_norm = normalized.get("color", {})
    color_parsed = color_norm.get("parsed")
    if color_parsed is not None:
        ptp_settings["color"] = color_parsed * 10  # Raw → ×10 for PTP
        preset_settings["color"] = color_parsed * 10

    # Highlight
    highlight_norm = normalized.get("highlight", {})
    highlight_parsed = highlight_norm.get("parsed")
    if highlight_parsed is not None:
        ptp_settings["highlight"] = highlight_parsed  # Already in correct range
        preset_settings["highlightTone"] = highlight_parsed * 10  # ×10 for preset

    # Shadow
    shadow_norm = normalized.get("shadow", {})
    shadow_parsed = shadow_norm.get("parsed")
    if shadow_parsed is not None:
        ptp_settings["shadow"] = shadow_parsed
        preset_settings["shadowTone"] = shadow_parsed * 10

    # Sharpness
    sharp_norm = normalized.get("sharpness", {})
    sharp_parsed = sharp_norm.get("parsed")
    if sharp_parsed is not None:
        ptp_settings["sharpness"] = sharp_parsed  # Already in correct range
        preset_settings["sharpness"] = sharp_parsed * 10

    # Clarity
    clarity_norm = normalized.get("clarity", {})
    clarity_parsed = clarity_norm.get("parsed")
    if clarity_parsed is not None:
        preset_settings["clarity"] = clarity_parsed * 10

    # High ISO NR
    nr_norm = normalized.get("highIsoNr", {})
    nr_parsed = nr_norm.get("parsed")
    if nr_parsed is not None:
        ptp_settings["highIsoNr"] = (nr_parsed + 4) * 4096  # -4 to +4 → 0 to 32768
        preset_settings["highIsoNr"] = 0x8000  # Sentinel value for presets

    # Exposure Compensation
    ec_norm = normalized.get("exposureCompensation", {})
    ec_ev = ec_norm.get("evValue")
    if ec_ev is not None:
        ptp_settings["exposureCompensation"] = round(ec_ev * 3) * 333

    # White Balance
    if wb_kelvin:
        ptp_settings["colorTemp"] = wb_kelvin
        preset_settings["colorTemp"] = wb_kelvin
    if wb_shift_r is not None:
        ptp_settings["wbShiftRed"] = wb_shift_r
        preset_settings["wbShiftRed"] = wb_shift_r
    if wb_shift_b is not None:
        ptp_settings["wbShiftBlue"] = wb_shift_b
        preset_settings["wbShiftBlue"] = wb_shift_b
    if wb_norm.get("wbMode"):
        wb_mode = wb_norm.get("wbMode")
        # Map string WB mode to enum
        for name, enum_val in WB_MODE_ENUM.items():
            if name in wb_mode:
                ptp_settings["whiteBalance"] = enum_val
                preset_settings["whiteBalance"] = enum_val
                break

    return {
        "id": recipe.get("id"),
        "name": recipe.get("name"),
        "sensorGeneration": recipe.get("sensorGeneration"),
        "filmSimulation": film_sim_raw,
        "filmSimEnum": film_sim_enum,
        "settings": settings,
        "ptpSettings": ptp_settings,
        "presetSettings": preset_settings,
        "sourceUrl": recipe.get("sourceUrl"),
        "previewImageUrl": recipe.get("previewImageUrl"),
        "imageUrls": recipe.get("imageUrls", []),
        "date": recipe.get("date"),
        "compatibleCameras": recipe.get("compatibleCameras", []),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Export iOS app-ready recipe data.")
    parser.add_argument("--input", default=None, help="Input normalized JSON path (auto-detect if not set)")
    parser.add_argument("--output", "-o", default="ios-app-data.json", help="Output JSON path")
    parser.add_argument("--macos-resources", default="FujiRecipesMac/macos/Resources/recipes-data.json", help="Path to macOS app recipes-data.json")
    args = parser.parse_args()

    # Auto-detect input path
    if args.input is None:
        default = Path("data/fujixweekly/x-trans-v-recipes-normalized.json")
        alt = Path("data/fujixweekly/x-trans-v-recipes.json")
        args.input = str(default) if default.exists() else str(alt)

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        return 1

    with open(input_path) as f:
        data = json.load(f)

    recipes = data.get("recipes", [])
    ios_recipes = [
        normalize_recipe_for_ios(r) for r in recipes
        if r.get("sensorGeneration") == "X-Trans V"
        and "X100VI" in (r.get("compatibleCameras") or [])
    ]

    output = {
        "version": "1.0",
        "exportDate": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat(),
        "camera": {
            "model": "X100VI",
            "sensorGeneration": "X-Trans V",
            "usbVendorId": "0x04CB",
            "usbProductId": "0x0305",
            "ptpVendorExtensionId": "0x0000000E",
        },
        "filmSimulationEnum": {k: v for k, v in FILM_SIM_ENUM.items()},
        "wbModeEnum": {k: v for k, v in WB_MODE_ENUM.items()},
        "dynamicRangeEnum": {k: v for k, v in DR_ENUM.items()},
        "grainEffectEnum": {k: v for k, v in GRAIN_ENUM.items()},
        "activeProperties": ACTIVE_PROPERTIES,
        "presetSlotProperties": PRESET_SLOT_PROPERTIES,
        "recipeCount": len(ios_recipes),
        "recipes": ios_recipes,
    }

    json_text = json.dumps(output, indent=2, ensure_ascii=False) + "\n"

    output_path = Path(args.output)
    output_path.write_text(json_text, encoding="utf-8")
    print(f"Wrote {output_path}")
    print(f"  {len(ios_recipes)} recipes with PTP mappings")

    macos_path = Path(args.macos_resources)
    macos_path.parent.mkdir(parents=True, exist_ok=True)
    macos_path.write_text(json_text, encoding="utf-8")
    print(f"Wrote {macos_path}")

    # Print summary
    with_film_sim = sum(1 for r in ios_recipes if r.get("filmSimEnum") is not None)
    with_ptp = sum(1 for r in ios_recipes if r.get("ptpSettings"))
    with_preset = sum(1 for r in ios_recipes if r.get("presetSettings"))
    print(f"  Film sim enum mapped: {with_film_sim}/{len(ios_recipes)}")
    print(f"  PTP settings available: {with_ptp}/{len(ios_recipes)}")
    print(f"  Preset slot settings available: {with_preset}/{len(ios_recipes)}")
    print(f"  Filtered to X-Trans V + X100VI: {len(ios_recipes)} recipes")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
