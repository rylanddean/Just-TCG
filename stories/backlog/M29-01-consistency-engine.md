# M29-01 — Deck Consistency Engine

**Status:** todo  
**Milestone:** M29 — Deck Consistency Calculator  
**Dependencies:** M2-01 (Deck & DeckCard models)

## User Story

As a competitive player, I want to see opening hand probabilities and a consistency score for my deck so that I can identify weak ratios and optimize my count choices before a tournament.

## Acceptance Criteria

### ConsistencyEngine

- [ ] New file `JustTCG/Domain/Entities/ConsistencyEngine.swift` — a pure value-type engine with no SwiftData dependencies
- [ ] `ConsistencyEngine` takes a `[DeckCardEntry]` (name + count) and deck size (default 60) and exposes:

**Hypergeometric probability:**
```swift
/// P(drawing at least `desired` copies of a card with `copies` copies in a `deckSize`-card deck
/// when drawing `drawn` cards) — uses exact hypergeometric CDF.
static func probabilityAtLeast(
    copies: Int,
    deckSize: Int,
    drawn: Int,
    desired: Int
) -> Double
```
- Implements via the exact hypergeometric CDF: `P(X ≥ desired) = 1 − Σ_{k=0}^{desired−1} [C(copies,k) * C(deckSize−copies, drawn−k) / C(deckSize, drawn)]`
- Clamps output to `[0, 1]`
- Uses `Double` throughout; binomial coefficients computed with log-gamma to avoid overflow

**Opening hand probability convenience:**
```swift
/// P(at least 1 copy in opening 7) for a card with `copies` copies in the deck.
static func openingHandProbability(copies: Int, deckSize: Int) -> Double
```

**Turn-N probability:**
```swift
/// P(having drawn at least 1 copy by the start of turn N), accounting for:
/// - 7-card opening hand
/// - 1 draw per turn (going-second player draws on turn 1; going-first does not)
/// Returns both going-first and going-second values.
static func probabilityByTurn(copies: Int, deckSize: Int, turn: Int) -> (first: Double, second: Double)
```

**Consistency score:**
```swift
/// A 0–100 score summarising the deck's overall draw/search density.
/// Formula:
///   score = min(100, (drawScore + searchScore) × 5)
/// where:
///   drawScore  = total copies of cards tagged "Draw" (capped at 14)
///   searchScore = total copies of cards tagged "Search" (capped at 12)
func consistencyScore(cards: [DeckCardEntry], roleTags: (String) -> [String]) -> Int
```

- `DeckCardEntry` is a plain struct: `struct DeckCardEntry { let name: String; let copies: Int }`
- `roleTags` is a closure injected by the caller (looks up `CachedCard.roleTags` via repository); this keeps the engine dependency-free

**Breakdown struct:**
```swift
struct ConsistencyBreakdown {
    let consistencyScore: Int        // 0–100
    let drawCount: Int               // total draw-tagged card copies
    let searchCount: Int             // total search-tagged card copies
    let keyCards: [KeyCardOdds]      // one entry per unique card (sorted by copies desc)
}

struct KeyCardOdds {
    let name: String
    let copies: Int
    let openingHandProbability: Double   // P(≥1 in opening 7)
    let byTurn2First: Double             // P(≥1 by turn 2, going first)
    let byTurn2Second: Double            // P(≥1 by turn 2, going second)
}
```

- [ ] `ConsistencyEngine.breakdown(entries:deckSize:roleTags:) -> ConsistencyBreakdown` returns a fully-populated breakdown
- [ ] `keyCards` includes all cards with ≥ 1 copy; sorted by copies descending, then name ascending as tiebreak
- [ ] Engine is fully unit-testable with no simulator needed (pure Swift, no SwiftUI/SwiftData imports)

### Tests

- [ ] `ConsistencyEngineTests.swift` added to the test target with at least these cases:
  - `openingHandProbability(copies:4, deckSize:60)` ≈ `0.398` (±0.001)
  - `openingHandProbability(copies:1, deckSize:60)` ≈ `0.117` (±0.001)
  - `probabilityByTurn(copies:4, deckSize:60, turn:2).second` > `probabilityByTurn(copies:4, deckSize:60, turn:2).first`
  - `consistencyScore` increases monotonically as draw/search counts increase

## Technical Notes

**Hypergeometric CDF with log-gamma:**
```swift
private static func logBinomial(_ n: Int, _ k: Int) -> Double {
    guard k >= 0, k <= n else { return -Double.infinity }
    return lgamma(Double(n + 1)) - lgamma(Double(k + 1)) - lgamma(Double(n - k + 1))
}

private static func hypergeometricPMF(N: Int, K: Int, n: Int, k: Int) -> Double {
    let log_p = logBinomial(K, k) + logBinomial(N - K, n - k) - logBinomial(N, n)
    return exp(log_p)
}
```

**`probabilityByTurn` drawn-cards formula:**
- Going first, turn N: drawn = 7 + (N − 1) (no draw on turn 1)
- Going second, turn N: drawn = 7 + N

**Files to create:**
- `JustTCG/Domain/Entities/ConsistencyEngine.swift`
- `JustTCGTests/ConsistencyEngineTests.swift`
