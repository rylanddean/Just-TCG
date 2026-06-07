# M1-02 — CachedCard SwiftData Model

**Status:** todo  
**Milestone:** M1 — Card Browser  
**Dependencies:** M0

## User Story
As a developer, I need a `CachedCard` SwiftData model that locally mirrors the Limitless card database so that card browsing and deck building work fully offline after the first sync.

## Acceptance Criteria

- [ ] `CachedCard` `@Model` class lives in `Data/Models/CachedCard.swift`
- [ ] Fields: `id: String`, `name: String`, `setCode: String`, `setName: String`, `number: String`, `types: [String]`, `subtypes: [String]`, `hp: Int?`, `isStandardLegal: Bool`, `imageURL: String`, `cachedAt: Date`
- [ ] `id` is marked `@Attribute(.unique)` to allow safe upserts
- [ ] `CachedCard` is registered in the app's `ModelContainer`
- [ ] A `CardRepository` class in `Data/Repositories/` exposes:
  - `func upsert(_ cards: [LimitlessCard])` — maps `LimitlessCard` → `CachedCard` and saves
  - `func fetchAll(standardOnly: Bool) -> [CachedCard]`
  - `func fetch(matching query: String, types: [String], sets: [String]) -> [CachedCard]`
- [ ] `CardRepository` is excluded from iCloud sync (`CachedCard` should not be in the CloudKit schema)

## Technical Notes

- Upsert pattern: fetch by `id`, update if found, insert if not
- `CardRepository` takes a `ModelContext` in its initialiser — do not use `@Environment(\.modelContext)` inside the repository
- To exclude from CloudKit: use a separate `ModelConfiguration(isStoredInMemoryOnly: false, cloudKitDatabase: .none)` for `CachedCard` vs the user-data models
