#!/usr/bin/env python3
"""Scrape Fuji X Weekly X-Trans V recipe metadata and settings.

This is intended for private research/personal camera recipe management.
It preserves source URLs and flags pages that need manual review.
"""

from __future__ import annotations

import argparse
import csv
import html
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable


INDEX_URL = "https://fujixweekly.com/fujifilm-x-trans-v-recipes/"
SOURCE_NAME = "Fuji X Weekly"
SENSOR_GENERATION = "X-Trans V"
USER_AGENT = "Mozilla/5.0 (compatible; personal-fuji-recipe-research/1.0)"

OUTPUT_DIR = Path(__file__).resolve().parents[1] / "data" / "fujixweekly"
JSON_OUTPUT = OUTPUT_DIR / "x-trans-v-recipes.json"
CSV_OUTPUT = OUTPUT_DIR / "x-trans-v-recipes.csv"
REPORT_OUTPUT = OUTPUT_DIR / "scrape-report.md"

FIELD_ALIASES = {
    "film simulation": "filmSimulation",
    "dynamic range": "dynamicRange",
    "d range priority": "dRangePriority",
    "grain effect": "grainEffect",
    "color chrome effect": "colorChromeEffect",
    "colour chrome effect": "colorChromeEffect",
    "color chrome fx blue": "colorChromeFxBlue",
    "colour chrome fx blue": "colorChromeFxBlue",
    "white balance": "whiteBalance",
    "wb": "whiteBalance",
    "highlight": "highlight",
    "highlights": "highlight",
    "shadow": "shadow",
    "shadows": "shadow",
    "color": "color",
    "colour": "color",
    "sharpness": "sharpness",
    "high iso nr": "highIsoNr",
    "noise reduction": "highIsoNr",
    "clarity": "clarity",
    "iso": "iso",
    "exposure compensation": "exposureCompensation",
    "exp. comp.": "exposureCompensation",
    "exposure comp": "exposureCompensation",
}

KNOWN_SETTING_KEYS = sorted(FIELD_ALIASES.keys(), key=len, reverse=True)
SETTING_LINE_RE = re.compile(
    r"^(?P<key>Film Simulation|Dynamic Range|D Range Priority|Grain Effect|Color Chrome Effect|Colour Chrome Effect|Color Chrome FX Blue|Colour Chrome FX Blue|White Balance|WB|Highlight|Highlights|Shadow|Shadows|Color|Colour|Sharpness|High ISO NR|Noise Reduction|Clarity|ISO|Exposure Compensation|Exp\. Comp\.|Exposure Comp)\s*:\s*(?P<value>.+)$",
    re.IGNORECASE,
)

RECIPE_LINK_HINTS = (
    "film-simulation-recipe",
    "fujifilm-recipe",
    "film-simulation-recipes",
    "film-dial-settings",
    "universal-negative",
)


def clean_text(value: str) -> str:
    value = html.unescape(value)
    value = value.replace("\xa0", " ")
    value = value.replace("\u2013", "-")
    value = value.replace("\u2014", "-")
    value = value.replace("\u2019", "'")
    value = value.replace("\u2018", "'")
    value = value.replace("\u201c", '"')
    value = value.replace("\u201d", '"')
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()


def slugify(value: str) -> str:
    value = clean_text(value).lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-") or "recipe"


def fetch_url(url: str, delay: float = 0.0) -> str:
    if delay:
        time.sleep(delay)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            charset = response.headers.get_content_charset() or "utf-8"
            return response.read().decode(charset, errors="replace")
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"HTTP {exc.code} fetching {url}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Network error fetching {url}: {exc}") from exc


def entry_content(html_text: str) -> str:
    match = re.search(r'<div[^>]+class="[^"]*entry-content[^"]*"[^>]*>', html_text, re.I)
    if not match:
        return html_text
    start = match.end()
    end_candidates = []
    for pattern in (
        r'<div[^>]+class="[^"]*sharedaddy[^"]*"',
        r'<footer[^>]+class="[^"]*entry-footer[^"]*"',
        r'<nav[^>]+class="[^"]*navigation[^"]*"',
        r'<div[^>]+id="comments"',
    ):
        candidate = re.search(pattern, html_text[start:], re.I)
        if candidate:
            end_candidates.append(start + candidate.start())
    end = min(end_candidates) if end_candidates else len(html_text)
    return html_text[start:end]


class ContentParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.links: list[tuple[str, str]] = []
        self.images: list[str] = []
        self.text_parts: list[str] = []
        self._current_href: str | None = None
        self._current_text: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr = dict(attrs)
        if tag == "a" and attr.get("href"):
            self._current_href = attr["href"]
            self._current_text = []
        elif tag == "img" and attr.get("src"):
            self.images.append(attr["src"] or "")
        elif tag in {"p", "br", "div", "li", "h1", "h2", "h3", "h4", "blockquote"}:
            self.text_parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag == "a" and self._current_href:
            self.links.append((self._current_href, clean_text("".join(self._current_text))))
            self._current_href = None
            self._current_text = []
        elif tag in {"p", "li", "h1", "h2", "h3", "h4", "blockquote"}:
            self.text_parts.append("\n")

    def handle_data(self, data: str) -> None:
        if self._current_href is not None:
            self._current_text.append(data)
        self.text_parts.append(data)

    @property
    def text(self) -> str:
        return clean_text("".join(self.text_parts))


def parse_content(html_text: str) -> ContentParser:
    parser = ContentParser()
    parser.feed(entry_content(html_text))
    return parser


def normalize_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    clean = parsed._replace(query="", fragment="")
    return urllib.parse.urlunparse(clean)


def extract_recipe_links(index_html: str) -> list[dict[str, str]]:
    parser = parse_content(index_html)
    seen: set[str] = set()
    result: list[dict[str, str]] = []
    for href, label in parser.links:
        absolute = urllib.parse.urljoin(INDEX_URL, href)
        normalized = normalize_url(absolute)
        parsed = urllib.parse.urlparse(normalized)
        if parsed.netloc not in {"fujixweekly.com", "www.fujixweekly.com"}:
            continue
        if not re.search(r"/20\d{2}/\d{2}/\d{2}/", parsed.path):
            continue
        path = parsed.path.lower()
        if not any(hint in path for hint in RECIPE_LINK_HINTS):
            continue
        if normalized in seen:
            continue
        seen.add(normalized)
        result.append({"url": normalized, "indexTitle": label or Path(parsed.path).name})
    return result


def page_title(html_text: str, fallback: str) -> str:
    title = re.search(r"<title[^>]*>(.*?)</title>", html_text, re.I | re.S)
    if title:
        value = clean_text(re.sub(r"<[^>]+>", "", title.group(1)))
        value = re.sub(r"\s*\|\s*FUJI X WEEKLY\s*$", "", value, flags=re.I)
        if value:
            return value
    entry_h1 = re.search(r"<h1[^>]+class=\"[^\"]*entry-title[^\"]*\"[^>]*>(.*?)</h1>", html_text, re.I | re.S)
    if entry_h1:
        return clean_text(re.sub(r"<[^>]+>", "", entry_h1.group(1)))
    title = re.search(r"<title[^>]*>(.*?)</title>", html_text, re.I | re.S)
    if title:
        return clean_text(re.sub(r"\s*\|\s*FUJI X WEEKLY\s*$", "", re.sub(r"<[^>]+>", "", title.group(1)), flags=re.I))
    return fallback


def page_date(html_text: str, url: str) -> str | None:
    url_date = re.search(r"/(20\d{2})/(\d{2})/(\d{2})/", url)
    time_tag = re.search(r'<time[^>]+datetime="([^"]+)"', html_text, re.I)
    if time_tag:
        value = time_tag.group(1)
        if re.search(r"20\d{2}", value):
            return value
        if url_date:
            return f"{url_date.group(1)}-{url_date.group(2)}-{url_date.group(3)}"
    posted = re.search(r"Posted on\s+([A-Za-z]+\s+\d{1,2},\s+\d{4})", clean_text(re.sub(r"<[^>]+>", " ", html_text)))
    if posted:
        return posted.group(1)
    if url_date:
        return f"{url_date.group(1)}-{url_date.group(2)}-{url_date.group(3)}"
    return None


def normalized_key(raw_key: str) -> str:
    key = clean_text(raw_key).lower().rstrip(":")
    return FIELD_ALIASES.get(key, slugify(key).replace("-", ""))


def parse_setting_line(line: str) -> tuple[str, str] | None:
    line = clean_text(line).strip("* ")
    match = SETTING_LINE_RE.match(line)
    if not match:
        return None
    return normalized_key(match.group("key")), clean_text(match.group("value").strip("* "))


