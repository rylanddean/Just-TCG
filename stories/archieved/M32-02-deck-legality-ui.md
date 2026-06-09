# M32-02 — Deck Legality Badge & Violation Sheet

**Status:** todo  
**Milestone:** M32 — Format Rotation Guard  
**Dependencies:** M32-01

## User Story

As a competitive player, I want to see a legality badge on each deck and a detailed violation list so I know at a glance whether my deck is tournament-legal and exactly which cards need to be swapped.

## Acceptance Criteria

### Deck Row Badge

- [ ] `DeckRow` in `DecksView` gains a legality badge alongside the existing win-rate badge:
  - `"STD ✓"` (green) — legal in Standard
  - `"STD ✗"` (red) — illegal in Standard (N violations)
  - Badge only shown if the deck has ≥ 1 card
- [ ] The badge format string is `"\(formatShort) \(isLegal ? "✓" : "✗")"`; Standard is always checked (Expanded shown only when user preference selects it — see Settings below)

### DeckBuilderView Banner

- [ ] When the current deck has 1 or more violations, a dismissible banner appears at the top of `DeckBuilderView`'s card list:
  - Red background, `exclamationmark.triangle.fill` icon
  - Text: `"N card(s) not legal in Standard — tap to review"`
  - Tapping presents `DeckLegalitySheet`
- [ ] Banner re-evaluates whenever the deck changes (on appear + `onChange(of:)` the deck cards)
- [ ] If the deck is fully legal, no banner is shown

### DeckLegalitySheet

- [ ] New file `JustTCG/Features/Decks/DeckLegalitySheet.swift`
- [ ] Header: format name + overall legal/illegal status icon
- [ ] `Picker` at the top to toggle between Standard and Expanded (segmented style)
- [ ] If no violations: `ContentUnavailableView("Deck is legal", systemImage: "checkmark.seal.fill")` in green tint
- [ ] Violations list section **"Issues Found"**:
  - One row per `LegalityViolation`
  - Card name + set code
  - Right tag: `"Banned"` (red) or `"Rotated"` (orange)
  - Tapping a row pushes `CardDetailView` for that card

### Deck Detail View Header

- [ ] In `DeckBuilderView`'s navigation bar, add a legality indicator icon button:
  - `checkmark.seal.fill` (green) if legal
  - `exclamationmark.triangle.fill` (red) if illegal
- [ ] Tapping it presents `DeckLegalitySheet`

### Settings

- [ ] A new **"Default Format"** row in `SettingsView` under a "Tournament" section:
  - `Picker("Default format", …)` — Standard / Expanded
  - Stored in `@AppStorage("defaultFormat")` as a `String` (`"standard"` default)
- [ ] The legality badge in `DeckRow` and the banner in `DeckBuilderView` both respect this setting

### Colour Tokens

- [ ] Legal → `.green`
- [ ] Rotated violation → `.orange`
- [ ] Banned violation → `.red`
- [ ] Use `.foregroundStyle` + small capsule background for badges (consistent with win-rate badge style)

## Technical Notes

**Files to create:**
- `JustTCG/Features/Decks/DeckLegalitySheet.swift`

**Files to change:**
- `JustTCG/Features/Decks/DecksView.swift` (or `DeckRow`) — add legality badge
- `JustTCG/Features/Decks/DeckBuilderView.swift` — add violation banner + navbar icon
- `JustTCG/Features/Settings/SettingsView.swift` — add Tournament section

**Card lookup in the sheet:**
The sheet receives `[DeckCard]`; resolve to `[CachedCard]` by fetching from the `ModelContext` by `cardID`. Cards that no longer exist in the local cache are excluded from legality checking silently (they will appear as missing in the import flow instead).

**Banner dismissal:**
Dismissal is per-session only (not persisted) — the banner re-appears next time the deck is opened if violations still exist.
