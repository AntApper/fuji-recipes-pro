#!/usr/bin/env python3
"""Validate provenance and deduplication for curated Fuji recipe imports."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASE = ROOT / "data" / "fujixweekly" / "x-trans-v-recipes.json"
DEFAULT_CURATED = ROOT / "data" / "curated" / "x100vi-recipes.json"


def normalized_text(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def setting_fingerprint(recipe: dict[str, Any]) -> str:
    """Stable hash of source-provided factual settings, independent of JSON order."""
    settings = recipe.get("settings", {})
    normalized = {
        normalized_text(str(key)): normalized_text(str(value))
        for key, value in settings.items()
    }
    serialized = json.dumps(normalized, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(serialized.encode("utf-8")).hexdigest()


def load_recipes(path: Path) -> list[dict[str, Any]]:
    with path.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    recipes = payload.get("recipes")
    if not isinstance(recipes, list):
        raise ValueError(f"{path}: 'recipes' must be an array")
    return recipes


def validate(base: list[dict[str, Any]], curated: list[dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    base_ids = {recipe.get("id") for recipe in base}
    base_names = {normalized_text(recipe.get("name", "")) for recipe in base}
    base_fingerprints = {setting_fingerprint(recipe) for recipe in base}
    curated_ids: set[str] = set()
    curated_names: set[str] = set()
    curated_fingerprints: set[str] = set()

    for recipe in curated:
        label = recipe.get("id") or "<missing id>"
        required = ("id", "name", "sourceUrl", "sourceType", "creator", "provenance")
        missing = [key for key in required if not recipe.get(key)]
        if missing:
            errors.append(f"{label}: missing required provenance fields: {', '.join(missing)}")
            continue

        provenance = recipe["provenance"]
        required_provenance = ("retrievedAt", "importMethod", "licenseStatus", "mappingCompleteness")
        missing_provenance = [key for key in required_provenance if not provenance.get(key)]
        if missing_provenance:
            errors.append(f"{label}: missing provenance fields: {', '.join(missing_provenance)}")

        settings = recipe.get("settings")
        if not isinstance(settings, dict) or not settings:
            errors.append(f"{label}: requires at least one factual setting")
            continue
        if recipe.get("settingCount") != len(settings):
            errors.append(f"{label}: settingCount does not match settings")

        recipe_id = recipe["id"]
        recipe_name = normalized_text(recipe["name"])
        fingerprint = setting_fingerprint(recipe)
        if recipe_id in base_ids or recipe_id in curated_ids:
            errors.append(f"{label}: duplicate id")
        if recipe_name in base_names or recipe_name in curated_names:
            errors.append(f"{label}: duplicate normalized name")
        if fingerprint in base_fingerprints or fingerprint in curated_fingerprints:
            errors.append(f"{label}: duplicate normalized setting fingerprint")
        curated_ids.add(recipe_id)
        curated_names.add(recipe_name)
        curated_fingerprints.add(fingerprint)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, default=DEFAULT_BASE)
    parser.add_argument("--curated", type=Path, default=DEFAULT_CURATED)
    args = parser.parse_args()

    try:
        errors = validate(load_recipes(args.base), load_recipes(args.curated))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Validation setup failed: {exc}", file=sys.stderr)
        return 2

    if errors:
        print("Recipe import validation failed:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1
    print(f"Validated {len(load_recipes(args.curated))} curated recipe(s) against {len(load_recipes(args.base))} base recipe(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
