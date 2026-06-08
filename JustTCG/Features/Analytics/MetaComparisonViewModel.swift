import Foundation
import Observation

enum MetaStatus {
    case ready
    case danger
    case practiceNeeded
}

struct MetaComparisonRow: Identifiable {
    let id = UUID()
    let archetype: String
    let metaShare: Double
    let tournamentCount: Int
    let matchupStat: MatchupStat?

    var status: MetaStatus? {
        guard metaShare >= 5 else { return nil }
        guard let stat = matchupStat, stat.sampleSize >= 5 else { return .practiceNeeded }
        if stat.winRate >= 0.50 { return .ready }
        if stat.winRate < 0.40  { return .danger }
        return .practiceNeeded
    }
}

@Observable
final class MetaComparisonViewModel {

    private(set) var rows: [MetaComparisonRow] = []
    private(set) var isLoading = false
    private(set) var hasData = false
    private(set) var error: String? = nil

    private let client = LimitlessTCGClient()
    private let metaEngine = MetaShareEngine()
    private let matchupEngine = MatchupStatsEngine()

    private static let detailCacheDir: URL = {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }()

    // MARK: - Load

    func load(matches: [Match]) async {
        guard !hasData else {
            recompute(matches: matches)
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let details = try await fetchRecentMajorTournamentDetails()
            let metaShares = metaEngine.compute(tournaments: details)
            buildRows(metaShares: metaShares, matches: matches)
            hasData = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func recompute(matches: [Match]) {
        guard hasData else { return }
        let currentMeta = rows.map { ($0.archetype, $0.metaShare, $0.tournamentCount) }
        let matchupStats = matchupEngine.compute(matches: matches)
        let statMap = Dictionary(uniqueKeysWithValues: matchupStats.map {
            ($0.archetype.lowercased().trimmingCharacters(in: .whitespaces), $0)
        })
        rows = currentMeta.map { archetype, share, tourns in
            let key = archetype.lowercased().trimmingCharacters(in: .whitespaces)
            return MetaComparisonRow(
                archetype: archetype,
                metaShare: share,
                tournamentCount: tourns,
                matchupStat: statMap[key]
            )
        }
    }

    func refresh(matches: [Match]) async {
        hasData = false
        await load(matches: matches)
    }

    // MARK: - Build rows

    private func buildRows(metaShares: [MetaShare], matches: [Match]) {
        let matchupStats = matchupEngine.compute(matches: matches)
        let statMap = Dictionary(uniqueKeysWithValues: matchupStats.map {
            ($0.archetype.lowercased().trimmingCharacters(in: .whitespaces), $0)
        })
        rows = metaShares.map { meta in
            let key = meta.archetype.lowercased().trimmingCharacters(in: .whitespaces)
            return MetaComparisonRow(
                archetype: meta.archetype,
                metaShare: meta.sharePercent,
                tournamentCount: meta.tournaments,
                matchupStat: statMap[key]
            )
        }
    }

    // MARK: - Tournament fetching (last 5 Regionals or higher)

    private func fetchRecentMajorTournamentDetails() async throws -> [LimitlessTournamentDetail] {
        let tournaments = try await client.fetchRecentTournaments(limit: 50)
        let majors = tournaments
            .filter { $0.tier == .regional || $0.tier == .ic || $0.tier == .worlds }
            .prefix(5)

        return try await withThrowingTaskGroup(of: LimitlessTournamentDetail.self) { group in
            for tournament in majors {
                group.addTask {
                    if let cached = self.loadDetailFromDisk(id: tournament.id) { return cached }
                    let detail = try await self.client.fetchTournamentDetail(id: tournament.id)
                    self.saveDetailToDisk(detail)
                    return detail
                }
            }
            var results: [LimitlessTournamentDetail] = []
            for try await detail in group { results.append(detail) }
            return results
        }
    }

    // MARK: - Disk cache for tournament details

    private func detailCacheURL(id: String) -> URL {
        Self.detailCacheDir.appendingPathComponent("tournament_detail_v2_\(id).json")
    }

    private func loadDetailFromDisk(id: String) -> LimitlessTournamentDetail? {
        guard let data = try? Data(contentsOf: detailCacheURL(id: id)) else { return nil }
        return try? JSONDecoder().decode(LimitlessTournamentDetail.self, from: data)
    }

    private func saveDetailToDisk(_ detail: LimitlessTournamentDetail) {
        let url = detailCacheURL(id: detail.id)
        if let data = try? JSONEncoder().encode(detail) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
