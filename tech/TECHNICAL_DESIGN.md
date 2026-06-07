# Just TCG — Technical Design Document

## Stack

| Layer | Choice | Rationale |
|---|---|---|
| Platform | iOS 17+ (SwiftUI) | Native performance; SwiftUI data flow aligns well with reactive card/deck state |
| Local persistence | SwiftData | First-class SwiftUI integration; replaces CoreData for new projects on iOS 17+ |
| Remote sync | CloudKit (NSPersistentCloudKitContainer) | Free iCloud sync; no backend to operate |
| Networking | URLSession + async/await | No third-party HTTP lib needed |
| Card data cache | SQLite via SwiftData | Local mirror of Limitless card data; refreshed periodically |
| Image cache | URLCache + disk cache | Cards are fetched once, stored locally |
| Minimum deployment | iOS 17.0 | SwiftData requires 17+ |

---

## Architecture

```
Just TCG
├── App
│   └── JustTCGApp.swift
├── Features
│   ├── DeckBuilder/
│   │   ├── DeckBuilderView
│   │   ├── CardSearchView
│   │   ├── CardDetailView
│   │   └── DeckBuilderViewModel
│   ├── Decks/
│   │   ├── DeckListView
│   │   ├── DeckDetailView
│   │   └── DeckViewModel
│   ├── MatchTracker/
│   │   ├── LogMatchView
│   │   ├── MatchHistoryView
│   │   └── MatchViewModel
│   ├── Analytics/
│   │   ├── MatchupRadarView
│   │   ├── WinRateChartView
│   │   └── AnalyticsViewModel
│   └── TournamentFeed/
│       ├── TournamentListView
│       ├── TournamentDetailView
│       ├── DeckListDetailView
│       └── TournamentViewModel
├── Data
│   ├── Models/           -- SwiftData @Model classes
│   ├── Repositories/     -- Abstracts SwiftData queries
│   └── LimitlessTCGClient/  -- All Limitless integration lives here
├── Domain
│   └── Entities/         -- Pure Swift value types (DeckArchetype, CardLegality, etc.)
└── Shared
    ├── Components/       -- Reusable SwiftUI views (CardThumbnail, WinRateBadge, etc.)
    └── Extensions/
```

Pattern: MVVM with repositories. Views own ViewModels (`@StateObject`). ViewModels call repositories. Repositories own SwiftData context and the Limitless client. No business logic in views.

---

## Data Models (SwiftData)

```swift
@Model
class Deck {
    var id: UUID
    var name: String
    var format: String          // "Standard"
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var cards: [DeckCard]
    @Relationship(deleteRule: .cascade) var matches: [Match]
}

@Model
class DeckCard {
    var cardId: String          // Limitless card ID
    var quantity: Int           // 1–4 (basic energy: up to 60)
    var deck: Deck?
}

@Model
class Match {
    var id: UUID
    var date: Date
    var opponentArchetype: String   // e.g. "Charizard ex / Pidgeot ex"
    var result: MatchResult         // .win / .loss / .tie
    var format: MatchFormat         // .bo1 / .bo3
    var eventType: EventType        // .casual / .leagueChallenge / .regional / .ic / .worlds
    var notes: String
    var deck: Deck?
}

// Cached card data — refreshed from Limitless, not user-owned
@Model
class CachedCard {
    var id: String              // Limitless card ID
    var name: String
    var setCode: String
    var setName: String
    var number: String
    var types: [String]
    var subtypes: [String]
    var hp: Int?
    var isStandardLegal: Bool
    var imageURL: String
    var cachedAt: Date
}
```

`CachedCard` is a local mirror. It is never edited by the user. It is refreshed from Limitless on first launch and then on a weekly schedule (or manually via pull-to-refresh).

---

## Limitless TCG Integration

### Overview

Limitless TCG does not publish an official documented REST API, but exposes structured data through its web endpoints. The client will use a combination of:

1. **Unofficial card data endpoint** — `https://limitlesstcg.com/cards` with query parameters supports filtered card lookups in a structured format. The response structure is observable from the network tab and stable enough to rely on.
2. **Tournament data endpoint** — `https://limitlesstcg.com/tournaments` lists recent events; each tournament has a detail page with placement and deck list data.
3. **HTML parsing fallback** — where JSON endpoints are unavailable, use `SwiftSoup` (or a lightweight Swift HTML parser) to parse tournament results.

### LimitlessTCGClient

```swift
struct LimitlessTCGClient {
    // Cards
    func fetchStandardCards(page: Int) async throws -> [LimitlessCard]
    func fetchCard(id: String) async throws -> LimitlessCard

    // Tournaments
    func fetchRecentTournaments(limit: Int) async throws -> [LimitlessTournament]
    func fetchTournamentDetail(id: String) async throws -> LimitlessTournamentDetail
    func fetchDeckList(tournamentId: String, placement: Int) async throws -> LimitlessDeckList
}
```

The client maps raw API/HTML responses to clean `Limitless*` value types. No SwiftData in the client — it returns plain structs. The repository layer decides what to persist.

### Card Cache Strategy

```
App launch
  └─> CardRepository.refreshIfStale()
        └─> if (lastRefreshedAt < 7 days ago) fetch all Standard cards from Limitless
              └─> upsert into CachedCard SwiftData store
              └─> update lastRefreshedAt in UserDefaults
```

Cards are fetched in paginated batches. The full Standard card pool is ~2,000–3,000 cards; a single refresh completes in a few seconds on a normal connection.

