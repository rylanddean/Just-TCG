import Foundation
import Observation

struct MetaShareEntry: Identifiable {
    let id = UUID()
    let archetype: String
    let count: Int
    let share: Double
}

@Observable
final class TournamentDetailViewModel {
    private(set) var detail: LimitlessTournamentDetail? = nil
    private(set) var isLoading = false
    private(set) var error: String? = nil

    var showLimit: Int = 8

    private let client = LimitlessTCGClient()

    var placements: [LimitlessPlacement] {
        detail?.placements ?? []
    }

    var visiblePlacements: [LimitlessPlacement] {
        Array(placements.prefix(showLimit))
    }

    var canShowMore: Bool { showLimit < placements.count }

    func showMore() {
        showLimit = showLimit == 8 ? 32 : placements.count
    }

    var metaShare: [MetaShareEntry] {
        let total = placements.count
        guard total > 0 else { return [] }
        let grouped = Dictionary(grouping: placements, by: \.archetype)
        return grouped
            .map { arch, group in
                MetaShareEntry(
                    archetype: arch,
                    count: group.count,
                    share: Double(group.count) / Double(total) * 100
                )
            }
            .sorted { $0.share > $1.share }
    }

    func load(tournamentId: String) async {
        guard detail == nil else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            detail = try await client.fetchTournamentDetail(id: tournamentId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh(tournamentId: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            detail = try await client.fetchTournamentDetail(id: tournamentId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
