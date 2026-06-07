# M8-01 — Card Sort State & Repository Integration

**Status:** todo  
**Milestone:** M8 — Card Sorting  
**Dependencies:** M1-03, M1-05

## User Story

As a user, I want the card browser to sort cards by expansion (newest first by default), name, HP, attack damage, set name, or regulation mark so that I can find cards in a logical order for my use case.

## Acceptance Criteria

- [ ] `CardSortOrder` enum is defined with five cases:
  - `.expansion` — sort by `setReleaseDate` descending, then by `number` ascending (card number within the set); **this is the default**
  - `.name` — sort by `name` ascending (case-insensitive)
  - `.hp` — sort by `hp` descending (highest HP first), then `name` ascending; Trainer/Energy cards (nil HP) appear last
  - `.attackDamage` — sort by `maxDamage` descending, then `name` ascending; cards with nil `maxDamage` appear last
  - `.regulationMark` — sort by `regulationMark` descending (Z→A, so latest mark is first), then `number` ascending; nil-mark cards appear last
- [ ] `CachedCard` gains a new stored property: `setReleaseDate: Date?`
  - Populated from the bundled JSON's per-set `releaseDate` string (`"yyyy/MM/dd"` format)
  - Same value for every card in the same set
- [ ] `CardSeedEntry` gains a decodable `setReleaseDate: Date?` field; the JSON scraper emits `releaseDate` on each card entry (copied from the set-level field at scrape time) — OR `BundledCardSeeder` resolves it from a `setReleaseDate` lookup keyed by `setCode` that it builds from the set metadata block in each JSON file
- [ ] `seededKey` is bumped one version beyond the current highest version to force a re-seed (coordinate with M7-01/M7-02 if those are landed first)
- [ ] `CardSortOrder` exposes `var sortDescriptors: [SortDescriptor<CachedCard>]` used by the repository
- [ ] `CardRepository.fetchFromDB(query:sets:sortOrder:)` accepts a `CardSortOrder` parameter (default `.expansion`) and passes the appropriate `sortDescriptors` to `FetchDescriptor`
- [ ] `CardRepository.fetch(matching:types:subtypes:sets:sortOrder:)` threads the parameter through to `fetchFromDB`
- [ ] `CardRepository.fetchDistinctSets()` returns sets ordered by `setReleaseDate` descending (newest first) — used to populate the set filter list so the most recent sets appear at the top

## Technical Notes

- **Number sort**: `number` is stored as a `String` (e.g. `"7"`, `"124"`, `"TG01"`). SwiftData `SortDescriptor(\.number)` will sort lexicographically (`"7"` > `"124"`). Pad the numeric prefix to 3 digits at seed time with a stored `numberSortKey: String` (e.g. `"007"`, `"124"`, `"TG01"`) and sort on that instead, OR accept lexicographic order as close enough within a set. Recommended: store `numberSortKey` as a derived String during seeding — `String(format: "%03d", Int(number.prefix(while: \.isNumber)) ?? 0) + number` — so the sort is DB-native
- **HP / maxDamage nil ordering**: SwiftData `SortDescriptor` puts `nil` last by default for optional numeric types — this is the desired behaviour; no special handling needed
- **`regulationMark` nil ordering**: same — `nil` naturally sorts last when descending
- **`setReleaseDate` source**: the bundled JSON already contains the `releaseDate` field at the top-level `set` object. The seeder can build a `[String: Date]` dictionary (setCode → Date) once per JSON file and stamp every card in that file — no per-card JSON changes needed
- `CardSortOrder` should be `Equatable`, `Hashable`, `CaseIterable`, and `Identifiable` (raw value = `String`) so the UI can iterate and compare it without extra conformances
