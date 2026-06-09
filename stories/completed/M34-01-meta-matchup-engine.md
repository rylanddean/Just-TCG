# M34-01 — Meta Matchup Engine

**Status:** done  
**Milestone:** M34 — Meta Matchup Score  
**Dependencies:** M29-01 (ConsistencyEngine / DeckCardEntry), M6-01 (MetaShareEngine), M30-01 (MetaTrendEngine / ArchetypeShare), M3-02 (archetypes.json)

## User Story

As a competitive player, I want to see how my deck's type composition lines up against the current meta so I can identify favourable and unfavourable matchups before a tournament, including type advantages granted by abilities in my deck.

## Acceptance Criteria

### DeckCardEntry extension

- [ ] Add `weaknessType: String? = nil` to `DeckCardEntry` (default nil preserves all existing call-site compatibility)
- [ ] Update the three call sites that build `DeckCardEntry` from `CachedCard` to populate the new field:
  - `DeckBuilderView.swift` (line ~557)
  - `ConsistencySheet.swift` (line ~232)
  - `DecksView.swift` (line ~219)
  - (`TechAdvisorEngine.swift` does not have `CachedCard` access — leave as default nil)

### MetaMatchupEngine

- [ ] New file `JustTCG/Domain/Entities/MetaMatchupEngine.swift` — a pure value-type engine with no SwiftData or SwiftUI dependencies

**Output models:**
```swift
enum MatchupAdvantage {
    case favoured       // user's deck has type edge against this archetype
    case even           // no clear type advantage either way
    case unfavoured     // this archetype's type exploits a weakness in user's Pokémon
}

struct MatchupEntry: Identifiable {
    let id: UUID
    let archetypeName: String
    let primaryType: String         // the meta deck's attacking type
    let weaknessType: String        // what type the meta deck is weak to
    let metaSharePercent: Double    // weight used in overall score
    let advantage: MatchupAdvantage
    let abilitySource: String?      // non-nil when advantage is ability-granted,
                                    // e.g. "Lillie's Clefairy ex — Fairy Zone"
}

struct MetaMatchupBreakdown {
    let matchupScore: Int           // 0–100 weighted average
    let matchups: [MatchupEntry]    // sorted by metaSharePercent descending
}
```

**Standard weakness chart (hardcoded, current PTCG Standard format):**
```swift
private static let weaknessChart: [String: String] = [
    "Fire":       "Water",
    "Water":      "Lightning",
    "Grass":      "Fire",
    "Lightning":  "Fighting",
    "Psychic":    "Darkness",
    "Fighting":   "Psychic",
    "Darkness":   "Fighting",
    "Metal":      "Fire",
    "Dragon":     "Dragon",
    "Colorless":  "Fighting"
]
```

**Ability-based type boost registry (hardcoded):**

Some Pokémon abilities alter type relationships beyond the standard weakness chart. The registry lists known cards and what type advantage they grant:

```swift
private struct TypeBoostAbility {
    let cardName: String
    let abilityName: String
    /// Pokémon that are normally weak to this type...
    let extendsWeaknessFor: String
    /// ...also become weak to this type while the ability is active.
    let grantsAdvantageToType: String
}

private static let typeBoostAbilities: [TypeBoostAbility] = [
    TypeBoostAbility(
        cardName: "Lillie's Clefairy ex",
        abilityName: "Fairy Zone",
        extendsWeaknessFor: "Darkness",   // Darkness-weak Pokémon also become weak to...
        grantsAdvantageToType: "Colorless" // ...Colorless attackers
    )
    // Extend this list as new type-modifying abilities enter the Standard format.
]
```

**Archetype type map (loaded from bundle):**
```swift
private static let archetypeTypeMap: [String: String] = {
    guard let url = Bundle.main.url(forResource: "archetypes", withExtension: "json"),
          let data = try? Data(contentsOf: url) else { return [:] }
    struct Entry: Decodable { let name: String; let primaryType: String }
    let entries = (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    // Keyed by lowercased archetype name for fuzzy lookup against MetaShare.archetype
    return Dictionary(entries.map { ($0.name.lowercased(), $0.primaryType) }) { $1 }
}()
```

**Core method:**
```swift
/// Returns a matchup breakdown for the given deck against the current meta.
/// - Parameters:
///   - deck: the user's deck as DeckCardEntry array (weaknessType populated)
///   - metaShares: top archetypes with share percentages, e.g. from MetaTrendEngine.snapshots.last
func breakdown(
    deck: [DeckCardEntry],
    metaShares: [ArchetypeShare]
) -> MetaMatchupBreakdown
```

