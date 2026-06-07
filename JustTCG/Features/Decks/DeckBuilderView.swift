import SwiftUI
import SwiftData

struct DeckBuilderView: View {
    let deck: Deck
    var showsDoneButton: Bool = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: DeckBuilderViewModel? = nil
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var renameFocused: Bool
    @State private var showCardPicker = false  // wired up in M2-04

    var body: some View {
        Group {
            if let vm = viewModel {
                builderList(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if viewModel == nil {
                let vm = DeckBuilderViewModel(deck: deck, modelContext: context)
                vm.loadCards()
                viewModel = vm
            }
        }
    }

    // MARK: - Builder list

    @ViewBuilder
    private func builderList(vm: DeckBuilderViewModel) -> some View {
        List {
            pokemonSection(vm: vm)
            trainerSection(vm: vm)
            energySection(vm: vm)

            Section {
                Button {
                    showCardPicker = true
                } label: {
                    Label("Add Cards", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent(vm: vm) }
        .sheet(isPresented: $showCardPicker, onDismiss: { viewModel?.loadCards() }) {
            CardPickerView(deck: deck)
        }
        .onTapGesture {
            if isRenaming { commitRename(vm: vm) }
        }
    }

    @ViewBuilder
    private func pokemonSection(vm: DeckBuilderViewModel) -> some View {
        if !vm.pokemonCards.isEmpty {
            Section(sectionTitle("Pokémon", cards: vm.pokemonCards)) {
                ForEach(vm.pokemonCards) { dc in
                    DeckCardRow(deckCard: dc, cachedCard: vm.cachedCards[dc.cardId]) {
                        vm.setQuantity($0, for: dc)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trainerSection(vm: DeckBuilderViewModel) -> some View {
        if !vm.trainerCards.isEmpty {
            Section(sectionTitle("Trainer", cards: vm.trainerCards)) {
                ForEach(vm.trainerCards) { dc in
                    DeckCardRow(deckCard: dc, cachedCard: vm.cachedCards[dc.cardId]) {
                        vm.setQuantity($0, for: dc)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func energySection(vm: DeckBuilderViewModel) -> some View {
        if !vm.energyCards.isEmpty {
            Section(sectionTitle("Energy", cards: vm.energyCards)) {
                ForEach(vm.energyCards) { dc in
                    DeckCardRow(deckCard: dc, cachedCard: vm.cachedCards[dc.cardId]) {
                        vm.setQuantity($0, for: dc)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ name: String, cards: [DeckCard]) -> String {
        let qty = cards.reduce(0) { $0 + $1.quantity }
        return "\(name) · \(qty)"
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent(vm: DeckBuilderViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if isRenaming {
                TextField("Deck name", text: $renameText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .focused($renameFocused)
                    .onSubmit { commitRename(vm: vm) }
                    .onChange(of: renameFocused) { _, focused in
                        if !focused { commitRename(vm: vm) }
                    }
            } else {
                VStack(spacing: 2) {
                    Button(deck.name) {
                        renameText = deck.name
                        isRenaming = true
                        renameFocused = true
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                    Text("\(vm.totalCount) / 60")
                        .font(.caption2)
                        .foregroundStyle(vm.totalCount == 60 ? .green : .red)
                }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            if showsDoneButton {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            } else {
                Button {
                    // M2-06 export
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(true)
            }
        }
    }

    private func commitRename(vm: DeckBuilderViewModel) {
        vm.rename(to: renameText)
        isRenaming = false
    }
}

// MARK: - Deck card row

private struct DeckCardRow: View {
    let deckCard: DeckCard
    let cachedCard: CachedCard?
    let onQuantityChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: cachedCard?.imageURL ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                default:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .aspectRatio(7/10, contentMode: .fit)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(cachedCard?.name ?? deckCard.cardId)
                    .font(.body)
                if let card = cachedCard {
                    Text("\(card.setName) · #\(card.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    onQuantityChange(deckCard.quantity - 1)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Text("\(deckCard.quantity)")
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 18, alignment: .center)

                Button {
                    onQuantityChange(deckCard.quantity + 1)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}
