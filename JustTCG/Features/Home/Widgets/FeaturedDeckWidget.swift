import SwiftUI
import SwiftData

struct FeaturedDeckWidget: View {
    @State private var vm = FeaturedDeckWidgetViewModel()
    @State private var showDeckViewer = false

    @Query(filter: #Predicate<CachedCard> { $0.supertype == "Pokémon" })
    private var pokemonCards: [CachedCard]

    private let resolver = ArchetypePrimaryCardResolver()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            bodyContent
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .task { await vm.load() }
        .sheet(isPresented: $showDeckViewer) {
            if let snapshot = vm.snapshot, let listId = snapshot.deckListId {
                NavigationStack {
                    DeckListViewerView(listId: listId, archetype: snapshot.archetype)
                }
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("Featured Deck")
                .font(.headline)
            Spacer()
            Text("Today")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(.tertiarySystemFill)))
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyContent: some View {
        if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if let snapshot = vm.snapshot {
            loadedContent(snapshot: snapshot)
        } else {
            ContentUnavailableView(
                "No Featured Deck",
                systemImage: "trophy",
                description: Text("Check back when tournament data loads.")
            )
        }
    }

    // MARK: - Loaded state

    @ViewBuilder
    private func loadedContent(snapshot: FeaturedDeckSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: primary card thumbnail — resolved reactively so it appears once the catalog loads
            if let card = resolver.resolve(archetype: snapshot.archetype, from: pokemonCards) {
                CardThumbnailView(card: card)
                    .frame(width: 72, height: 100)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.quaternarySystemFill))
                    .frame(width: 72, height: 100)
            }

            // Right: text details
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(snapshot.archetype)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    Text(ordinal(snapshot.placing))
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor))
                }

                Text(snapshot.playerName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(snapshot.tournamentName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                if snapshot.deckListId != nil {
                    Button {
                        showDeckViewer = true
                    } label: {
                        Label("See Deck", systemImage: "list.bullet.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

// MARK: - Ordinal helper

private func ordinal(_ n: Int) -> String {
    let suffix: String
    switch n % 100 {
    case 11, 12, 13:
        suffix = "th"
    default:
        switch n % 10 {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
    }
    return "\(n)\(suffix)"
}
