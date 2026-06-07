import Foundation

struct MetaShare {
    let archetype: String
    let sharePercent: Double
    let tournaments: Int
}

struct MetaShareEngine {

    func compute(tournaments: [LimitlessTournamentDetail]) -> [MetaShare] {
        guard !tournaments.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        var tournamentHits: [String: Set<String>] = [:]
        var totalPlayers = 0

        for detail in tournaments {
            for placement in detail.placements {
                let key = placement.archetype.trimmingCharacters(in: .whitespaces).lowercased()
                counts[key, default: 0] += 1
                tournamentHits[key, default: []].insert(detail.id)
                totalPlayers += 1
            }
        }

        guard totalPlayers > 0 else { return [] }

        return counts
            .map { key, count in
                let canonical = canonicalName(key, in: tournaments)
                return MetaShare(
                    archetype: canonical,
                    sharePercent: Double(count) / Double(totalPlayers) * 100,
                    tournaments: tournamentHits[key]?.count ?? 0
                )
            }
            .sorted { $0.sharePercent > $1.sharePercent }
    }

    func topArchetypes(limit: Int, tournaments: [LimitlessTournamentDetail]) -> [MetaShare] {
        Array(compute(tournaments: tournaments).prefix(limit))
    }

    // MARK: - Private

    // Recover original capitalisation from the first matching placement.
    private func canonicalName(_ normalised: String, in tournaments: [LimitlessTournamentDetail]) -> String {
        for detail in tournaments {
            for placement in detail.placements {
                if placement.archetype.trimmingCharacters(in: .whitespaces).lowercased() == normalised {
                    return placement.archetype.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return normalised
    }
}
