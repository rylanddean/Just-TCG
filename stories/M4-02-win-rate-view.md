# M4-02 — Matchup Analytics View

**Status:** todo  
**Milestone:** M4 — Analytics  
**Dependencies:** M4-01

## User Story
As a user, I want to see my win rate against every archetype I've faced with my deck, tagged as favourable or unfavourable, so that I know which matchups I need to practice or avoid.

## Acceptance Criteria

- [ ] Analytics tab shows a deck picker at the top — defaults to the most recently used deck
- [ ] Below the picker: overall record (e.g. "21W – 11L – 2T — 65.6%")
- [ ] A segmented list of matchup rows, one per archetype, sorted by sample size (desc):
  - Archetype name
  - Win/Loss/Tie counts (e.g. "4W 2L")
  - Win rate % 
  - Tag chip: "Favourable" (green), "Even" (grey), "Unfavourable" (red), "Low data" (outlined grey)
- [ ] A time filter (All time / Last 30 days / Last 90 days) above the list
- [ ] Tapping a matchup row expands it to show a mini match history (last 5 games vs that archetype)
- [ ] Empty state: "No matches logged yet — log your first match from the deck detail view"

## Technical Notes

- `AnalyticsViewModel` loads all matches for the selected deck via `@Query`, passes them through `MatchupStatsEngine.compute`
- Time filter drives the `since:` parameter on `compute`
- Deck picker is a `Picker` with `.menu` style backed by `@Query` on `Deck`
