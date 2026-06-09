# M33-02 — Tech Advisor UI

**Status:** done  
**Milestone:** M33 — Tech Card Advisor  
**Dependencies:** M33-01

## User Story

As a competitive player, I want a one-tap "Suggest Tech" button on my deck that shows AI-powered card suggestions with explanations so I can quickly evaluate which tech slots make sense for the current meta.

## Acceptance Criteria

### Entry Point

- [ ] A **"Suggest Tech"** button (icon: `wand.and.stars`) is added to `DeckBuilderView`'s toolbar
- [ ] Button is disabled (greyed out with a tooltip) when `TechAdvisorEngine.buildRequest` would return `nil` (< 5 matches logged)
- [ ] Tapping presents `TechAdvisorSheet` as a `.sheet`

### TechAdvisorSheet

- [ ] New file `JustTCG/Features/Decks/TechAdvisorSheet.swift`
- [ ] Sheet is presented with `deck` and `deckID` injected on init

**Loading state:**
- [ ] On appear, calls `TechAdvisorEngine.buildRequest(…)` then `suggestTech(for:)` automatically
- [ ] Shows a centred `ProgressView("Analysing your matchups…")` while `isGenerating == true`

**Results state (suggestions loaded):**
- [ ] Navigation title: `"Tech Suggestions"`
- [ ] Subtitle: `"Based on your last N matches"` (N from `TechAdvisorRequest.worstMatchups.reduce(0) { $0 + $1.gamesPlayed }`)
- [ ] **Matchup context section** (collapsible, collapsed by default):
  - Heading: "Your Worst Matchups"
  - One row per `MatchupSummary`: archetype name + win rate bar + `"XX%"` label (red if < 40%, orange if 40–49%, otherwise yellow)
- [ ] **Suggestions section**:
  - One card per `TechSuggestion`:
    - Card name (bold) + `"×N"` suggested count badge
    - Reasoning text (body style, secondary colour)
    - Tags: one chip per `targetMatchup`
    - **"+ Add to Deck"** button: tapping calls `DeckRepository.addCard(…)` with `suggestedCount` copies and dismisses the sheet; shows a brief toast `"Added N× CardName"`
    - **"View Card"** button: pushes `CardDetailView` for the matched `CachedCard` (looked up by name; if no match, button is hidden)

**Error state:**
- [ ] `TechAdvisorError.modelUnavailable` → `ContentUnavailableView("Requires iOS 26", systemImage: "cpu", description: Text("AI tech suggestions need Apple Intelligence, available on iOS 26+."))`
- [ ] `TechAdvisorError.insufficientData` → `ContentUnavailableView("Not Enough Data", systemImage: "chart.bar", description: Text("Log at least 5 matches with this deck to get tech suggestions."))`
- [ ] Other errors → generic error view with a "Try Again" button

**Regenerate:**
- [ ] A `"Regenerate"` button in the navigation bar (trailing) triggers `suggestTech` again while suggestions are showing
- [ ] During regeneration, existing suggestions remain visible with a subtle overlay `ProgressView`

### Add-to-Deck Confirmation

- [ ] If the card name from `TechSuggestion` matches a `CachedCard` by exact name (case-insensitive), the button adds `suggestedCount` copies via `DeckRepository`
- [ ] If no `CachedCard` match is found, the "+ Add to Deck" button is replaced with `"Card not in library"` in secondary colour (disabled)
- [ ] After adding, the suggestion row shows a `checkmark.circle.fill` (green) in place of the button — persists for the session

### Deck legality re-check

- [ ] After adding any suggested card, the legality banner in `DeckBuilderView` re-evaluates on the sheet's dismiss

## Technical Notes

**Files to create:**
- `JustTCG/Features/Decks/TechAdvisorSheet.swift`

**Files to change:**
- `JustTCG/Features/Decks/DeckBuilderView.swift` — add toolbar button + sheet state

**Disabled button tooltip (iOS 17+):**
```swift
Button("Suggest Tech") { … }
.disabled(insufficientData)
.help("Log at least 5 matches to unlock tech suggestions")
```

**Card name lookup:**
```swift
let descriptor = FetchDescriptor<CachedCard>(
    predicate: #Predicate { $0.name.localizedStandardContains(suggestion.cardName) }
)
let matches = try? context.fetch(descriptor)
let card = matches?.first
```

**Toast implementation:**
Reuse the existing toast pattern from M21-01 (quick-add to deck) — the same `ToastOverlay` modifier and `ToastMessage` model.
