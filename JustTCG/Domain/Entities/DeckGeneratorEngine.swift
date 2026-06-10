import Foundation
import FoundationModels
import OSLog

private let logger = Logger(subsystem: "com.justtcg.app", category: "DeckGenerator")

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
// We deliberately keep these slim — the on-device model has a small context
// window (~4k tokens), and bloated system instructions both slow generation
// and leave less room for the actual output.

// Phase 1 — Pokémon line only. Minimal rules; output is just card lines.
private let phase1SystemPrompt = """
You are a competitive Pokémon TCG deck builder. Choose the Pokémon line for a Standard deck (regulation marks H, I, or J only).
Rules:
- 12–20 Pokémon total.
- Main attacker: 3–4 copies.
- Include full evolution lines (Stage 1 needs Basic; Stage 2 needs Basic + Stage 1; Rare Candy skips Stage 1 but Basic is still required).
- Max 4 copies per card name.
"""

// Phase 2 — Trainer package.
private let phase2SystemPrompt = """
You are helping build a competitive Pokémon TCG Standard deck (regulation marks H, I, or J only).
Choose a Trainer package to support the given Pokémon line:
- 32–40 Trainers total.
- Include draw (Professor's Research 3–4, Iono 2–3), gust (Boss's Orders 2–4), search (Ultra Ball / Nest Ball / Buddy-Buddy Poffin 3–4), recovery (Night Stretcher / Super Rod 1–2).
- Max 4 copies per card name.
"""

// Phase 3 — Finalize. Format-only system prompt; selection is done.
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

// Repair — applied if Phase 3 output fails validation.
private let repairSystemPrompt = """
You are fixing a Pokémon TCG Standard deck list (regulation marks H, I, or J only). Apply ONLY the corrections requested. Output the corrected deck in the format:

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

// Refine — for follow-up tweaks after a deck is generated.
private let refineSystemPrompt = """
You are a competitive Pokémon TCG deck builder. The user wants to tweak an existing 60-card Standard deck. Apply their requested change while keeping the deck legal:
- Exactly 60 cards total.
- Max 4 copies per card name.
- Standard only: regulation marks H, I, or J.
- Output the full updated deck in the required format.

Output format:
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

// MARK: - Prompt builders

private func buildPhase1Prompt(userPrompt: String, pokemonCatalog: String?) -> String {
    var parts: [String] = []
    parts.append(userPrompt)
    if let catalog = pokemonCatalog, !catalog.isEmpty {
        parts.append("""

        Standard-legal Pokémon available in our card database (prefer these — use the exact set code and number shown):
        \(catalog)
        """)
    }
    parts.append("""

    Step 1 of 3 — Pokémon only. Output ONLY a plain list of Pokémon cards, one per line: qty name setCode number (example: 4 Gardevoir ex PRE 51). No Trainers. No Energy. No headers. No commentary.
    """)
    return parts.joined()
}

private func buildPhase2Prompt(pokemonList: String) -> String {
    """
    Pokémon line already selected:
    \(pokemonList)

    Step 2 of 3 — Trainers only. Output ONLY a plain list of 32–40 Trainer cards, one per line: qty name setCode number (example: 4 Iono PAL 185). No Energy. No headers. No commentary.
    """
}

private func buildPhase3Prompt(pokemonList: String, trainerList: String) -> String {
    """
    Cards already selected for this deck:

    Pokémon:
    \(pokemonList)

    Trainers:
    \(trainerList)

    Step 3 of 3 — Add Energy cards and output the complete deck in the required format. Count Pokémon + Trainers above, then add enough Energy to reach exactly 60 total cards.
    """
}

private func buildRepairPrompt(deck: String, violations: [DeckGeneratorViolation]) -> String {
    let bullets = violations.map { "- \($0.description)" }.joined(separator: "\n")
    return """
    Current deck:
    \(deck)

    Problems to fix:
    \(bullets)

    Output the corrected 60-card deck in the required format.
    """
}