### Tournament Feed Strategy

Tournament results are fetched fresh each time the user opens the feed (with a 1-hour in-memory cache). Tournament deck lists are fetched on demand when a user taps into a result. Both are cached to disk for offline reading.

### Resilience

All Limitless fetches are wrapped in retry logic (3 attempts, exponential backoff). Failure surfaces as a non-blocking banner — the app never blocks on network. If Limitless changes its response shape, a `DecodingError` is caught, logged, and surfaced as "Unable to refresh — check for an app update."

---

## Deck Builder

### Card Search & Filter

Filtering happens locally against `CachedCard` in SwiftData using predicates:

```swift
let descriptor = FetchDescriptor<CachedCard>(
    predicate: #Predicate {
        $0.isStandardLegal == true &&
        $0.name.localizedStandardContains(query)
    },
    sortBy: [SortDescriptor(\.name)]
)
```

Type, subtype, and set filters are composed additively. No server round-trip required for search.

### Legality Validation

A deck is valid if:
- Total card count == 60
- No more than 4 copies of any card with the same name (excluding basic Energy)
- All cards are Standard-legal (`CachedCard.isStandardLegal == true`)
- Exactly 1 Basic Pokémon is present (otherwise flagged as warning, not error — allows in-progress building)

Validation runs reactively in `DeckBuilderViewModel` using a `@Published var validationErrors: [DeckValidationError]`.

### Export

The deck export format matches PTCGL's copy-paste format:

```
Pokémon: 12
4 Charizard ex OBF 223
2 Charmander OBF 26
...

Trainer: 38
4 Professor's Research SVI 189
...

Energy: 10
10 Fire Energy SVE 2

Total Cards: 60
```

Generated in a pure function; shared via iOS `ShareSheet`.

---

## Match Tracker

### Log Match Flow

Target: < 5 taps to log a match.

1. Tap "+" from deck detail
2. Pick opponent archetype (search from archetype list, or type freeform)
3. Pick result (Win / Loss / Tie) — large tappable buttons
4. Confirm (date defaults to now; event type defaults to last used)

Advanced fields (event type, format, notes) are in a collapsible section.

### Archetype List

A curated list of current meta archetypes is bundled with the app and updated on each release. Users can also type any freeform archetype. Fuzzy matching on the curated list surfaces suggestions as the user types.

---

## Analytics Engine

All analytics are computed client-side from `Match` records in SwiftData.

### Win Rate by Archetype

```swift
struct MatchupStat {
    let archetype: String
    let wins: Int
    let losses: Int
    let ties: Int
    var winRate: Double { Double(wins) / Double(wins + losses + ties) }
    var sampleSize: Int { wins + losses + ties }
}
```

Computed via a `@Query` on `Match` filtered by `deck.id`, then grouped by `opponentArchetype`.

### Strength / Weakness Radar

Archetypes with ≥ 5 games and winRate ≥ 60% → "Favourable"
Archetypes with ≥ 5 games and winRate ≤ 40% → "Unfavourable"
Archetypes with < 5 games → "Insufficient data"

Displayed as a segmented list (not a literal radar chart — too hard to read on small screens). A radar/spider chart is considered for iPad layout.

### Meta Comparison

1. Fetch top archetypes from recent Limitless tournament results (meta share %)
2. Cross-reference with user's logged matchup win rates
3. Highlight: archetypes popular in the meta where user has < 5 games logged (practice gaps)
4. Highlight: archetypes popular in the meta where user win rate < 40% (danger matchups)

---

## Offline Behaviour

| Feature | Offline |
|---|---|
| Deck building | Full — uses local card cache |
| Match logging | Full — writes to SwiftData |
| Analytics | Full — computed from local data |
| Tournament feed | Read cached results; no refresh |
| Card cache refresh | Queued for next online session |

---

## iCloud Sync

SwiftData's `NSPersistentCloudKitContainer` is used to sync `Deck`, `DeckCard`, and `Match` records. `CachedCard` is excluded from sync (it is re-fetchable from Limitless on any device).

Conflict resolution follows CloudKit's last-write-wins default, which is acceptable for this use case (single user, multiple devices).

---

## Privacy & Data

- No account required
- No analytics SDK (no Mixpanel, Firebase, etc.)
- No personal data leaves the device except via iCloud sync (user-controlled)
- Limitless card image URLs are fetched at runtime; images are cached locally, not re-hosted

---

## Project Milestones

| Milestone | Scope |
|---|---|
| **M1 — Card Browser** | Card cache sync from Limitless; browse & search Standard cards; card detail view |
| **M2 — Deck Builder** | Build, save, validate, and export decks |
| **M3 — Match Tracker** | Log match results; match history per deck |
| **M4 — Analytics** | Win rate breakdown; favourable/unfavourable matchup tagging |
| **M5 — Tournament Feed** | Recent event results; inline deck list viewer |
| **M6 — Meta Comparison** | Cross-reference personal data with tournament meta; practice gap surface |

---

## Open Questions

1. **Limitless ToS** — Confirm scraping/data use is acceptable. If Limitless publishes an official API, migrate to it immediately.
2. **Archetype taxonomy** — Who maintains the canonical archetype list? Options: bundled + app-update cadence, or community-contributed via a lightweight backend.
3. **Push notifications** — Should we notify users when new tournament results are posted? Requires a small backend (push token registration). Out of scope for M1–M5.
4. **Android** — Not in scope. SwiftData and CloudKit are iOS-only. A future Android port would require a different persistence/sync strategy.
