# M23-02 — Rules Q&A Engine

**Status:** done  
**Milestone:** M23 — Rules Assistant  
**Dependencies:** M23-01

## User Story

As a developer, I need a rules query engine backed by the on-device Foundation Models framework that answers Pokémon TCG rules questions grounded strictly in the bundled rulebook, so the app can give quick, accurate answers without a network call.

## Acceptance Criteria

- [x] A new `@Observable` class `RulesQueryEngine` is created at `JustTCG/Domain/Entities/RulesQueryEngine.swift`
- [x] The engine uses `FoundationModels.LanguageModelSession` (iOS 26+, `import FoundationModels`)
- [x] The session is initialised with a system prompt that:
  - Establishes the model as a Pokémon TCG rules expert
  - Injects the full rulebook text via `RulebookLoader.fullText()`
  - Instructs the model to answer only from the provided rules text, say "I don't know" if a topic isn't covered, and keep answers concise (2–4 sentences)
- [x] `func ask(_ question: String) async throws -> String` sends the question to the session and returns the response string
- [x] The engine maintains conversation history so follow-up questions work in context (e.g., "Does that apply to GX Pokémon too?")
- [x] `func reset()` clears the conversation and starts a fresh session
- [x] If `LanguageModelSession` is unavailable (simulator, unsupported device), the engine returns a fallback string: `"Rules Assistant requires Apple Intelligence (iPhone 16 or later with iOS 26+)."`
- [x] The engine is availability-gated with `@available(iOS 26, *)`; call sites check availability before presenting the UI

## Technical Notes

**New file:** `JustTCG/Domain/Entities/RulesQueryEngine.swift`

**Availability guard pattern:**
```swift
@available(iOS 26, *)
@Observable
final class RulesQueryEngine {
    private var session: LanguageModelSession?

    init() {
        let rules = RulebookLoader.fullText()
        let systemPrompt = """
        You are a Pokémon TCG rules expert. Answer questions using only the official rules provided below. \
        Keep answers to 2–4 sentences. If the answer is not in the rules, say so.

        --- RULES ---
        \(rules)
        """
        session = LanguageModelSession(instructions: systemPrompt)
    }

    func ask(_ question: String) async throws -> String {
        guard let session else { return "Rules Assistant is unavailable." }
        let response = try await session.respond(to: question)
        return response.content
    }

    func reset() {
        let rules = RulebookLoader.fullText()
        // Re-initialise with the same system prompt
        session = LanguageModelSession(instructions: /* same prompt */ "...")
    }
}
```

**Fallback (pre-iOS 26):**
```swift
struct RulesQueryEngineFallback {
    func ask(_ question: String) async -> String {
        "Rules Assistant requires Apple Intelligence (iPhone 16 or later running iOS 26 or later)."
    }
}
```

> **Note:** `FoundationModels` is part of the iOS 26 SDK (Xcode 17+). The deployment target for this feature should remain iOS 17+ for the rest of the app; only the `RulesQueryEngine` class is gated with `@available(iOS 26, *)`.
