import SwiftUI

struct DeckListViewerView: View {
    let listId: String
    let archetype: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var vm: DeckListViewerViewModel? = nil
    @State private var showImportConfirm = false
    @State private var navigateToImported = false

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(archetype)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if vm == nil {
                let v = DeckListViewerViewModel(listId: listId, modelContext: context)
                vm = v
                await v.load()
            }
        }
        .refreshable {
            await vm?.refresh()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: DeckListViewerViewModel) -> some View {
        if vm.isLoading && vm.groups.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.error, vm.groups.isEmpty {
            errorState(error, vm: vm)
        } else {
            deckListContent(vm: vm)
        }
    }

    private func deckListContent(vm: DeckListViewerViewModel) -> some View {
        List {
            ForEach(vm.groups, id: \.title) { group in
                Section(header: Text("\(group.title) · \(group.total)")) {
                    ForEach(group.entries) { ve in
                        NavigationLink {
                            if let card = ve.cachedCard {
                                CardDetailView(card: card)
                            }
                        } label: {
                            EntryRow(ve: ve)
                        }
                        .disabled(ve.cachedCard == nil)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        UIPasteboard.general.string = vm.ptcglExport
                    } label: {
                        Label("Copy List", systemImage: "doc.on.clipboard")
                    }
                    Button {
                        showImportConfirm = true
                    } label: {
                        Label("Import to My Decks", systemImage: "square.and.arrow.down")
                    }
                    .disabled(vm.deckList == nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Import \"\(archetype)\" to My Decks?",
            isPresented: $showImportConfirm,
            titleVisibility: .visible
        ) {
            Button("Import") {
                vm.importDeck(named: archetype)
                if vm.importedDeck != nil {
                    navigateToImported = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A new deck will be created with this list.")
        }
        .navigationDestination(isPresented: $navigateToImported) {
            if let deck = vm.importedDeck {
                DeckBuilderView(deck: deck)
            }
        }
    }

    // MARK: - Error

    private func errorState(_ message: String, vm: DeckListViewerViewModel) -> some View {
        ContentUnavailableView {
            Label("Couldn't Load Deck List", systemImage: "wifi.slash")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { Task { await vm.refresh() } }
        }
    }
}

// MARK: - Entry row

private struct EntryRow: View {
    let ve: ViewerEntry

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: ve.cachedCard?.imageURL ?? "")) { phase in
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
                Text(ve.cachedCard?.name ?? ve.entry.name)
                    .font(.body)
                if let card = ve.cachedCard {
                    Text("\(card.setName) · #\(card.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(ve.entry.setCode) #\(ve.entry.number)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text("×\(ve.entry.quantity)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
