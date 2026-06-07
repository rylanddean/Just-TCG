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
        container = Self.makeContainer()
    }

    private static func makeContainer(afterCacheReset: Bool = false) -> ModelContainer {
        let userDataConfig = ModelConfiguration(
            "UserData",
            schema: Schema([Deck.self, DeckCard.self, Match.self]),
            cloudKitDatabase: .automatic
        )
        let cardCacheConfig = ModelConfiguration(
            "CardCache",
            schema: Schema([CachedCard.self]),
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(
                for: Schema([Deck.self, DeckCard.self, Match.self, CachedCard.self]),
                configurations: [userDataConfig, cardCacheConfig]
            )
        } catch {
            if !afterCacheReset {
                // CardCache schema changed (new fields); it's a pure cache so wipe and retry.
                deleteCardCacheStore()
                return makeContainer(afterCacheReset: true)
            }
            fatalError("SwiftData container setup failed: \(error)")
        }
    }

    private static func deleteCardCacheStore() {
        let base = URL.applicationSupportDirectory
        for ext in ["store", "store-wal", "store-shm"] {
            try? FileManager.default.removeItem(at: base.appending(path: "CardCache.\(ext)"))
        }
        // Reset seed/refresh flags so the seeder re-runs and network sync isn't suppressed.
        UserDefaults.standard.removeObject(forKey: BundledCardSeeder.seededKey)
        UserDefaults.standard.removeObject(forKey: CardRepository.lastRefreshKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