def split_fused_settings(line: str) -> list[str]:
    line = clean_text(line).strip("* ")
    if not line:
        return []
    lower = line.lower()
    positions = []
    for key in KNOWN_SETTING_KEYS:
        for match in re.finditer(r"(?<![a-z])" + re.escape(key) + r"\s*:", lower):
            positions.append(match.start())
    positions = sorted(set(positions))
    if len(positions) <= 1:
        return [line]
    chunks = []
    for idx, start in enumerate(positions):
        end = positions[idx + 1] if idx + 1 < len(positions) else len(line)
        chunks.append(line[start:end].strip())
    return chunks


def extract_settings(text: str) -> dict[str, str]:
    settings: dict[str, str] = {}
    lines = [clean_text(line) for line in text.splitlines()]
    for line in lines:
        for chunk in split_fused_settings(line):
            parsed = parse_setting_line(chunk)
            if parsed:
                key, value = parsed
                if key not in settings:
                    settings[key] = value
    return settings


def count_setting_blocks(text: str) -> int:
    return len(re.findall(r"(?im)^\s*\*{0,2}\s*Film Simulation\s*:", text))


def split_recipe_blocks(text: str) -> list[dict[str, str]]:
    """Split text into individual recipe blocks.

    Each block contains:
      - 'header': recipe name header text (if found)
      - 'body': the settings block text
      - 'sensorGenHint': X-Trans V or X-Trans IV hint from the header
    """
    # Find all Film Simulation: line positions (block starts)
    block_starts: list[int] = []
    for match in re.finditer(r"(?im)^\s*\*{0,2}\s*Film Simulation\s*:", text):
        block_starts.append(match.start())

    if not block_starts:
        return [{"header": "", "body": text, "sensorGenHint": None}]

    lines = text.splitlines(keepends=True)

    # Pre-scan all recipe name headers with sensor gen hints (X-Trans V/IV)
    # Pattern: "Recipe Name (X-Trans V)" or "**Recipe Name** (X-Trans V)"
    # Also matches bold-only: "**Recipe Name**"
    sensor_headers: list[tuple[int, str, str | None]] = []  # (char_pos, name, sensor_gen)
    char_offset = 0
    for li, line in enumerate(lines):
        clean = clean_text(line).strip()
        # Remove bold markers if present
        candidate = re.sub(r"\*{1,3}", "", clean).strip()
        # Match "Name (X-Trans V)" pattern
        sensor_gen_match = re.match(r"^(.+?)\s*\((X-Trans\s*(?:IV|V))\)$", candidate, re.I)
        if sensor_gen_match:
            name = sensor_gen_match.group(1).strip()
            sensor_gen = sensor_gen_match.group(2)
            # Skip if it's clearly not a recipe name (camera model, etc.)
            if not re.match(r"^(Fujifilm\s+X|X-Pro|X100|X-T|X-H|X-E|X-S|X-G|GFX)", name, re.I):
                if name and len(name) < 60:  # Sanity check on name length
                    sensor_headers.append((char_offset, name, sensor_gen))
                    continue
        # Also match bold-only headers: "**Recipe Name**"
        bold_match = re.match(r"^\*{1,3}\s*(.+?)\s*\*{1,3}$", clean)
        if bold_match:
            name = bold_match.group(1).strip()
            if name and len(name) < 60:
                sensor_headers.append((char_offset, name, None))
        char_offset += len(line)

    blocks: list[dict[str, str]] = []

    for idx, block_start_pos in enumerate(block_starts):
        # Find which line the block starts on
        char_pos = 0
        start_line_idx = 0
        for li, line in enumerate(lines):
            if char_pos >= block_start_pos:
                start_line_idx = li
                break
            char_pos += len(line)

        # Collect lines from start to next block (or end)
        if idx + 1 < len(block_starts):
            next_pos = block_starts[idx + 1]
            char_pos = 0
            end_line_idx = len(lines)
            for li, line in enumerate(lines):
                if char_pos >= next_pos:
                    end_line_idx = li
                    break
                char_pos += len(line)
        else:
            end_line_idx = len(lines)

        block_lines = lines[start_line_idx:end_line_idx]
        block_text = "".join(block_lines)

        # Find the closest sensor header that appears before this block
        header = ""
        sensor_gen_hint = None
        closest_header = None
        for h_pos, h_name, h_sensor in sensor_headers:
            if h_pos < block_start_pos:
                closest_header = (h_name, h_sensor)
            else:
                break
        if closest_header:
            header, sensor_gen_hint = closest_header

        blocks.append({
            "header": header,
            "body": block_text,
            "sensorGenHint": sensor_gen_hint,
        })

    return blocks