**Algorithm:**

1. **Derive user's attacker types**: collect all `types` from entries where `supertype == "Pokémon"`. Deduplicates — order doesn't matter.

2. **Derive ability-boosted types**: for each entry in `deck` where `hasAbility == true`, look up `entry.name` in `typeBoostAbilities`. For each match, if the meta deck's weakness type equals `extendsWeaknessFor`, the user's `grantsAdvantageToType` is also treated as an effective attacker type for that archetype. Track the `abilityName` + `cardName` for display in `abilitySource`.

3. **Derive user's weakness types**: collect all `weaknessType` (non-nil) from entries where `supertype == "Pokémon"` and `copies >= 1`. If a meta deck's `primaryType` appears in this set, the matchup leans unfavoured.

4. **For each meta archetype** (top 10 by `sharePercent`, minimum 0.5% share):
   - Look up `primaryType` via `archetypeTypeMap` (fuzzy: try exact lowercase match, then first prefix match)
   - Look up `weaknessType` via `weaknessChart[primaryType]`
   - **isFavoured**: user's effective attacker types (step 1 + step 2) contain `weaknessType`
   - **isUnfavoured**: `primaryType` appears in user's weakness types (step 3)
   - **advantage**:
     - If `isFavoured && !isUnfavoured` → `.favoured`
     - If `isUnfavoured && !isFavoured` → `.unfavoured`
     - Otherwise (both or neither) → `.even`
   - Skip archetypes where `primaryType` cannot be resolved

5. **Weighted score**:
   ```
   advantageScore = favoured → 100, even → 50, unfavoured → 0
   matchupScore = round( Σ(advantageScore_i × sharePercent_i) / Σ sharePercent_i )
   ```
   If `metaShares` is empty or no archetypes resolve, return score of 50 and empty `matchups`.

- [ ] `MatchupEntry.abilitySource` is nil for standard type-chart advantages; non-nil only when an ability override triggered the favoured classification, formatted as `"<CardName> — <AbilityName>"`
- [ ] Engine is fully unit-testable with no simulator needed (pure Swift, no SwiftUI/SwiftData imports)

### Tests

- [ ] `MetaMatchupEngineTests.swift` added to the test target with at least these cases:
  - A deck with Fire attackers scores Favoured against a Grass archetype (Grass → weak to Fire)
  - A deck with only Water attackers scores Unfavoured against a Lightning archetype (Lightning → weak to Fighting, Water is not Fighting; user's Water Pokémon have Lightning weakness)
  - A deck containing Lillie's Clefairy ex with Colorless attackers scores Favoured against a Psychic archetype (Psychic → weak to Darkness; Fairy Zone extends Darkness-weak to Colorless)
  - Empty `metaShares` input returns `matchupScore == 50` and empty `matchups`
  - Weighted score increases when Favoured archetypes have higher meta share

## Technical Notes

**Fuzzy archetype name matching:**

`MetaShare.archetype` values come from the Limitless API and may differ in casing or spacing from `archetypes.json` names (e.g. `"Dragapult ex"` vs `"dragapult-ex"`). Match strategy:
1. Try `archetypeTypeMap[metaShare.archetype.lowercased()]` (direct lowercase match)
2. If nil, try `archetypeTypeMap.keys.first { metaShare.archetype.lowercased().contains($0) }`
3. If still nil, skip the archetype (do not include in score denominator)

**Why the ability registry is hardcoded:**

Parsing ability text from `rulesText` to infer type interactions would be fragile and error-prone. A curated list is small (< 10 entries at any given Standard format) and can be updated alongside content releases. The registry is a `private static let` so it costs nothing at runtime.

**Files to create:**
- `JustTCG/Domain/Entities/MetaMatchupEngine.swift`
- `JustTCGTests/MetaMatchupEngineTests.swift`

**Files to modify:**
- `JustTCG/Domain/Entities/ConsistencyEngine.swift` — add `weaknessType: String? = nil` to `DeckCardEntry`
- `JustTCG/Features/Decks/DeckBuilderView.swift` — populate `weaknessType` when building `DeckCardEntry`
- `JustTCG/Features/Decks/ConsistencySheet.swift` — populate `weaknessType`
- `JustTCG/Features/Decks/DecksView.swift` — populate `weaknessType`
