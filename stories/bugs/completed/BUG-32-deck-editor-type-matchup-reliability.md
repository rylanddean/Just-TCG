# BUG-32 — Deck Editor "Strong against" / "Weak against" Rows Are Unreliable

**Status:** done  
**Area:** M22 / Deck Builder — Type Matchup section

## Description

The "Type Matchup" section in `DeckBuilderView` shows two rows — "Strong against" and "Weak against" — sourced from `MetaMatchupEngine.breakdown(...)`. In practice these are unreliable:

- The "Weak against" computation derives `userWeaknessTypes` from each Pokémon's `weaknessType` field on `DeckCardEntry`, but only one `weaknessType` per card is captured and many entries are empty or stale, so the displayed "weak against" set is incomplete or wrong.
- The "Strong against" computation depends on whether the user's deck's attacker `types` contain the meta archetype's weakness type. Because meta archetype data is sparse, ability-based interactions are coarse, and same-type attackers are conflated with type-effective attackers, the "Strong against" row produces false positives that misinform deckbuilding decisions.

Until the strength side can be made trustworthy, we should remove "Strong against" entirely and rebuild the "Weak against" row by **scanning every Pokémon card actually in the deck** and aggregating the real `weaknessType` values from `CachedCard`, not from the slim `DeckCardEntry` projection.

## Steps to Reproduce

1. Open any deck in the Deck Builder
2. Scroll to the "Type Matchup" section
3. Compare "Strong against" / "Weak against" pills to the actual weaknesses printed on the Pokémon cards in the deck

## Observed Behaviour

- "Strong against" frequently shows matchups that aren't actually favourable
- "Weak against" misses meta types that the deck's Pokémon are literally weak to (per the printed card text)
- Result is misleading and erodes trust in the deck stats

## Desired Behaviour

- The "Strong against" row is removed for now (the underlying signal isn't reliable enough to display)
- The "Weak against" row is rebuilt to reflect the **actual printed weaknesses** of every Pokémon in the deck, deduplicated, with each weakness type shown only if at least one Pokémon copy in the deck is weak to it
- Quantity-weighted: if every Pokémon weak to type X has been cut to 0 or 1 copies versus a heavy `Basic` presence, the row should still surface X (presence-based, not threshold-based, for now)

## Acceptance Criteria

### Remove Strong Against
- [ ] The "Strong against" row in `DeckBuilderView.deckStatsSection` is removed
- [ ] The same row in `ImportDeckSheet`'s deck stats preview is removed (it's mirrored there)
- [ ] `MetaMatchupBreakdown.favouredAgainstTypes` may stay in the model (still used by `matchupScore`) but is no longer rendered in the editor

### Rebuild Weak Against From Deck Cards
- [ ] A helper (e.g. `DeckWeaknessSummary` in `JustTCG/Domain/Entities/`) takes the deck's Pokémon cards as `CachedCard` and returns the sorted, deduplicated set of `weaknessType` values present in the deck
- [ ] `DeckBuilderView` calls this helper using the full `CachedCard` records fetched via `CardRepository`, not the trimmed `DeckCardEntry` projection
- [ ] The "Weak against" row renders one capsule per distinct printed weakness, using the existing typeColor styling
- [ ] If no Pokémon in the deck have a printed weakness, the row is hidden entirely
- [ ] Quantity 0 entries (cards removed from the deck but still in the relationship) are excluded

### No Regressions
- [ ] Matchup gauge / `matchupScore` is unaffected — only the visible rows change
- [ ] `MetaMatchupSheet` (the detailed matchup breakdown) still renders the per-archetype list as before

## Technical Notes

**Files to change:**
- `JustTCG/Features/Decks/DeckBuilderView.swift` — remove the "Strong against" branch; replace the "Weak against" branch with the new helper output
- `JustTCG/Features/Decks/ImportDeckSheet.swift` — mirror the same removal/replacement in the import preview
- `JustTCG/Domain/Entities/` — new `DeckWeaknessSummary` (small pure struct/function) that takes `[CachedCard]` (Pokémon-only filter applied by caller) and returns `[String]` of unique weakness types

**Why pull from `CachedCard` directly:**
`DeckCardEntry` (defined in `ConsistencyEngine.swift`) is a slim projection. `CachedCard.weaknessType` is the authoritative field already populated from the bundled JSON pipeline. Fetching the full `CachedCard` for the deck's Pokémon and aggregating there avoids the lossy projection.
