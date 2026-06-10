import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.justtcg.app", category: "DeckGeneratorCatalog")

/// Builds a constrained Pokémon-candidate snippet from the local card catalog,
/// filtered by keywords extracted from the user's prompt.
///
/// The on-device model otherwise invents card names and set codes from training
/// data, which then fail import lookup. Injecting a real, scoped list of cards
/// gives it a known-good pool to choose from.
enum DeckGeneratorCatalog {

    /// Words too common to use for filtering (would match every card).
    private static let stopwords: Set<String> = [
        "build", "make", "create", "deck", "with", "that", "the", "and", "for", "from",
        "using", "use", "give", "want", "need", "good", "competitive", "fast", "best",
        "something", "around", "based", "tcg", "pokemon", "pokémon", "standard",
        "card", "cards", "trainer", "energy", "attack", "attacker", "this", "more",
        "include", "any", "all", "what", "show", "help", "please", "ex", "vmax", "vstar"
    ]

    /// Extracts archetype keywords from a free-form prompt. Returns lowercased
    /// tokens of length ≥ 3 not in the stopword list.
    static func keywords(from prompt: String) -> [String] {
        let normalized = prompt
            .lowercased()
            .replacingOccurrences(of: "'s", with: "")
            .replacingOccurrences(of: "'", with: "")
        let tokens = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        return tokens.filter { token in
            guard token.count >= 3, !stopwords.contains(token), seen.insert(token).inserted else {
                return false
            }
            return true
        }
    }

    /// Returns the top N matching Pokémon candidates (most-recent print per name,
    /// ordered by release date desc). Used by `DeckSourceStrategy` to look up
    /// tournament decks before falling back to AI generation.
    static func archetypeCandidates(for prompt: String, in context: ModelContext, limit: Int = 5) -> [CachedCard] {
        let keys = keywords(from: prompt)
        guard !keys.isEmpty else { return [] }

        let descriptor = FetchDescriptor<CachedCard>(
            predicate: #Predicate<CachedCard> {
                $0.supertype == "Pokémon" && $0.isStandardLegal == true
            }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        let matches = all.filter { card in
            let lname = card.name.lowercased()
            return keys.contains(where: { lname.contains($0) })
        }
        guard !matches.isEmpty else { return [] }

        // Deduplicate by name keeping the most-recent print.
        var byName: [String: CachedCard] = [:]
        for card in matches {
            let key = card.name.lowercased()
            if let existing = byName[key] {
                let existingDate = existing.setReleaseDate ?? .distantPast
                let candidateDate = card.setReleaseDate ?? .distantPast
                if candidateDate > existingDate {
                    byName[key] = card
                }
            } else {
                byName[key] = card
            }
        }

        // Prefer "ex" / "VMAX" / "VSTAR" prints (competitively dominant) and
        // newer releases. Within each tier, newer dates win.
        let competitiveMarkers = ["ex", "vmax", "vstar", "gx", "v "]
        let sorted = byName.values.sorted { lhs, rhs in
            let lhsCompetitive = competitiveMarkers.contains(where: { lhs.name.lowercased().contains($0) })
            let rhsCompetitive = competitiveMarkers.contains(where: { rhs.name.lowercased().contains($0) })
            if lhsCompetitive != rhsCompetitive { return lhsCompetitive && !rhsCompetitive }
            let lhsDate = lhs.setReleaseDate ?? .distantPast
            let rhsDate = rhs.setReleaseDate ?? .distantPast
            return lhsDate > rhsDate
        }
        return Array(sorted.prefix(limit))
    }

    /// Selects Pokémon cards whose names match any extracted keyword. Picks the
    /// most-recent print per unique card name to keep the list compact.
    /// Returns nil if there's no match (the engine will fall back to free choice).
    static func candidatePokemon(for prompt: String, in context: ModelContext, limit: Int = 50) -> String? {
        let keys = keywords(from: prompt)
        guard !keys.isEmpty else {
            logger.debug("no usable keywords in prompt")
            return nil
        }

        let descriptor = FetchDescriptor<CachedCard>(
            predicate: #Predicate<CachedCard> {
                $0.supertype == "Pokémon" && $0.isStandardLegal == true
            }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        if all.isEmpty {
            logger.notice("catalog empty — Pokémon supertype yielded zero cards")
            return nil
        }

        let matches = all.filter { card in
            let lname = card.name.lowercased()
            return keys.contains(where: { lname.contains($0) })
        }
        if matches.isEmpty {
            logger.info("no catalog matches for keywords: \(keys.joined(separator: ","), privacy: .public)")
            return nil
        }

        // Pick most-recent print per unique name to keep the list short.
        var byName: [String: CachedCard] = [:]
        for card in matches {
            let key = card.name.lowercased()
            if let existing = byName[key] {
                let existingDate = existing.setReleaseDate ?? .distantPast
                let candidateDate = card.setReleaseDate ?? .distantPast
                if candidateDate > existingDate {
                    byName[key] = card
                }
            } else {
                byName[key] = card
            }
        }

        let sorted = byName.values.sorted { lhs, rhs in
            let lhsDate = lhs.setReleaseDate ?? .distantPast
            let rhsDate = rhs.setReleaseDate ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.name < rhs.name
        }
        let trimmed = Array(sorted.prefix(limit))
        let lines = trimmed.map { "\($0.name) \($0.setCode) \($0.number)" }
        logger.info("catalog snippet built — keywords=\(keys.count, privacy: .public) candidates=\(lines.count, privacy: .public)")
        return lines.joined(separator: "\n")
    }
}
