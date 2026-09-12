#!/usr/bin/env python3
"""Normalize Fuji recipe setting values into camera-ready, PTP-mapped structures.

Reads the scraped recipe JSON, normalizes each setting value, and produces:
  1. A normalized JSON with PTP property hints per setting.
  2. A summary of unmapped or ambiguous values for manual review.

Usage:
    python3 tools/normalize_settings.py
    python3 tools/normalize_settings.py --input data/fujixweekly/x-trans-v-recipes.json
    python3 tools/normalize_settings.py --output data/fujixweekly/x-trans-v-recipes-normalized.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

INPUT_PATH = Path(__file__).resolve().parents[1] / "data" / "fujixweekly" / "x-trans-v-recipes.json"
OUTPUT_PATH = INPUT_PATH.with_stem("x-trans-v-recipes-normalized")


# ---------------------------------------------------------------------------
# Film Simulation
# ---------------------------------------------------------------------------

FILM_SIM_MAP: dict[str, int] = {
    # X-Trans IV/V shared — confirmed from libgphoto2 + FilmKit
    "provia": 1,
    "provia/std": 1,
    "standard": 1,
    "velvia": 2,
    "vivid": 2,
    "astia": 3,
    "soft": 3,
    "pro neg.hi": 4,
    "pro neg hi": 4,
    "proneg.hi": 4,
    "pro neg.std": 5,
    "pro neg std": 5,
    "proneg.std": 5,
    "black & white": 6,
    "monochrome": 6,
    "bw": 6,
    "b&w": 6,
    "bw + yellow": 7,
    "b&w + yellow filter": 7,
    "black & white + yellow filter": 7,
    "bw + red": 8,
    "b&w + red filter": 8,
    "black & white + red filter": 8,
    "bw + green": 9,
    "b&w + green filter": 9,
    "black & white + green filter": 9,
    "monochrome+g": 9,
    "monochrome+y": 7,
    "monochrome+r": 8,
    "sepia": 10,
    "classic chrome": 11,
    "acros": 12,
    "acros + yellow": 13,
    "acros + yellow filter": 13,
    "acros + red": 14,
    "acros + red filter": 14,
    "acros + green": 15,
    "acros + green filter": 15,
    "acros+g": 15,
    "acros+y": 13,
    "acros+r": 14,
    "acros (including +ye, +r, or +g)": 12,
    "acros (or acros+y, acros+r, acros+g)": 12,
    "any (see below)": None,  # Universal recipe - film sim varies
    "any": None,  # Universal recipe
    "ETERNA": 16,
    "eterna": 16,
    "cinema": 16,
    "ETERNA/Cinema": 16,
    "eterna/cinema": 16,
    "classic negative": 17,
    "classic neg": 17,
    "ETERNA Bleach Bypass": 18,
    "eterna bleach bypass": 18,
    "ETERNA BB": 18,
    "eterna bb": 18,
    "cinema bleached bypass": 18,
    # X-Trans V only — confirmed from FilmKit enums (eggricesoy/filmkit)
    "reala ace": 20,
    "nostalgic neg": 19,
    "nostalgic neg.": 19,
    "nostalgic negative": 19,
    "nostalgic negative.": 19,
}

# ---------------------------------------------------------------------------
# Dynamic Range / D-Range Priority
# ---------------------------------------------------------------------------

DR_MAP: dict[str, int | None] = {
    "dr100": 100,
    "dr200": 200,
    "dr400": 400,
    "dr640": 640,
    "dr-auto": None,  # Camera decides
    # D-Range Priority — values TBD
    "dr-p off": None,
    "dr-p weak": None,
    "dr-p medium": None,
    "dr-p strong": None,
    "d-range priority (dr-p) auto": None,
}

# ---------------------------------------------------------------------------
# Grain Effect
# ---------------------------------------------------------------------------

GRAIN_MAP: dict[str, int | None] = {
    "off": 0,
    "weak, small": 1,
    "weak, large": 2,
    "strong, small": 3,
    "strong, large": 4,
}

# ---------------------------------------------------------------------------
# Color Chrome Effect / Color Mode
# ---------------------------------------------------------------------------

COLOR_CHROME_MAP: dict[str, int | None] = {
    "off": 0,
    "weak": 1,
    "medium": 2,
    "strong": 3,
}

# Color Chrome FX Blue — property TBD
COLOR_CHROME_FX_BLUE_MAP: dict[str, int | None] = {
    "off": 0,
    "weak": 1,
    "strong": 2,
}

# ---------------------------------------------------------------------------
# Numeric settings (range -4 to +4)
# ---------------------------------------------------------------------------

NUMERIC_SETTING_KEYS = {
    "color",
    "highlight",
    "shadow",
    "sharpness",
    "highisonr",
    "clarity",
}

# ---------------------------------------------------------------------------
# White Balance parsing
# ---------------------------------------------------------------------------

WB_KELVIN_RE = re.compile(r"(\d{3,4})\s*k", re.I)
WB_SHIFT_RE = re.compile(
    r"([\+\-]?\s*\d+)\s*red\s*&\s*([\+\-]?\s*\d+)\s*blue",
    re.I,
)

WB_MODE_MAP: dict[str, str] = {
    "auto": "auto",
    "auto ambience priority": "auto-ambience",
    "daylight": "daylight",
    "cloudy": "cloudy",
    "tungsten": "tungsten",
    "fluorescent h": "fluorescent-h",
    "fluorescent l": "fluorescent-l",
    "fluorescent b": "fluorescent-b",
    "fluorescent w": "fluorescent-w",
    "fluorescent": "fluorescent",
}


def _slug(value: str) -> str:
    """Lowercase, strip, normalize whitespace, remove trailing period."""
    v = re.sub(r"\s+", " ", value.strip().lower())
    v = v.rstrip(". ")
    return v


def _parse_signed_int(value: str) -> int | float | None:
    """Parse signed integer or fractional value from strings like '+2', '-4', '+2/3'."""
    value = value.strip().strip("*")
    # Handle fractional notation like +2/3, -1 2/3
    result = _parse_fraction(value)
    if result is not None:
        return result
    if value in ("0",):
        return 0
    m = re.match(r"^([\+\-])?\s*(\d+)$", value)
    if m:
        sign = -1 if m.group(1) == "-" else 1
        return sign * int(m.group(2))
    return None


# ---------------------------------------------------------------------------
# Normalization functions per setting key
# ---------------------------------------------------------------------------

def normalize_film_simulation(raw: str) -> dict[str, Any]:
    slug = _slug(raw)
    ptp_value = FILM_SIM_MAP.get(slug)
    return {
        "raw": raw,
        "slug": slug,
        "ptpProperty": "0xD001",
        "ptpValue": ptp_value,
        "needsProbe": ptp_value is None,
    }


def normalize_dynamic_range(raw: str) -> dict[str, Any]:
    slug = _slug(raw)
    ptp_value = DR_MAP.get(slug)
    return {
        "raw": raw,
        "slug": slug,
        "ptpProperty": "0xD007",
        "ptpValue": ptp_value,
        "needsProbe": ptp_value is None or slug.startswith("dr-p"),
    }


def normalize_grain_effect(raw: str) -> dict[str, Any]:
    slug = _slug(raw)
    ptp_value = GRAIN_MAP.get(slug)
    # Active property (0xD023) uses 1=Off, 2=WeakS, 3=StrongS, 4=WeakL, 5=StrongL
    # But the scraper maps "off" → 0; adjust to match PTP spec
    if ptp_value is not None and slug == "off":
        ptp_value = 1  # PTP active property uses 1 for Off
    return {
        "raw": raw,
        "slug": slug,
        "ptpProperty": "0xD023",
        "ptpValue": ptp_value,
        "needsProbe": ptp_value is None,
    }


def normalize_color_chrome_effect(raw: str) -> dict[str, Any]:
    slug = _slug(raw)
    ptp_value = COLOR_CHROME_MAP.get(slug)
    return {
        "raw": raw,
        "slug": slug,
        "ptpProperty": "0xD008",
        "ptpValue": ptp_value,
        "needsProbe": ptp_value is None,
    }


def normalize_color_chrome_fx_blue(raw: str) -> dict[str, Any]:
    slug = _slug(raw)
    ptp_value = COLOR_CHROME_FX_BLUE_MAP.get(slug)
    return {
        "raw": raw,
        "slug": slug,
        "ptpProperty": "TBD",
        "ptpValue": ptp_value,
        "needsProbe": True,  # Property itself is unknown
    }


def normalize_white_balance(raw: str) -> dict[str, Any]:
    slug = _slug(raw)
    kelvin_match = WB_KELVIN_RE.search(raw)
    shift_match = WB_SHIFT_RE.search(raw)

    kelvin = int(kelvin_match.group(1)) if kelvin_match else None
    shift_red = _parse_signed_int(shift_match.group(1)) if shift_match else None
    shift_blue = _parse_signed_int(shift_match.group(2)) if shift_match else None

    # Determine WB mode
    wb_mode = "unknown"
    for label, mode in WB_MODE_MAP.items():
        if label in slug:
            wb_mode = mode
            break

    return {
        "raw": raw,
        "slug": slug,
        "kelvin": kelvin,
        "wbMode": wb_mode,
        "wbShiftRed": shift_red,
        "wbShiftBlue": shift_blue,
        "ptpProperties": {
            "colorTemp": "0xD017" if kelvin else None,
            "wbTune1": "0xD00B",  # Red shift
            "wbTune2": "0xD00C",  # Blue shift
        },
        "ptpValues": {
            "colorTemp": kelvin,
            "wbShiftRed": shift_red,
            "wbShiftBlue": shift_blue,
        },
        "needsProbe": wb_mode == "unknown",
    }


def normalize_numeric(raw: str, setting_key: str, ptp_property: str) -> dict[str, Any]:
    value = _parse_signed_int(raw)
    # Highlight/Shadow use step 5 from -20 to +40 (12 discrete values)
    # Recipe values are -4 to +4; we keep them as-is for the app layer
    # and convert at PTP write time
    return {
        "raw": raw,
        "parsed": value,
        "ptpProperty": ptp_property,
        "ptpValue": value,
        "needsProbe": value is None,
        "inRange": -4 <= value <= 4 if value is not None else None,
    }


def normalize_clarity(raw: str) -> dict[str, Any]:
    return normalize_numeric(raw, "clarity", "TBD")  # Property unknown


def normalize_iso(raw: str) -> dict[str, Any]:
    slug = _slug(raw)
    # Extract max ISO from "Auto, up to ISO 6400"
    iso_match = re.search(r"iso\s*(\d+)", slug)
    max_iso = int(iso_match.group(1)) if iso_match else None
    return {
        "raw": raw,
        "slug": slug,
        "maxIso": max_iso,
        "ptpProperty": "0xD018",  # Quality — may not be ISO limit
        "needsProbe": True,
    }


def normalize_exposure_compensation(raw: str) -> dict[str, Any]:
    # raw might be None if the recipe doesn't have exposure compensation
    if raw is None or not raw.strip():
        return {
            "raw": raw or "",
            "slug": "",
            "ptpProperty": "0x5010",
            "ptpOperation": "0x902E",
            "ptpValue": None,
            "evValue": None,
            "needsProbe": False,  # Not unmapped, just absent
            "absent": True,
        }
    slug = _slug(raw)
    # Extract a single value from ranges like "0 to +2/3" or "+1/3 to +1"
    # Use the midpoint for a reasonable default
    midpoint = _parse_exposure_range(raw)
    # PTP: 0x5010, range -5000 to +5000, step 333 (1/3 EV)
    ptp_value = _ev_to_ptp(midpoint) if midpoint is not None else None
    return {
        "raw": raw,
        "slug": slug,
        "ptpProperty": "0x5010",
        "ptpOperation": "0x902E",  # Vendor operation, not property
        "ptpValue": ptp_value,
        "evValue": midpoint,
        "needsProbe": midpoint is None,
    }


# ---------------------------------------------------------------------------
# Exposure compensation range parsing
# ---------------------------------------------------------------------------

_EV_RE = re.compile(
    r"(\d+\s*\d+/\d+|\d+/\d+|\d+)"
    r"\s*(?:ev)?",
    re.I,
)


def _parse_fraction(s: str) -> float | None:
    """Parse a fraction string like '+2/3', '-1 2/3', '1', '+1' into float.

    Also handles hyphenated EV notation like '+1-1/3' which means '+1 1/3' (i.e., 4/3 EV).
    """
    s = s.strip()
    # Handle hyphenated notation like "+1-1/3" → "+1 1/3" (common in recipe blogs)
    m = re.match(r"([\+\-]?)(\d+)-(\d+)/(\d+)$", s)
    if m:
        sign = 1 if m.group(1) in ("+", "") else -1
        return sign * (float(m.group(2)) + float(m.group(3)) / float(m.group(4)))
    # Handle leading +/-
    sign = 1
    if s.startswith("+"):
        s = s[1:]
    elif s.startswith("-"):
        sign = -1
        s = s[1:].strip()
    # Mixed fraction: "1 2/3"
    m = re.match(r"(\d+)\s+(\d+)/(\d+)$", s)
    if m:
        return sign * (float(m.group(1)) + float(m.group(2)) / float(m.group(3)))
    # Simple fraction: "2/3"
    m = re.match(r"(\d+)/(\d+)$", s)
    if m:
        return sign * float(m.group(1)) / float(m.group(2))
    # Integer
    m = re.match(r"(\d+)$", s)
    if m:
        return sign * float(m.group(1))
    return None


def _parse_exposure_range(raw: str) -> float | None:
    """Parse exposure compensation range like '0 to +2/3' and return midpoint as EV.

    Handles:
      "0 to +2/3" → 0.33
      "+1/3 to +1" → 0.83
      "-1/3 to +2/3" → 0.17
      "+1" → 1.0
      "-2/3 to 0" → -0.33
      "+2/3 to + 1 1/3" → 1.0 (handles extra space in "+ 1 1/3")
    """
    if raw is None:
        return None
    raw = raw.lower().strip()
    # Strip trailing notes like "(typically)" or "- hiroshi says..."
    raw = re.sub(r"\(.*?\).*", "", raw).strip()
    # Normalize spaces around numbers: "+ 1 1/3" → "+1 1/3"
    raw = re.sub(r"\+\s+(\d)\s+", r"+\1 ", raw)
    raw = re.sub(r"-\s+(\d)\s+", r"-\1 ", raw)

    parts = re.split(r"\s*to\s*", raw)
    if len(parts) != 2:
        return _parse_fraction(raw)

    start = parts[0].strip()
    end = parts[1].strip()

    ev_start = _parse_fraction(start)
    ev_end = _parse_fraction(end)
    if ev_start is not None and ev_end is not None:
        return (ev_start + ev_end) / 2.0

    return None


def _ev_to_ptp(ev: float | None) -> int | None:
    """Convert EV value to PTP exposure compensation value.

    PTP 0x5010: range -5000 to +5000, step 333 (1/3 EV)
    Formula: round(ev / (1/3)) * 333 = round(ev * 3) * 333
    """
    if ev is None:
        return None
    return round(ev * 3) * 333


# ---------------------------------------------------------------------------
# Dispatch table
# ---------------------------------------------------------------------------

SETTING_NORMALIZERS: dict[str, Any] = {
    "filmsimulation": (normalize_film_simulation, "0xD001"),
    "dynamicrange": (normalize_dynamic_range, "0xD007"),
    "drangepriority": (normalize_dynamic_range, "0xD007"),
    "graineffect": (normalize_grain_effect, "0xD023"),
    "colorchromeeffect": (normalize_color_chrome_effect, "0xD008"),
    "colorchromefxblue": (normalize_color_chrome_fx_blue, "TBD"),
    "whitebalance": (normalize_white_balance, "0xD00B/0xD00C/0xD017"),
    "highlight": (lambda r: normalize_numeric(r, "highlight", "0xD320"), "0xD320"),
    "shadow": (lambda r: normalize_numeric(r, "shadow", "0xD321"), "0xD321"),
    "color": (lambda r: normalize_numeric(r, "color", "0xD002"), "0xD002"),
    "sharpness": (lambda r: normalize_numeric(r, "sharpness", "0xD029"), "0xD029"),
    "highisonr": (lambda r: normalize_numeric(r, "highIsoNr", "0xD01C"), "0xD01C"),
    "clarity": (normalize_clarity, "TBD"),
    "iso": (normalize_iso, "0xD018"),
    "exposurecompensation": (normalize_exposure_compensation, "0x902E"),
}


def normalize_setting(key: str, value: str) -> dict[str, Any]:
    """Normalize a single recipe setting key/value pair."""
    normalized_key = re.sub(r"[-\s]", "", key).lower()
    if normalized_key not in SETTING_NORMALIZERS:
        return {
            "raw": value,
            "key": key,
            "slug": normalized_key,
            "ptpProperty": None,
            "ptpValue": None,
            "needsProbe": True,
            "unmapped": True,
        }
    normalizer, _ = SETTING_NORMALIZERS[normalized_key]
    result = normalizer(value)
    result["key"] = key
    return result


def normalize_recipe(recipe: dict[str, Any]) -> dict[str, Any]:
    """Normalize all settings for a recipe, returning the full recipe with normalized block."""
    settings = recipe.get("settings", {})
    normalized_settings: dict[str, dict[str, Any]] = {}
    needs_probe_count = 0
    unmapped_count = 0

    for key, value in settings.items():
        norm = normalize_setting(key, value)
        normalized_settings[key] = norm
        if norm.get("needsProbe"):
            needs_probe_count += 1
        if norm.get("unmapped"):
            unmapped_count += 1

    return {
        **recipe,
        "normalizedSettings": normalized_settings,
        "normalizationSummary": {
            "totalSettings": len(settings),
            "needsProbe": needs_probe_count,
            "unmapped": unmapped_count,
            "fullyMapped": len(settings) - needs_probe_count - unmapped_count,
        },
    }


# ---------------------------------------------------------------------------
# Summary generation
# ---------------------------------------------------------------------------

def generate_summary(recipes: list[dict[str, Any]]) -> str:
    """Generate a human-readable normalization summary."""
    all_raw_values: dict[str, set[str]] = {}
    probe_needed: list[dict[str, str]] = []
    unmapped: list[dict[str, str]] = []

    for recipe in recipes:
        for key, norm in (recipe.get("normalizedSettings") or {}).items():
            slug_key = norm.get("slug", key)
            raw = norm.get("raw", "")
            all_raw_values.setdefault(slug_key, set()).add(raw)
            if norm.get("needsProbe") and not norm.get("unmapped"):
                probe_needed.append({
                    "recipe": recipe.get("name", "?"),
                    "setting": key,
                    "value": raw,
                    "ptpProperty": norm.get("ptpProperty") or norm.get("ptpProperties", {}),
                })
            if norm.get("unmapped"):
                unmapped.append({
                    "recipe": recipe.get("name", "?"),
                    "setting": key,
                    "value": raw,
                })

    lines = [
        "# Normalization Summary",
        "",
        f"Total recipes: {len(recipes)}",
        "",
        "## Distinct Raw Values Per Setting",
        "",
    ]
    for key in sorted(all_raw_values.keys()):
        values = sorted(all_raw_values[key])
        lines.append(f"### {key} ({len(values)} distinct values)")
        for v in values:
            lines.append(f"- `{v}`")
        lines.append("")

    lines.append("## Settings Needing Probe Confirmation")
    lines.append(f"Total instances: {len(probe_needed)}")
    lines.append("")
    # Deduplicate by setting+value
    seen = set()
    for item in probe_needed:
        dedup_key = (item["setting"], item["value"])
        if dedup_key in seen:
            continue
        seen.add(dedup_key)
        lines.append(
            f"- **{item['setting']}** = `{item['value']}` "
            f"(PTP: {item['ptpProperty']}) — e.g. in *{item['recipe']}*"
        )

    lines.append("")
    lines.append("## Unmapped Settings")
    lines.append(f"Total instances: {len(unmapped)}")
    lines.append("")
    seen = set()
    for item in unmapped:
        dedup_key = (item["setting"], item["value"])
        if dedup_key in seen:
            continue
        seen.add(dedup_key)
        lines.append(f"- **{item['setting']}** = `{item['value']}` — in *{item['recipe']}*")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description="Normalize Fuji recipe settings for PTP mapping.")
    parser.add_argument("--input", default=str(INPUT_PATH), help="Input recipe JSON path.")
    parser.add_argument("--output", default=str(OUTPUT_PATH), help="Output normalized JSON path.")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        return 1

    with open(input_path, "r", encoding="utf-8") as f:
        payload = json.load(f)

    recipes = payload.get("recipes", [])
    normalized_recipes = [normalize_recipe(r) for r in recipes]

    # Build output payload
    output_payload = {
        **payload,
        "recipes": normalized_recipes,
        "normalizationMeta": {
            "tool": "normalize_settings.py",
            "sourceFile": str(input_path),
            "totalRecipes": len(normalized_recipes),
        },
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.with_suffix(".json").write_text(
        json.dumps(output_payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote normalized JSON: {output_path.with_suffix('.json')}")

    # Write summary
    summary = generate_summary(normalized_recipes)
    summary_path = output_path.parent / (output_path.stem + "-normalization-summary.md")
    summary_path.write_text(summary + "\n", encoding="utf-8")
    print(f"Wrote summary: {summary_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
