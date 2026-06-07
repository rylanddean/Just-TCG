import SwiftUI
import SwiftData

struct CardsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<CachedCard> { $0.isStandardLegal }, sort: \.name)
    private var cards: [CachedCard]

    @State private var isSyncing = false
    @State private var syncError: String? = nil

    private let columns = [
        GridItem(.flexible(minimum: 100)),
        GridItem(.flexible(minimum: 100)),
        GridItem(.flexible(minimum: 100)),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isSyncing && cards.isEmpty {
                    skeletonGrid
                } else if cards.isEmpty && syncError != nil {
                    offlineEmptyState
                } else if !cards.isEmpty {
                    cardGrid
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Cards")
            .toolbar {
                if isSyncing && !cards.isEmpty {
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
    }

    // MARK: - Sub-views

    private var cardGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cards) { card in
                    NavigationLink(destination: CardDetailView(card: card)) {
                        CardThumbnailView(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .refreshable { await syncCards(force: true) }
    }

    private var skeletonGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<30, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.15))
                        .aspectRatio(7/10, contentMode: .fit)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
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

    // MARK: - Sync

    private func syncCards(force: Bool) async {
        isSyncing = true
        syncError = nil
        let repo = CardRepository(modelContext: context)
        do {
            try await repo.refreshIfStale(force: force)
        } catch {
            syncError = error.localizedDescription
        }
        isSyncing = false
    }
}
