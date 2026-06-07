import SwiftUI

// Routing shim — DecksView uses DeckDetailMode to distinguish create vs edit.
// .create presents NewDeckSheet (owns its own NavigationStack inside a sheet).
// .edit(deck) renders DeckBuilderView directly inside the caller's NavigationStack.
enum DeckDetailMode {
    case create
    case edit(Deck)
}

struct DeckDetailView: View {
    let mode: DeckDetailMode

    var body: some View {
        switch mode {
        case .create:
            NewDeckSheet()
        case .edit(let deck):
            DeckBuilderView(deck: deck)
        }
    }
}
