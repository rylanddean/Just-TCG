#!/usr/bin/env python3
"""
Analyze role tags across all bundled card JSON files.
Classifies each card against the canonical M9 tag taxonomy and reports
per-tag card counts, untagged ability-bearing cards, and top ability names.
Exits non-zero if the number of untagged ability-bearing cards exceeds an
acceptable threshold (some purely utility abilities are intentionally untagged).
"""

import json
import re
import sys
from pathlib import Path

CARD_DATA_DIR = Path(__file__).parent.parent / "JustTCG" / "CardData"

SET_FILES = [
    "TEF", "TWM", "SFA", "SCR", "SSP",
    "PRE", "JTG", "DRI", "BLK", "WHT",
    "MEG", "PFL", "ASC", "POR", "CRI",
]

# Cards whose abilities are intentionally outside the 13-tag taxonomy
# (extra-attack enablers, conditional evolution speed, opponent bench seeding, etc.)
KNOWN_UNTAGGABLE = {
    "Relicanth",          # Memory Dive — lets evolved Pokémon use prior stage attacks
    "Dipplin",            # Festival Lead — extra attack after KO
    "Swirlix",            # Festival Lead — extra attack after KO
    "Palafin ex",         # Hero's Spirit — placement-only restriction
    "Eevee",              # Boosted Evolution — faster evolution speed
    "Eevee ex",           # Rainbow DNA — universal Eeveelution evolution
    "Karrablast",         # conditional same-turn evolution
    "Shelmet",            # conditional same-turn evolution
    "Luxio",              # conditional same-turn evolution vs ex
    "Ludicolo",           # Vibrant Dance — +40 HP buff (no healing tag, no Survival)
    "Lillie's Ribombee",  # Inviting Wink — puts opponent's own Pokémon onto Bench
    "Mandibuzz",          # puts opponent's Pokémon onto their Bench
    "Azumarill",          # Glistening Bubbles — attack type override
}

# Max fraction of ability-bearing cards allowed to be untagged before failing.
UNTAGGED_THRESHOLD_PCT = 0.05   # 5 %


def _ci(text: str, sub: str) -> bool:
    """Case-insensitive contains."""
    return sub.lower() in text.lower()


def classify(abilities: list, attacks: list) -> list[str]:
    all_texts = [a.get("text", "") for a in abilities] + [a.get("text", "") for a in attacks]
    ability_texts = [a.get("text", "") for a in abilities]
    tags: set[str] = set()

    for text in all_texts:
        if not text:
            continue

        if _ci(text, "draw") and _ci(text, "card"):
            tags.add("Draw")
        if _ci(text, "search your deck") or _ci(text, "look at the top"):
            tags.add("Search")
        if (_ci(text, "attach") and _ci(text, "energy")
                or _ci(text, "move") and _ci(text, "energy")):
            tags.add("Energy Acceleration")
        if _ci(text, "heal") or re.search(r"remove.*damage counter", text, re.IGNORECASE):
            tags.add("Healing")
        if (_ci(text, "less damage")
                or re.search(r"prevent.*damage", text, re.IGNORECASE)
                or re.search(r"reduce.*damage", text, re.IGNORECASE)
                or _ci(text, "prevent all effects")):
            tags.add("Damage Reduction")
        if _ci(text, "more damage") or _ci(text, "additional damage"):
            tags.add("Damage Boost")
        if (_ci(text, "discard") or _ci(text, "lost zone") or _ci(text, "can't play")
                or _ci(text, "devolve")
                or (_ci(text, "shuffle") and "opponent's hand" in text)
                or (_ci(text, "opponent") and _ci(text, "cost") and _ci(text, "more"))):
            tags.add("Disruption")
        # Status — exact capitalised strings as printed on cards
        if any(s in text for s in ["Poisoned", "Burned", "Paralyzed", "Asleep", "Confused"]):
            tags.add("Status")
        # Spread Damage — exact capitalised strings for "Benched"/"each" cases; regex for ability placements
        if ((_ci(text, "damage counter") and (
                "Benched" in text or "each of your opponent's Pokémon" in text))
                or re.search(r"(?:put|place) \d+ damage counter", text, re.IGNORECASE)):
            tags.add("Spread Damage")
        if (_ci(text, "switch")
                or "no Retreat Cost" in text
                or ("Retreat Cost" in text and _ci(text, "less"))
                or (_ci(text, "shuffle") and "into your deck" in text)):
            tags.add("Mobility")
        if ("Prize card" in text
                and any(_ci(text, w) for w in ["take", "more", "fewer", "additional"])):
            tags.add("Prize Control")
        if (_ci(text, "can't play") or _ci(text, "can't use") or _ci(text, "can't be put")
                or _ci(text, "can't be moved")
                or re.search(r"lose.*Ability", text, re.IGNORECASE)
                or "no Abilities" in text):
            tags.add("Lock")

    # Survivability — ability text only
    for text in ability_texts:
        if not text:
            continue
        if "not Knocked Out" in text or re.search(r"remaining HP.*10", text):
            tags.add("Survivability")

    return sorted(tags)


