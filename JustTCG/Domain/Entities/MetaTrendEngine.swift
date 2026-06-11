import Foundation
import Observation

// MARK: - Models

struct WeekSnapshot: Identifiable, Codable {
    let id: UUID
    let weekLabel: String
    let date: Date
    let archetypeShares: [ArchetypeShare]
}

struct ArchetypeShare: Identifiable, Codable {
    let id: UUID
    let archetypeName: String
    let sharePercent: Double
}

struct ArchetypeTrend: Identifiable {
    let id: UUID
    let archetypeName: String
    let averageShare: Double
    let recentShare: Double
    let trend: Double
    let weeklyShares: [Double]
}

// MARK: - Engine

@Observable
final class MetaTrendEngine {

    private(set) var snapshots: [WeekSnapshot] = []
    private(set) var isLoading = false
    private(set) var loadError: Error? = nil

    private let client: LimitlessTCGClient
    private let cacheURL: URL
    private static let cacheTTL: TimeInterval = 6 * 3600
    private static let shareEngine = MetaShareEngine()
    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }()

    init(
        client: LimitlessTCGClient = LimitlessTCGClient(),
        cacheDirectory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    ) {
        self.client = client
        self.cacheURL = cacheDirectory.appendingPathComponent("meta_trends.json")
    }

    // MARK: - Public API

    func loadTrends(weekCount: Int = 13, forceRefresh: Bool = false) async throws {
        if !forceRefresh, !snapshots.isEmpty, !isCacheStale() { return }
        if snapshots.isEmpty, let cached = loadFromDisk() { snapshots = cached }
        if !forceRefresh, !snapshots.isEmpty, !isCacheStale() { return }

        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let tournaments = try await client.fetchRecentTournaments(limit: weekCount * 3)
            let standardOnly = tournaments.filter { $0.format.lowercased().contains("standard") }
            let toFetch = Array(standardOnly.prefix(weekCount * 2))

            // Fetch details concurrently; keep only those with placements
            var details: [(detail: LimitlessTournamentDetail, date: Date)] = []
            await withTaskGroup(of: (LimitlessTournamentDetail, Date)?.self) { group in
                for t in toFetch {
                    group.addTask {
                        guard let d = try? await self.client.fetchTournamentDetail(id: t.id),
                              !d.placements.isEmpty else { return nil }
                        return (d, t.date)
                    }
                }
                for await result in group {
                    if let r = result { details.append(r) }
                }
            }

            // Sort newest first, take at most weekCount
            let sorted = details
                .sorted { $0.date > $1.date }
                .prefix(weekCount)

            // Group by ISO year+week to handle year boundaries
            var buckets: [Int: [(detail: LimitlessTournamentDetail, date: Date)]] = [:]
            for item in sorted {
                let week = Self.calendar.component(.weekOfYear, from: item.date)
                let year = Self.calendar.component(.yearForWeekOfYear, from: item.date)
                buckets[year * 100 + week, default: []].append(item)
            }

            // Build a snapshot per bucket, sorting by date to derive week label
            var result: [WeekSnapshot] = []
            for (_, items) in buckets {
                let earliestDate = items.map(\.date).sorted().first!
                let merged = items.map(\.detail)
                let shares = computeShares(for: merged)
                result.append(WeekSnapshot(
                    id: UUID(),
                    weekLabel: Self.weekLabel(for: earliestDate),
                    date: earliestDate,
                    archetypeShares: shares
                ))
            }

            // Sort oldest → newest
            let labelToDate: [String: Date] = {
                var d: [String: Date] = [:]
                for item in sorted {
                    let label = Self.weekLabel(for: item.date)
                    if d[label] == nil { d[label] = item.date }
                }
                return d
            }()
            snapshots = result.sorted {
                (labelToDate[$0.weekLabel] ?? .distantPast) < (labelToDate[$1.weekLabel] ?? .distantPast)
            }
            saveToDisk(snapshots)
        } catch {
            loadError = error
            throw error
        }
    }

    private static let blockedArchetypes: Set<String> = ["regidrago"]

    /// Returns snapshots within the given day window, falling back to all snapshots
    /// if the window contains fewer than 2 entries.
    func snapshots(for dayWindow: Int) -> [WeekSnapshot] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -dayWindow, to: Date()) ?? .distantPast
        let filtered = snapshots.filter { $0.date >= cutoff }
        return filtered.count >= 2 ? filtered : snapshots
    }

    func topArchetypes(n: Int, dayWindow: Int = 90) -> [ArchetypeTrend] {
        let windowedSnapshots = snapshots(for: dayWindow)
        guard !windowedSnapshots.isEmpty else { return [] }

        var allNames: Set<String> = []
        for snap in windowedSnapshots {
            for share in snap.archetypeShares { allNames.insert(share.archetypeName) }
        }

        return allNames
            .filter { !Self.blockedArchetypes.contains($0.lowercased()) }
            .map { name -> ArchetypeTrend in
                let weekly = windowedSnapshots.map { snap in
                    snap.archetypeShares.first { $0.archetypeName == name }?.sharePercent ?? 0
                }
                let average = weekly.reduce(0, +) / Double(weekly.count)
                let recent  = weekly.last  ?? 0
                let oldest  = weekly.first ?? 0
                return ArchetypeTrend(
                    id: UUID(),
                    archetypeName: name,
                    averageShare: average,
                    recentShare: recent,
                    trend: recent - oldest,
                    weeklyShares: weekly
                )
            }
            .sorted { $0.averageShare > $1.averageShare }
            .prefix(n)
            .map { $0 }
    }

    // MARK: - Private helpers

    private func computeShares(for details: [LimitlessTournamentDetail]) -> [ArchetypeShare] {
        var counts: [String: Int] = [:]
        var total = 0
        for detail in details {
            for p in detail.placements {
                let key = p.archetype.trimmingCharacters(in: .whitespaces)
                let norm = key.lowercased()
                if counts[norm] == nil { counts[norm] = 0 }
                counts[norm]! += 1
                total += 1
            }
        }
        guard total > 0 else { return [] }

        var canonicalNames: [String: String] = [:]
        for detail in details {
            for p in detail.placements {
                let norm = p.archetype.trimmingCharacters(in: .whitespaces).lowercased()
                if canonicalNames[norm] == nil {
                    canonicalNames[norm] = p.archetype.trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return counts.map { norm, count in
            ArchetypeShare(
                id: UUID(),
                archetypeName: canonicalNames[norm] ?? norm,
                sharePercent: Double(count) / Double(total) * 100
            )
        }
    }

    private static func weekLabel(for date: Date) -> String {
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: weekStart)
    }

    // MARK: - Disk cache

    private func isCacheStale() -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
              let modified = attrs[.modificationDate] as? Date else { return true }
        return Date().timeIntervalSince(modified) > Self.cacheTTL
    }

    private func loadFromDisk() -> [WeekSnapshot]? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode([WeekSnapshot].self, from: data)
    }

    private func saveToDisk(_ value: [WeekSnapshot]) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
