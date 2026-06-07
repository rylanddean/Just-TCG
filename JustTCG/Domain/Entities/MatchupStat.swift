import Foundation

enum MatchupConfidence {
    case sufficient
    case insufficient
}

enum MatchupTag {
    case favourable
    case unfavourable
    case even
    case insufficientData
}

struct MatchupStat {
    let archetype: String
    let wins: Int
    let losses: Int
    let ties: Int

    var sampleSize: Int { wins + losses + ties }

    var winRate: Double {
        guard sampleSize > 0 else { return 0 }
        return Double(wins) / Double(sampleSize)
    }

    var confidence: MatchupConfidence {
        sampleSize >= 5 ? .sufficient : .insufficient
    }

    var tag: MatchupTag {
        guard confidence == .sufficient else { return .insufficientData }
        if winRate >= 0.60 { return .favourable }
        if winRate <= 0.40 { return .unfavourable }
        return .even
    }
}
