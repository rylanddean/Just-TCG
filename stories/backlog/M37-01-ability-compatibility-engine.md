# M37-01 — Ability Compatibility Engine

**Status:** backlog  
**Milestone:** M37 — Ability Compatibility  
**Dependencies:** M29-01 (ConsistencyEngine — hypergeometric math reused here)

## User Story

As a deck builder, I want the app to automatically detect when a Pokémon's ability has a hard or soft condition (e.g., requires 4 Team Rocket's Pokémon in play) and score how likely that condition is to be met given the rest of the deck, so I can catch dead-weight ability Pokémon before a tournament.

## Research findings

Analyzed all 502 ability texts across 16 Standard card sets (regulation marks H, I, J). Of 260 unique ability-bearing Pokémon, **21 cards (8%) have compat-relevant conditional abilities** that the engine must detect and score. The full set by type:

| Type | Count | Cards |
|------|-------|-------|
| A — Minimum count in play | 1 | Team Rocket's Mewtwo ex |
| B — Named card required in play | 4 | Lunatone, Karrablast, Shelmet, Munkidori ex |
| C — Category Pokémon required in play | 6 | Azumarill, Noctowl, Ludicolo, Oricorio ex, Seviper, Linoone |
| D — Activation cost: specific card/energy | 3 | Iono's Kilowattrel, Volcarona, Meowstic |
| E — Specific trainer played this turn | 2 | Heliolisk (Canari), Crobat (Janine's Secret Art) |
| F — Self energy type attached | 5 | Munkidori, Okidogi, Fezandipiti, Shuckle, Tyrantrum |

Conditions **not** relevant to deck composition (no compat concern):
- Position-based ("in the Active Spot", "on the Bench") — always achievable by placement
- Frequency restrictions ("once during your turn") — inherent to the card, not deck-dependent
- Trigger events ("when you play from hand to evolve") — automatic, no deck requirement
- KO/damage responses ("if this Pokémon is Knocked Out") — game-state dependent
- Prize card scaling ("for each Prize card taken") — game-state dependent
- Hand parity ("same number of cards as your opponent") — game-state dependent
- Generic discard cost ("discard a card from your hand", "discard 2 cards") — any card works, no compat concern

## Acceptance Criteria

### AbilityCompatibilityEngine

- [ ] New file `JustTCG/Domain/Entities/AbilityCompatibilityEngine.swift` — pure value-type, no SwiftData or SwiftUI imports
- [ ] Single entry point:

```swift
struct AbilityCompatibilityEngine {
    func breakdown(
        entries: [DeckCardEntry],
        abilityTexts: (String) -> [(name: String, text: String)]
    ) -> AbilityCompatibilityBreakdown
}
```

`abilityTexts` is injected by the caller and mirrors the `roleTags` closure pattern in `ConsistencyEngine` — returns structured ability `(name, text)` pairs for a given card name, parsed from `CachedCard.rulesText`.

### Ability text parsing helper

- [ ] `static func parseAbilities(from rulesText: [String]) -> [(name: String, text: String)]` — public so the caller can build the closure
- [ ] Input format: each rulesText element for an ability is `"[Ability] Name\nability text"` or `"[Pokémon Power] Name\nability text"` (the scraper format — a single String with an embedded newline)
- [ ] Lines not starting with `[Ability]` or `[Pokémon Power]` are skipped (attacks, rules, etc.)
- [ ] Strip the bracket prefix to get the name; everything after `\n` is the text; if no `\n`, text is `""`

### Condition types

```swift
enum AbilityConditionType: Equatable {
    /// No compat-relevant condition — ability fires unconditionally or condition is position/frequency/trigger-based
    case unconditional

    /// Requires at least N Pokémon matching a qualifier to be in play
    /// qualifier is the raw extracted substring, e.g. "Team Rocket's", "Fire", "" (any Pokémon)
    case minimumInPlay(count: Int, qualifier: String)

    /// Requires a specific named card to be in play or on the Bench
    case namedCardRequired(cardName: String)

    /// Requires at least one Pokémon of a specific category (subtype keyword, optional type filter) in play
    /// subtypeKeyword: "MEGA" or "Tera"; typeFilter: "Fire", "Grass", nil (any type)
    case categoryPokemonRequired(subtypeKeyword: String, typeFilter: String?)

    /// Ability can only be activated by discarding a specific named card or energy type from hand (or from self)
    /// cardPattern is the extracted phrase, e.g. "Basic Fire Energy", "Chill Teaser Toy"
    case activationCost(cardPattern: String, isEnergy: Bool)

    /// Ability only fires if a specific Trainer card was played from hand this turn
    case trainerRequired(cardName: String)

    /// This Pokémon must have a specific energy type attached
    case selfEnergyRequired(energyType: String)

    /// Ability is conditional on prize card count differential — unpredictable from deck
    case prizeDependent

    /// Detected a conditional keyword but pattern didn't match above — unclassified risk
    case unknown
}
```

### Condition detection

Run detection on the lowercased ability text in the order below. A single ability text can match **multiple** condition types (e.g., Lunatone's Lunar Cycle requires both Solrock in play AND must discard a Fighting Energy). Collect all matches.

**Type A — minimumInPlay**

Pattern: `"(\d+) or more (.+?)pok[eé]mon in play"` or `"unless you have (\d+) or more (.+?)pok[eé]mon in play"` or `"at least (\d+) (.+?)pok[eé]mon in play"`
- Extract integer as `count`, extract substring between "have" and "pokémon" (trim whitespace) as `qualifier`
- Qualifier examples: `"team rocket's "` → trim to `"Team Rocket's"`, `"fire "` → trim to `"Fire"`, `""` → empty (any Pokémon)

**Type B — namedCardRequired**

Pattern: `"if you have (?:any )?([A-Za-z][A-Za-z0-9 '♂♀♀-]+?) (?:in play|on your bench)"` — but only when the captured name does NOT contain a category keyword (`"tera"`, `"mega"`, `"fire"`, `"grass"`, `"water"`, `"darkness"`, `"lightning"`, `"fighting"`, `"psychic"`, `"metal"` followed by a space — these belong to Type C).
- Captured group is the card name; title-case it for display
- Example: `"if you have solrock in play"` → `namedCardRequired("Solrock")`
- Example: `"if you have any pecharunt ex in play"` → `namedCardRequired("Pecharunt ex")`

**Type C — categoryPokemonRequired**

Pattern: `"if you have any (.+?)pok[eé]mon"` — when the captured prefix contains a category keyword.
- Parse `subtypeKeyword` and `typeFilter` from the captured prefix:
  - Contains `"tera"` → `subtypeKeyword = "Tera"`, `typeFilter = nil`
  - Contains `"mega"` (or `"mega evolution"`) → `subtypeKeyword = "MEGA"`; look for a preceding Pokémon type word in the same prefix (`"fire"` → `typeFilter = "Fire"`, `"grass"` → `"Grass"`, `"darkness"` → `"Darkness"`, otherwise `nil`)
- Example: `"any fire mega evolution pokémon ex in play"` → `categoryPokemonRequired("MEGA", "Fire")`
- Example: `"any tera pokémon in play"` → `categoryPokemonRequired("Tera", nil)`
- Example: `"any mega evolution pokémon ex in play"` → `categoryPokemonRequired("MEGA", nil)`

**Type D — activationCost**

Pattern: `"you must discard (?:a |an )?(.+?)(?: from .+?| in order)"` where captured group is the thing being discarded.
- Exclude generic discards: captured group is `"card"`, `"2 cards"`, `"3 cards"`, or any `"[N] cards"` pattern → treat as `unconditional` (any card works, no compat concern)
- `isEnergy`: true if captured group contains `"energy"` (e.g., `"Basic Fire Energy"`, `"Basic Lightning Energy"`)
- `isEnergy`: false for named items (e.g., `"Chill Teaser Toy"`)
- Example: `"you must discard a basic fire energy card from your hand in order to use this ability"` → `activationCost("Basic Fire Energy", isEnergy: true)`
- Example: `"you must discard a chill teaser toy card from your hand in order to use this ability"` → `activationCost("Chill Teaser Toy", isEnergy: false)`
- Note on Iono's Kilowattrel: text says "discard a Basic Lightning Energy **from this Pokémon**" (not from hand). Detect identically — still requires Lightning Energy in the deck to attach to this Pokémon.

**Type E — trainerRequired**

Pattern: `"if you played (.+?) from your hand this turn"` — captured group is the Trainer card name.
- Example: `"if you played janine's secret art from your hand this turn"` → `trainerRequired("Janine's Secret Art")`
- Example: `"if you played canari from your hand this turn"` → `trainerRequired("Canari")`

**Type F — selfEnergyRequired**

Pattern: `"if this pok[eé]mon has any (.+?) energy attached"` — captured group is the energy type name.
- Example: `"darkness energy attached"` → `selfEnergyRequired("Darkness")`
- Example: `"special energy attached"` → `selfEnergyRequired("Special")`
- Example: `"grass energy attached"` → `selfEnergyRequired("Grass")`

**prizeDependent**

Text contains `"fewer prize"` or `"more prize"` or `"prize cards remaining"` or `"same number of cards in your hand as your opponent"` → `prizeDependent`

**unknown**

If text contains any of `["unless", "if you have", "as long as you have", "if you don't have"]` but none of the above patterns matched → `unknown`

**unconditional fallback**

If none of the above condition types were detected → `unconditional`

### Qualifier resolution for matching deck entries

When scoring `minimumInPlay`, resolve `qualifier` against deck entries as follows:

```swift
private func matchingCount(qualifier: String, in entries: [DeckCardEntry]) -> Int {
    let q = qualifier.trimmingCharacters(in: .whitespaces).lowercased()
    let pokemonEntries = entries.filter { $0.supertype == "Pokémon" }
    if q.isEmpty {
        return pokemonEntries.reduce(0) { $0 + $1.copies }
    }
    // Pokémon type match (Fire, Water, etc.)
    let typeNames = ["fire","water","grass","lightning","fighting","psychic","darkness","metal","dragon","colorless"]
    if typeNames.contains(q) {
        return pokemonEntries.filter { $0.types.map { $0.lowercased() }.contains(q) }.reduce(0) { $0 + $1.copies }
    }
    // Subtype match (MEGA, Tera, ex, etc.)
    if entries.flatMap(\.subtypes).map({ $0.lowercased() }).contains(q) {
        return pokemonEntries.filter { $0.subtypes.map { $0.lowercased() }.contains(q) }.reduce(0) { $0 + $1.copies }
    }
    // Name prefix match — for qualifiers like "Team Rocket's"
    return pokemonEntries.filter { $0.name.lowercased().hasPrefix(q) }.reduce(0) { $0 + $1.copies }
}
```

For `categoryPokemonRequired(subtypeKeyword, typeFilter)`:
```swift
private func categoryCount(subtypeKeyword: String, typeFilter: String?, in entries: [DeckCardEntry]) -> Int {
    entries.filter { entry in
        guard entry.supertype == "Pokémon" else { return false }
        let hasSubtype = entry.subtypes.contains(subtypeKeyword)
        let hasType = typeFilter.map { entry.types.contains($0) } ?? true
        return hasSubtype && hasType
    }.reduce(0) { $0 + $1.copies }
}
```

### Compatibility scoring

For each condition type detected on an ability, compute a score (0–100):

**unconditional** → `100`

**minimumInPlay(count, qualifier)**:
1. `matchingCount` = count of matching Pokémon copies in deck (using qualifier resolution above)
2. If `matchingCount < count` → `0` (impossible to satisfy even with perfect draws)
3. Otherwise: `p = ConsistencyEngine.probabilityAtLeast(copies: matchingCount, deckSize: 60, drawn: 11, desired: count) × 0.80`
   - `drawn = 11` (7 opening hand + 4 draws = start of turn 4 going second — early mid-game reference point)
   - `× 0.80` bench-to-hand ratio (accounts for prize cards, bench-full scenarios, or cards held in hand)
4. Map `p` to score: `p ≥ 0.60 → 100`, `p 0.40–0.59 → 65`, `p 0.20–0.39 → 35`, `p < 0.20 → 10`

**namedCardRequired(cardName)**:
- Count copies of `cardName` in entries (case-insensitive match on `entry.name`): `4+ → 100`, `3 → 85`, `2 → 65`, `1 → 40`, `0 → 0`

**categoryPokemonRequired(subtypeKeyword, typeFilter)**:
- `n = categoryCount(subtypeKeyword, typeFilter, in: entries)`
- `n == 0 → 5` (near-impossible without any matching category Pokémon in deck), `n == 1 → 65`, `n ≥ 2 → 90`

**activationCost(cardPattern, isEnergy)**:
- For `isEnergy == true`: extract the energy type from `cardPattern` (e.g., `"Basic Fire Energy"` → `"Fire"`); count Energy-supertype entries in deck whose name contains that type word: `≥ 4 → 100`, `3 → 85`, `2 → 65`, `1 → 40`, `0 → 0`
- For `isEnergy == false` (named item): count copies of the named item (match `entry.name` case-insensitively against `cardPattern`): `≥ 2 → 90`, `1 → 60`, `0 → 0`

**trainerRequired(cardName)**:
- Count copies of the named Trainer (case-insensitive `entry.name` match): `4 → 100`, `3 → 85`, `2 → 65`, `1 → 40`, `0 → 0`

**selfEnergyRequired(energyType)**:
- For named type (Darkness, Grass, etc.): count Energy entries in deck whose name contains `energyType`: `≥ 4 → 100`, `2–3 → 80`, `1 → 50`, `0 → 0`
- For `energyType == "Special"`: count Energy entries whose `subtypes` contains `"Special"`: `≥ 2 → 80`, `1 → 55`, `0 → 0`

**prizeDependent** → `55` (unpredictable from deck composition)

**unknown** → `50`

### Scoring rollup

- A single ability text may produce multiple condition scores (compound conditions like Lunatone); the **ability text score = minimum** of all its condition scores.
- A Pokémon entry with multiple abilities takes the **minimum** across its ability text scores as its `compatibilityScore`.
- Severity mapping: `score ≥ 70 → .ok`, `40 ≤ score < 70 → .caution`, `score < 40 → .conflict`
- Deck-level `compatibilityScore`: start at 100, subtract 30 per `.conflict` result, subtract 15 per `.caution` result, clamp to `[0, 100]`; if no ability-bearing Pokémon in deck, return 100

### Output structs

```swift
enum AbilitySeverity {
    case ok
    case caution
    case conflict
}

struct AbilityCompatibilityResult {
    let cardName: String
    let copies: Int
    /// The ability name of the worst-scoring ability on this card
    let abilityName: String
    /// The worst-scoring condition detected on that ability
    let conditionType: AbilityConditionType
    let score: Int
    let severity: AbilitySeverity
    /// Human-readable warning; nil when severity == .ok
    let warningMessage: String?
}

struct AbilityCompatibilityBreakdown {
    /// One per ability-bearing Pokémon, sorted by score ascending (worst first)
    let results: [AbilityCompatibilityResult]
    let compatibilityScore: Int

    var conflicts: [AbilityCompatibilityResult] { results.filter { $0.severity == .conflict } }
    var cautions: [AbilityCompatibilityResult]  { results.filter { $0.severity == .caution } }
    var hasIssues: Bool { results.contains { $0.severity != .ok } }
}
```

### Warning message generation

Generate `warningMessage` automatically from the condition type and score. Use the card's `copies` in the message where relevant.

- `.minimumInPlay(4, "Team Rocket's")`, score = 0: `"Power Saver requires 4+ Team Rocket's Pokémon in play, but the deck has 0 — condition can never be met."`
- `.minimumInPlay(4, "Team Rocket's")`, score = 35: `"Power Saver requires 4+ Team Rocket's Pokémon in play. The deck has N — condition is met roughly X% of the time by turn 4."`
- `.namedCardRequired("Solrock")`, score = 0: `"Lunar Cycle requires Solrock in play, but the deck contains 0 copies."`
- `.categoryPokemonRequired("MEGA", "Fire")`, score = 5: `"Excited Turbo requires a Fire Mega Evolution Pokémon ex in play, but the deck contains none."`
- `.activationCost("Basic Fire Energy", isEnergy: true)`, score = 0: `"Torrid Scales requires discarding a Basic Fire Energy — deck contains 0 Fire Energy cards."`
- `.activationCost("Chill Teaser Toy", isEnergy: false)`, score = 0: `"Beckoning Tail requires discarding a Chill Teaser Toy — deck contains 0 copies."`
- `.trainerRequired("Janine's Secret Art")`, score = 0: `"Shadowy Envoy only fires when Janine's Secret Art is played this turn — deck contains 0 copies."`
- `.selfEnergyRequired("Darkness")`, score = 0: `"Adrena-Brain requires Darkness Energy attached — deck contains 0 Darkness Energy cards."`
- `.prizeDependent`: `"Ability effectiveness depends on prize count — unpredictable from deck composition alone."`
- `.unknown`: `"Ability has a conditional trigger that couldn't be fully analysed — review manually."`

### Tests

- [ ] `AbilityCompatibilityEngineTests.swift` in the test target:

  **Type A detection and scoring:**
  - `"This Pokémon can't attack unless you have 4 or more Team Rocket's Pokémon in play."` → `minimumInPlay(count: 4, qualifier: "Team Rocket's")`
  - With 0 Team Rocket's Pokémon in entries → `score == 0`, `severity == .conflict`
  - With 8 Team Rocket's copies in entries → `score == 100` (easily satisfies 4 minimum)

  **Type B detection and scoring:**
  - `"if you have Solrock in play"` → `namedCardRequired("Solrock")`
  - With 0 Solrock in entries → `score == 0`
  - With 2 Solrock in entries → `score == 65`

  **Type C detection:**
  - `"if you have any Fire Mega Evolution Pokémon ex in play"` → `categoryPokemonRequired("MEGA", "Fire")`
  - `"if you have any Tera Pokémon in play"` → `categoryPokemonRequired("Tera", nil)`
  - `"if you have any Mega Evolution Pokémon ex in play"` → `categoryPokemonRequired("MEGA", nil)`
  - With 0 matching category entries → `score == 5`, `severity == .conflict`
  - With 2+ matching entries → `score == 90`, `severity == .ok`

  **Type D detection:**
  - `"You must discard a Basic Fire Energy card from your hand in order to use this Ability."` → `activationCost("Basic Fire Energy", isEnergy: true)`
  - `"You must discard a Chill Teaser Toy card from your hand in order to use this Ability."` → `activationCost("Chill Teaser Toy", isEnergy: false)`
  - `"You must discard a card from your hand in order to use this Ability."` → `unconditional` (generic discard, no compat concern)

  **Type E detection:**
  - `"if you played Janine's Secret Art from your hand this turn"` → `trainerRequired("Janine's Secret Art")`
  - With 0 copies in deck → `score == 0`

  **Type F detection:**
  - `"if this Pokémon has any Darkness Energy attached"` → `selfEnergyRequired("Darkness")`
  - `"if this Pokémon has any Special Energy attached"` → `selfEnergyRequired("Special")`
  - With 0 Energy of that type in deck → `score == 0`

  **Compound condition (Lunatone):**
  - Ability text with both `namedCardRequired("Solrock")` and `activationCost("Basic Fighting Energy", isEnergy: true)` → ability score = `min(score_B, score_D)`

  **Deck-level score:**
  - Deck with 1 conflict and 1 caution → `compatibilityScore == max(0, 100 - 30 - 15) == 55`
  - Deck with no ability Pokémon → `compatibilityScore == 100`

  **Non-compat conditions do not produce results:**
  - `"Once during your turn, if this Pokémon is in the Active Spot, you may draw 2 cards."` → `unconditional`, not in `breakdown.results` that would have `severity != .ok`

## Technical Notes

**Why Team Rocket's uses name prefix, not subtype:**
The Team Rocket's card set uses name prefixing (`"Team Rocket's Mewtwo ex"`, `"Team Rocket's Moltres ex"`) not a custom subtype. Their `subtypes` arrays are standard (`["Basic", "ex"]`). The engine must check `name.lowercased().hasPrefix(qualifier.lowercased())` after type and subtype lookups fail.

**Why drawn = 11 for the in-play estimate:**
By the start of turn 4 going second: 7 opening hand + 4 draw steps = 11 cards seen. This is the early mid-game window when ability Pokémon are expected to be operational. The 0.80 bench factor accounts for prize-carded Pokémon, a full bench, and deliberate hand-holding.

**Why `categoryPokemonRequired` has a minimum score of 5 (not 0):**
Zero copies of a Mega Evolution or Tera Pokémon in play is a near-certain conflict, but game mechanics allow a card to be played onto the bench mid-game from a draw, so it's not mathematically impossible to the same degree as an absolute `minimumInPlay` impossibility. Score 5 vs 0 reflects this subtle distinction.

**Abilities with no text are skipped silently:**
The `parseAbilities` helper returns `[]` for empty text strings. `breakdown()` skips entries where `abilityTexts` returns an empty array.

**Files to create:**
- `JustTCG/Domain/Entities/AbilityCompatibilityEngine.swift`
- `JustTCGTests/AbilityCompatibilityEngineTests.swift`