def build_recipe_from_block(
    block: dict[str, str],
    url: str,
    page_title: str,
    html_text: str,
    parser: ContentParser,
    block_index: int,
    total_blocks: int,
) -> dict[str, object]:
    """Build a single recipe dict from a split recipe block."""
    settings = extract_settings(block["body"])
    header = block["header"] or ""

    # Derive recipe name
    if header:
        name = header
    else:
        name = re.sub(r"\s+-\s+Fujifilm.*$", "", page_title).strip()

    # Build ID
    base_id = slugify(name)
    if total_blocks > 1:
        # Check for sensor gen hint in header
        sensor_hint = block.get("sensorGenHint")
        if sensor_hint:
            suffix = slugify(sensor_hint)
        else:
            suffix = str(block_index + 1)
        recipe_id = f"{base_id}-{suffix}"
    else:
        recipe_id = base_id

    # Determine sensor generation
    sensor_gen = SENSOR_GENERATION
    if block.get("sensorGenHint"):
        sensor_gen = block["sensorGenHint"]

    review_notes: list[str] = []
    if len(settings) < 8:
        review_notes.append(f"Fewer than 8 recognized settings were parsed ({len(settings)} found).")

    recipe = {
        "id": recipe_id,
        "name": name,
        "title": f"{name} - {page_title}" if not header else page_title,
        "source": SOURCE_NAME,
        "sourceUrl": url,
        "sensorGeneration": sensor_gen,
        "date": page_date(html_text, url),
        "previewImageUrl": parser.images[0] if parser.images else None,
        "imageUrls": parser.images[:20],
        "compatibleCameras": extract_compatibility(block["body"], page_title),
        "tags": parse_tags(html_text),
        "settings": settings,
        "settingCount": len(settings),
        "settingBlockCount": total_blocks,
        "blockIndex": block_index,
        "parseStatus": "ok" if not review_notes else "needs_review",
        "reviewNotes": review_notes,
    }
    return recipe


def extract_compatibility(text: str, title: str) -> list[str]:
    cameras = ["X-H2", "X-H2S", "X-T5", "X-S20", "X100VI", "X-T50", "X-M5", "X-E5", "X-T30 III", "GFX100 II", "GFX100S II", "GFX100RF"]
    haystack = f"{title}\n{text[:2500]}"
    return [camera for camera in cameras if camera.lower() in haystack.lower()]


def parse_tags(html_text: str) -> list[str]:
    tag_matches = re.findall(r'rel="tag"[^>]*>(.*?)</a>', html_text, re.I | re.S)
    return [clean_text(re.sub(r"<[^>]+>", "", tag)) for tag in tag_matches]


def parse_recipe_page(url: str, fallback_title: str, delay: float) -> list[dict[str, object]]:
    """Parse a recipe page, returning one or more recipe dicts.

    Pages with multiple recipe blocks (e.g. X-Trans V + X-Trans IV variants)
    are split into separate recipe records.
    """
    html_text = fetch_url(url, delay=delay)
    parser = parse_content(html_text)
    title = page_title(html_text, fallback_title)

    blocks = split_recipe_blocks(parser.text)
    total_blocks = len(blocks)

    recipes: list[dict[str, object]] = []
    for idx, block in enumerate(blocks):
        recipes.append(build_recipe_from_block(
            block, url, title, html_text, parser, idx, total_blocks
        ))

    return recipes


def write_json(recipes: list[dict[str, object]], links: list[dict[str, str]], errors: list[dict[str, str]]) -> None:
    payload = {
        "source": SOURCE_NAME,
        "sourceUrl": INDEX_URL,
        "sensorGeneration": SENSOR_GENERATION,
        "scrapedAt": datetime.now(timezone.utc).isoformat(),
        "recipeCount": len(recipes),
        "indexLinkCount": len(links),
        "errorCount": len(errors),
        "recipes": recipes,
        "errors": errors,
    }
    JSON_OUTPUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def flattened_settings_keys(recipes: Iterable[dict[str, object]]) -> list[str]:
    keys: set[str] = set()
    for recipe in recipes:
        settings = recipe.get("settings", {})
        if isinstance(settings, dict):
            keys.update(str(key) for key in settings.keys())
    preferred = list(dict.fromkeys(FIELD_ALIASES.values()))
    return [key for key in preferred if key in keys] + sorted(keys.difference(preferred))


