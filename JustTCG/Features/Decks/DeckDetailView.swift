import SwiftUI

// Placeholder — full implementation in M2-03.
enum DeckDetailMode {
    case create
    case edit(Deck)
}

struct DeckDetailView: View {
    let mode: DeckDetailMode

    private var title: String {
        switch mode {
        case .create: return "New Deck"
        case .edit(let deck): return deck.name
        }
    }

    var body: some View {
        Text(title)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