def main() -> None:
    all_cards: list[dict] = []
    for code in SET_FILES:
        path = CARD_DATA_DIR / f"{code}.json"
        if not path.exists():
            print(f"WARNING: {path} not found", file=sys.stderr)
            continue
        with open(path) as f:
            data = json.load(f)
        all_cards.extend(data.get("cards", []))

    tag_counts: dict[str, int] = {
        t: 0 for t in [
            "Draw", "Search", "Energy Acceleration", "Healing",
            "Damage Reduction", "Damage Boost", "Disruption", "Status",
            "Spread Damage", "Survivability", "Mobility", "Prize Control", "Lock",
        ]
    }
    untagged_ability_cards: list[str] = []
    unexpected_untagged: list[str] = []
    ability_name_counts: dict[str, int] = {}

    for card in all_cards:
        abilities = card.get("abilities", [])
        attacks = card.get("attacks", [])
        tags = classify(abilities, attacks)

        for tag in tags:
            tag_counts[tag] = tag_counts.get(tag, 0) + 1

        for ability in abilities:
            name = ability.get("name", "")
            if name:
                ability_name_counts[name] = ability_name_counts.get(name, 0) + 1

        if abilities and not tags:
            entry = f"{card['name']} ({card['id']})"
            untagged_ability_cards.append(entry)
            if card["name"] not in KNOWN_UNTAGGABLE:
                unexpected_untagged.append(entry)

    print("=== Per-Tag Card Counts ===")
    for tag, count in sorted(tag_counts.items(), key=lambda x: -x[1]):
        print(f"  {tag:<25} {count:>4}")

    ability_bearing = sum(1 for c in all_cards if c.get("abilities"))
    print(f"\n=== Untagged ability-bearing cards: {len(untagged_ability_cards)} / {ability_bearing} ===")
    for name in sorted(untagged_ability_cards)[:30]:
        print(f"  {name}")
    if len(untagged_ability_cards) > 30:
        print(f"  ... and {len(untagged_ability_cards) - 30} more")

    if unexpected_untagged:
        print(f"\n  Unexpected (not in KNOWN_UNTAGGABLE):")
        for name in unexpected_untagged:
            print(f"    {name}")

    print("\n=== Top-10 ability names ===")
    for name, count in sorted(ability_name_counts.items(), key=lambda x: -x[1])[:10]:
        print(f"  {count:>4}  {name}")

    print(f"\nTotal cards: {len(all_cards)}")

    threshold = int(ability_bearing * UNTAGGED_THRESHOLD_PCT)
    if unexpected_untagged:
        print(
            f"\nERROR: {len(unexpected_untagged)} unexpected untagged ability card(s)."
            " Add them to KNOWN_UNTAGGABLE or extend the classifier.",
            file=sys.stderr,
        )
        sys.exit(1)

    if len(untagged_ability_cards) > threshold:
        print(
            f"\nERROR: {len(untagged_ability_cards)} untagged ability cards exceeds"
            f" {UNTAGGED_THRESHOLD_PCT:.0%} threshold ({threshold})."
            " Extend the classifier.",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"Tag coverage within threshold ({len(untagged_ability_cards)}/{ability_bearing} untagged). ✓")


if __name__ == "__main__":
    main()