def write_csv(recipes: list[dict[str, object]]) -> None:
    setting_keys = flattened_settings_keys(recipes)
    fields = ["id", "name", "title", "sourceUrl", "date", "sensorGeneration", "compatibleCameras", "parseStatus", "settingCount"] + setting_keys
    with CSV_OUTPUT.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for recipe in recipes:
            settings = recipe.get("settings", {})
            row = {field: recipe.get(field) for field in fields}
            row["compatibleCameras"] = ", ".join(recipe.get("compatibleCameras", [])) if isinstance(recipe.get("compatibleCameras"), list) else ""
            if isinstance(settings, dict):
                row.update(settings)
            writer.writerow(row)


def write_report(
    recipes: list[dict[str, object]],
    links: list[dict[str, str]],
    errors: list[dict[str, str]],
    multi_recipe_pages: list[tuple[str, int]] | None = None,
) -> None:
    ok = [recipe for recipe in recipes if recipe.get("parseStatus") == "ok"]
    needs_review = [recipe for recipe in recipes if recipe.get("parseStatus") != "ok"]
    lines = [
        "# Fuji X Weekly X-Trans V Scrape Report",
        "",
        f"Scraped: {datetime.now(timezone.utc).isoformat()}",
        f"Source: {INDEX_URL}",
        "",
        f"Index recipe links found: {len(links)}",
        f"Recipe pages fetched: {len(links) - len(errors)}",
        f"Total recipe records: {len(recipes)}",
        f"Parsed OK: {len(ok)}",
        f"Needs manual review: {len(needs_review)}",
        f"Errors: {len(errors)}",
        "",
    ]
    if multi_recipe_pages:
        lines.append(f"## Multi-Recipe Pages ({len(multi_recipe_pages)})")
        lines.append("")
        for url, count in multi_recipe_pages:
            lines.append(f"- {url} → {count} recipe records")
        lines.append("")
    lines.append("## Manual Review")
    if needs_review:
        for recipe in needs_review:
            lines.append(f"- {recipe.get('name')} - {recipe.get('sourceUrl')} ({recipe.get('settingCount')} settings)")
    else:
        lines.append("- None")
    lines.extend(["", "## Errors"])
    if errors:
        for error in errors:
            lines.append(f"- {error['url']} - {error['error']}")
    else:
        lines.append("- None")
    lines.extend(["", "## Parsed Recipes"])
    for recipe in recipes:
        lines.append(f"- {recipe.get('name')} - {recipe.get('settingCount')} settings - {recipe.get('sourceUrl')}")
    REPORT_OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run(limit: int | None, delay: float) -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    index_html = fetch_url(INDEX_URL)
    links = extract_recipe_links(index_html)
    if limit is not None:
        links = links[:limit]
    recipes: list[dict[str, object]] = []
    errors: list[dict[str, str]] = []
    multi_recipe_pages: list[tuple[str, int]] = []
    for index, link in enumerate(links, start=1):
        url = link["url"]
        print(f"[{index}/{len(links)}] {url}", file=sys.stderr)
        try:
            page_recipes = parse_recipe_page(url, link.get("indexTitle", ""), delay=delay if index > 1 else 0)
            if len(page_recipes) > 1:
                multi_recipe_pages.append((url, len(page_recipes)))
            recipes.extend(page_recipes)
        except Exception as exc:  # noqa: BLE001 - report and continue scraping remaining pages.
            errors.append({"url": url, "error": str(exc)})
    write_json(recipes, links, errors)
    write_csv(recipes)
    write_report(recipes, links, errors, multi_recipe_pages)
    print(f"Wrote {JSON_OUTPUT}")
    print(f"Wrote {CSV_OUTPUT}")
    print(f"Wrote {REPORT_OUTPUT}")
    return 0 if not errors else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Scrape Fuji X Weekly X-Trans V recipes.")
    parser.add_argument("--limit", type=int, default=None, help="Limit number of recipe pages for testing.")
    parser.add_argument("--delay", type=float, default=0.35, help="Delay between recipe page fetches in seconds.")
    args = parser.parse_args()
    return run(args.limit, args.delay)


if __name__ == "__main__":
    raise SystemExit(main())
