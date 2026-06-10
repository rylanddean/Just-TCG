import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.justtcg.app", category: "DeckLegalityChecker")

/// Outcome of a Standard-legality check.
enum DeckLegalityResult: Equatable {
    /// Every non-basic-energy card was confirmed Standard-legal in the local catalog.
    case legal
    /// No card was positively rejected, but `unknownCount` cards weren't in the
    /// local catalog so legality couldn't be confirmed. Callers should accept
    /// the deck but warn the user to validate manually.
    case uncertain(unknownCount: Int)
    /// Catalog has positive evidence at least one card is not in Standard.
    case rejected(setCode: String, number: String, name: String, reason: String)
}

/// Validates a fetched tournament deck against the current Standard regulation
/// marks (H, I, J). Used by `DeckSourceStrategy` to skip historical decks whose
/// cards have rotated out of Standard.
///
/// The check is intentionally lenient on cards the local catalog doesn't know
/// about: the catalog can lag behind new set releases, while Limitless's
/// tournament data is always legal at the time of play. Rejecting unknown
/// cards would block almost every fresh tournament deck. We only reject when
/// the catalog has *positive* evidence a card is non-Standard.
enum DeckLegalityChecker {

    /// Current Standard regulation marks for the 2025/26 season.
    static let standardMarks: Set<String> = ["H", "I", "J"]

    private static let basicEnergyTypes: Set<String> = [
        "fire", "water", "grass", "lightning", "psychic",
        "darkness", "fighting", "metal", "fairy", "dragon"
    ]

    /// Walks the deck entries, returning the first rejection reason found, or
    /// `.legal` / `.uncertain(N)` depending on whether any card couldn't be
    /// verified against the local catalog.
    static func check(_ deck: LimitlessDeckList, in context: ModelContext) -> DeckLegalityResult {
        var unknownCount = 0
        for entry in deck.entries {
            if isBasicEnergyName(entry.name) { continue }

            let setCode = entry.setCode
            let number = entry.number
            var descriptor = FetchDescriptor<CachedCard>(
                predicate: #Predicate<CachedCard> { $0.setCode == setCode && $0.number == number }
            )
            descriptor.fetchLimit = 1
            guard let card = (try? context.fetch(descriptor))?.first else {
                // Card not in local catalog — can't confirm Standard legality.
                // Don't reject (catalog can lag fresh set releases) but count
                // so the caller can warn the user.
                unknownCount += 1
                continue
            }
            if !card.isStandardLegal {
                return .rejected(setCode: setCode, number: number, name: entry.name,
                                 reason: "isStandardLegal=false in catalog")
            }
            if let mark = card.regulationMark, !standardMarks.contains(mark) {
                return .rejected(setCode: setCode, number: number, name: entry.name,
                                 reason: "regulationMark=\(mark) not in \(standardMarks.sorted())")
            }
        }
        if unknownCount > 0 {
            logger.debug("deck \(deck.listId, privacy: .public) uncertain — \(unknownCount, privacy: .public) cards not in local catalog")
            return .uncertain(unknownCount: unknownCount)
        }
        return .legal
    }

    private static func isBasicEnergyName(_ name: String) -> Bool {
        let lower = name.lowercased()
        guard lower.hasSuffix("energy") else { return false }
        return basicEnergyTypes.contains(where: { lower.contains($0) })
    }
}
