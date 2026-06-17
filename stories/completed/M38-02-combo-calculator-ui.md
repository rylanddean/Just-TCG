# M38-02 — Combo Calculator UI

**Status:** done  
**Milestone:** M38 — Opening Hand Combo Calculator  
**Dependencies:** M38-01, M29-02 (ConsistencySheet)

## User Story

As a competitive player, I want to select up to 5 cards from my deck inside the Consistency sheet and instantly see the probability that all of them appear together in my opening hand and in later draws, so I can quickly validate my key combo lines.

## Acceptance Criteria

### New Section in ConsistencySheet

- [ ] A new **"Combo Calculator"** section is added to `ConsistencySheet`'s `List`, positioned between the existing "Opening Hand Odds" section and the "About" section
- [ ] The section is always visible (not conditional on selection state)

### Card Selector

- [ ] A tappable **"+ Add Card"** row at the top of the Combo Calculator section (icon: `plus.circle`, label: "Add Card")
  - Disabled and shows a muted label ("Max 5 cards") when 5 cards are already selected
- [ ] Tapping "Add Card" presents a **`ComboCardPickerSheet`** as a `.sheet`
  - The picker lists all cards in the current deck (`mergedEntries`), one row per unique card name
  - Each row shows: card thumbnail (28×38 pt, same style as the odds rows), card name, `×N` copy badge
  - Tapping a row that is not already selected adds it to the selection and dismisses the sheet
  - Cards already selected are greyed out (`.opacity(0.4)`) and non-tappable
  - The sheet has a "Cancel" button in the toolbar
- [ ] Selected cards appear as rows directly in the Combo Calculator section, each showing:
  - Card thumbnail (28×38 pt)
  - Card name (1 line, truncated)
  - `×N` copies badge
  - A trailing **remove button** (`xmark.circle.fill`, `.secondary` tint) that deselects the card
- [ ] Selection state is `@State private var comboSelection: [ComboCardSelection]` in `ConsistencySheet`

### Probability Display

- [ ] Below the selected-card rows (or below "Add Card" when selection is empty), show a **probability table** when at least 1 card is selected:

| Row label | Value |
|---|---|
| Opening Hand (7 cards) | e.g. 43% |
| Turn 2 (9 cards) | e.g. 67% |
| Turn 3 (10 cards) | e.g. 74% |
| Turn 4 (11 cards) | e.g. 80% |

- [ ] Each row: leading label in `.secondary` foreground; trailing percentage in `.monospacedDigit()` weighted by the same colour-coding used elsewhere in the sheet (`< 40` → red, `40–59` → orange, `60–79` → yellow, `≥ 80` → green)
- [ ] When selection is empty, replace the table with a single `.secondary` hint row: "Select cards to calculate combo odds"
- [ ] While the engine is computing (async), show a `ProgressView()` in place of the table

### Async Computation

- [ ] Combo odds are computed **off the main thread** using `Task { await MainActor.run { … } }` (or `Task.detached`)
- [ ] A new `@State private var comboOdds: ComboOdds? = nil` and `@State private var comboComputing: Bool = false` drive the loading state
- [ ] Recompute whenever `comboSelection` changes (`.onChange(of: comboSelection)`)
- [ ] Cancel any in-flight task before starting a new one (store `@State private var comboTask: Task<Void, Never>?`)
- [ ] If `comboSelection` becomes empty, set `comboOdds = nil` immediately without computing

### Formatting

- [ ] All probabilities formatted with the existing `formatPercent(_:)` helper (`< 1%` for values below 1%)
- [ ] Section header: "Combo Calculator"
- [ ] No section footer

## Technical Notes

**`ComboCardPickerSheet` is a new private inner view** (defined at the bottom of `ConsistencySheet.swift` via a `fileprivate struct`) rather than a separate file — it is small and only used here.

**Computation call:**
```swift
comboTask?.cancel()
let selection = comboSelection
comboTask = Task.detached(priority: .userInitiated) {
    let odds = ConsistencyEngine.comboOdds(
        selectedCards: selection,
        deckSize: 60,
        simCount: 50_000
    )
    await MainActor.run {
        self.comboOdds = odds
        self.comboComputing = false
    }
}
```

**`ComboCardSelection` conformance:** add `Equatable` so `.onChange(of: comboSelection)` compiles cleanly.

**Files to change:**
- `JustTCG/Features/Decks/ConsistencySheet.swift` — add Combo Calculator section, `ComboCardPickerSheet`, combo odds state and async task
