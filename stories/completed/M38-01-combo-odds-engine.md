# M38-01 — Combo Odds Engine

**Status:** done  
**Milestone:** M38 — Opening Hand Combo Calculator  
**Dependencies:** M29-01 (ConsistencyEngine)

## User Story

As a competitive player, I want to calculate the probability that a specific combination of up to 5 cards all appear together — in my opening hand and in subsequent draws — so I can evaluate how reliably I can set up a key play.

## Acceptance Criteria

### ComboOdds & ComboCardSelection

- [ ] New structs added to `JustTCG/Domain/Entities/ConsistencyEngine.swift`:

```swift
struct ComboCardSelection {
    let name: String
    let copies: Int
}

struct ComboOdds {
    let opening: Double       // P(all selected appear in opening 7)
    let byTurn2: Double       // P(all appear by turn 2 going second — 9 cards)
    let byTurn3: Double       // P(all appear by turn 3 going second — 10 cards)
    let byTurn4: Double       // P(all appear by turn 4 going second — 11 cards)
}
```

### ConsistencyEngine.comboOdds

- [ ] New static method added to `ConsistencyEngine`:

```swift
/// Returns the probability that every card in `selectedCards` appears at least once
/// in a hand of `drawn` cards drawn from a `deckSize`-card deck.
///
/// Single-card selections use the exact hypergeometric CDF.
/// Multi-card selections use a Monte Carlo simulation with `simCount` trials.
static func comboOdds(
    selectedCards: [ComboCardSelection],
    deckSize: Int = 60,
    simCount: Int = 50_000
) -> ComboOdds
```

**Single-card path:**
- When `selectedCards.count == 1`, delegate to the existing exact `probabilityAtLeast` for each drawn count (7, 9, 10, 11). No simulation needed.

**Multi-card Monte Carlo path:**
- Build a virtual deck of `deckSize` slot labels where each selected card contributes `copies` labeled slots (e.g., 4 copies of "Arven" → 4 slots labeled "Arven") and the remaining `deckSize − Σcopies` slots are labeled "other"
- For each of `simCount` trials: shuffle the slot array using `Array.shuffle()`, then draw the first `drawn` slots and test whether every selected card name appears at least once in the drawn set
- Count successes / simCount to get the probability for that drawn count
- Run four separate simulations for drawn = 7, 9, 10, 11 (or run one simulation and check each prefix per trial)
- Clamp output to [0.0, 1.0]

**Efficiency note:**
- One pass per trial (draw 11 slots, check at prefixes 7, 9, 10, 11) saves three extra shuffles:
  ```
  shuffle(deck)
  let hand7  = first 7 slots
  let hand9  = first 9 slots
  let hand10 = first 10 slots
  let hand11 = first 11 slots
  ```
- `simCount` default of 50,000 yields < ±0.5% error on any probability; completes in < 200 ms on device

**Edge cases:**
- If `selectedCards` is empty, return `ComboOdds(opening: 1.0, byTurn2: 1.0, byTurn3: 1.0, byTurn4: 1.0)`
- If total copies of all selected cards exceed `deckSize − 7`, clamp drawn counts to avoid out-of-bounds
- If a card's `copies` is 0, treat it as impossible: return all-zero `ComboOdds`

### Tests

- [ ] `ConsistencyEngineTests.swift` — new test cases:
  - Single card, 4 copies: `comboOdds(selectedCards: [.init(name: "A", copies: 4)], deckSize: 60).opening` ≈ `0.398` (±0.01) — matches existing `openingHandProbability`
  - Two-card combo both with 4 copies: `opening` probability is strictly less than the single-card result
  - Empty selection: all probabilities equal `1.0`
  - `byTurn4` ≥ `byTurn3` ≥ `byTurn2` ≥ `opening` for any valid selection (monotonically increasing)

## Technical Notes

**Why Monte Carlo instead of exact multivariate hypergeometric:**
Exact multivariate hypergeometric via inclusion-exclusion requires iterating 2^m subsets (m = up to 5 cards) and computing a nested sum of C(N,n)-scaled products — feasible but complex to verify. Monte Carlo at 50k trials achieves sub-percent accuracy and is straightforward to audit. On an iPhone 15 Pro, 50k × 11-card shuffles runs in well under 100 ms.

**Drawn counts mapping to turns (going second):**
- Opening hand: 7
- Turn 2 going second: 7 (opening) + 1 (T1 draw) + 1 (T2 draw) = 9
- Turn 3 going second: 10
- Turn 4 going second: 11

**Files to change:**
- `JustTCG/Domain/Entities/ConsistencyEngine.swift` — add `ComboCardSelection`, `ComboOdds`, `ConsistencyEngine.comboOdds`
- `JustTCGTests/ConsistencyEngineTests.swift` — add combo odds test cases
