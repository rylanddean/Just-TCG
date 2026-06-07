# M6-02 — Meta Comparison View

**Status:** todo  
**Milestone:** M6 — Meta Comparison  
**Dependencies:** M6-01, M4-01

## User Story
As a user, I want to see how my matchup data lines up against the current tournament meta so that I know which popular decks I'm prepared for and which ones I need to practice against.

## Acceptance Criteria

- [ ] A "Meta" section on the Analytics tab (below the matchup list) shows the top meta archetypes ranked by tournament share %
- [ ] Each meta archetype row shows:
  - Archetype name and meta share % (e.g. "18.4%")
  - My win rate vs this archetype from logged matches (if any data exists)
  - A combined status tag:
    - "Ready" — meta share ≥ 5% AND my win rate ≥ 50% AND sampleSize ≥ 5
    - "Danger" — meta share ≥ 5% AND my win rate < 40% AND sampleSize ≥ 5
    - "Practice needed" — meta share ≥ 5% AND sampleSize < 5
    - No tag for archetypes < 5% meta share
- [ ] Tapping a row opens the matchup detail (filtered match history for that archetype + the meta share chart for context)
- [ ] Empty state if no tournament data is loaded: "Connect to the internet to load tournament meta data"

## Technical Notes

- Cross-reference: join `MetaShare` list with `MatchupStat` list on archetype name (normalised)
- Archetype name normalisation must be consistent between `MetaShareEngine` and `MatchupStatsEngine`
- `MetaComparisonViewModel` composes both engines; data is recomputed when either matches or tournament data change
