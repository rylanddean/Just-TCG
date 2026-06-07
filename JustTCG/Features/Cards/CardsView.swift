import SwiftUI
import SwiftData

struct CardsView: View {
    @Environment(\.modelContext) private var context
    @State private var isSyncing = false
    @State private var hasCards = false
    @State private var syncError: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isSyncing && !hasCards {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading cards…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasCards && syncError != nil {
                    offlineEmptyState
                } else {
                    Text("Cards")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Cards")
            .toolbar {
                if isSyncing && hasCards {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
        }
        .task {
            await syncCards(force: false)
        }
        .refreshable {
            await syncCards(force: true)
        }
    }

    private var offlineEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Connection")
                .font(.title2.bold())
            Text("Cards will load once you connect to the internet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task { await syncCards(force: true) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func syncCards(force: Bool) async {
        isSyncing = true
        syncError = nil
        let repo = CardRepository(modelContext: context)
        do {
            try await repo.refreshIfStale(force: force)
        } catch {
            syncError = error.localizedDescription
        }
        hasCards = ((try? repo.fetchAll()) ?? []).isEmpty == false
        isSyncing = false
    }
}
