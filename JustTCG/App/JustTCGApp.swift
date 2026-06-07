import SwiftUI
import SwiftData

@main
struct JustTCGApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Deck.self,
            DeckCard.self,
            Match.self,
            CachedCard.self,
        ])
    }
}
