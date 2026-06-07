# M9-01 — Card Role Tag Taxonomy & Analysis Script

**Status:** done  
**Milestone:** M9 — Card Role Tag Filtering  
**Dependencies:** none (analysis only)

## User Story

As a developer, I want a well-defined, validated taxonomy of card role tags so that downstream stories (model, seeder, filter UI) all use the exact same canonical strings and cover the meaningful ability/attack patterns present in the bundled card set.

## Acceptance Criteria

- [x] A Python script `scripts/analyze_role_tags.py` is written that:
  - Loads all 15 bundled JSON files from `JustTCG/CardData/`
  - Classifies each card against the canonical tag list (see below) using ability name + text and attack name + text
  - Prints per-tag card counts, a list of untagged ability-bearing cards, and top-10 unmatched ability names
  - Exits non-zero if unexpected ability-bearing cards receive zero tags (exits cleanly when untagged cards are all in the documented `KNOWN_UNTAGGABLE` set and the count is within the 5% threshold)
- [x] The script output is reviewed and all 13 canonical tags have non-zero card counts with reasonable distribution
- [x] The canonical tag strings are documented in this story and agreed upon before M9-02 begins

## Canonical Tag List

| Tag | Triggers on |
|-----|-------------|
| `Draw` | Ability/attack text contains "draw … card" |
| `Search` | Ability/attack text contains "search your deck" or "look at the top" |
| `Energy Acceleration` | Ability/attack text contains "attach"+"energy" OR "move"+"energy" |
| `Healing` | Ability/attack text contains "heal" or "remove … damage counter" |
| `Damage Reduction` | Ability/attack text contains "less damage", "prevent … damage", "reduce … damage", or "prevent all effects" |
| `Damage Boost` | Ability/attack text contains "more damage" or "additional damage" |
| `Disruption` | Ability/attack text contains "discard", "lost zone", "can't play", "devolve", or (opponent's hand + shuffle) or (opponent + cost + more) |
| `Status` | Ability/attack text contains "Poisoned", "Burned", "Paralyzed", "Asleep", "Confused" |
| `Spread Damage` | Ability/attack text places damage counters on Benched Pokémon, "each of your opponent's Pokémon", or matches `put/place \d+ damage counter` |
| `Survivability` | Ability text (only) contains "not Knocked Out" or "remaining HP.*10" |
| `Mobility` | Ability/attack text contains "switch", "no Retreat Cost", "Retreat Cost"+"less", or "shuffle"+"into your deck" |
| `Prize Control` | Ability/attack text mentions "Prize card" + take/more/fewer/additional |
| `Lock` | Ability/attack text contains "can't play", "can't use", "can't be put", "can't be moved", "lose.*Ability", or "no Abilities" |

## Actual Per-Tag Card Counts (from script run on 2788 cards)

| Tag | Count |
|-----|-------|
| Disruption | 483 |
| Damage Boost | 429 |
| Energy Acceleration | 337 |
| Status | 236 |
| Search | 223 |
| Damage Reduction | 184 |
| Mobility | 137 |
| Lock | 131 |
| Draw | 125 |
| Healing | 114 |
| Spread Damage | 113 |
| Prize Control | 63 |
| Survivability | 9 |

23/509 ability-bearing cards are intentionally untagged (pure utility abilities — extra attack enablers, conditional evolution speed, opponent bench seeding — that don't fit the 13-tag taxonomy). These are documented in `KNOWN_UNTAGGABLE` in the script.

## Technical Notes

- Classification is purely keyword-based (no ML). False negatives are acceptable at this stage; the goal is covering the majority of meaningful cards.
- Cards with no abilities and no non-damage attack text receive an empty `roleTags` array — this is intentional. Trainers and Energy cards without effects will be untagged.
- The script is a dev tool only and does not run at build time. The canonical strings it validates against become the ground truth for M9-03's Swift classifier.
