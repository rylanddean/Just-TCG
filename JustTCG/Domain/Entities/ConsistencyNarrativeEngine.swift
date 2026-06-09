import Foundation
import FoundationModels

@available(iOS 26, *)
struct ConsistencyNarrativeEngine {

    func generate(for breakdown: ConsistencyBreakdown, deckName: String) async throws -> String {
        let session = LanguageModelSession(
            instructions: "You are an expert Pokémon TCG deck analyst. Write concise, insightful consistency analysis for competitive players."
        )
        let response = try await session.respond(to: buildPrompt(for: breakdown, deckName: deckName))
        return response.content
    }

    private func buildPrompt(for bd: ConsistencyBreakdown, deckName: String) -> String {
        """
        Write a single paragraph (3–5 sentences) analysing the consistency of the Pokémon TCG deck "\(deckName)".

        Consistency data:
        - Overall score: \(bd.consistencyScore)/100
        - Draw engine copies: \(bd.drawCount)
        - Search engine copies: \(bd.searchCount)
        - Pokémon ability impact score: \(bd.abilityImpactScore)/100 (weighted score across all ability roles: draw, search, energy accel, disruption, etc.)
        - Energy setup score: \(bd.energyScore)/100 (\(bd.energyAccelCount) acceleration cards, \(bd.energyCardCount) energy cards total)

        Describe what this deck does well for consistency, where it is fragile or inconsistent, and give one concrete recommendation. Write in second person. No bullet points. No markdown.
        """
    }
}
