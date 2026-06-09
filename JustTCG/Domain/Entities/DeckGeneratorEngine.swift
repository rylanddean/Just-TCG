import Foundation
import FoundationModels

private let generatorSystemPrompt = """
You are a competitive Pokémon TCG deck builder. When asked to build a deck:
1. Briefly explain the strategy (2–3 sentences).
2. Output the full 60-card list in PTCGL export format, for example: "4 Charizard ex OBF 125".
3. Confirm the total is exactly 60 cards.

Current Standard regulation marks: H, I, J.
Max 4 copies of any card except Basic Energy (unlimited copies allowed).
If the request is unclear, ask ONE clarifying question before building.
"""

@available(iOS 26, *)
@Observable
final class DeckGeneratorEngine {
    private var session: LanguageModelSession

    init() {
        session = LanguageModelSession(instructions: generatorSystemPrompt)
    }

    func generate(prompt: String) async throws -> DeckGeneratorResponse {
        let response = try await session.respond(to: prompt)
        return makeResponse(from: response.content)
    }

    func refine(prompt: String) async throws -> DeckGeneratorResponse {
        let response = try await session.respond(to: prompt)
        return makeResponse(from: response.content)
    }

    func reset() {
        session = LanguageModelSession(instructions: generatorSystemPrompt)
    }

    private func makeResponse(from text: String) -> DeckGeneratorResponse {
        let deckList = DeckListExtractor.extract(from: text)
        let isFollowUp = deckList == nil && text.trimmingCharacters(in: .whitespaces).hasSuffix("?")
        return DeckGeneratorResponse(message: text, deckList: deckList, isFollowUpQuestion: isFollowUp)
    }
}

struct DeckGeneratorEngineFallback {
    func generate(prompt: String) async -> DeckGeneratorResponse {
        fallbackResponse
    }

    func refine(prompt: String) async -> DeckGeneratorResponse {
        fallbackResponse
    }

    private var fallbackResponse: DeckGeneratorResponse {
        DeckGeneratorResponse(
            message: "Deck Generator requires Apple Intelligence (iPhone 16 or later running iOS 26 or later).",
            deckList: nil,
            isFollowUpQuestion: false
        )
    }
}
