import Foundation

enum RecommendationType {
    case dangerMatchup
    case practiceGap
    case allClear
}

struct Recommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let archetype: String
    let metaShare: Double
    let winRate: Double?
    let sampleSize: Int

    var message: String {
        switch type {
        case .dangerMatchup:
            let wl = winRateFraction
            return "You're \(wl) vs \(archetype) (top meta deck)"
        case .practiceGap:
            let games = sampleSize == 0 ? "0 logged games" : "\(sampleSize) game\(sampleSize == 1 ? "" : "s")"
            return "You have \(games) vs \(archetype) (\(String(format: "%.1f", metaShare))% of meta)"
        case .allClear:
            return "You're well-prepared — no major gaps detected"
        }
    }

    private var winRateFraction: String {
        guard let wr = winRate, sampleSize > 0 else { return "—" }
        let wins   = Int((wr * Double(sampleSize)).rounded())
        let losses = sampleSize - wins
        return "\(wins)W–\(losses)L"
    }
}

struct PracticeGapEngine {

    func recommendations(
        meta: [MetaShare],
        stats: [MatchupStat],
        limit: Int = 3
    ) -> [Recommendation] {
        let statMap = Dictionary(uniqueKeysWithValues: stats.map {
            ($0.archetype.lowercased().trimmingCharacters(in: .whitespaces), $0)
        })

        var results: [Recommendation] = []

        for share in meta where share.sharePercent >= 5 {
            let key = share.archetype.lowercased().trimmingCharacters(in: .whitespaces)
            let stat = statMap[key]
            let sampleSize = stat?.sampleSize ?? 0

            if let s = stat, s.sampleSize >= 5, s.winRate <= 0.40 {
                results.append(Recommendation(
                    type: .dangerMatchup,
                    archetype: share.archetype,
                    metaShare: share.sharePercent,
                    winRate: s.winRate,
                    sampleSize: s.sampleSize
                ))
            } else if sampleSize < 5 {
                results.append(Recommendation(
                    type: .practiceGap,
                    archetype: share.archetype,
                    metaShare: share.sharePercent,
                    winRate: stat.map(\.winRate),
                    sampleSize: sampleSize
                ))
            }
        }

        // Danger matchups first, then practice gaps; within each group sort by meta share desc.
        results.sort {
            if $0.type == .dangerMatchup && $1.type != .dangerMatchup { return true }
            if $0.type != .dangerMatchup && $1.type == .dangerMatchup { return false }
            return $0.metaShare > $1.metaShare
        }

        if results.isEmpty {
            return [Recommendation(
                type: .allClear,
                archetype: "",
                metaShare: 0,
                winRate: nil,
                sampleSize: 0
            )]
        }

        return Array(results.prefix(limit))
    }
}
