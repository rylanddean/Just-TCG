import SwiftUI
import SwiftData

@main
struct JustTCGApp: App {

    let container: ModelContainer

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1_024 * 1_024,
            diskCapacity: 500 * 1_024 * 1_024,
            diskPath: "card_image_cache"
        )
        do {
            // User-owned data — iCloud sync via CloudKit when capability is configured.
            // cloudKitDatabase: .automatic falls back to local storage gracefully if
            // the iCloud entitlement is not yet present.
            let userDataConfig = ModelConfiguration(
                "UserData",
                schema: Schema([Deck.self, DeckCard.self, Match.self]),
                cloudKitDatabase: .automatic
            )
            // Card cache — always local only, never synced.
            let cardCacheConfig = ModelConfiguration(
                "CardCache",
                schema: Schema([CachedCard.self]),
                cloudKitDatabase: .none
            )
            container = try ModelContainer(
                for: Schema([Deck.self, DeckCard.self, Match.self, CachedCard.self]),
                configurations: [userDataConfig, cardCacheConfig]
            )
        } catch {
            fatalError("SwiftData container setup failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
