# M13-01 — Meta Deck Picker in Log Match Sheet

**Status:** done  
**Milestone:** M13 — Match Log UX  
**Dependencies:** M3-03

## User Story

As a player logging a match, I want to pick my opponent's deck from a dropdown of current meta archetypes, so that I can log quickly without typing and keep archetype names consistent across my match history.

## Acceptance Criteria

- [x] The "Opponent Archetype" section in `LogMatchSheet` gains a `Picker` (`.menu` style) labelled **"Quick Pick"** that lists the current meta decks in prevalence order, with a **"Custom"** entry as the first/default option
- [x] Selecting any non-Custom option from the picker pre-fills `archetypeQuery` with that archetype name and suppresses the type-ahead suggestions (same behaviour as tapping an existing suggestion row)
- [x] After a Quick Pick selection the picker resets its own displayed value back to "Custom" — the chosen name lives in the text field, not the picker selection
- [x] The `TextField` remains visible at all times; it is the fallback for any deck not in the list
- [x] If the user types in the `TextField` after making a Quick Pick selection, the type-ahead suggestions resume as normal (existing `suppressSuggestions` logic is unchanged)
- [x] The meta deck list is loaded from a bundled `metaDecks.json` file; if the file is missing or malformed the picker is hidden and the section falls back to text-only entry
- [x] `metaDecks.json` ships with the current Standard meta at time of implementation — at minimum the top 10 archetypes by tournament share

## Technical Notes

**New file — `JustTCG/metaDecks.json`**

A flat JSON array of archetype name strings in prevalence order.

**New file — `JustTCG/Domain/Entities/MetaDeckRepository.swift`**

Loads and decodes the bundled JSON. Returns empty array on failure so the picker hides gracefully.

**`LogMatchViewModel` changes**

- Added `var metaDecks: [String] { MetaDeckRepository.shared.all }`
- Added `var quickPickSelection: String = "Custom"` — the picker binding
- In `selectArchetype(_:)`, resets `quickPickSelection = "Custom"` so the picker label clears after selection

**`LogMatchSheet.archetypeSection` changes**

- Picker guarded on `!vm.metaDecks.isEmpty`
- `.onChange` calls `vm.selectArchetype` when value is not `"Custom"` (which resets picker via `quickPickSelection = "Custom"`)
