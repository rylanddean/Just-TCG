import Foundation
import Observation

@Observable
final class TournamentListViewModel {

    private(set) var tournaments: [LimitlessTournament] = []
    private(set) var isLoading = false
    private(set) var error: String? = nil
    private(set) var lastFetchDate: Date? = nil

    var selectedTier: TournamentTier? = nil

    var filtered: [LimitlessTournament] {
        guard let tier = selectedTier else { return tournaments }
        return tournaments.filter { $0.tier == tier }
    }

    // MARK: - Private

    private let client = LimitlessTCGClient()
    private static let cacheURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("tournaments.json")
    }()
    private static let cacheTTL: TimeInterval = 3600 // 1 hour

    // MARK: - Load / refresh

    func loadIfNeeded() async {
        if let last = lastFetchDate, Date().timeIntervalSince(last) < Self.cacheTTL {
            return
        }
        if tournaments.isEmpty { loadFromDisk() }
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    // MARK: - Fetch

    private func fetch() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let results = try await client.fetchRecentTournaments(limit: 50)
            tournaments = results
            lastFetchDate = Date()
            saveToDisk(results)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Disk cache

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: Self.cacheURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let cached = try? decoder.decode([LimitlessTournament].self, from: data) {
            tournaments = cached
        }
    }

    private func saveToDisk(_ list: [LimitlessTournament]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(list) {
            try? data.write(to: Self.cacheURL, options: .atomic)
        }
    }
}
