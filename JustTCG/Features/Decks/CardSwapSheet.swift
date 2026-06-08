import SwiftUI
import SwiftData

struct CardSwapSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let entry: DeckImportEntry
    let onSelect: (CachedCard) -> Void

    @State private var searchText: String = ""
    @State private var results: [CachedCard] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            TextField("Search", text: $searchText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        if results.isEmpty {
                            Text("No cards found matching '\(searchText)'.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(results, id: \.id) { card in
                                Button {
                                    onSelect(card)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        AsyncImage(url: URL(string: card.imageURL)) { phase in
                                            if case .success(let img) = phase {
                                                img.resizable().aspectRatio(contentMode: .fit)
                                            } else {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.secondary.opacity(0.15))
                                            }
                                        }
                                        .frame(width: 36, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(card.name).font(.body)
                                            Text("\(card.setCode) \(card.number)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Replace Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                searchText = entry.name
                results = fetchResults(query: entry.name)
                isLoading = false
            }
            .onChange(of: searchText) { _, newValue in
                results = fetchResults(query: newValue)
            }
        }
    }

    private func fetchResults(query: String) -> [CachedCard] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        var descriptor = FetchDescriptor<CachedCard>(
            predicate: #Predicate { $0.name.localizedStandardContains(query) },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = 50
        return (try? context.fetch(descriptor)) ?? []
    }
}
