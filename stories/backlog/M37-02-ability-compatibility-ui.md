# M37-02 — Ability Compatibility UI

**Status:** backlog  
**Milestone:** M37 — Ability Compatibility  
**Dependencies:** M37-01 (AbilityCompatibilityEngine), M29-02 (ConsistencySheet / ConsistencyGauge), M34-02 (MetaMatchupSheet — structural reference for stat sheet pattern)

## User Story

As a deck builder, I want to see at a glance when any Pokémon in my deck has an ability that the deck composition makes hard to use — with a warning badge on the specific card and a score in the stats panel — so I can fix the issue before it costs me a game.

## Acceptance Criteria

### DeckBuilderView changes

- [ ] Add `@State private var abilityCompatBreakdown: AbilityCompatibilityBreakdown? = nil`
- [ ] Add `@State private var showAbilityCompatSheet = false`
- [ ] Extend `computeStats()` to call `AbilityCompatibilityEngine().breakdown(entries:abilityTexts:)` and store the result in `abilityCompatBreakdown`
  - `abilityTexts` closure: for a given card name, look up the `CachedCard` in `vm.cachedCards`, then call `AbilityCompatibilityEngine.parseAbilities(from: card.rulesText)`; return `[]` if card not found
  - Compute this after `deckBreakdown` (which already builds `mergedDeckEntries`) — reuse `mergedDeckEntries` as input
- [ ] `abilityCompatBreakdown` is only computed (and displayed) when `mergedDeckEntries` contains at least one Pokémon with `hasAbility == true`; otherwise leave it `nil`

### Stats section — new sub-score row

- [ ] In `deckStatsSection`, add a new `statsSubScoreRow` for `"Ability Compat"` immediately after the existing `"Ability Impact"` row:

```swift
if let acb = abilityCompatBreakdown, acb.hasIssues {
    statsSubScoreRow(
        "Ability Compat", score: acb.compatibilityScore,
        explainer: abilityCompatExplainer(acb)
    )
    .onTapGesture { showAbilityCompatSheet = true }
}
```

- [ ] The row is **only shown when `acb.hasIssues` is true** — decks with no conditional abilities are silently OK and don't need a row
- [ ] The row is tappable (`.onTapGesture`) and opens `AbilityCompatibilitySheet`
- [ ] Add `.sheet(isPresented: $showAbilityCompatSheet)` presenting `AbilityCompatibilitySheet(breakdown: abilityCompatBreakdown!)`
- [ ] `abilityCompatExplainer(_:)` — private helper returning a String:
  - Format: `"N ability conflict\(N == 1 ? "" : "s") detected. [Card] — [abilityName]: [warningMessage]"` where the first conflict is inlined; if there are more, append `" + M more."` Tap to see all.`
  - Example: `"1 ability conflict detected. Mewtwo ex — Power Saver: Requires 4 Team Rocket's Pokémon in play, but the deck only has 2 — condition is rarely met."`

### Conflict badges on card rows

- [ ] Add `var abilityConflictSeverity: AbilitySeverity? = nil` parameter to `DeckCardRow`
- [ ] In the `DeckCardRow` body, when `abilityConflictSeverity` is `.conflict` or `.caution`, add a small badge after the `RoleBadge` in the subtitle `HStack`:

```swift
if let severity = abilityConflictSeverity {
    AbilityConflictBadge(severity: severity)
}
```

- [ ] `AbilityConflictBadge` — private view (defined at the bottom of `DeckBuilderView.swift` alongside `RoleBadge`):
  - `.conflict`: `Image(systemName: "exclamationmark.triangle.fill")` in `.red`, caption label `"Ability Conflict"` — SF Symbol + text in a `HStack` with `.caption2` font
  - `.caution`: `Image(systemName: "exclamationmark.circle.fill")` in `.orange`, caption label `"Ability Caution"`
  - Both use the same capsule-background chip style as `RoleBadge`
- [ ] In the section that builds each `DeckCardRow`, look up the conflict severity from `abilityCompatBreakdown?.results.first(where: { $0.cardName == card.name })?.severity` and pass it as `abilityConflictSeverity`; pass `nil` when the breakdown is nil or no result found

### AbilityCompatibilitySheet

- [ ] New file `JustTCG/Features/Decks/AbilityCompatibilitySheet.swift`

```swift
struct AbilityCompatibilitySheet: View {
    let breakdown: AbilityCompatibilityBreakdown
}
```

**Header section:**
- Large `ConsistencyGauge` (96×96) centred at top showing `breakdown.compatibilityScore`
- Below gauge: `"ability compatibility"` in `.secondary` caption style

**Conflict list:**
- Section titled `"Issues"` (only shown when `breakdown.hasIssues`)
- One row per `AbilityCompatibilityResult` where `severity != .ok`, sorted by `score` ascending (worst first)
- Each row:
  - Leading: `AbilityConflictBadge(severity: result.severity)` icon only (no label text, just the SF Symbol)
  - Centre: card name (`.body`) + ability name (`.caption`, secondary colour) on two lines; count shown as `"×\(result.copies)"` in caption secondary
  - Trailing: score chip — same capsule style as `RoleBadge`, colour matching severity (red for conflict, orange for caution)
  - Below the centre text, the `warningMessage` in `.caption2` secondary if non-nil

**OK section:**
- Section titled `"No Issues"` (only when there are `.ok` results)
- One compact row per OK result: checkmark icon + card name + ability name — no warning text needed

**About section:**
Static explanatory text:
> "Ability Compatibility scores how reliably each ability Pokémon in your deck can use its ability given your deck's composition. A 100 means every ability fires unconditionally or the deck easily satisfies any conditions. Scores fall when abilities require a minimum number of specific Pokémon in play (e.g., 'Team Rocket's Pokémon') or a named card that isn't in the deck. Conflicts (red) mean the condition is almost never met; Cautions (orange) mean it's sometimes met but unreliably. The deck-level score starts at 100 and loses 30 points per conflict and 15 per caution."

**Empty state:**
- If `breakdown.results.isEmpty`, show `ContentUnavailableView("No ability Pokémon", systemImage: "pawprint")` with subtitle `"Add Pokémon with abilities to see compatibility analysis."`

**Navigation:**
- `.navigationTitle("Ability Compatibility")`
- `.navigationBarTitleDisplayMode(.inline)`
- Toolbar `"Done"` button dismisses

## Technical Notes

**Why the row is hidden when no issues exist:**  
Most competitive decks run unconditional draw/search abilities (Bibarel, Pidgeot ex, etc.) and would always score 100. Showing a 100-score row for these decks adds noise without value. The row surfaces only when the engine finds a real problem to act on.

**Score colour semantics:**  
Reuse the existing `scoreColor(_:)` private function already in `DeckBuilderView` (green ≥ 80, yellow 60–79, orange 40–59, red < 40) — no new colour logic needed.

**`AbilityConflictBadge` sharing with `AbilityCompatibilitySheet`:**  
Define `AbilityConflictBadge` as a `fileprivate` struct in `DeckBuilderView.swift`. Import it into `AbilityCompatibilitySheet.swift` by moving it to its own file `JustTCG/Features/Decks/AbilityConflictBadge.swift` with `internal` access so both files can use it without making it public API.

**Files to create:**
- `JustTCG/Features/Decks/AbilityCompatibilitySheet.swift`
- `JustTCG/Features/Decks/AbilityConflictBadge.swift`

**Files to modify:**
- `JustTCG/Features/Decks/DeckBuilderView.swift` — state, `computeStats()`, `deckStatsSection`, `DeckCardRow`, sheet trigger
