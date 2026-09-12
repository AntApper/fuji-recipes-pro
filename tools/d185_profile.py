#!/usr/bin/env python3
"""d185 native profile binary packer/unpacker for Fujifilm RAW conversion.

The 0xD185 property is a 625-byte binary profile used for in-camera
RAW conversion. Field offsets confirmed on X100VI.

Usage:
    # Unpack a binary d185 profile to JSON
    python3 tools/d185_profile.py unpack profile.d185 --out profile.json

    # Pack JSON back to binary
    python3 tools/d185_profile.py pack profile.json --out profile.d185

    # Show a profile as a table
    python3 tools/d185_profile.py inspect profile.d185

    # Generate a default/empty profile
    python3 tools/d185_profile.py default --out default.d185

    # Apply settings to a profile and pack
    python3 tools/d185_profile.py apply default.d185 \
        --filmsim 19 --sharpness 0 \
        --grain weak-small --color-chrome strong \
        --wb-mode daylight --wb-shift-r 0 --wb-shift-b -2 \
        --dr 200 --exposure-comp 0 \
        --pack --out custom.d185
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

# d185 profile field layout (confirmed offsets on X100VI)
# 625 bytes total
# Note: Highlight/Shadow/Color tone fields are listed in the source doc at
# offsets 16-18, which fall within the ColorTemp UINT32 range (15-18).
# These tone offsets are unconfirmed and may need live camera probe.
# The tool currently supports all non-overlapping confirmed fields.
FIELD_OFFSETS = {
    "exposureBias": 4,
    "filmSimulation": 8,
    "grainEffect": 9,
    "dynamicRange": 6,
    "colorChrome": 10,
    "smoothSkin": 11,
    "wbShiftRed": 13,
    "wbShiftBlue": 14,
    "colorTemp": 15,
    "sharpness": 19,
    "noiseReduction": 20,
    "ccfxFxBlue": 25,
    "clarity": 27,
}

# All fields (some may be reserved)
ALL_FIELDS = [
    ("exposureBias", "B", 1),     # UINT8: EV × 10
    ("filmSimulation", "B", 1),   # UINT8: Film sim enum
    ("grainEffect", "B", 1),      # UINT8: 1=Off, 2=Weak, 3=Strong
    ("dynamicRange", "B", 1),     # UINT8: DR percentage/100
    ("colorChrome", "B", 1),      # UINT8: 1=Off, 2=Weak, 3=Strong
    ("smoothSkin", "B", 1),       # UINT8: 1=Off, 2=Weak, 3=Strong
    ("wbShiftRed", "b", 1),       # INT8: -9 to +9
    ("wbShiftBlue", "b", 1),      # INT8: -9 to +9
    ("colorTemp", "I", 4),        # UINT32: Kelvin (0 = Auto)
    ("sharpness", "b", 1),        # INT8: ×10 encoding
    ("noiseReduction", "I", 4),   # UINT32: proprietary encoding
    ("padding1", "x", 1),         # Reserved (byte 24)
    ("ccfxFxBlue", "B", 1),       # UINT8: Color Chrome FX Blue
    ("padding2", "x", 1),         # Reserved (byte 26)
    ("clarity", "b", 1),          # INT8: ×10 encoding
    ("padding3", "x", 596),       # Reserved / unknown fields
]

assert len(FIELD_OFFSETS) == 13, f"Expected 13 known fields, got {len(FIELD_OFFSETS)}"

# Value mappings
GRAIN_MAP = {
    "off": 0,
    "weak": 1,
    "strong": 2,
}

COLOR_CHROME_MAP = {
    "off": 1,
    "weak": 2,
    "strong": 3,
}

SMOOTH_SKIN_MAP = {
    "off": 1,
    "weak": 2,
    "strong": 3,
}


def read_profile(path: Path) -> bytes:
    data = path.read_bytes()
    if len(data) != 625:
        print(f"Warning: file is {len(data)} bytes, expected 625", file=sys.stderr)
    return data


def pack_profile(fields: dict) -> bytes:
    """Pack a dict of field values into a 625-byte binary profile."""
    buf = bytearray(625)
    for name, fmt, size in ALL_FIELDS:
        if name.startswith("padding") or name.startswith("_"):
            continue
        if name not in fields:
            continue
        value = fields[name]
        offset = FIELD_OFFSETS.get(name)
        if offset is None:
            continue
        if fmt == "x":
            continue
        packed = struct.pack(f"<{fmt}", value)
        buf[offset:offset + len(packed)] = packed
    return bytes(buf)


def unpack_profile(data: bytes) -> dict:
    """Unpack a 625-byte binary profile into a dict."""
    if len(data) < 28:
        raise ValueError(f"Profile data too short: {len(data)} bytes")

    result = {}
    for name, fmt, size in ALL_FIELDS:
        if name.startswith("padding") or name.startswith("_"):
            continue
        offset = FIELD_OFFSETS.get(name)
        if offset is None:
            continue
        if fmt == "x":
            continue
        value = struct.unpack(f"<{fmt}", data[offset:offset + size])[0]
        result[name] = value

    return result


def format_field(name: str, value) -> str:
    """Format a field value for display."""
    if name == "grainEffect":
        strength = value & 0xFF
        size = (value >> 8) & 0xFF
        strength_str = {0: "Off", 1: "Weak", 2: "Strong"}.get(strength, f"Unknown({strength})")
        size_str = {0: "Small", 1: "Large"}.get(size, f"Unknown({size})")
        return f"{strength_str} {size_str}"

    if name == "filmSimulation":
        sims = {
            1: "PROVIA/Standard", 2: "Velvia/Vivid", 3: "ASTIA/Soft",
            4: "PRO Neg.Hi", 5: "PRO Neg.Std", 6: "Monochrome",
            7: "Monochrome+Y", 8: "Monochrome+R", 9: "Monochrome+G",
            10: "Sepia", 11: "Classic Chrome", 12: "ACROS",
            13: "ACROS+Y", 14: "ACROS+R", 15: "ACROS+G",
            16: "ETERNA/Cinema", 17: "Classic Negative", 18: "ETERNA BB",
            19: "Nostalgic Neg", 20: "Reala Ace",
        }
        return sims.get(value, f"Unknown({value})")

    if name == "dynamicRange":
        dr_map = {0: "Off", 1: "DR100", 2: "DR200", 3: "DR400"}
        return dr_map.get(value, f"{value}")

    if name == "colorChrome":
        cc = {1: "Off", 2: "Weak", 3: "Strong"}
        return cc.get(value, f"{value}")

    if name == "smoothSkin":
        ss = {1: "Off", 2: "Weak", 3: "Strong"}
        return ss.get(value, f"{value}")

    if name == "exposureBias":
        return f"{value / 10:.1f} EV" if value != 0 else "0 EV"

    if name == "colorTemp" and value > 0:
        return f"{value}K"
    if name == "colorTemp":
        return "Auto"

    if name == "noiseReduction":
        return f"0x{value:08X}"

    if name in ("color", "sharpness", "clarity"):
        return f"{value / 10:.1f}"

    return str(value)


def inspect_profile(data: bytes) -> str:
    fields = unpack_profile(data)
    lines = [
        "=== d185 Profile ===",
        f"Size: {len(data)} bytes",
        "",
    ]
    for name, fmt, size in ALL_FIELDS:
        if name.startswith("padding") or name.startswith("_"):
            continue
        offset = FIELD_OFFSETS.get(name)
        if offset is None:
            continue
        if name in fields:
            lines.append(f"  [{offset:3d}] {name:20s} = {format_field(name, fields[name]):30s} ({fmt}, {size}B)")
        else:
            raw = data[offset:offset + size]
            lines.append(f"  [{offset:3d}] {name:20s} = <raw: {raw.hex()}>")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Settings conversion helpers
# ---------------------------------------------------------------------------

def parse_grain(value: str) -> int | None:
    """Parse grain effect string to binary value."""
    return GRAIN_MAP.get(value.lower().replace(" ", "-"))


def parse_color_chrome(value: str) -> int | None:
    return COLOR_CHROME_MAP.get(value.lower())


def parse_smooth_skin(value: str) -> int | None:
    return SMOOTH_SKIN_MAP.get(value.lower())


def parse_digital_grain(value: str) -> int | None:
    dg_map = {
        "off": 0,
        "weak": 1,
        "strong": 2,
    }
    return dg_map.get(value.lower())


def ev_to_10x(ev: float) -> int:
    return round(ev * 10)


def tone_to_10x(value: float) -> int:
    return round(value * 10)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def cmd_unpack(args: argparse.Namespace) -> int:
    data = read_profile(Path(args.input))
    fields = unpack_profile(data)
    output = {
        "size": len(data),
        "fields": fields,
        "formatted": {name: format_field(name, val) for name, val in fields.items()},
    }
    out = Path(args.output) if args.output else None
    if out:
        out.write_text(json.dumps(output, indent=2) + "\n")
        print(f"Wrote {out}")
    else:
        print(json.dumps(output, indent=2))
    return 0


def cmd_pack(args: argparse.Namespace) -> int:
    with open(args.input) as f:
        data = json.load(f)
    fields = data.get("fields", data)
    raw = pack_profile(fields)
    out = Path(args.output) if args.output else None
    if out:
        out.write_bytes(raw)
        print(f"Wrote {out} ({len(raw)} bytes)")
    else:
        sys.stdout.buffer.write(raw)
    return 0


def cmd_inspect(args: argparse.Namespace) -> int:
    data = read_profile(Path(args.input))
    print(inspect_profile(data))
    return 0


def cmd_default(args: argparse.Namespace) -> int:
    """Generate a default (all zeros) profile."""
    buf = bytearray(625)
    buf[8] = 1  # PROVIA/Standard
    # Noise Reduction at offset 20: UINT32, neutral ≈ 16384
    struct.pack_into("<I", buf, 20, 16384)
    out = Path(args.output) if args.output else None
    if out:
        out.write_bytes(bytes(buf))
        print(f"Wrote {out} (default profile, {len(buf)} bytes)")
    else:
        sys.stdout.buffer.write(bytes(buf))
    return 0


def cmd_apply(args: argparse.Namespace) -> int:
    """Apply settings to a profile and optionally pack."""
    base = read_profile(Path(args.input))
    fields = unpack_profile(base)

    if args.filmsim is not None:
        fields["filmSimulation"] = args.filmsim
    if args.color is not None:
        fields["color"] = round(args.color * 10)
    if args.sharpness is not None:
        fields["sharpness"] = round(args.sharpness * 10)
    if args.clarity is not None:
        fields["clarity"] = round(args.clarity * 10)
    if args.grain is not None:
        fields["grainEffect"] = parse_grain(args.grain)
    if args.color_chrome is not None:
        fields["colorChrome"] = parse_color_chrome(args.color_chrome)
    if args.smooth_skin is not None:
        fields["smoothSkin"] = parse_smooth_skin(args.smooth_skin)
    if args.wb_shift_r is not None:
        fields["wbShiftRed"] = int(args.wb_shift_r)
    if args.wb_shift_b is not None:
        fields["wbShiftBlue"] = int(args.wb_shift_b)
    if args.color_temp is not None:
        fields["colorTemp"] = int(args.color_temp)
    if args.dr is not None:
        dr_map = {100: 1, 200: 2, 400: 3}
        fields["dynamicRange"] = dr_map.get(args.dr, args.dr)
    if args.exposure_comp is not None:
        fields["exposureBias"] = ev_to_10x(args.exposure_comp)

    if args.pack:
        raw = pack_profile(fields)
        out = Path(args.output) if args.output else None
        if out:
            out.write_bytes(raw)
            print(f"Wrote {out} ({len(raw)} bytes)")
        else:
            sys.stdout.buffer.write(raw)
    else:
        # Show the result as a table
        print(inspect_profile(pack_profile(fields)))

    # Also output JSON
    result = {
        "source": str(args.input),
        "settings_applied": {
            k: v for k, v in locals().items()
            if k in ("filmsim", "color", "sharpness",
                     "clarity", "grain", "color_chrome", "smooth_skin",
                     "wb_shift_r", "wb_shift_b", "color_temp", "dr", "exposure_comp")
            and v is not None
        },
        "result_fields": {k: format_field(k, v) for k, v in fields.items()},
    }
    print(f"\n=== Applied Settings ===")
    for k, v in result["settings_applied"].items():
        print(f"  {k}: {v}")
    print(f"\n=== Result Fields ===")
    for k, v in result["result_fields"].items():
        print(f"  {k}: {v}")

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="d185 native profile binary packer/unpacker for Fujifilm RAW conversion.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # unpack
    p_un = sub.add_parser("unpack", help="Unpack binary profile to JSON")
    p_un.add_argument("input", help="Input .d185 file")
    p_un.add_argument("--output", "-o", help="Output JSON file (default: stdout)")

    # pack
    p_pk = sub.add_parser("pack", help="Pack JSON to binary profile")
    p_pk.add_argument("input", help="Input JSON file")
    p_pk.add_argument("--output", "-o", help="Output .d185 file (default: stdout)")

    # inspect
    p_in = sub.add_parser("inspect", help="Inspect binary profile as table")
    p_in.add_argument("input", help="Input .d185 file")

    # default
    p_def = sub.add_parser("default", help="Generate default/empty profile")
    p_def.add_argument("--output", "-o", help="Output .d185 file (default: stdout)")

    # apply
    p_apply = sub.add_parser("apply", help="Apply settings to profile")
    p_apply.add_argument("input", help="Input .d185 file")
    p_apply.add_argument("--filmsim", type=int, help="Film simulation enum (1-20)")
    p_apply.add_argument("--color", type=float, help="Film sim tune (-4 to +4) — offset TBD, needs camera probe")
    p_apply.add_argument("--sharpness", type=float, help="Sharpness (-4 to +4)")
    p_apply.add_argument("--clarity", type=float, help="Clarity (-4 to +4)")
    p_apply.add_argument("--grain", type=str, help="Grain effect: off/weak/strong/weak-small/strong-small/weak-large/strong-large")
    p_apply.add_argument("--color-chrome", type=str, help="Color Chrome: off/weak/strong")
    p_apply.add_argument("--smooth-skin", type=str, help="Smooth Skin: off/weak/strong")
    p_apply.add_argument("--wb-shift-r", type=int, help="WB red shift (-9 to +9)")
    p_apply.add_argument("--wb-shift-b", type=int, help="WB blue shift (-9 to +9)")
    p_apply.add_argument("--color-temp", type=int, help="Color temperature (Kelvin)")
    p_apply.add_argument("--dr", type=int, help="Dynamic range: 100/200/400")
    p_apply.add_argument("--exposure-comp", type=float, help="Exposure compensation (EV)")
    p_apply.add_argument("--pack", action="store_true", help="Pack to binary and write")
    p_apply.add_argument("--output", "-o", help="Output .d185 file (with --pack)")

    args = parser.parse_args()

    commands = {
        "unpack": cmd_unpack,
        "pack": cmd_pack,
        "inspect": cmd_inspect,
        "default": cmd_default,
        "apply": cmd_apply,
    }
    return commands[args.command](args)


if __name__ == "__main__":
    raise SystemExit(main())
