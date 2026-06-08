import SwiftUI
import SwiftData

struct CoverCardPickerSheet: View {
    let deck: Deck
    let cardMap: [String: CachedCard]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIds: [String] = []

    private let maxPins = 3

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                    ForEach(orderedCards, id: \.id) { card in
                        cardCell(card)
                    }
                }
                .padding()
            }
            .navigationTitle("Cover Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save(); dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset to Auto") { selectedIds = [] }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .disabled(selectedIds.isEmpty)
                }
            }
        }
        .onAppear { selectedIds = deck.coverCardIds }
    }

    // MARK: - Card cell

    private func cardCell(_ card: CachedCard) -> some View {
        let selectionIndex = selectedIds.firstIndex(of: card.id)
        let isSelected = selectionIndex != nil
        let isDisabled = !isSelected && selectedIds.count >= maxPins

        return Button { toggle(card.id) } label: {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: card.imageURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.2))
                        .aspectRatio(2/3, contentMode: .fit)
                }
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )

                if let idx = selectionIndex {
                    Text("\(idx + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.15), value: selectedIds)
    }

    // MARK: - Helpers

    private func toggle(_ id: String) {
        if let idx = selectedIds.firstIndex(of: id) {
            selectedIds.remove(at: idx)
        } else if selectedIds.count < maxPins {
            selectedIds.append(id)
        }
    }

    private func save() {
        deck.coverCardIds = selectedIds
        try? context.save()
    }

    // Pokémon first (by qty desc), then trainers, then energy
    private var orderedCards: [CachedCard] {
        deck.cards
            .compactMap { dc -> (DeckCard, CachedCard)? in
                guard let card = cardMap[dc.cardId] else { return nil }
                return (dc, card)
            }
            .sorted { lhs, rhs in
                let lGroup = sortGroup(lhs.1)
                let rGroup = sortGroup(rhs.1)
                if lGroup != rGroup { return lGroup < rGroup }
                return lhs.0.quantity != rhs.0.quantity
                    ? lhs.0.quantity > rhs.0.quantity
                    : lhs.1.name < rhs.1.name
            }
            .map(\.1)
    }

    private func sortGroup(_ card: CachedCard) -> Int {
        switch card.supertype {
        case "Pokémon": return 0
        case "Trainer": return 1
        default: return 2  // Energy
        }
    }
}
