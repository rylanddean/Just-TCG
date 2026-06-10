import Foundation
import Observation
import SwiftData

@Observable
final class FeaturedDeckWidgetViewModel {

    private(set) var snapshot: FeaturedDeckSnapshot? = nil
    private(set) var primaryCards: [CachedCard] = []
    private(set) var isLoading = false
    private(set) var error: String? = nil

    private let client = LimitlessTCGClient()

    private static let cacheURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("featured_deck_today.json")
    }()

    // MARK: - Public API

    func load(modelContext: ModelContext) async {
        if let existing = snapshot, !existing.isStale() { return }
        if let cached = loadFromDisk(), !cached.isStale() {
            snapshot = cached
            primaryCards = resolveCards(names: cached.primaryCardNames, modelContext: modelContext)
            return
        }
        await fetch(modelContext: modelContext)
    }

    func refresh(modelContext: ModelContext) async {
        clearDiskCache()
        snapshot = nil
        primaryCards = []
        await fetch(modelContext: modelContext)
    }

    // MARK: - Private

    private func fetch(modelContext: ModelContext) async {
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
            primaryCards = resolveCards(names: picked.primaryCardNames, modelContext: modelContext)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func resolveCards(names: [String], modelContext: ModelContext) -> [CachedCard] {
        var result: [CachedCard] = []
        var seen = Set<String>()
        let resolver = ArchetypePrimaryCardResolver()
        for name in names {
            let primary = name
                .split(separator: "/", maxSplits: 1)
                .first
                .map { $0.trimmingCharacters(in: .whitespaces) }
                ?? name
            guard !primary.isEmpty else { continue }
            var descriptor = FetchDescriptor<CachedCard>(predicate: #Predicate { card in
                card.supertype == "Pokémon" && card.name.localizedStandardContains(primary)
            })
            descriptor.fetchLimit = 20
            let candidates = (try? modelContext.fetch(descriptor)) ?? []
            if let card = resolver.resolve(archetype: name, from: candidates), !seen.contains(card.id) {
                seen.insert(card.id)
                result.append(card)
            }
        }
        return result
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
