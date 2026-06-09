import Foundation
import FoundationModels
import SwiftData

// MARK: - Request / Response Models

struct TechAdvisorRequest {
    let deck: [DeckCardEntry]
    let worstMatchups: [MatchupSummary]
    let metaShare: [ArchetypeShare]
    let availableCards: [String]
}

struct MatchupSummary {
    let archetypeName: String
    let winRate: Double
    let gamesPlayed: Int
}

struct TechSuggestion: Identifiable {
    let id: UUID
    let cardName: String
    let reasoning: String
    let targetMatchups: [String]
    let suggestedCount: Int
}

enum TechAdvisorError: LocalizedError {
    case modelUnavailable
    case insufficientData
    case parseFailure(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "AI tech suggestions require Apple Intelligence (iOS 26 or later)."
        case .insufficientData:
            return "Log at least 5 matches with this deck to get tech suggestions."
        case .parseFailure(let detail):
            return "Could not parse suggestions: \(detail)"
        }
    }
}

// MARK: - Engine

@available(iOS 26, *)
@Observable
final class TechAdvisorEngine {

    private(set) var isGenerating = false
    private(set) var lastError: TechAdvisorError? = nil

    func buildRequest(deck: Deck, context: ModelContext, trendSnapshots: [WeekSnapshot]) -> TechAdvisorRequest? {
        let totalCards = deck.cards.reduce(0) { $0 + $1.quantity }
        guard totalCards >= 20, deck.matches.count >= 5 else { return nil }

        let deckEntries: [DeckCardEntry] = deck.cards.compactMap { deckCard in
            let cardId = deckCard.cardId
            let cached = try? context.fetch(
                FetchDescriptor<CachedCard>(predicate: #Predicate { $0.id == cardId })
            ).first
            let name = cached?.name ?? deckCard.cardId
            return DeckCardEntry(name: name, copies: deckCard.quantity)
        }

        let statsEngine = MatchupStatsEngine()
        let allStats = statsEngine.compute(matches: deck.matches)
        let worstMatchups: [MatchupSummary] = allStats
            .filter { $0.confidence == .sufficient }
            .sorted { $0.winRate < $1.winRate }
            .prefix(5)
            .map { MatchupSummary(archetypeName: $0.archetype, winRate: $0.winRate, gamesPlayed: $0.sampleSize) }

        let metaShare: [ArchetypeShare] = Array(
            (trendSnapshots.last?.archetypeShares ?? [])
                .sorted { $0.sharePercent > $1.sharePercent }
                .prefix(8)
        )

        let allCards = (try? context.fetch(FetchDescriptor<CachedCard>())) ?? []
        let availableCards = allCards.map { $0.name }

        return TechAdvisorRequest(
            deck: deckEntries,
            worstMatchups: worstMatchups,
            metaShare: metaShare,
            availableCards: availableCards
        )
    }

    func suggestTech(for request: TechAdvisorRequest) async throws -> [TechSuggestion] {
        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        do {
            let systemPrompt = buildSystemPrompt(for: request)
            let session = LanguageModelSession(instructions: systemPrompt)
            let response = try await session.respond(to: "Suggest 3–5 tech cards for the deck described above. Reply with a valid JSON array only.")

            let extractSession = LanguageModelSession()
            let extracted = try await extractSession.respond(
                to: "Extract the JSON array from the following response and return only the raw JSON, no markdown:\n\(response.content)"
            )

            guard let data = extracted.content.data(using: .utf8),
                  let raw = try? JSONDecoder().decode([RawTechSuggestion].self, from: data) else {
                let err = TechAdvisorError.parseFailure(extracted.content)
                lastError = err
                throw err
            }

            return raw.map {
                TechSuggestion(
                    id: UUID(),
                    cardName: $0.cardName,
                    reasoning: $0.reasoning,
                    targetMatchups: $0.targetMatchups,
                    suggestedCount: max(1, min(2, $0.suggestedCount))
                )
            }
        } catch let error as TechAdvisorError {
            lastError = error
            throw error
        } catch {
            let wrapped = TechAdvisorError.parseFailure(error.localizedDescription)
            lastError = wrapped
            throw wrapped
        }
    }

    // MARK: - Private

    private func buildSystemPrompt(for request: TechAdvisorRequest) -> String {
        let deckLines = request.deck.map { "  \($0.copies)x \($0.name)" }.joined(separator: "\n")

        let matchupLines = request.worstMatchups.isEmpty
            ? "  No matchup data available."
            : request.worstMatchups
                .map { "  \($0.archetypeName): \(Int($0.winRate * 100))% win rate (\($0.gamesPlayed) games)" }
                .joined(separator: "\n")

        let metaLines = request.metaShare.isEmpty
            ? "  No meta data available."
            : request.metaShare
                .map { "  \($0.archetypeName): \(String(format: "%.1f", $0.sharePercent))%" }
                .joined(separator: "\n")

        return """
        You are an expert Pokémon TCG deck advisor helping a competitive player improve their deck for the current Standard format.

        Current deck:
        \(deckLines)

        Worst matchups (win rate):
        \(matchupLines)

        Current meta share:
        \(metaLines)

        Suggest 3–5 specific tech card options (cards not already in the deck at 4 copies) that would improve performance against the weakest matchups. For each card, explain in 1–2 sentences why it helps and against which archetypes. Respond with a valid JSON array matching this schema exactly: [{\"cardName\": string, \"reasoning\": string, \"targetMatchups\": [string], \"suggestedCount\": number}]
        """
    }
}

// MARK: - Codable intermediate

private struct RawTechSuggestion: Codable {
    let cardName: String
    let reasoning: String
    let targetMatchups: [String]
    let suggestedCount: Int
}

// MARK: - Fallback

struct TechAdvisorEngineFallback {
    func suggestTech(for request: TechAdvisorRequest) async -> Result<[TechSuggestion], TechAdvisorError> {
        .failure(.modelUnavailable)
    }
}
