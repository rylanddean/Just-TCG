# M8-01 — Card Sort State & Repository Integration

**Status:** done  
**Milestone:** M8 — Card Sorting  
**Dependencies:** M1-03, M1-05

## User Story

As a user, I want the card browser to sort cards by expansion (newest first by default), name, HP, attack damage, set name, or regulation mark so that I can find cards in a logical order for my use case.

## Acceptance Criteria

- [x] `CardSortOrder` enum is defined with five cases:
  - `.expansion` — sort by `setReleaseDate` descending, then by `numberSortKey` ascending; **this is the default**
  - `.name` — sort by `name` ascending (case-insensitive)
  - `.hp` — sort by `hp` descending (highest HP first), then `name` ascending; Trainer/Energy cards (nil HP) appear last
  - `.attackDamage` — sort by `maxDamage` descending, then `name` ascending; cards with nil `maxDamage` appear last
  - `.regulationMark` — sort by `regulationMark` descending (Z→A, so latest mark is first), then `numberSortKey` ascending; nil-mark cards appear last
- [x] `CachedCard` gains a new stored property: `setReleaseDate: Date?`
  - Populated from the bundled JSON's per-set `releaseDate` string (`"yyyy/MM/dd"` format)
- [x] `CachedCard` gains `numberSortKey: String` — zero-padded numeric prefix so DB sort is lexicographically correct
- [x] `BundledCardSeeder` resolves `setReleaseDate` from the `set` metadata block per JSON file; computes `numberSortKey` per card
- [x] `seededKey` bumped to `"bundled_cards_seeded_v5"`
- [x] `CardSortOrder` exposes `var sortDescriptors: [SortDescriptor<CachedCard>]` used by the repository
- [x] `CardRepository.fetch(matching:filterState:sortOrder:)` accepts a `CardSortOrder` parameter (default `.expansion`) and passes the appropriate `sortDescriptors` to `FetchDescriptor`
- [x] `CardRepository.fetchDistinctSets()` returns sets ordered by `setReleaseDate` descending (newest first)

## Technical Notes

- `numberSortKey` formula: `String(format: "%03d", numericPrefix) + number` — handles `"7"`, `"124"`, `"TG01"` correctly
- `setReleaseDate` source: the bundled JSON `set` object already has `releaseDate` — the seeder builds a per-file date and stamps every card in that file
- `CardSortOrder` is `Equatable`, `Hashable`, `CaseIterable`, `Identifiable` (raw value = `String`)
