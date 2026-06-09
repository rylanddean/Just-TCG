# M29-02 — Consistency Sheet UI

**Status:** done  
**Milestone:** M29 — Deck Consistency Calculator  
**Dependencies:** M29-01

## User Story

As a competitive player, I want to open a consistency report from my deck so I can see my consistency score, draw/search counts, and opening-hand odds for every card at a glance.

## Acceptance Criteria

### Entry Point

- [ ] A **"Consistency"** toolbar button (icon: `chart.bar.xaxis`) is added to `DeckBuilderView`'s navigation bar (leading side, opposite the existing "Edit" button)
- [ ] Tapping it presents `ConsistencySheet` as a `.sheet`

### ConsistencySheet

- [ ] New file `JustTCG/Features/Decks/ConsistencySheet.swift`
- [ ] Sheet header: deck name + `ConsistencyGauge` (see below)
- [ ] Three sections in a `List`:

**Section 1 — Summary**
- Consistency Score row: large number (0–100) with colour coding:
  - `< 40` → `.red`
  - `40–59` → `.orange`
  - `60–79` → `.yellow`
  - `≥ 80` → `.green`
- Draw count row: "Draw cards: N copies" with `hand.draw` SF Symbol
- Search count row: "Search cards: N copies" with `magnifyingglass` SF Symbol

**Section 2 — Opening Hand Odds**
- One row per card in `ConsistencyBreakdown.keyCards` (all cards, sorted by copies desc)
- Row layout:
  - Leading: card name (truncated to 1 line) + copies badge (`×N`)
  - Trailing: probability bar (see below) + percentage label (`43%`)
- Probability bar: a `GeometryReader`-based filled capsule 60 pt wide, fill colour matching the score colour bands above applied to the probability value
- Tapping a row expands an inline disclosure showing:
  - "By Turn 2 (going first): XX%"
  - "By Turn 2 (going second): XX%"

**Section 3 — About This Score**
- Static explanatory text: "Consistency Score (0–100) measures how reliably you can draw or search for cards in the first two turns. Scores above 60 are generally considered tournament-ready."

### ConsistencyGauge

- [ ] A `Gauge(value:in:)` arc-style gauge (iOS 16+) showing the consistency score 0–100
- [ ] Labelled with the score number in the centre and "Consistency" below
- [ ] Gauge colour uses `Gradient` across the same red→green colour band

### Data Loading

- [ ] Sheet receives the deck's `[DeckCard]` on init; resolves `DeckCardEntry` values inline
- [ ] `roleTags` closure is satisfied by looking up `CachedCard` from the injected `ModelContext` by card name — if no match found, returns `[]`
- [ ] All computation happens synchronously on appear (deck is ≤ 60 cards; no async needed)
- [ ] If the deck has 0 cards, show a `ContentUnavailableView("No cards in deck", …)`

### Formatting

- [ ] All percentages formatted as `"XX%"` (no decimal places) using `NumberFormatter` with `numberStyle = .percent`, `maximumFractionDigits = 0`
- [ ] Probabilities below 1% shown as `"< 1%"` rather than `"0%"`

## Technical Notes

**Files to create:**
- `JustTCG/Features/Decks/ConsistencySheet.swift`

**Files to change:**
- `JustTCG/Features/Decks/DeckBuilderView.swift` — add toolbar button + sheet state
