# BUG-38 — Player Rankings Discrepancy: Limitless vs. Play! Pokémon

**Status:** resolved  
**Area:** Competition Tab — `CompetitorsView` / player ranking data source

## Description

The player standings shown in the app draw from Limitless TCG (`limitlesstcg.com/players`), but the official Play! Pokémon leaderboard (`pokemon.com/us/play-pokemon/leaderboards/tcg-masters/`) displays different rankings for the same players. It is unclear which source the app should trust, and whether the official Pokémon leaderboard data is accessible for use.

## Observed Behaviour

- Limitless TCG rankings are community-aggregated from tournament results reported on their platform.
- Play! Pokémon rankings reflect official Championship Points (CP) awarded by TPCi at sanctioned events.
- The two can diverge significantly — a player strong on Limitless may rank differently on official standings, and vice versa.
- The app currently surfaces Limitless data with no indication that official standings may differ.

## Desired Behaviour

- If the Play! Pokémon leaderboard is accessible via a public API or structured endpoint, use it (or offer it alongside Limitless) so players see the standings that matter for Day 2 invites and World Championship qualification.
- If official data is not programmatically accessible, surface a clear data-source label in the UI so users know they are viewing Limitless community rankings, not official CP standings.

## Investigation Findings

### Root cause
The discrepancy is fundamental: Limitless TCG "points" are a **community ranking system** (proprietary points awarded by Limitless for placing in tournaments on their platform). Official Play! Pokémon **Championship Points (CP)** are a separate TPCi metric that determines World Championship invites. They are not the same number, measure different things, and will always diverge.

### Pokemon.com API
An undocumented public API exists at `https://www.pokemon.com/us/play-pokemon/leaderboards/op/api/`. Discovered via page source inspection of the JS bundle:
- Returns JSON: `{ leaderboards: [{ id, records: [{ screen_name, rank, country, country_name, score }] }] }`
- `score` = Championship Points
- Covers all divisions: `tcg-master`, `tcg-senior`, `tcg-junior`, `vg-master`, `vg-senior`, `vg-junior`, `pgo-all`
- **No auth required** — but protected by Incapsula bot detection. First cold request succeeds; subsequent calls from the same IP get blocked with a CAPTCHA page. Unreliable for repeated app use without backend infrastructure.
- No player IDs, no profile URLs, no tournament history — data is too thin to replace Limitless.

### Decision: Path B — source attribution + link-out
Limitless remains the data source. The fix is UI-only: make the data source visible and give users a path to official standings.

## Acceptance Criteria

### Investigation
- [x] Document whether `pokemon.com/us/play-pokemon/leaderboards/tcg-masters/` exposes a machine-readable endpoint — **yes**, at `/us/play-pokemon/leaderboards/op/api/`, but it's unreliable for direct app calls (Incapsula rate limiting).
- [x] Data source decision made: **Path B** — attribution + link-out.

### Fix (path B — implemented)
- [x] Add "Rankings via Limitless TCG" source label to the leaderboard section header in `CompetitorsView`.
- [x] Add "Official CP Standings ↗" link-out button that opens `pokemon.com/us/play-pokemon/leaderboards/tcg-masters/` via `openURL`.
- [x] Rename "pts" to "Limitless pts" in `PlayerCard` so the metric is clear in search results too.

## Technical Notes

**Files changed:** `JustTCG/Features/Competition/CompetitorsView.swift`  
- Added `@Environment(\.openURL)` and `officialStandingsURL` constant
- `filterHeader` now wraps zone chips + attribution row in a VStack
- `PlayerCard` label changed from `"\(pts) pts"` → `"\(pts) Limitless pts"`

**If official CP data is ever needed properly:** build a thin backend proxy that calls the pokemon.com API (to avoid Incapsula triggering on a single IP), or use the Limitless Labs CP aggregation at `labs.limitlesstcg.com/rankings` (scrape-able, aggregates rk9/playlatam data, but includes a "may contain mistakes" disclaimer).
