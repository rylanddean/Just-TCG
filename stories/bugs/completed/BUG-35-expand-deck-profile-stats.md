# BUG-35 — Expand Deck Profile Stat Axes

**Status:** done  
**Area:** M29 — Consistency Engine / Deck Profile

## Description

The Deck Profile section in `DeckBuilderView` currently exposes eight sub-scores via `ConsistencyBreakdown`:

- Ability Impact, Energy Setup, Mobility, Prize Resilience, Disruption Power, Evolution Reliability, Recovery, Item Dependency

These cover a lot but leave gaps that competitive players reason about when tuning a list. We should explore expanding the profile with additional, well-defined axes — each one has to be (a) computable from data we already have on `DeckCardEntry` + `CachedCard` + role tags, (b) actionable (changes the deckbuilding decision), and (c) explainable in a one-paragraph explainer like the existing rows.

This is partly a design bug — we want to land a concrete next set of axes — and partly an engineering story.

## Steps to Reproduce

1. Open a deck in the Deck Editor
2. View the Deck Profile section
3. Notice missing dimensions that experienced players care about (gust pressure, prize trade math, late-game closer reliability, etc.)

## Observed Behaviour

- Profile is comprehensive but doesn't surface several dimensions players still reason about manually
- No way to compare two decks on dimensions like "how hard does this deck hit turn 2" or "how punishable is its prize trade math"

## Desired Behaviour

Add a set of new sub-scores to `ConsistencyBreakdown`, render them in the Deck Profile section, and back each with an explainer. Initial proposals (we should land 3–5 of these in the first pass — prioritization is part of the bug):

### Proposed New Axes

1. **Gust / Pull Pressure** — How many cards in the deck can gust the opponent's bench up (Boss's Orders, Counter Catcher, equivalent abilities). High = strong KO control.
2. **Turn-2 Aggression** — Probability of attacking on turn 2 with the deck's primary attacker, derived from basic counts, energy acceleration, and primary attacker copies. Could reuse hypergeometric math from `ConsistencyEngine`.
3. **Prize Trade Math** — Weighted average prize count given up per KO across the deck's attackers (single-prize=1, ex/V=2, VMAX/Tera ex Stage 2=3). Lower is better. Combine with Prize Resilience for a clearer picture.
4. **Bench Space Pressure** — How many bench slots are typically occupied by required engine Pokémon (e.g. Bibarel, Pidgeot ex, Squawkabilly ex) versus available for attackers. Players need to know if their engine is starving their attacker bench.
5. **Damage Ceiling** — Highest reliable damage output across the deck's attackers, normalized against current meta HP pools. Surfaces decks that can't OHKO common meta threats.
6. **Energy Discard Tolerance** — How well the deck recovers from energy denial (Iono's Bellibolt, Drapion V Riotous Beating analogs, etc.). Combines basic energy count, acceleration, and recovery cards.
7. **Bricking Risk (Mulligan + Dead Hand)** — Estimated mulligan rate (Basic count) and probability of a "no playable card" opening hand. Already partially exposed by `mulliganRiskPercent` — promote to a profile axis with a clearer name.
8. **Setup Speed** — Time-to-online estimate: how many turns to reach the deck's win-condition board state. Pair with Turn-2 Aggression.
9. **Tech Slot Flexibility** — Count of "free" slots in the list (Trainers not load-bearing in any core axis) — a high score means the deck is rigid; low means there's room to tech.

## Acceptance Criteria

### Selection
- [ ] Pick 3–5 of the proposed axes (or new ones) for the first pass, justifying each pick in the PR description against the (a)/(b)/(c) criteria above
- [ ] Drop ideas that overlap too heavily with existing axes (e.g. don't add "Bricking Risk" if `mulliganRiskPercent` already covers it well — just rename/promote)

### Engine
- [ ] Each selected axis is added as a stored `Int` (0–100) property on `ConsistencyBreakdown`
- [ ] Each axis has a unit-tested deterministic computation in `ConsistencyEngine` (or a sibling engine if the math is large — e.g. `DamageCeilingEngine`)
- [ ] Where the math requires data not on `DeckCardEntry`, extend the projection at the source (`DeckBuilderViewModel` / wherever `DeckCardEntry` is constructed) rather than re-fetching cards in the engine
- [ ] `overallScore` weighting is reviewed — decide whether the new axes count toward it and at what weight

### UI
- [ ] Each new axis is rendered as a `statsSubScoreRow` in the Deck Profile section with an explainer (≥ 2 sentences, no jargon-without-definition)
- [ ] If any axis is "lower is better" (like Item Dependency), use `colorInverted: true`
- [ ] Section length stays scannable — if the profile starts feeling crowded, group related axes under sub-headers (e.g. "Engine", "Prize Trade", "Pressure") inside the existing Deck Profile section

### Downstream
- [ ] `DeckCleanupEngine` (see BUG-34) can read the new axes — make sure the new axes plug into the same suggestion framework where they could drive cleanup rules
- [ ] No changes required to `MetaTrendEngine`, `MetaMatchupEngine`, or `TechAdvisorEngine` — those operate on different inputs

## Technical Notes

**Files to change:**
- `JustTCG/Domain/Entities/ConsistencyEngine.swift` — extend `ConsistencyBreakdown` with the new fields, compute them in the existing `breakdown(...)` flow
- `JustTCG/Features/Decks/DeckBuilderView.swift` — render new rows in `deckStatsSection` with explainers
- (Optional) `JustTCG/Features/Decks/ConsistencySheet.swift` — surface the new axes in the dedicated consistency sheet too if it currently mirrors the editor profile

**Data we already have (no new pipeline work needed):**
- `DeckCardEntry`: `name`, `quantity`, `supertype`, `types`, `roleTags`, `weaknessType`, `hasAbility`
- `CachedCard`: HP, retreat cost, attacks (with damage and energy cost), abilities, weaknesses, resistances

**Data we may need to add to `DeckCardEntry`:**
- Damage values from primary attacks (for Damage Ceiling)
- Required bench slots / occupies-bench role tag (for Bench Space Pressure)
- Energy acceleration target type (already loosely captured by role tags — verify before extending)

**Watch out for:**
- Sample size: many of these axes are sensitive to card-data accuracy. If a new axis depends on a field that's empty or stale in the bundled JSON, fix the seeder first (and bump `bundled_cards_seeded_v8` accordingly).
- Don't add an axis that can't be explained in one paragraph — players will distrust scores they can't reason about.
