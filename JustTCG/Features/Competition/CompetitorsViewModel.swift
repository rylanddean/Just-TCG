import Foundation
import Observation

@Observable
final class CompetitorsViewModel {
    private let sortBy: PlayerRankSort = .points
    var zone: PlayerZone = .global

    private(set) var leaderboard: [LimitlessPlayerSearchResult] = []
    private(set) var isLoadingLeaderboard = false

    private(set) var searchResults: [LimitlessPlayerSearchResult] = []
    private(set) var isSearching = false
    private(set) var searchError: String? = nil
    private(set) var hasSearched = false

    private let client = LimitlessTCGClient()

    func loadLeaderboard() async {
        isLoadingLeaderboard = true
        leaderboard = (try? await client.fetchPlayerLeaderboard(rank: sortBy, zone: zone)) ?? []
        isLoadingLeaderboard = false
    }

    func search(query: String) async {
        isSearching = true
        searchError = nil
        do {
            searchResults = try await client.searchPlayers(query: query)
        } catch {
            searchError = error.localizedDescription
            searchResults = []
        }
        isSearching = false
        hasSearched = true
    }

    func cancelSearch() {
        searchResults = []
        isSearching = false
        searchError = nil
        hasSearched = false
    }
}
