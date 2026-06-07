# M10-01 — Deck List Parser

**Status:** done  
**Milestone:** M10 — Deck Import  
**Dependencies:** none

## Acceptance Criteria

- [x] `DeckImportEntry` struct with `quantity`, `name`, `setCode`, `number`
- [x] `DeckListParser` enum (no cases) with `static func parse(_ text: String) -> [DeckImportEntry]`
- [x] Section headers (`Pokémon: N`, `Trainer: N`, `Energy: N`) skipped
- [x] `Total Cards: N` footer skipped
- [x] Empty lines and malformed lines silently skipped
- [x] Card line: first token → quantity, last → number, second-to-last → setCode, middle → name
- [x] Special characters preserved verbatim (`{D}`, `é`, `'`, `-`)
- [x] Lines with fewer than 4 tokens silently skipped
- [x] Unit tests: full deck list, multi-word name, `{D}` energy, section headers, `Total Cards:`, empty input

## Technical Notes

- `JustTCG/Data/Import/DeckListParser.swift` — no SwiftData, no SwiftUI
