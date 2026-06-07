# M12-01 — FavouritePlayer SwiftData Model

**Status:** todo  
**Milestone:** M12 — Player Profiles  
**Dependencies:** none

## User Story

As a user, I want the app to persist which players I've starred as favourites so that my list survives app restarts.

## Acceptance Criteria

- [ ] A `FavouritePlayer` SwiftData model is added with the following properties:
  - `id: String` — Limitless player ID (e.g. `"6821"`)
  - `name: String` — display name (e.g. `"Cerys Jones"`)
  - `country: String` — as returned by the API
  - `addedAt: Date` — timestamp when starred; defaults to `Date.now`
- [ ] `FavouritePlayer` is included in the app's `ModelContainer` schema alongside existing models
- [ ] A `FavouritePlayerRepository` (`@Observable` class) exposes:
  - `func isFavourite(id: String) -> Bool`
  - `func add(_ player: FavouritePlayer)`
  - `func remove(id: String)`
  - `var all: [FavouritePlayer]` — sorted by `addedAt` descending
- [ ] `add` is a no-op if a record with that `id` already exists — no duplicates
- [ ] Adding and removing a favourite persists correctly across cold launches

## Technical Notes

- `FavouritePlayer.swift` lives at `JustTCG/Features/Players/Models/FavouritePlayer.swift`
- `FavouritePlayerRepository.swift` lives at `JustTCG/Features/Players/FavouritePlayerRepository.swift`
- Inject via `.environment` so both the standings and player detail view share the same instance
- Do not store career stats or archetype history in SwiftData — that data is always fetched live and never persisted
