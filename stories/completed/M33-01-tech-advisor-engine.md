# M33-01 — Tech Card Advisor Engine

**Status:** done  
**Milestone:** M33 — Tech Card Advisor  
**Dependencies:** M24-01 (DeckGeneratorEngine / FoundationModels pattern), M4-01 (matchup stats), M6-01 (meta share)

## User Story

As a competitive player, I want the app to suggest tech cards that would improve my worst matchups so I can fine-tune my deck list for the current meta without spending hours researching every option.

## Acceptance Criteria

### TechAdvisorEngine

- [ ] New file `JustTCG/Domain/Entities/TechAdvisorEngine.swift`
- [ ] `@Observable` class; follows the same `FoundationModels` session pattern as `DeckGeneratorEngine`

**Input model:**
```swift
struct TechAdvisorRequest {
    let deck: [DeckCardEntry]           // current deck list (name + count)
    let worstMatchups: [MatchupSummary] // up to 5 weakest matchups by win rate
    let metaShare: [ArchetypeShare]     // current meta share (top 8 archetypes)
    let availableCards: [String]        // card names in the local card database
}

struct MatchupSummary {
    let archetypeName: String
    let winRate: Double        // 0.0–1.0
    let gamesPlayed: Int
}
```

**Output model:**
```swift
struct TechSuggestion: Identifiable {
    let id: UUID
    let cardName: String
    let reasoning: String        // 1–2 sentence explanation
    let targetMatchups: [String] // which matchups this helps
    let suggestedCount: Int      // 1–2
}
```

**Core method:**
```swift
func suggestTech(for request: TechAdvisorRequest) async throws -> [TechSuggestion]
```

**FoundationModels prompt strategy:**
- Uses `LanguageModelSession` with a structured system prompt that describes:
  1. The player's current deck list
  2. Their worst matchups (archetype name + win rate)
  3. The current meta share
  4. The instruction to suggest 3–5 single-card tech options that address those matchups
- Parses the response into `[TechSuggestion]` via a `Codable` JSON extraction step (same two-pass approach used in `DeckGeneratorEngine`)
- If the model is unavailable (device doesn't support FoundationModels), throws `TechAdvisorError.modelUnavailable`

**System prompt template:**
```
You are an expert Pokémon TCG deck advisor helping a competitive player improve their deck for the current Standard format.

Current deck:
<deck list>

Worst matchups (win rate):
<matchup list>

Current meta share:
<meta share>

Suggest 3–5 specific tech card options (cards not already in the deck at 4 copies) that would improve performance against the weakest matchups. For each card, explain in 1–2 sentences why it helps and against which archetypes. Respond with valid JSON array matching this schema: [{cardName, reasoning, targetMatchups, suggestedCount}]
```

**Data assembly:**
- [ ] `TechAdvisorEngine.buildRequest(deckID: UUID, context: ModelContext) async -> TechAdvisorRequest?`
  - Fetches deck cards from SwiftData
  - Fetches matchup stats from `MatchupStatsEngine` (reuse existing)
  - Fetches meta share from `MetaShareEngine` (reuse existing)
  - Returns `nil` if deck has < 20 cards or < 5 matches logged

**Error cases:**
```swift
enum TechAdvisorError: LocalizedError {
    case modelUnavailable      // FoundationModels not supported on this device
    case insufficientData      // fewer than 5 matches logged
    case parseFailure(String)  // model responded but JSON didn't parse
}
```

- [ ] `isGenerating: Bool` published for the UI to observe
- [ ] `lastError: TechAdvisorError?` published

## Technical Notes

**Files to create:**
- `JustTCG/Domain/Entities/TechAdvisorEngine.swift`

**FoundationModels availability:**
Wrap all `LanguageModelSession` usage in `if #available(iOS 26, *)` — show a graceful unavailable state on older iOS (same guard used in `DeckGeneratorEngine` and `RulesQueryEngine`).

**JSON extraction pass:**
After the model returns free text, run a second prompt: `"Extract the JSON array from the following response and return only the raw JSON, no markdown: \(response)"` — this matches the two-pass approach in `DeckGeneratorEngine` that has already proven reliable.

**Environment injection:**
Add `TechAdvisorEngine` to the environment in `JustTCGApp.swift`.
