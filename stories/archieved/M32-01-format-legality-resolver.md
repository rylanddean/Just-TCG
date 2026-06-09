# M32-01 — Format Legality Resolver

**Status:** todo  
**Milestone:** M32 — Format Rotation Guard  
**Dependencies:** M1-02 (CachedCard model), M2-01 (Deck model)

## User Story

As a competitive player, I want the app to know which cards are legal in Standard and Expanded so I can immediately see if my deck would be disqualified at a tournament before I show up.

## Acceptance Criteria

### Bundled Legality Data

- [ ] New file `JustTCG/CardData/SetLegality.json` bundled with the app
- [ ] JSON schema:
```json
{
  "lastUpdated": "2025-06-01",
  "standardRotationDate": "2025-04-04",
  "standardLegalSetCodes": ["SVI", "OBF", "MEW", "PAR", "PAF", "TEF", "TWM", "SFA", "SCR", "SSP", "PRE", "CRI"],
  "expandedLegalSetCodes": ["SVI", "OBF", "MEW", "PAR", "PAF", "TEF", "TWM", "SFA", "SCR", "SSP", "PRE", "CRI",
    "BRS", "ASR", "CRZ", "SIT", "LOR", "GRI", "SIL", "EVS", "CRE", "BST", "SHF", "VIV", "CPA",
    "DAA", "RCL", "SSH", "CEC"],
  "bannedCardNames": [
    "Forest Seal Stone",
    "Chip-Chip Ice Axe",
    "Scoop Up Net"
  ]
}
```
- [ ] `standardLegalSetCodes` and `expandedLegalSetCodes` reflect the current season's legal sets; this file is updated by the developer when rotation occurs (not fetched from network)

### FormatLegalityResolver

- [ ] New file `JustTCG/Domain/Entities/FormatLegalityResolver.swift`
- [ ] Loaded once at app start from the bundled JSON; a singleton value cached in memory
- [ ] `enum Format { case standard, expanded }`
- [ ] `enum CardLegality { case legal, rotated, banned }`

```swift
struct FormatLegalityResolver {
    static let shared: FormatLegalityResolver

    /// Returns the legality of a card in the given format.
    func legality(of card: CachedCard, in format: Format) -> CardLegality

    /// Returns all cards in a deck that are not legal in the given format.
    func violations(in deckCards: [CachedCard], format: Format) -> [LegalityViolation]
}

struct LegalityViolation {
    let card: CachedCard
    let reason: CardLegality   // .rotated or .banned
}
```

**Legality logic:**
- `CardLegality.banned` — card name (case-insensitive) is in `bannedCardNames`
- `CardLegality.rotated` — card's `setCode` is not in the chosen format's legal set codes list (and not banned)
- `CardLegality.legal` — otherwise
- Basic energy cards (supertype `"Energy"`, subtypes contains `"Basic"`) are always `.legal` in both formats regardless of set

### DeckLegalityResult

```swift
struct DeckLegalityResult {
    let format: Format
    let violations: [LegalityViolation]
    var isLegal: Bool { violations.isEmpty }
    var bannedCount: Int { violations.filter { $0.reason == .banned }.count }
    var rotatedCount: Int { violations.filter { $0.reason == .rotated }.count }
}
```

- [ ] `FormatLegalityResolver.checkDeck(cards: [CachedCard], format: Format) -> DeckLegalityResult`

### CachedCard Field

- [ ] `CachedCard` must already have `setCode: String` — if this field is not present, it must be added and populated by the card scraper/seeder
- [ ] If `setCode` is empty or unknown, treat the card as `CardLegality.legal` (fail open to avoid false positives on data gaps)

### Tests

- [ ] `FormatLegalityResolverTests.swift` with:
  - A card whose `setCode` is not in `standardLegalSetCodes` resolves to `.rotated` in `.standard`
  - A card whose name matches `bannedCardNames` (case-insensitive) resolves to `.banned` in both formats
  - A basic energy card always resolves to `.legal`
  - An empty deck returns an empty violations list

## Technical Notes

**Files to create:**
- `JustTCG/CardData/SetLegality.json`
- `JustTCG/Domain/Entities/FormatLegalityResolver.swift`
- `JustTCGTests/FormatLegalityResolverTests.swift`

**Set code source:**
`CachedCard.setCode` is already scraped by `scripts/scrape_cards.py` (the `set.id` field from the Pokémon TCG API). Verify it is present in the current `CachedCard` model; if not, add it in this story (bump seeded key to v9).

**Banned list source:**
The Pokémon TCG official banned list is maintained at `https://www.pokemon.com/us/pokemon-tcg/rules/banned-cards/` — check before shipping and update `SetLegality.json` accordingly.
