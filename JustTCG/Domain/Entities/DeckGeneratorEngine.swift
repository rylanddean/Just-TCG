import Foundation
import FoundationModels

// MARK: - User-facing errors

enum DeckGeneratorError: LocalizedError {
    case rateLimited
    case assetsUnavailable
    case contentRefused
    case contextTooLong
    case generic

    var errorDescription: String? {
        switch self {
        case .rateLimited:
            return "Apple Intelligence is busy. Please wait a moment and try again."
        case .assetsUnavailable:
            return "Apple Intelligence isn't ready yet. Open Settings › Apple Intelligence & Siri and wait for setup to finish."
        case .contentRefused:
            return "The request was blocked by a content filter. Try rephrasing your deck idea."
        case .contextTooLong:
            return "The generation produced too much content. Please try again."
        case .generic:
            return "Something went wrong. Please try again."
        }
    }
}

@available(iOS 26, *)
private extension DeckGeneratorError {
    static func from(_ error: LanguageModelSession.GenerationError) -> DeckGeneratorError {
        switch error {
        case .rateLimited, .concurrentRequests:
            return .rateLimited
        case .assetsUnavailable:
            return .assetsUnavailable
        case .guardrailViolation, .refusal:
            return .contentRefused
        case .exceededContextWindowSize:
            return .contextTooLong
        case .unsupportedLanguageOrLocale, .unsupportedGuide, .decodingFailure:
            return .generic
        @unknown default:
            return .generic
        }
    }
}

// MARK: - System prompts
//
// Each phase gets its own fresh session with a purpose-scoped system prompt.
// Phase 1 gets the full rule set. Phases 2 and 3 get only what they need,
// which keeps each session's total token budget well within the model's window.

// Full rules — used for Phase 1 (cold start) and refinements.
private let generatorSystemPrompt = """
You are a competitive Pokémon TCG deck builder. Build legal, tournament-ready 60-card Standard decks.

HARD RULES:
- Exactly 60 cards total.
- Max 4 copies per card name across all sets. Basic Energy is unlimited.
- Standard only: regulation marks H, I, or J. Never use older marks.
- Full evolution lines always: Stage 1 requires its Basic; Stage 2 requires Basic + Stage 1 (Rare Candy skips Stage 1 but the Basic is still required).

RATIOS:
- Pokémon 12–20: main attacker 3–4 copies; Stage 2 lines 4-3-3 or 4-2-3 + Rare Candy.
- Trainers 32–40: Professor's Research 3-4, Iono 2-3, Boss's Orders 2-4, search (Ultra Ball/Nest Ball/Buddy-Buddy Poffin) 3-4, recovery (Night Stretcher/Super Rod) 1-2.
- Energy 6–14: fewer with acceleration engines, more for manual attachment.

OUTPUT FORMAT:
[One sentence: strategy and win condition.]

Pokémon: N
qty name setCode number
...

Trainer: N
qty name setCode number
...

Energy: N
qty name setCode number
...

Total Cards: 60

Section counts must match listed cards. Grand total must be exactly 60.
If the request is unclear, ask ONE focused clarifying question.
"""

// Minimal — Phase 2 only needs to pick Trainers; no need for full rules in every token.
private let phase2SystemPrompt = """
You are helping build a competitive Pokémon TCG Standard deck (regulation marks H, I, or J only). \
Choose a Trainer package to support the given Pokémon line.
"""

// Minimal — Phase 3 only needs the output format; card selection is already done.
private let phase3SystemPrompt = """
Complete and format a 60-card Pokémon TCG Standard deck list (regulation marks H, I, or J only).

Output format — use exactly this:
[One sentence: strategy and win condition.]

Pokémon: N
qty name setCode number
...

Trainer: N
qty name setCode number
...

Energy: N
qty name setCode number
...

Total Cards: 60
"""

private let phase1Suffix = """


Step 1 of 3 — Pokémon only. \
Output ONLY a plain list of Pokémon cards, one per line: qty name setCode number \
(example: 4 Gardevoir ex PRE 51). No Trainers. No Energy. No headers. No commentary.
"""

private func buildPhase2Prompt(pokemonList: String) -> String {
    """
    Pokémon line already selected:
    \(pokemonList)

    Step 2 of 3 — Trainers only. \
    Output ONLY a plain list of 32–40 Trainer cards, one per line: qty name setCode number \
    (example: 4 Iono PAL 185). No Energy. No headers. No commentary.
    """
}

private func buildPhase3Prompt(pokemonList: String, trainerList: String) -> String {
    """
    Cards already selected for this deck:

    Pokémon:
    \(pokemonList)

    Trainers:
    \(trainerList)

    Step 3 of 3 — Add Energy cards and output the complete deck in the required format. \
    Count Pokémon + Trainers above, then add enough Energy to reach exactly 60 total cards.
    """
}

