# BUG-24 — Rulebook / Rules Assistant Is Not Discoverable

**Status:** todo  
**Area:** M23 — Rulebook & Rules Assistant

## Description

`RulesAssistantSheet` exists and is functional, but its only entry point is a plain `questionmark.circle` toolbar button in the top-right of `HomeView`. There is no label, no visible affordance, and nothing in the tab bar or navigation that signals a rulebook feature exists. Most users will not find it. Additionally, the rules feature is AI-only (a chat sheet) with no way to browse the underlying rulebook sections directly — `RulebookSection` and `RulebookLoader` are bundled but never surfaced in a UI.

## Steps to Reproduce

1. Launch the app
2. Try to find where to look up a Pokémon TCG rule

## Observed Behaviour

- No tab, menu item, or card on the Home screen indicates a rulebook or rules assistant exists
- The only entry point is a `questionmark.circle` icon in the `HomeView` toolbar — indistinguishable from a help/about button
- Tapping it opens a chat sheet (`RulesAssistantSheet`) — no way to browse the 18 bundled rule sections

## Desired Behaviour

Users can discover and navigate to the rules feature without being told it exists. They can both browse rulebook sections directly and ask the AI assistant questions.

## Acceptance Criteria

### Entry Point — Home Quick-Action Card
- [ ] A tappable "Rules" quick-action row or card is added to `HomeView` (alongside the existing widgets), showing a `book.fill` icon, the title "Rules", and a subtitle "Browse the rulebook or ask a question"
- [ ] Tapping it opens a new `RulesView` (a `NavigationStack`-wrapped sheet or a full navigation destination)
- [ ] The existing `questionmark.circle` toolbar button in `HomeView` is **removed** — the quick-action card replaces it

### RulesView — Browseable Rulebook
- [ ] A new `RulesView` is created at `JustTCG/Features/Rules/RulesView.swift`
- [ ] It loads sections via `RulebookLoader` and renders them as a `List` with each `RulebookSection.title` as a navigation row
- [ ] Tapping a section opens a `RulebookSectionDetailView` showing the section title as a `navigationTitle` and the `body` text in a scrollable `Text` view with `.body` font and comfortable padding
- [ ] A persistent "Ask the Rules Assistant" button is visible at the bottom of `RulesView` (above the list or as a toolbar button) — tapping it opens `RulesAssistantSheet` as a sheet

### No Regressions
- [ ] `RulesAssistantSheet` itself is unchanged
- [ ] Profile and Settings toolbar buttons on `HomeView` are unaffected

## Technical Notes

**New files:**
- `JustTCG/Features/Rules/RulesView.swift` — list of sections + "Ask Assistant" button
- `JustTCG/Features/Rules/RulebookSectionDetailView.swift` — detail view for a single section

**Files to change:**
- `JustTCG/Features/Home/HomeView.swift` — remove `questionmark.circle` toolbar button + `showRulesAssistant` state; add a `RulesQuickActionCard` widget or row that presents `RulesView`

**RulebookLoader pattern:**
```swift
// RulebookLoader.load() → [RulebookSection] (reads PokemonTCGRules.json from bundle)
let sections = RulebookLoader.load()
```
