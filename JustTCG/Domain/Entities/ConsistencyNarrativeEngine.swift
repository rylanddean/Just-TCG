import Foundation
import FoundationModels

@available(iOS 26, *)
struct ConsistencyNarrativeEngine {

    func generate(for breakdown: ConsistencyBreakdown, deckName: String, deckEntries: [DeckCardEntry]) async throws -> String {
        let session = LanguageModelSession(
            instructions: "You are an expert Pokémon TCG deck analyst. Write concise, insightful consistency analysis for competitive players."
        )
        let response = try await session.respond(to: buildPrompt(for: breakdown, deckName: deckName, deckEntries: deckEntries))
        return response.content
    }

    private func buildPrompt(for bd: ConsistencyBreakdown, deckName: String, deckEntries: [DeckCardEntry]) -> String {
        let pokemon = deckEntries.filter { $0.supertype == "Pokémon" }
            .sorted { $0.copies > $1.copies }
            .map { "\($0.copies)x \($0.name)" }
            .joined(separator: ", ")
        let trainers = deckEntries.filter { $0.supertype == "Trainer" }
            .sorted { $0.copies > $1.copies }
            .map { "\($0.copies)x \($0.name)" }
            .joined(separator: ", ")
        let energy = deckEntries.filter { $0.supertype == "Energy" }
            .sorted { $0.copies > $1.copies }
            .map { "\($0.copies)x \($0.name)" }
            .joined(separator: ", ")

        return """
        Write a single paragraph (3–5 sentences) analysing the consistency of the Pokémon TCG deck "\(deckName)".

        Deck list:
        Pokémon: \(pokemon.isEmpty ? "none" : pokemon)
        Trainers: \(trainers.isEmpty ? "none" : trainers)
        Energy: \(energy.isEmpty ? "none" : energy)

        Consistency scores:
        - Overall: \(bd.consistencyScore)/100
        - Draw engine copies: \(bd.drawCount)
        - Search engine copies: \(bd.searchCount)
        - Ability impact: \(bd.abilityImpactScore)/100
        - Energy setup: \(bd.energyScore)/100 (\(bd.energyAccelCount) acceleration cards, \(bd.energyCardCount) energy cards\(bd.identifiedAttackerCopies > 0 ? ", \(bd.identifiedAttackerCopies) attacker copies identified" : ""))

        Only reference cards that appear in the deck list above. Describe what the deck does well for consistency, where it is fragile, and give one concrete recommendation. Write in second person. No bullet points. No markdown.
        """
    }
}
