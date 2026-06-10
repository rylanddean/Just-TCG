import Foundation
import OSLog

private let logger = Logger(subsystem: "com.justtcg.app", category: "DeckSourceStrategy")

/// Result of a successful tournament-deck lookup.
struct DeckSourceResult {
    /// PTCGL-formatted 60-card deck text.
    let deckList: String
    /// Display label, e.g. "Charizard Pidgeot by Nathan Hollar — Daytona Regional".
    let label: String
    /// Local catalog card used to seed the lookup (for analytics / debugging).
    let sourceCardId: String
    /// True when the legality check passed but some cards weren't in the local
    /// catalog. UI should warn the user to validate Standard legality manually.
    let hasUnknownCards: Bool
}

/// Tries to satisfy a deck-generation request by fetching a real tournament
/// deck off limitlesstcg.com before falling back to on-device AI generation.
///
/// Closure-based dependencies make the strategy testable without hitting the
/// network — tests inject canned `fetchDecklists` / `fetchDeck` closures.
struct DeckSourceStrategy {
    var fetchDecklists: (_ setCode: String, _ number: String) async throws -> [LimitlessPlacement]
    var fetchDeck: (_ listId: String) async throws -> LimitlessDeckList

    /// Live strategy backed by `LimitlessTCGClient`.
    static let live = DeckSourceStrategy(
        fetchDecklists: { setCode, number in
            try await LimitlessTCGClient().fetchCardDecklists(setCode: setCode, number: number)
        },
        fetchDeck: { listId in
            try await LimitlessTCGClient().fetchDeckList(listId: listId)
        }
    )

    /// Maximum tournament placements to try per candidate Pokémon. Older or
    /// off-rotation decks are skipped via the `isStandardLegal` predicate; this
    /// cap bounds how many we'll fetch before moving to the next candidate.
    private static let maxPlacementsPerCandidate = 5

    /// Walks the candidate Pokémon in order, fetching tournament decklists and
    /// trying up to N placements each. Prefers a fully-legal deck but accepts
    /// an `.uncertain` one (with `hasUnknownCards == true`) as fallback so a
    /// stale local catalog doesn't block all tournament lookups.
    /// Returns nil only if every candidate's placements were positively
    /// rejected or failed to fetch.
    ///
    /// - Parameter checkLegality: closure evaluated against each fetched deck.
    ///   Defaults to always-legal for tests; production passes a closure that
    ///   resolves against the SwiftData catalog.
    func lookup(
        candidates: [CachedCard],
        checkLegality: @escaping (LimitlessDeckList) -> DeckLegalityResult = { _ in .legal }
    ) async -> DeckSourceResult? {
        let start = Date()
        logger.info("lookup start — candidates=\(candidates.count, privacy: .public)")
        guard !candidates.isEmpty else {
            logger.info("lookup miss — no catalog candidates for prompt")
            return nil
        }

        // Across all candidates, remember the first uncertain hit so we can
        // return it if no fully-legal deck is found.
        var uncertainFallback: DeckSourceResult? = nil

        for card in candidates {
            do {
                let placements = try await fetchDecklists(card.setCode, card.number)
                let withLists = placements.filter { $0.hasDeckList }
                logger.debug("candidate \(card.name, privacy: .public) \(card.setCode, privacy: .public) \(card.number, privacy: .public) — placements=\(placements.count, privacy: .public) withLists=\(withLists.count, privacy: .public)")

                for placement in withLists.prefix(Self.maxPlacementsPerCandidate) {
                    guard let listId = placement.deckListId else { continue }
                    do {
                        let deck = try await fetchDeck(listId)
                        let total = deck.entries.reduce(0) { $0 + $1.quantity }
                        guard total >= 55 && total <= 65 else {
                            logger.notice("rejecting deck \(listId, privacy: .public) — total=\(total, privacy: .public) out of range")
                            continue
                        }

                        switch checkLegality(deck) {
                        case .legal:
                            let result = Self.makeResult(deck: deck, placement: placement, card: card, hasUnknownCards: false)
                            logger.info("lookup hit (legal) in \(Self.ms(start), privacy: .public)ms — card=\(card.name, privacy: .public) listId=\(listId, privacy: .public)")
                            return result
                        case .uncertain(let count):
                            if uncertainFallback == nil {
                                uncertainFallback = Self.makeResult(deck: deck, placement: placement, card: card, hasUnknownCards: true)
                                logger.notice("uncertain fallback set — listId=\(listId, privacy: .public) unknownCards=\(count, privacy: .public)")
                            }
                            continue
                        case .rejected(let setCode, let number, let name, let reason):
                            logger.notice("rejecting deck \(listId, privacy: .public) — \(name, privacy: .public) \(setCode, privacy: .public) \(number, privacy: .public): \(reason, privacy: .public)")
                            continue
                        }
                    } catch {
                        logger.notice("deck fetch \(listId, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                        continue
                    }
                }
            } catch {
                logger.notice("candidate \(card.name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                continue
            }
        }

        if let fallback = uncertainFallback {
            logger.info("lookup hit (uncertain) in \(Self.ms(start), privacy: .public)ms — \(fallback.label, privacy: .public)")
            return fallback
        }

        logger.info("lookup miss in \(Self.ms(start), privacy: .public)ms — no candidate yielded a usable deck")
        return nil
    }

    private static func makeResult(deck: LimitlessDeckList, placement: LimitlessPlacement, card: CachedCard, hasUnknownCards: Bool) -> DeckSourceResult {
        DeckSourceResult(
            deckList: LimitlessDeckFormatter.toPTCGL(deck),
            label: makeLabel(placement: placement, archetype: card.name),
            sourceCardId: card.id,
            hasUnknownCards: hasUnknownCards
        )
    }

    private static func makeLabel(placement: LimitlessPlacement, archetype: String) -> String {
        let player = placement.playerName.trimmingCharacters(in: .whitespaces)
        let arch = placement.archetype.trimmingCharacters(in: .whitespaces)
        let archetypeText = arch.isEmpty ? archetype : arch
        if let tournament = placement.tournamentName?.trimmingCharacters(in: .whitespaces), !tournament.isEmpty {
            return "\(archetypeText) by \(player) — \(tournament)"
        }
        return "\(archetypeText) by \(player)"
    }

    private static func ms(_ start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}
