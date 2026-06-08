# M27-01 — Backup Serializer

**Status:** done  
**Milestone:** M27 — Backlog Export & Import  
**Dependencies:** M2-01, M3-01, M16-01

## User Story

As a developer, I need a pure, testable serializer that encodes all user data (decks, matches, edits, and streak settings) into a portable JSON backup and decodes it back into SwiftData objects, so that the export and import UI can delegate all data logic to a single place.

## Acceptance Criteria

### Backup Format

- [ ] A new `BackupPayload` struct at `JustTCG/Data/Backup/BackupPayload.swift` that is fully `Codable`:
  ```swift
  struct BackupPayload: Codable {
      let version: Int                 // current: 1
      let exportedAt: Date
      let streakDailyGoal: Int
      let decks: [DeckBackup]
  }
  ```
- [ ] `DeckBackup` encodes a complete snapshot of a `Deck` and its cascaded relationships:
  ```swift
  struct DeckBackup: Codable {
      let id: UUID
      let name: String
      let format: String
      let status: String               // raw value of DeckStatus
      let createdAt: Date
      let updatedAt: Date
      let coverCardIds: [String]
      let cards: [DeckCardBackup]
      let edits: [DeckEditBackup]
      let matches: [MatchBackup]
  }
  ```
- [ ] `DeckCardBackup`, `DeckEditBackup`, and `MatchBackup` map 1-to-1 to `DeckCard`, `DeckEdit`, and `Match` fields respectively — all primitive types only (no SwiftData object references)
- [ ] All `Date` values encode/decode as ISO 8601 using `JSONEncoder.DateEncodingStrategy.iso8601`
- [ ] Matches are nested under their deck — orphaned matches (no deck) are excluded from the backup

### `BackupSerializer`

- [ ] New struct `BackupSerializer` at `JustTCG/Data/Backup/BackupSerializer.swift`
- [ ] `static func encode(decks: [Deck], streakDailyGoal: Int) throws -> Data` builds a `BackupPayload` from the given decks and serialises to JSON
- [ ] `static func decode(from data: Data) throws -> BackupPayload` deserialises JSON back to `BackupPayload`
- [ ] `static func fileName() -> String` returns `"JustTCG-Backup-\(formattedDate).json"` using `yyyy-MM-dd` formatting

### `BackupImporter`

- [ ] New struct `BackupImporter` at `JustTCG/Data/Backup/BackupImporter.swift`
- [ ] `func importPayload(_ payload: BackupPayload, into context: ModelContext) -> BackupImportResult` writes the backup into SwiftData
- [ ] `BackupImportResult`:
  ```swift
  struct BackupImportResult {
      let decksImported: Int
      let decksSkipped: Int          // UUIDs already present in the store
      let matchesImported: Int
  }
  ```
- [ ] Import strategy for decks: if a `Deck` with the same `id` already exists in the store, **skip** it (do not overwrite) and increment `decksSkipped`
- [ ] New `Deck` and all its cascaded `DeckCard`, `DeckEdit`, and `Match` children are inserted in a single pass
- [ ] `streakDailyGoal` from the payload is written to `UserDefaults` key `"streak_daily_goal"` only if the current stored value is the default (1), preventing an import from silently overwriting a user's customised setting — if the stored value differs from the default, the importer leaves it unchanged
- [ ] The importer calls `context.save()` once after all inserts

### Tests

- [ ] `JustTCGTests/BackupSerializerTests.swift` covers: round-trip encode → decode produces identical data, empty deck list, deck with matches and edits, `fileName()` format
- [ ] `JustTCGTests/BackupImporterTests.swift` covers: fresh import creates all records, duplicate deck ID is skipped, `matchesImported` count is accurate

## Technical Notes

**New files:**
- `JustTCG/Data/Backup/BackupPayload.swift`
- `JustTCG/Data/Backup/BackupSerializer.swift`
- `JustTCG/Data/Backup/BackupImporter.swift`
- `JustTCGTests/BackupSerializerTests.swift`
- `JustTCGTests/BackupImporterTests.swift`

**`BackupImporter` insert pattern:**
```swift
func importPayload(_ payload: BackupPayload, into context: ModelContext) -> BackupImportResult {
    let existingIds = (try? context.fetch(FetchDescriptor<Deck>()))?.map(\.id) ?? []
    let existingSet = Set(existingIds)

    var decksImported = 0
    var decksSkipped = 0
    var matchesImported = 0

    for deckBackup in payload.decks {
        guard !existingSet.contains(deckBackup.id) else {
            decksSkipped += 1
            continue
        }
        let deck = Deck(name: deckBackup.name, format: deckBackup.format)
        deck.id = deckBackup.id
        deck.status = DeckStatus(rawValue: deckBackup.status) ?? .playing
        deck.createdAt = deckBackup.createdAt
        deck.updatedAt = deckBackup.updatedAt
        deck.coverCardIds = deckBackup.coverCardIds

        deck.cards = deckBackup.cards.map { DeckCard(cardId: $0.cardId, quantity: $0.quantity) }
        deck.edits = deckBackup.edits.map { /* reconstruct DeckEdit */ }
        deck.matches = deckBackup.matches.map { /* reconstruct Match */ }

        context.insert(deck)
        decksImported += 1
        matchesImported += deckBackup.matches.count
    }

    try? context.save()
    return BackupImportResult(decksImported: decksImported, decksSkipped: decksSkipped, matchesImported: matchesImported)
}
```

> **Note on card IDs:** `DeckCard.cardId` references the Pokémon TCG API card ID (e.g. `"sv3-125"`). These are not embedded in the backup file — they're identifiers that resolve against the separately-synced card cache. Imported decks with card IDs not currently in the cache will still be imported correctly; the deck builder will show unknown cards as unresolved until the cache syncs.
