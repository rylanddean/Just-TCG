import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("streak_daily_goal") private var dailyGoal: Int = 1

    var body: some View {
        NavigationStack {
            Form {
                streakSection
                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        Section("Streak") {
            Stepper("Goal: \(dailyGoal) game\(dailyGoal == 1 ? "" : "s") / day", value: $dailyGoal, in: 1...10)
        }
    }

    // MARK: - Developer

    #if DEBUG
    private var developerSection: some View {
        Section("Developer") {
            CardCacheDebugRow()
        }
    }
    #endif
}

// MARK: - Card Cache Debug Row

#if DEBUG
private struct CardCacheDebugRow: View {
    @Environment(\.modelContext) private var context

    @State private var cardCount: Int = 0
    @State private var lastRefreshed: Date? = nil
    @State private var isSyncing = false
    @State private var statusMessage: String? = nil

    var body: some View {
        Group {
            LabeledContent("Cached cards", value: "\(cardCount)")
            LabeledContent("Last refreshed") {
                Text(lastRefreshed.map { $0.formatted(.relative(presentation: .named)) } ?? "Never")
                    .foregroundStyle(.secondary)
            }

            Button("Force network sync") {
                Task { await forceSync() }
            }
            .disabled(isSyncing)

            Button("Clear card cache", role: .destructive) {
                clearCache()
            }
            .disabled(isSyncing)

            if isSyncing {
                HStack {
                    ProgressView()
                    Text("Syncing…")
                        .foregroundStyle(.secondary)
                }
            }

            if let msg = statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { refreshStats() }
    }

    private func refreshStats() {
        let descriptor = FetchDescriptor<CachedCard>()
        cardCount = (try? context.fetchCount(descriptor)) ?? 0
        lastRefreshed = UserDefaults.standard.object(forKey: CardRepository.lastRefreshKey) as? Date
    }

    private func forceSync() async {
        isSyncing = true
        statusMessage = nil
        do {
            let repo = CardRepository(modelContext: context)
            try await repo.refreshIfStale(force: true)
            refreshStats()
            statusMessage = "Sync complete."
        } catch {
            statusMessage = "Sync failed: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    private func clearCache() {
        try? context.delete(model: CachedCard.self)
        try? context.save()
        UserDefaults.standard.removeObject(forKey: CardRepository.lastRefreshKey)
        UserDefaults.standard.removeObject(forKey: BundledCardSeeder.seededKey)
        refreshStats()
        statusMessage = "Cache cleared. Re-launch to reseed from bundle."
    }
}
#endif
