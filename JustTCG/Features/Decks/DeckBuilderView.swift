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
    @State private var showCardPicker = false
    @State private var showLogMatch = false
    @State private var highlightedCardIds: Set<String> = []

    var body: some View {
        Group {
            if let vm = viewModel {
                builderList(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showCardPicker, onDismiss: { viewModel?.loadCards() }) {
            CardPickerView(deck: deck)
        }
        .sheet(isPresented: $showLogMatch) {
            LogMatchSheet(deck: deck)
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
        ScrollViewReader { proxy in
            List {
                validationSection(vm: vm, proxy: proxy)
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

                matchesSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent(vm: vm) }
            .onTapGesture {
                if isRenaming { commitRename(vm: vm) }
            }
        }
    }

    // MARK: - Matches section

    private var matchesSection: some View {
        let sorted = deck.matches.sorted { $0.date > $1.date }
        let preview = Array(sorted.prefix(5))
        return Section {
            if preview.isEmpty {
                Label("No matches logged yet", systemImage: "sportscourt")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(preview) { match in
                    NavigationLink {
                        MatchDetailView(match: match)
                    } label: {
                        MatchRow(match: match)
                    }
                }
                if sorted.count > 5 {
                    NavigationLink("See all \(sorted.count) matches") {
                        MatchHistoryView(deck: deck)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                }
            }
        } header: {
            Text("Match History")
        }
    }

    // MARK: - Validation banner

    @ViewBuilder
    private func validationSection(vm: DeckBuilderViewModel, proxy: ScrollViewProxy) -> some View {
        let errors = vm.validationErrors
        let fatals = errors.filter { $0.isFatal }
        let warnings = errors.filter { !$0.isFatal }

        Section {
            if errors.isEmpty {
                Label("Legal deck", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                ForEach(fatals) { err in
                    validationRow(err, color: .red, vm: vm, proxy: proxy)
                }
                ForEach(warnings) { err in
                    validationRow(err, color: .yellow, vm: vm, proxy: proxy)
                }
            }
        }
    }

    @ViewBuilder
    private func validationRow(
        _ error: DeckValidationError,
        color: Color,
        vm: DeckBuilderViewModel,
        proxy: ScrollViewProxy
    ) -> some View {
        let icon = error.isFatal ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
        if let name = error.affectedCardName {
            Button {
                scrollToCards(named: name, vm: vm, proxy: proxy)
            } label: {
                Label(error.message, systemImage: icon)
                    .foregroundStyle(color)
            }
            .buttonStyle(.plain)
        } else {
            Label(error.message, systemImage: icon)
                .foregroundStyle(color)
        }
    }

    private func scrollToCards(named name: String, vm: DeckBuilderViewModel, proxy: ScrollViewProxy) {
        let ids = vm.cardIds(forName: name)
        guard let firstId = ids.first else { return }
        withAnimation { highlightedCardIds = Set(ids) }
        proxy.scrollTo(firstId, anchor: .center)
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            highlightedCardIds = []
        }
    }

    // MARK: - Card sections

    @ViewBuilder
    private func pokemonSection(vm: DeckBuilderViewModel) -> some View {
        if !vm.pokemonCards.isEmpty {
            Section(sectionTitle("Pokémon", cards: vm.pokemonCards)) {
                ForEach(vm.pokemonCards) { dc in
                    DeckCardRow(
                        deckCard: dc,
                        cachedCard: vm.cachedCards[dc.cardId],
                        isHighlighted: highlightedCardIds.contains(dc.cardId)
                    ) {
                        vm.setQuantity($0, for: dc)
                    }
                    .id(dc.cardId)
                }
            }
        }
    }

    @ViewBuilder
    private func trainerSection(vm: DeckBuilderViewModel) -> some View {
        if !vm.trainerCards.isEmpty {
            Section(sectionTitle("Trainer", cards: vm.trainerCards)) {
                ForEach(vm.trainerCards) { dc in
                    DeckCardRow(
                        deckCard: dc,
                        cachedCard: vm.cachedCards[dc.cardId],
                        isHighlighted: highlightedCardIds.contains(dc.cardId)
                    ) {
                        vm.setQuantity($0, for: dc)
                    }
                    .id(dc.cardId)
                }
            }
        }
    }

    @ViewBuilder
    private func energySection(vm: DeckBuilderViewModel) -> some View {
        if !vm.energyCards.isEmpty {
            Section(sectionTitle("Energy", cards: vm.energyCards)) {
                ForEach(vm.energyCards) { dc in
                    DeckCardRow(
                        deckCard: dc,
                        cachedCard: vm.cachedCards[dc.cardId],
                        isHighlighted: highlightedCardIds.contains(dc.cardId)
                    ) {
                        vm.setQuantity($0, for: dc)
                    }
                    .id(dc.cardId)
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
            Button { showLogMatch = true } label: {
                Image(systemName: "plus")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            if showsDoneButton {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            } else {
                ShareLink(item: vm.exportString) {
                    Image(systemName: "square.and.arrow.up")
                }
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
    var isHighlighted: Bool = false
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
        .listRowBackground(isHighlighted ? Color.yellow.opacity(0.25) : nil)
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }
}
