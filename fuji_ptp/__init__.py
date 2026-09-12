"""Fuji PTP mapping — single source of truth for all camera encoding.

Consolidates film simulation, white balance, dynamic range, grain effect,
and color chrome tables from normalize_settings.py, export_ios_app_data.py,
and the PTP property docs into one module.

Exports:
  - Enum lookup tables (raw text → PTP value)
  - Property definitions (active shooting + preset slot)
  - Encoding conversion functions (numeric, WB, exposure)
  - CLI: python -m fuji_ptp generate  → outputs mapping.json
"""

from .mapping import (
    # Enum lookup tables
    FILM_SIM,
    WB_MODE,
    DR_MODE,
    GRAIN_EFFECT,
    COLOR_CHROME,
    COLOR_CHROME_FX_BLUE,
    # Property definitions
    ACTIVE_PROPERTIES,
    PRESET_PROPERTIES,
    # Encoding functions
    encode_numeric,
    encode_exposure_comp,
    parse_white_balance,
    parse_exposure_comp,
    to_preset,
)

__all__ = [
    # Enum tables
    "FILM_SIM", "WB_MODE", "DR_MODE", "GRAIN_EFFECT",
    "COLOR_CHROME", "COLOR_CHROME_FX_BLUE",
    # Properties
    "ACTIVE_PROPERTIES", "PRESET_PROPERTIES",
    # Encoding
    "encode_numeric", "encode_exposure_comp", "parse_white_balance",
    "parse_exposure_comp", "to_preset",
]
