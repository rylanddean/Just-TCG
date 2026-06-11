import Foundation
import Observation

@Observable
final class FeaturedDeckWidgetViewModel {

    private(set) var snapshot: FeaturedDeckSnapshot? = nil
    private(set) var isLoading = false
    private(set) var error: String? = nil

    private let client = LimitlessTCGClient()

    private static let cacheURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("featured_deck_today.json")
    }()

    // MARK: - Public API

    func load() async {
        if let existing = snapshot, !existing.isStale() { return }
        if let cached = loadFromDisk(), !cached.isStale() {
            snapshot = cached
            return
        }
        await fetch()
    }

    func refresh() async {
        clearDiskCache()
        snapshot = nil
        await fetch()
    }

    // MARK: - Private

    private func fetch() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let tournaments = try await client.fetchRecentTournaments(limit: 5)

            var candidates: [FeaturedDeckCandidate] = []
            await withTaskGroup(of: [FeaturedDeckCandidate].self) { group in
                for tournament in tournaments {
                    group.addTask {
                        guard let detail = try? await self.client.fetchTournamentDetail(id: tournament.id),
                              !detail.placements.isEmpty else { return [] }
                        return detail.placements
                            .filter { $0.rank <= 8 }
                            .map { FeaturedDeckCandidate(tournament: tournament, placement: $0) }
                    }
                }
                for await batch in group {
                    candidates.append(contentsOf: batch)
                }
            }

            guard let picked = FeaturedDeckEngine.pick(from: candidates) else {
                error = "No top-8 placements found in recent tournaments."
                return
            }

            saveToDisk(picked)
            snapshot = picked
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Disk cache

    private func loadFromDisk() -> FeaturedDeckSnapshot? {
        guard let data = try? Data(contentsOf: Self.cacheURL) else { return nil }
        return try? JSONDecoder().decode(FeaturedDeckSnapshot.self, from: data)
    }

    private func saveToDisk(_ value: FeaturedDeckSnapshot) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: Self.cacheURL, options: .atomic)
    }

    private func clearDiskCache() {
        try? FileManager.default.removeItem(at: Self.cacheURL)
    }
}
