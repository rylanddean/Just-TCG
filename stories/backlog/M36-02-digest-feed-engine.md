# M36-02 — Digest Feed Engine

**Status:** todo  
**Milestone:** M36 — Digest & Reading Queue  
**Dependencies:** M36-01 (DigestItem), M35-01 (FeaturedDeckEngine/FeaturedDeckSnapshot), M30-01 (MetaTrendEngine/ArchetypeShare), M5-01 (LimitlessTournament/LimitlessPlacement), M22-01 (ArchetypePrimaryCardResolver), M1-02 (CachedCard)

## User Story

As a developer, I need a pure engine that assembles a ranked, de-duplicated list of `DigestItem`s from the app's existing data sources so that the Digest Feed View always has fresh, relevant content without re-implementing any data-fetching logic.

## Acceptance Criteria

### DigestFeedEngine

- [ ] New file `JustTCG/Domain/Entities/DigestFeedEngine.swift`
- [ ] Pure struct, no SwiftData or SwiftUI imports
- [ ] Single static method:
  ```swift
  static func feed(
      featured: FeaturedDeckSnapshot?,
      recentPlacements: [(tournament: LimitlessTournament, placement: LimitlessPlacement)],
      metaShares: [ArchetypeShare],
      cards: [CachedCard],
      queuedIds: Set<UUID>
  ) -> [DigestItem]
  ```

**Assembly rules (applied in order):**

1. **Featured deck** — if `featured != nil`, add a `.featuredDeck` item first (position 0), resolving `primaryCards` via `ArchetypePrimaryCardResolver.resolveAll(names: featured.primaryCardNames, from: cards)`

2. **Top tournament placements** — from `recentPlacements`, keep only entries where `placement.rank <= 4`; sort by `tournament.date` descending; take up to 5; map each to a `.tournamentDeck` item, resolving `primaryCards` from the archetype name via `ArchetypePrimaryCardResolver`

3. **Meta trends** — from `metaShares`, keep only entries where `|weekDelta| >= 2.0` (meaningful movement); sort by `|weekDelta|` descending; take up to 3; map each to a `.metaTrend` item, resolving `primaryCard` (single card) via `ArchetypePrimaryCardResolver.resolve(archetype:from:cards:)`

4. **De-duplication** — if the `.featuredDeck` snapshot's `deckListId` matches any `.tournamentDeck` item's `placement.deckListId`, remove the duplicate tournament deck entry (the featured deck already covers it)

5. **Queue pinning** — items whose `id` appears in `queuedIds` are sorted to the **end** of the feed (the user has already seen them; fresh content leads); within queued items, preserve the order from steps 1–4

- [ ] If all inputs are empty/nil, returns an empty array (never returns placeholder items — the view handles empty state)
- [ ] Each item is assigned a stable `UUID` derived deterministically from its content (use `UUID(uuidString:)` hashed from the item's unique string key — see technical notes) so that queue membership checks remain valid across re-fetches without requiring SwiftData IDs

### Stable UUID derivation

- [ ] Private helper `func stableId(for key: String) -> UUID` in the same file:
  - Computes `SHA256(key.utf8Data)` and takes the first 16 bytes
  - Sets bits 12–15 of byte 6 to `0100` (version 4 marker) and bits 6–7 of byte 8 to `10` (variant marker) to produce a valid UUID v4-compatible value
  - Returns `UUID(uuid: ...)` from the 16-byte tuple
- [ ] Key strings per item type:
  - `.featuredDeck`: `"featured:\(snapshot.tournamentName):\(snapshot.playerName):\(snapshot.tournamentDate)"`
  - `.tournamentDeck`: `"tournament:\(tournament.id):\(placement.player):\(placement.rank)"`
  - `.metaTrend`: `"meta:\(archetype):\(sharePercent)"`

## Technical Notes

**Why stable UUIDs matter:** The queue stores `DigestItem.id` values. If UUIDs were random on each feed rebuild, every app launch would produce new IDs and the queue would never match any feed item. Deterministic IDs mean an item queued this morning is still recognised as queued when the feed refreshes this afternoon.

**`weekDelta` source:** `ArchetypeShare` from `MetaTrendEngine` already exposes share percentages across snapshots. The caller (the ViewModel in M36-03) is responsible for computing `weekDelta = currentShare - previousWeekShare` and passing it in — the engine does not reach back into the trend model directly.

**Why the engine doesn't fetch data:** All inputs are already loaded by existing ViewModels (FeaturedDeckWidgetViewModel, tournament detail fetchers). The engine's job is assembly and ranking, not I/O. This keeps it unit-testable without networking.

**Files to create:**
- `JustTCG/Domain/Entities/DigestFeedEngine.swift`
