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
- [x] The meta deck list is sourced from the bundled `archetypes.json` file (the single archetype source of truth); if the file is missing or malformed the picker is hidden and the section falls back to text-only entry
- [x] `archetypes.json` ships with the current Standard meta at time of implementation, ordered by tournament share — at minimum the top 10 archetypes by prevalence

## Technical Notes

> **Revised design (post-implementation):** the originally-planned standalone `metaDecks.json` + `MetaDeckRepository` were scrapped to avoid a second, duplicate archetype source. The Quick Pick picker now reads from the existing `archetypes.json` via `ArchetypeRepository`, which is the single source of truth shared with the type-ahead suggestions.

**`archetypes.json` (existing file, rewritten)**

A flat JSON array of `{ id, name, primaryType }` objects, ordered by current meta prevalence (most popular first). Sourced from `limitlesstcg.com/decks?format=TEF-POR`. The file order *is* the prevalence order.

**`ArchetypeRepository` changes**

- `all: [Archetype]` — sorted alphabetically, used for type-ahead search (unchanged behaviour)
- `metaOrdered: [Archetype]` — preserves the JSON file order (prevalence order), used by the Quick Pick picker
- Returns empty arrays on decode failure so the picker hides gracefully

**`LogMatchViewModel` changes**

- Added `var metaDecks: [String] { ArchetypeRepository.shared.metaOrdered.map(\.name) }`
- Added `var quickPickSelection: String = "Custom"` — the picker binding
- In `selectArchetype(_:)`, resets `quickPickSelection = "Custom"` so the picker label clears after selection

**`LogMatchSheet.archetypeSection` changes**

- Picker guarded on `!vm.metaDecks.isEmpty`
- `.onChange` calls `vm.selectArchetype` when value is not `"Custom"` (which resets picker via `quickPickSelection = "Custom"`)
- `TextField` placeholder updated to a current-meta example (`"e.g. Dragapult ex"`)
