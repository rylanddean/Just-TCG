import SwiftUI

// Placeholder — full implementation in M1-06.
struct CardDetailView: View {
    let card: CachedCard

    var body: some View {
        Text(card.name)
            .navigationTitle(card.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}