private func buildRefinePrompt(deck: String, change: String) -> String {
    """
    Current deck:
    \(deck)

    Requested change:
    \(change)

    Output the full updated deck in the required format.
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

    // Per-phase token caps. The on-device model is small; capping per phase
    // avoids runaway generations that read as timeouts to the user.
    private let phase1Tokens = 400  // ~20 lines of Pokémon
    private let phase2Tokens = 700  // ~40 lines of Trainers
    private let phase3Tokens = 1200 // Full formatted deck + strategy sentence
    private let repairTokens = 1200
    private let refineTokens = 1200

    init() {
        refineSession = LanguageModelSession(instructions: refineSystemPrompt)
    }

    /// Optional Pokémon-candidate snippet to inject into Phase 1 (filtered from local catalog).
    /// When supplied, the model is steered toward set codes that exist in our database,
    /// reducing import-lookup misses caused by hallucinated set/number pairs.
    func generate(prompt: String, pokemonCatalog: String? = nil) -> AsyncThrowingStream<DeckGeneratorResponse, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let start = Date()
                logger.info("generate start — promptLen=\(prompt.count, privacy: .public) catalogLines=\(pokemonCatalog?.components(separatedBy: "\n").count ?? 0, privacy: .public)")
                do {
                    // Phase 1 — Pokémon line
                    let p1Start = Date()
                    let session1 = LanguageModelSession(instructions: phase1SystemPrompt)
                    let phase1Prompt = buildPhase1Prompt(userPrompt: prompt, pokemonCatalog: pokemonCatalog)
                    logger.debug("phase1 prompt bytes=\(phase1Prompt.count, privacy: .public)")
                    let p1 = try await self.respondWithRetry(session1, phase1Prompt, maxTokens: self.phase1Tokens, phase: "phase1")
                    let p1Lines = extractCardLines(p1)
                    logger.info("phase1 done in \(Self.ms(p1Start), privacy: .public)ms cardLines=\(p1Lines.components(separatedBy: "\n").filter { !$0.isEmpty }.count, privacy: .public) rawLen=\(p1.count, privacy: .public)")
                    continuation.yield(DeckGeneratorResponse(message: p1, deckList: nil, isFollowUpQuestion: false, isIntermediate: true))

                    // Phase 2 — Trainer package
                    let p2Start = Date()
                    let session2 = LanguageModelSession(instructions: phase2SystemPrompt)
                    let p2 = try await self.respondWithRetry(session2, buildPhase2Prompt(pokemonList: p1Lines), maxTokens: self.phase2Tokens, phase: "phase2")
                    let p2Lines = extractCardLines(p2)
                    logger.info("phase2 done in \(Self.ms(p2Start), privacy: .public)ms cardLines=\(p2Lines.components(separatedBy: "\n").filter { !$0.isEmpty }.count, privacy: .public) rawLen=\(p2.count, privacy: .public)")
                    continuation.yield(DeckGeneratorResponse(message: p2, deckList: nil, isFollowUpQuestion: false, isIntermediate: true))

                    // Phase 3 — Finalize
                    let p3Start = Date()
                    let session3 = LanguageModelSession(instructions: phase3SystemPrompt)
                    let p3 = try await self.respondWithRetry(session3, buildPhase3Prompt(pokemonList: p1Lines, trainerList: p2Lines), maxTokens: self.phase3Tokens, phase: "phase3")
                    logger.info("phase3 done in \(Self.ms(p3Start), privacy: .public)ms rawLen=\(p3.count, privacy: .public)")

                    let final = self.makeResponse(from: p3)

                    // Validate-and-repair. If Phase 3 produced something parseable but
                    // illegal, try one focused repair round-trip before giving up.
                    let repaired = try await self.maybeRepair(initial: final, originalRaw: p3)

                    if let deck = repaired.deckList {
                        self.lastDeck = deck
                        self.refineSession = Self.makeRefineSession(from: deck)
                        logger.info("generate success in \(Self.ms(start), privacy: .public)ms deckLen=\(deck.count, privacy: .public)")
                    } else {
                        logger.error("generate produced no parseable deck — raw len=\(p3.count, privacy: .public)")
                    }

                    continuation.yield(repaired)
                    continuation.finish()
                } catch {
                    logger.error("generate failed in \(Self.ms(start), privacy: .public)ms error=\(String(describing: error), privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func refine(prompt: String) async throws -> DeckGeneratorResponse {
        let start = Date()
        logger.info("refine start — promptLen=\(prompt.count, privacy: .public) hasDeck=\(self.lastDeck != nil, privacy: .public)")
        do {
            let userPrompt = lastDeck.map { buildRefinePrompt(deck: $0, change: prompt) } ?? prompt
            let text = try await respondWithRetry(refineSession, userPrompt, maxTokens: refineTokens, phase: "refine")
            let response = makeResponse(from: text)
            let repaired = try await maybeRepair(initial: response, originalRaw: text)
            if let deck = repaired.deckList {
                lastDeck = deck
                refineSession = Self.makeRefineSession(from: deck)
            }
            logger.info("refine done in \(Self.ms(start), privacy: .public)ms hasDeck=\(repaired.deckList != nil, privacy: .public)")
            return repaired
        } catch let error as DeckGeneratorError {
            if case .contextTooLong = error, lastDeck != nil {
                // Refine instructions are already slim — context overflow most likely
                // means the cumulative user-prompt history grew large. Reset the
                // session and try once more with the deck injected into the user prompt.
                logger.notice("refine context overflow — resetting session and retrying")
                refineSession = LanguageModelSession(instructions: refineSystemPrompt)
                let userPrompt = lastDeck.map { buildRefinePrompt(deck: $0, change: prompt) } ?? prompt
                let text = try await respondWithRetry(refineSession, userPrompt, maxTokens: refineTokens, phase: "refine-retry")
                let response = makeResponse(from: text)
                if let newDeck = response.deckList {
                    lastDeck = newDeck
                    refineSession = Self.makeRefineSession(from: newDeck)
                }
                logger.info("refine recovered in \(Self.ms(start), privacy: .public)ms")
                return response
            }
            throw error
        }
    }

    func reset() {
        logger.info("reset")
        lastDeck = nil
        refineSession = LanguageModelSession(instructions: refineSystemPrompt)
    }

    // MARK: - Validation-and-repair

    private func maybeRepair(initial: DeckGeneratorResponse, originalRaw: String) async throws -> DeckGeneratorResponse {
        guard let deck = initial.deckList else {
            logger.notice("repair skipped — no parseable deck to repair")
            return initial
        }
        let violations = DeckGeneratorValidator.validate(deck)
        if violations.isEmpty {
            logger.debug("validation passed — no repair needed")
            return initial
        }
        let summary = violations.map { $0.description }.joined(separator: "; ")
        logger.notice("validation failed — repairing: \(summary, privacy: .public)")

        let repairStart = Date()
        let session = LanguageModelSession(instructions: repairSystemPrompt)
        let repairPrompt = buildRepairPrompt(deck: deck, violations: violations)
        do {
            let repaired = try await respondWithRetry(session, repairPrompt, maxTokens: repairTokens, phase: "repair")
            let response = makeResponse(from: repaired)
            let postViolations = response.deckList.map { DeckGeneratorValidator.validate($0) } ?? []
            logger.info("repair done in \(Self.ms(repairStart), privacy: .public)ms postViolations=\(postViolations.count, privacy: .public)")
            // Only return the repaired version if it's actually parseable; otherwise
            // fall back to the original so the user still sees something useful.
            return response.deckList != nil ? response : initial
        } catch {
            logger.error("repair failed — returning original. error=\(String(describing: error), privacy: .public)")
            return initial
        }
    }

    // MARK: - Session helpers

    private static func makeRefineSession(from deck: String) -> LanguageModelSession {
        // Keep instructions slim — the deck itself is injected per-turn in the
        // user prompt rather than baked into instructions, which would otherwise
        // double the system-prompt size on every refine.
        LanguageModelSession(instructions: refineSystemPrompt)
    }

    private func respondWithRetry(_ session: LanguageModelSession, _ prompt: String, maxTokens: Int, phase: String, maxAttempts: Int = 3) async throws -> String {
        var attempt = 0
        while true {
            attempt += 1
            do {
                let options = GenerationOptions(maximumResponseTokens: maxTokens)
                return try await session.respond(to: prompt, options: options).content
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .rateLimited, .concurrentRequests:
                    logger.notice("\(phase, privacy: .public) rateLimited attempt=\(attempt, privacy: .public)")
                    if attempt >= maxAttempts { throw DeckGeneratorError.rateLimited }
                    try await Task.sleep(for: .seconds(Double(attempt) * 3))
                default:
                    logger.error("\(phase, privacy: .public) GenerationError: \(String(describing: error), privacy: .public)")
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

    private static func ms(_ start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}

