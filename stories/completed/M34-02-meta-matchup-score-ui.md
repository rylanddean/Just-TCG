# M34-02 — Meta Matchup Score UI

**Status:** done  
**Milestone:** M34 — Meta Matchup Score  
**Dependencies:** M34-01 (MetaMatchupEngine), M29-02 (ConsistencySheet / ConsistencyGauge), M30-02 (MetaTrendEngine environment injection)

## User Story

As a competitive player, I want to see my deck's meta matchup score at a glance in the deck builder alongside my Overall and Consistency scores, and drill into a breakdown showing exactly which top meta decks I beat, lose to, or split against.

## Acceptance Criteria

### DeckBuilderView changes

- [ ] Add `@Environment(MetaTrendEngine.self) private var metaTrendEngine` to `DeckBuilderView`
- [ ] Add `@State private var matchupBreakdown: MetaMatchupBreakdown? = nil` 
- [ ] Add `@State private var showMatchupSheet = false`
- [ ] Extend `computeStats()` (the method that also computes `deckBreakdown`) to call `MetaMatchupEngine().breakdown(deck:metaShares:)` and store the result in `matchupBreakdown`
  - `metaShares`: use `metaTrendEngine.snapshots.last?.archetypeShares ?? []`
  - If `metaTrendEngine.snapshots` is empty, skip matchup computation and leave `matchupBreakdown` as nil
- [ ] In `deckStatsSection`, add a third `ConsistencyGauge` for "Matchup" beside the existing Overall and Consistency gauges:

```swift
// Before (two gauges):
HStack {
    Spacer()
    ConsistencyGauge(score: bd.overallScore, label: "Overall")
    Spacer()
    ConsistencyGauge(score: bd.consistencyScore, label: "Consistency")
    Spacer()
}

// After (three gauges):
HStack {
    Spacer()
    ConsistencyGauge(score: bd.overallScore, label: "Overall")
    Spacer()
    ConsistencyGauge(score: bd.consistencyScore, label: "Consistency")
    Spacer()
    if let mb = matchupBreakdown {
        ConsistencyGauge(score: mb.matchupScore, label: "Matchup")
            .onTapGesture { showMatchupSheet = true }
        Spacer()
    }
}
```

- [ ] Add `.sheet(isPresented: $showMatchupSheet)` presenting `MetaMatchupSheet` with the breakdown and deck entries passed in
- [ ] The Matchup gauge does not appear if `matchupBreakdown` is nil (meta trend data not yet loaded)
- [ ] The Matchup gauge is tappable (same tap area as the gauge frame) — use `.onTapGesture` on the gauge, not a `Button` wrapper, to match the existing Overall/Consistency gauges which also respond to tap in the same section

### MetaMatchupSheet

- [ ] New file `JustTCG/Features/Decks/MetaMatchupSheet.swift`

```swift
struct MetaMatchupSheet: View {
    let breakdown: MetaMatchupBreakdown
    let deckEntries: [DeckCardEntry]   // for potential future per-card callouts
}
```

**Header section — score summary:**
- Large `ConsistencyGauge` (size 96×96) centred at the top of the sheet showing `breakdown.matchupScore`
- Below the gauge, one-line descriptor: `"vs. top meta"` in secondary colour

**Matchup list — one row per `MatchupEntry` in `breakdown.matchups`:**

Each row shows:
- Leading: type colour dot (use the existing type colour system if present, otherwise a plain circle) with `primaryType` label
- Centre: archetype name (primary text) + meta share percentage (secondary, e.g. `"12.4% meta"`)
- Trailing: advantage badge
  - Favoured → green checkmark chip: `"Favoured"`
  - Even → grey equals chip: `"Even"`
  - Unfavoured → red X chip: `"Unfavoured"`
- If `abilitySource` is non-nil, show a secondary line beneath the archetype name in a caption style: `"via <abilitySource>"` — this surfaces ability-driven advantages so the player understands why a non-obvious matchup scores well

**About section:**

Static explanatory text:
> "Matchup Score (0–100) rates how your deck's type composition fares against the most-played archetypes in recent tournaments. 100 means a type advantage in every meta matchup weighted by popularity; 0 means you're consistently on the wrong side of the weakness chart. Ability-driven advantages (such as Fairy Zone) are factored in where known. A score above 65 is generally strong for the current meta."

**Empty state:**
- If `breakdown.matchups` is empty, show `ContentUnavailableView("No meta data", systemImage: "chart.bar.xaxis")` with subtitle `"Load tournament data to calculate matchup scores."`

**Navigation:**
- `.navigationTitle("Meta Matchup")`
- `.navigationBarTitleDisplayMode(.inline)`
- Toolbar `"Done"` button dismisses

### Score colour semantics

Reuse the existing `ConsistencyGauge` colour thresholds (green ≥ 70, yellow 40–69, red < 40) — no new colour logic needed for the Matchup gauge.

## Technical Notes

**Why `deckEntries` is passed to the sheet even though it is not used in this story:**

The sheet signature includes `deckEntries` to leave room for a future enhancement where tapping an Unfavoured row shows which specific Pokémon in the deck carry the exploitable weakness, without requiring a sheet redesign.

**Gauge sizing in the three-gauge layout:**

The existing two-gauge `HStack` uses `.frame(width: 80, height: 80)` per gauge. With three gauges the same padding strategy applies — test at iPhone 15 Pro (393 pt wide) to confirm no clipping. If it clips, drop gauge size to 72×72 for all three uniformly.

**Files to create:**
- `JustTCG/Features/Decks/MetaMatchupSheet.swift`

**Files to modify:**
- `JustTCG/Features/Decks/DeckBuilderView.swift` — environment, state, gauge, sheet trigger
