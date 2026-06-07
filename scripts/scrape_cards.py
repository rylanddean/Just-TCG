#!/usr/bin/env python3
"""
Scrape all Standard-regulation cards (TEF / reg-H onward) from api.pokemontcg.io.
Outputs one JSON file per set into ../card_data/{SET_CODE}.json

Usage:
    python3 scrape_cards.py [--api-key YOUR_KEY]

Without an API key the free tier is used (100 req/day, rate-limited).
With a key limits are much higher. Get one free at https://pokemontcg.io/
"""

import argparse
import json
import os
import time
import subprocess
import sys
from typing import Optional

# Sets in Standard regulation as of 2026-06 (TEF and later, release date >= 2024-03-22).
# Keyed by pokemontcg.io set id -> ptcgo code used as the output filename.
REGULATION_SET_IDS = [
    "sv5",       # TEF  Temporal Forces
    "sv6",       # TWM  Twilight Masquerade
    "sv6pt5",    # SFA  Shrouded Fable
    "sv7",       # SCR  Stellar Crown
    "sv8",       # SSP  Surging Sparks
    "sv8pt5",    # PRE  Prismatic Evolutions
    "sv9",       # JTG  Journey Together
    "sv10",      # DRI  Destined Rivals
    "zsv10pt5",  # BLK  Black Bolt
    "rsv10pt5",  # WHT  White Flare
    "me1",       # MEG  Mega Evolution
    "me2",       # PFL  Phantasmal Flames
    "me2pt5",    # ASC  Ascended Heroes
    "me3",       # POR  Perfect Order
    "me4",       # CRI  Chaos Rising
]

BASE_URL = "https://api.pokemontcg.io/v2"


def curl_get(url: str, api_key: Optional[str] = None) -> dict:
    """Fetch JSON via curl to avoid Python SSL cert issues on macOS."""
    cmd = ["curl", "-s", "-H", "Accept: application/json"]
    if api_key:
        cmd += ["-H", f"X-Api-Key: {api_key}"]
    cmd.append(url)
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        raise RuntimeError(f"curl failed: {result.stderr}")
    return json.loads(result.stdout)


def fetch_set_info(set_id: str, api_key: Optional[str]) -> dict:
    url = f"{BASE_URL}/sets/{set_id}"
    data = curl_get(url, api_key)
    return data["data"]


def fetch_all_cards_for_set(set_id: str, api_key: Optional[str]) -> list[dict]:
    """Pages through all cards for a given set, returns a list of raw PTCGCard dicts."""
    page = 1
    page_size = 250
    all_cards = []

    while True:
        url = (
            f"{BASE_URL}/cards"
            f"?q=set.id:{set_id}"
            f"&pageSize={page_size}"
            f"&page={page}"
            f"&orderBy=number"
        )
        data = curl_get(url, api_key)
        cards = data.get("data", [])
        all_cards.extend(cards)

        total = data.get("totalCount", 0)
        fetched = data.get("count", 0)
        print(f"  page {page}: got {fetched} cards (total so far: {len(all_cards)}/{total})")

        if page * page_size >= total:
            break
        page += 1
        time.sleep(0.25)  # be polite to the API

    return all_cards


