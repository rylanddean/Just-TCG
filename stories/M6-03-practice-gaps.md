# M6-03 — Practice Gaps & Danger Matchup Surface

**Status:** todo  
**Milestone:** M6 — Meta Comparison  
**Dependencies:** M6-02

## User Story
As a user, I want the app to proactively surface my biggest preparation gaps — both archetypes I haven't played against and archetypes I'm consistently losing to — so that I know exactly where to focus my testing before a tournament.

## Acceptance Criteria

- [ ] A "Prepare for tournament" card at the top of the Analytics tab shows 2–3 priority practice recommendations
- [ ] Recommendation logic (in priority order):
  1. **Danger matchup**: meta share ≥ 5% AND my win rate ≤ 40% AND sampleSize ≥ 5 → "You're 2W–6L vs Dragapult ex (top meta deck)"
  2. **Practice gap**: meta share ≥ 5% AND sampleSize < 5 → "You have 0 logged games vs Gardevoir ex (8.2% of meta)"
  3. If no urgent issues: "You're well-prepared — no major gaps detected"
- [ ] Each recommendation card has a "Find deck lists" button that deep-links to the tournament feed filtered for that archetype
- [ ] The summary card shows "Based on last 5 Regionals+" so users understand the meta source
- [ ] The card is dismissable per session (reappears on next launch)

## Technical Notes

- Recommendation generation: `PracticeGapEngine.recommendations(meta: [MetaShare], stats: [MatchupStat], limit: Int) -> [Recommendation]`
- `Recommendation` struct: `type: RecommendationType`, `archetype: String`, `metaShare: Double`, `winRate: Double?`, `sampleSize: Int`
- `PracticeGapEngine` is a pure function — no side effects
- "Find deck lists" deep link: navigate to Tournaments tab, open search filtered to that archetype
