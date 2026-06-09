# M24-01 — Natural Language Deck Generation Engine

**Status:** done  
**Milestone:** M24 — Natural Language Deck Generator  
**Dependencies:** M23-02

## User Story

As a developer, I need a deck generation engine that takes a natural language prompt (e.g. "build me a Charizard ex deck that's good for beginners") and produces a valid 60-card Standard-legal deck list, with support for follow-up refinement messages.

## Acceptance Criteria

### `DeckGeneratorEngine`
- [x] New `@Observable` class at `JustTCG/Domain/Entities/DeckGeneratorEngine.swift`
- [x] Uses `FoundationModels.LanguageModelSession` (iOS 26+) gated with `@available(iOS 26, *)`
- [x] System prompt instructs the model to:
  - Generate exactly 60-card Standard-legal Pokémon TCG deck lists
  - Always respond with a brief explanation followed by the deck list in PTCGL export format
  - Ask one clarifying follow-up question when the request is ambiguous (e.g. "Would you prefer a more aggressive or control-oriented build?")
  - Stick to regulation marks H, I, J (current Standard)
  - Respect the 4-copy limit (unlimited for Basic Energy)
- [x] `func generate(prompt: String) async throws -> DeckGeneratorResponse` submits the user prompt and parses the response
- [x] `func refine(prompt: String) async throws -> DeckGeneratorResponse` continues the existing conversation for follow-up messages
- [x] `func reset()` clears conversation history
- [x] Conversation history is maintained across `generate` / `refine` calls within the same session

### `DeckGeneratorResponse`
- [x] New struct at `JustTCG/Domain/Entities/DeckGeneratorResponse.swift`:
  ```swift
  struct DeckGeneratorResponse {
      let message: String           // The model's full text response (explanation + list)
      let deckList: String?         // Extracted PTCGL-format deck list block, if present
      let isFollowUpQuestion: Bool  // true when the model responded with a clarifying question
  }
  ```
- [x] `deckList` is extracted by detecting the presence of lines matching the PTCGL format pattern (`^\d+ .+$`) in the model's response
- [x] `isFollowUpQuestion` is `true` when `deckList == nil` and the response ends with a `?`

### Deck List Extraction
- [x] A `DeckListExtractor.extract(from: String) -> String?` helper (can be a private method or a small struct) scans the model response for a contiguous block of PTCGL-format lines and returns them as a single string
- [x] The extracted string is compatible with the existing `DeckListParser` (M10-01) so it can be imported directly

### Fallback (pre-iOS 26)
- [x] A non-`@available`-gated `DeckGeneratorEngineFallback` struct exposes the same `generate` / `refine` signatures and returns a fixed `DeckGeneratorResponse` explaining that Apple Intelligence is required

## Technical Notes

**New files:**
- `JustTCG/Domain/Entities/DeckGeneratorEngine.swift`
- `JustTCG/Domain/Entities/DeckGeneratorResponse.swift`

**System prompt excerpt:**
```
You are a competitive Pokémon TCG deck builder. When asked to build a deck:
1. Briefly explain the strategy (2–3 sentences).
2. Output the full 60-card list in PTCGL export format (e.g. "4 Charizard ex OBF 125").
3. Confirm the total is exactly 60 cards.

Current Standard regulation marks: H, I, J.
Max 4 copies of any card except Basic Energy (unlimited).
If the request is unclear, ask ONE clarifying question before building.
```

**PTCGL format detection regex:**
```swift
let linePattern = /^\d{1,3} .+$/
```
Use `lines.filter { $0.wholeMatch(of: linePattern) != nil }` to identify the deck block.