// Strips commentary from an intermediate phase response, keeping only valid card lines
// (4+ tokens, first token is a number). Keeps the injected context small and clean.
private func extractCardLines(_ text: String) -> String {
    text.components(separatedBy: "\n").filter { line in
        let tokens = line.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return tokens.count >= 4 && Int(tokens[0]) != nil
    }.joined(separator: "\n")
}

// MARK: - Engine

@available(iOS 26, *)
@Observable
final class DeckGeneratorEngine {
    private var refineSession: LanguageModelSession
    private var lastDeck: String?

    init() {
        refineSession = LanguageModelSession(instructions: generatorSystemPrompt)
    }

    func generate(prompt: String) -> AsyncThrowingStream<DeckGeneratorResponse, Error> {
        // Each phase gets its own fresh session so no history accumulates across phases.
        // Phases 2 and 3 also use leaner system prompts — only the full rules are needed
        // for Phase 1. Results from earlier phases are injected explicitly into the next
        // prompt rather than carried in session history.
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Phase 1 — Pokémon line (full rules, cold start)
                    let session1 = LanguageModelSession(instructions: generatorSystemPrompt)
                    let p1 = try await self.respondWithRetry(session1, prompt + phase1Suffix)
                    continuation.yield(DeckGeneratorResponse(message: p1, deckList: nil, isFollowUpQuestion: false, isIntermediate: true))

                    // Phase 2 — Trainer package (minimal system prompt + Phase 1 card lines injected)
                    let session2 = LanguageModelSession(instructions: phase2SystemPrompt)
                    let p2 = try await self.respondWithRetry(session2, buildPhase2Prompt(pokemonList: extractCardLines(p1)))
                    continuation.yield(DeckGeneratorResponse(message: p2, deckList: nil, isFollowUpQuestion: false, isIntermediate: true))

                    // Phase 3 — Finalize (format-only system prompt + Phases 1 & 2 injected)
                    let session3 = LanguageModelSession(instructions: phase3SystemPrompt)
                    let p3 = try await self.respondWithRetry(session3, buildPhase3Prompt(
                        pokemonList: extractCardLines(p1),
                        trainerList: extractCardLines(p2)
                    ))
                    let final = self.makeResponse(from: p3)

                    if let deck = final.deckList {
                        self.lastDeck = deck
                        self.refineSession = Self.makeRefineSession(from: deck)
                    }

                    continuation.yield(final)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func refine(prompt: String) async throws -> DeckGeneratorResponse {
        do {
            let text = try await respondWithRetry(refineSession, prompt)
            let response = makeResponse(from: text)
            if let deck = response.deckList {
                lastDeck = deck
                refineSession = Self.makeRefineSession(from: deck)
            }
            return response
        } catch let error as DeckGeneratorError {
            if case .contextTooLong = error, let deck = lastDeck {
                refineSession = Self.makeRefineSession(from: deck)
                let text = try await respondWithRetry(refineSession, prompt)
                let response = makeResponse(from: text)
                if let newDeck = response.deckList {
                    lastDeck = newDeck
                    refineSession = Self.makeRefineSession(from: newDeck)
                }
                return response
            }
            throw error
        }
    }

    func reset() {
        lastDeck = nil
        refineSession = LanguageModelSession(instructions: generatorSystemPrompt)
    }

    private static func makeRefineSession(from deck: String) -> LanguageModelSession {
        LanguageModelSession(
            instructions: generatorSystemPrompt + "\n\nThe deck you are currently working with:\n\n" + deck
        )
    }

    private func respondWithRetry(_ session: LanguageModelSession, _ prompt: String, maxAttempts: Int = 3) async throws -> String {
        var attempt = 0
        while true {
            attempt += 1
            do {
                return try await session.respond(to: prompt).content
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .rateLimited, .concurrentRequests:
                    if attempt >= maxAttempts { throw DeckGeneratorError.rateLimited }
                    try await Task.sleep(for: .seconds(Double(attempt) * 3))
                default:
                    throw DeckGeneratorError.from(error)
                }
            }
        }
    }

    private func makeResponse(from text: String) -> DeckGeneratorResponse {
        let deckList = DeckListExtractor.extract(from: text)
        let isFollowUp = deckList == nil && text.trimmingCharacters(in: .whitespaces).hasSuffix("?")
        return DeckGeneratorResponse(message: text, deckList: deckList, isFollowUpQuestion: isFollowUp)
    }
}

// MARK: - Fallback

struct DeckGeneratorEngineFallback {
    func generate(prompt: String) -> AsyncThrowingStream<DeckGeneratorResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(fallbackResponse)
            continuation.finish()
        }
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