def transform_card(raw: dict) -> dict:
    """Convert a raw PTCGCard response into the app's LimitlessCard shape."""
    abilities = raw.get("abilities") or []
    attacks = raw.get("attacks") or []
    rules = raw.get("rules") or []

    ability_lines = []
    for ab in abilities:
        header = f"[{ab.get('type', 'Ability')}] {ab['name']}"
        text = ab.get("text", "")
        ability_lines.append(f"{header}\n{text}" if text else header)

    attack_lines = []
    for atk in attacks:
        header = atk["name"]
        dmg = atk.get("damage", "")
        if dmg:
            header += f" · {dmg}"
        text = atk.get("text", "")
        attack_lines.append(f"{header}\n{text}" if text else header)

    rules_text = ability_lines + attack_lines + rules

    set_info = raw.get("set", {})
    ptcgo_code = set_info.get("ptcgoCode") or set_info.get("id", "").upper()

    # Regulation marks H, I, J are the current Standard window.
    # Some reprints in TEF+ sets carry old G marks and are NOT Standard-legal
    # even though the API's legalities field says "Legal" (it reflects set legality,
    # not the card's own mark). Use the mark as the authoritative signal.
    reg_mark = raw.get("regulationMark")
    LEGAL_MARKS = {"H", "I", "J"}
    if reg_mark:
        is_standard_legal = reg_mark in LEGAL_MARKS
    else:
        legalities = raw.get("legalities") or {}
        std = legalities.get("standard", "")
        is_standard_legal = std.lower() == "legal" if std else True

    images = raw.get("images", {})

    hp_str = raw.get("hp")
    hp = int(hp_str) if hp_str and hp_str.isdigit() else None

    return {
        "id": raw["id"],
        "name": raw["name"],
        "setCode": ptcgo_code,
        "setName": set_info.get("name", ""),
        "number": raw.get("number", ""),
        "supertype": raw.get("supertype", ""),
        "types": raw.get("types") or [],
        "subtypes": raw.get("subtypes") or [],
        "hp": hp,
        "isStandardLegal": is_standard_legal,
        "imageURL": images.get("small", ""),
        "largeImageURL": images.get("large"),
        "rulesText": rules_text,
        "attacks": [
            {
                "name": a["name"],
                "cost": a.get("cost") or [],
                "damage": a.get("damage", ""),
                "text": a.get("text", ""),
            }
            for a in attacks
        ],
        "abilities": [
            {
                "name": a["name"],
                "text": a.get("text", ""),
                "type": a.get("type", "Ability"),
            }
            for a in abilities
        ],
        "regulationMark": raw.get("regulationMark"),
        "artist": raw.get("artist"),
        "rarity": raw.get("rarity"),
    }


def scrape_set(set_id: str, output_dir: str, api_key: Optional[str], force: bool = False):
    print(f"\n=== {set_id} ===")

    # Fetch set metadata first to get the ptcgo code for the filename
    try:
        set_info = fetch_set_info(set_id, api_key)
    except Exception as e:
        print(f"  ERROR fetching set info: {e}")
        return

    ptcgo_code = set_info.get("ptcgoCode") or set_id.upper()
    set_name = set_info.get("name", set_id)
    release_date = set_info.get("releaseDate", "")
    total_cards = set_info.get("total", "?")

    print(f"  {set_name} ({ptcgo_code}) — released {release_date} — {total_cards} cards")

    out_path = os.path.join(output_dir, f"{ptcgo_code}.json")
    if os.path.exists(out_path) and not force:
        print(f"  Skipping — {out_path} already exists (use --force to overwrite)")
        return

    try:
        raw_cards = fetch_all_cards_for_set(set_id, api_key)
    except Exception as e:
        print(f"  ERROR fetching cards: {e}")
        return

    cards = [transform_card(c) for c in raw_cards]

    payload = {
        "set": {
            "id": ptcgo_code,
            "apiId": set_id,
            "name": set_name,
            "releaseDate": release_date,
            "total": set_info.get("total"),
            "printedTotal": set_info.get("printedTotal"),
            "series": set_info.get("series", ""),
            "symbolURL": set_info.get("images", {}).get("symbol"),
            "logoURL": set_info.get("images", {}).get("logo"),
        },
        "cards": cards,
    }

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"  Saved {len(cards)} cards -> {out_path}")


def main():
    parser = argparse.ArgumentParser(description="Scrape Pokemon TCG regulation cards")
    parser.add_argument("--api-key", help="api.pokemontcg.io API key (optional)")
    parser.add_argument(
        "--output-dir",
        default=os.path.join(os.path.dirname(__file__), "..", "card_data"),
        help="Directory to write JSON files into (default: ../card_data/)",
    )
    parser.add_argument(
        "--force", action="store_true", help="Overwrite existing files"
    )
    parser.add_argument(
        "--sets",
        nargs="+",
        help="Only scrape specific set IDs (e.g. sv5 sv6). Defaults to all regulation sets.",
    )
    args = parser.parse_args()

    output_dir = os.path.abspath(args.output_dir)
    os.makedirs(output_dir, exist_ok=True)
    print(f"Output directory: {output_dir}")

    set_ids = args.sets or REGULATION_SET_IDS

    for set_id in set_ids:
        scrape_set(set_id, output_dir, args.api_key, force=args.force)
        time.sleep(0.5)  # brief pause between sets

    print("\nDone.")


if __name__ == "__main__":
    main()
