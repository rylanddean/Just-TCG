# M30-01 — Meta Trend Engine

**Status:** done  
**Milestone:** M30 — Meta Trend Tracker  
**Dependencies:** M5-01 (tournament list), M6-01 (meta share engine)

## User Story

As a competitive player, I want to see how archetype meta share is moving week over week so I can spot rising threats and fading decks before they surprise me at a tournament.

## Acceptance Criteria

### MetaTrendEngine

- [ ] New file `JustTCG/Domain/Entities/MetaTrendEngine.swift`
- [ ] `@Observable` class injected via `.environment` (same pattern as other repository classes)
- [ ] On init, receives `LimitlessTCGClient` and a cache directory URL

**Data fetch:**
```swift
/// Fetch the most recent `weekCount` major-event tournaments and compute
/// per-archetype meta share for each week bucket.
func loadTrends(weekCount: Int = 8) async throws
```
- Calls `LimitlessTCGClient.fetchTournaments()` and takes the most recent `weekCount` tournaments that have placement data
- For each tournament, computes archetype share using the same bucketing as `MetaShareEngine` (top-N cut, count by archetype name)
- Groups tournaments by ISO week (`Calendar.current.component(.weekOfYear, …)`) — multiple tournaments in the same week are averaged
- Produces `[WeekSnapshot]` sorted oldest → newest

**Models:**
```swift
struct WeekSnapshot: Identifiable {
    let id: UUID
    let weekLabel: String          // e.g. "May 26"
    let archetypeShares: [ArchetypeShare]
}

struct ArchetypeShare: Identifiable {
    let id: UUID
    let archetypeName: String
    let sharePercent: Double       // 0–100
}
```

**Trend computation:**
```swift
/// Returns the top N archetypes by average share across all weeks,
/// with a `trend` value: share in the most recent week minus share in the oldest week.
func topArchetypes(n: Int) -> [ArchetypeTrend]

struct ArchetypeTrend: Identifiable {
    let id: UUID
    let archetypeName: String
    let averageShare: Double
    let recentShare: Double
    let trend: Double              // positive = rising, negative = falling
    let weeklyShares: [Double]     // one entry per WeekSnapshot, same order
}
```

**Caching:**
- [ ] Results are cached to disk as JSON in the provided cache directory under `meta_trends.json`
- [ ] Cache is considered stale if older than 6 hours — `loadTrends` uses the cache unless stale or `forceRefresh: true` is passed
- [ ] `isLoading: Bool` and `loadError: Error?` published properties for the UI to observe

## Technical Notes

**Files to create:**
- `JustTCG/Domain/Entities/MetaTrendEngine.swift`

**Environment injection:**
- Add `MetaTrendEngine` to the environment in `JustTCGApp.swift` alongside the other `@Observable` services
- Use the app's Caches directory: `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!`

**Archetype bucketing:**
- Reuse the same name-normalisation logic already in `MetaShareEngine` (or extract it to a shared `ArchetypeNameNormalizer` if duplication becomes a concern — that refactor is out of scope for this story)
