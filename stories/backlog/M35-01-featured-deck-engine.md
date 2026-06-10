# M35-01 — Featured Deck of the Day Engine

**Status:** done  
**Milestone:** M35 — Featured Deck of the Day  
**Dependencies:** M1-02 (CachedCard), M5-01 (LimitlessTournament), M22-01 (ArchetypePrimaryCardResolver)

## User Story

As a developer, I need a pure engine that selects a stable daily "featured deck" from recent top-8 tournament placements so that the Home screen widget can display a new deck every day without network thrash on every render.

## Acceptance Criteria

### FeaturedDeckCandidate

- [ ] New value type `FeaturedDeckCandidate` at `JustTCG/Features/Home/FeaturedDeckEngine.swift`:
  ```swift
  struct FeaturedDeckCandidate {
      let tournament: LimitlessTournament
      let placement: LimitlessPlacement
  }
  ```

### FeaturedDeckSnapshot

- [ ] New `Codable` value type `FeaturedDeckSnapshot` in the same file:
  ```swift
  struct FeaturedDeckSnapshot: Codable {
      let fetchedAt: Date
      let playerName: String
      let tournamentName: String
      let tournamentDate: Date
      let placing: Int            // 1–8
      let archetype: String
      let deckListId: String?
      let primaryCardNames: [String]  // up to 3, parsed from archetype
  }
  ```
- [ ] `isStale(now:)` computed property returns `true` when `fetchedAt` is **not** the same calendar day as `now` (use `Calendar.current.isDate(fetchedAt, inSameDayAs: now)`)

### FeaturedDeckEngine

- [ ] New `struct FeaturedDeckEngine` in the same file with a single static method:
  ```swift
  static func pick(from candidates: [FeaturedDeckCandidate], date: Date = .now) -> FeaturedDeckSnapshot?
  ```
- [ ] Filtering: only candidates with `placement.rank <= 8` are eligible
- [ ] If the filtered pool is empty, return `nil`
- [ ] Date-seeded selection: derive a stable daily index using `Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0` modulo `pool.count` — this produces the same index for any `Date` within the same calendar day and rotates at midnight
- [ ] Primary card names: split `placement.archetype` on `" / "` and take up to 3 non-empty segments, trimming whitespace from each — no network call required
- [ ] Return a `FeaturedDeckSnapshot` with all fields populated from the chosen candidate

### Primary Card Resolver Extension

- [ ] New static method on `ArchetypePrimaryCardResolver`:
  ```swift
  static func resolveAll(names: [String], from cards: [CachedCard]) -> [CachedCard]
  ```
  Calls `resolve(archetype:from:)` on each name and compacts the results, preserving order, deduplicating by card `id`

### Unit Tests

- [ ] `FeaturedDeckEngineTests.swift` covers:
  - Pool with all ranks > 8 → returns `nil`
  - Same date always produces the same pick from a fixed pool
  - Different calendar days produce a different index (verify index rotates)
  - Archetype `"Dragapult ex / Pidgeot ex / Duskull"` → `primaryCardNames` is `["Dragapult ex", "Pidgeot ex", "Duskull"]`
  - Archetype with more than 3 segments → only first 3 are kept
  - Single-name archetype → `primaryCardNames` has exactly one entry

## Technical Notes

**New file:** `JustTCG/Features/Home/FeaturedDeckEngine.swift`  
**Modified file:** `JustTCG/Domain/Entities/ArchetypePrimaryCardResolver.swift` (add `resolveAll`)

- The engine performs no I/O, no SwiftData imports, and no SwiftUI imports — pure Swift only
- `fetchedAt` is set to the `date` argument passed to `pick(from:date:)`, not `Date.now` inside the engine, so tests can control it
- The modulo-based index is intentionally simple and produces mild collisions across years (same ordinal day in different years may pick the same deck) — this is acceptable for a home screen widget
