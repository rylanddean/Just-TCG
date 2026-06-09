import Foundation
import FoundationModels

private func makeRulesSystemPrompt() -> String {
    let rules = RulebookLoader.fullText()
    return """
    You are a Pokémon TCG rules expert. Answer questions using only the official rules provided below. \
    Keep answers to 2–4 sentences. If the answer is not covered in the rules, say so directly. \
    Do not speculate beyond the provided text.

    --- RULES ---
    \(rules)
    """
}

@available(iOS 26, *)
@Observable
final class RulesQueryEngine {
    private var session: LanguageModelSession

    init() {
        session = LanguageModelSession(instructions: makeRulesSystemPrompt())
    }

    func ask(_ question: String) async throws -> String {
        let response = try await session.respond(to: question)
        return response.content
    }

    func reset() {
        session = LanguageModelSession(instructions: makeRulesSystemPrompt())
    }
}

struct RulesQueryEngineFallback {
    func ask(_ question: String) async -> String {
        "Rules Assistant requires Apple Intelligence (iPhone 16 or later running iOS 26 or later)."
    }
}
