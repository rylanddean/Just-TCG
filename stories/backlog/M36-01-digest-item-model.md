# M36-01 — DigestItem Model & Read Queue

**Status:** todo  
**Milestone:** M36 — Digest & Reading Queue  
**Dependencies:** M5-01 (LimitlessTournament/LimitlessPlacement), M35-01 (FeaturedDeckSnapshot), M30-01 (ArchetypeShare), M22-01 (ArchetypePrimaryCardResolver), M1-02 (CachedCard)

## User Story

As a developer, I need a shared `DigestItem` value type and a persistent `ReadQueueItem` SwiftData model so that the digest feed and the reading queue can speak the same language — regardless of whether the content came from a tournament result, today's featured deck, or a meta trend snapshot.

## Background

The current app has multiple surfaces that surface "readable" content (featured deck widget, tournament list, meta trend chart) but each navigates to its own detail screen. There is no shared abstraction for "a piece of content the user might want to read or save for later." This story defines that abstraction and its persistence layer so the digest feed view (M36-02) can be built on top of it.

## Acceptance Criteria

### DigestItem

- [ ] New file `JustTCG/Domain/Entities/DigestItem.swift`
- [ ] `enum DigestItem: Identifiable` with three cases:

```swift
enum DigestItem: Identifiable {
    case tournamentDeck(
        id: UUID,
        tournament: LimitlessTournament,
        placement: LimitlessPlacement,
        primaryCards: [CachedCard]
    )
    case featuredDeck(
        id: UUID,
        snapshot: FeaturedDeckSnapshot,
        primaryCards: [CachedCard]
    )
    case metaTrend(
        id: UUID,
        archetype: String,
        sharePercent: Double,
        weekDelta: Double,     // positive = trending up, negative = trending down
        primaryCard: CachedCard?
    )
}
```

- [ ] `var id: UUID` computed property returns the associated `id` for all cases
- [ ] `var title: String` computed property:
  - `.tournamentDeck`: player name from `placement.player`
  - `.featuredDeck`: `snapshot.playerName`
  - `.metaTrend`: archetype name
- [ ] `var subtitle: String` computed property:
  - `.tournamentDeck`: `"\(ordinalString(placement.rank)) Place · \(tournament.name)"`
  - `.featuredDeck`: `"\(ordinalString(snapshot.placing)) Place · \(snapshot.tournamentName)"`
  - `.metaTrend`: `"\(String(format: "%.1f", sharePercent))% meta share"` plus `" · ↑\(delta)%"` or `" · ↓\(abs(delta))%"` when `|weekDelta| >= 1.0`, omitted otherwise
- [ ] `var deckListId: String?` computed property — non-nil only for `.tournamentDeck` (`placement.deckListId`) and `.featuredDeck` (`snapshot.deckListId`)
- [ ] `var contentTypeLabel: String` computed property — `"Top Placement"`, `"Featured Deck"`, or `"Meta Trend"` — used as the type badge in the feed row
- [ ] Private `ordinalString(_ n: Int) -> String` function in the same file — shared with `FeaturedDeckWidget`'s existing private helper; do not duplicate across files (one canonical location here, the widget calls it via a module-internal helper or refactor both to a shared location)
- [ ] No SwiftData, SwiftUI, or network imports — pure Swift only

### ReadQueueItem

- [ ] New `@Model final class ReadQueueItem` in `JustTCG/Domain/Entities/ReadQueueItem.swift`
- [ ] Properties:
  ```swift
  @Attribute(.unique) var id: UUID
  var addedAt: Date
  var isRead: Bool
  var contentType: String      // "tournamentDeck" | "featuredDeck" | "metaTrend"
  var title: String
  var subtitle: String
  var deckListId: String?
  var archetypeName: String?   // non-nil for metaTrend items; used to look up fresh data
  ```
- [ ] `init` with all fields; `isRead` defaults to `false`
- [ ] Convenience `static func from(_ item: DigestItem) -> ReadQueueItem` factory that maps each `DigestItem` case to the appropriate fields

### ReadQueueItem SwiftData container registration

- [ ] `ReadQueueItem` is added to the `ModelContainer` schema in the app's entry point alongside existing models
- [ ] No migration needed — new model; existing container definition just gains an additional type

## Technical Notes

**Why an enum, not a protocol:** `DigestItem` is always produced by the app's own feed engine and never persisted. An enum makes exhaustive pattern-matching in the view layer straightforward and avoids the overhead of existentials or protocol witnesses.

**Why `ReadQueueItem` doesn't store the full `DigestItem`:** `DigestItem` contains non-Codable SwiftData objects (`CachedCard`, `LimitlessPlacement`). The queue only needs the minimal fields required to reconstruct a meaningful row in the queue UI and deep-link back to the detail view. Fresh card images and tournament data are resolved at display time.

**`deckListId` nullable for `.metaTrend`:** meta trend items don't have a specific deck list — they represent an archetype's aggregate performance. The queue row for a meta trend item will link to the archetype detail view rather than `DeckListViewer`.

**Files to create:**
- `JustTCG/Domain/Entities/DigestItem.swift`
- `JustTCG/Domain/Entities/ReadQueueItem.swift`

**Files to modify:**
- App entry point — add `ReadQueueItem` to the `ModelContainer` schema
