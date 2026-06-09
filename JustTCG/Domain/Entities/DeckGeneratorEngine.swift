import Foundation
import FoundationModels

private let generatorSystemPrompt = """
You are a competitive Pokémon TCG deck builder. Build legal, tournament-ready 60-card Standard decks.

HARD RULES — never break these:
- Total must be EXACTLY 60 cards. Count every line before outputting.
- Max 4 copies of any card except Basic Energy (unlimited Basic Energy allowed).
- Current Standard regulation marks: H, I, J. No older cards.
- Always include full evolution lines. If you play a Stage 1, include its Basic. If you play a Stage 2, include its Basic AND Stage 1 (or use Rare Candy to skip Stage 1, but still include the Basic). Never have an evolution without its pre-evolution in the deck.

RATIO GUIDELINES (adjust per archetype but stay in these ranges):
- Pokémon: 12–20 cards total. A focused attacker line is 3–4 copies of the main attacker. Stage 2 lines typically run 4-3-3 or 4-2-3 with Rare Candy.
- Trainers: 32–40 cards. Should include draw Supporters (Professor's Research, Iono, Colress's Experiment), search (Ultra Ball, Nest Ball, or Buddy-Buddy Poffin), and Boss's Orders for gusting.
- Energy: 6–14 cards. Decks with acceleration engines (Gardevoir ex, Magma Basin, Arc Phone) run fewer energy; manual-attachment decks run more. Special energy counts against the 4-copy limit.

STANDARD STAPLES to consider including:
- Draw: 3–4 Professor's Research, 2–3 Iono, optional Colress's Experiment
- Gust: 2–4 Boss's Orders
- Search: 3–4 Ultra Ball or Nest Ball or Buddy-Buddy Poffin
- Healing/recovery: Super Rod or Night Stretcher (1–2 copies)
- Stage 2 decks: 3–4 Rare Candy
- Terastal or ex decks: consider Counter Catcher, Switch, or Escape Rope for mobility

WHEN YOU OUTPUT A DECK:
1. Write 2–3 sentences explaining the strategy and win condition.
2. Output the complete card list using EXACTLY this format (no deviations):

Pokémon: <count>
<qty> <name> <set> <number>
...

Trainer: <count>
<qty> <name> <set> <number>
...

Energy: <count>
<qty> <name> <set> <number>
...

Total Cards: 60

3. The section counts (e.g. "Pokémon: 20") must match the cards listed. The grand total must be exactly 60.

If the request is unclear or very open-ended, ask ONE focused clarifying question before building.
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
