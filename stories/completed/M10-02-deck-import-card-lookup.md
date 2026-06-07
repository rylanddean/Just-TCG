# M10-02 — Deck Import Card Lookup

**Status:** done  
**Milestone:** M10 — Deck Import  
**Dependencies:** M10-01

## Acceptance Criteria

- [x] `DeckImportMatch` struct with `entry: DeckImportEntry`, `cardId: String?`, `var isMatched: Bool`
- [x] `DeckImportLookup` struct with `func resolve(_ entries: [DeckImportEntry], in context: ModelContext) -> [DeckImportMatch]`
- [x] Lookup queries `CachedCard` where `setCode == entry.setCode && number == entry.number`
- [x] Exactly one match → `cardId` set; zero or multiple → `cardId` nil
- [x] Returned array preserves input order
- [x] Unit tests (in-memory `ModelContext`): matched entry, unknown setCode, known setCode wrong number

## Technical Notes

- `JustTCG/Data/Import/DeckImportLookup.swift`
- Uses `FetchDescriptor<CachedCard>` with `#Predicate` — does not load all cards into memory
