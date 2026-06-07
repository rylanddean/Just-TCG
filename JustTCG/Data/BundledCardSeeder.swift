import Foundation
import SwiftData

// Seeds the SwiftData card cache from bundled JSON files on first launch.
// Subsequent launches skip this entirely (UserDefaults check is instant).
// When new regulation sets ship in an app update, bump seededKey's version suffix.
enum BundledCardSeeder {

    static let seededKey = "bundled_cards_seeded_v1"

    private static let setFiles = [
        "TEF", "TWM", "SFA", "SCR", "SSP",
        "PRE", "JTG", "DRI", "BLK", "WHT",
        "MEG", "PFL", "ASC", "POR", "CRI",
    ]

    // Decodes JSON off the main thread, then inserts into the provided context.
    // Must be called from MainActor (the view's .task or similar) so that context
    // operations happen on the right thread.
    static func seedIfNeeded(context: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

        let cards: [CardSeedEntry] = await Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()
            var result: [CardSeedEntry] = []
            result.reserveCapacity(3000)
            for code in setFiles {
                guard
                    let url = Bundle.main.url(forResource: code, withExtension: "json",
                                              subdirectory: "CardData"),
                    let data = try? Data(contentsOf: url),
                    let payload = try? decoder.decode(CardSetPayload.self, from: data)
                else { continue }
                result.append(contentsOf: payload.cards)
            }
            return result
        }.value

        for entry in cards {
            context.insert(CachedCard(
                id: entry.id,
                name: entry.name,
                setCode: entry.setCode,
                setName: entry.setName,
                number: entry.number,
                types: entry.types,
                subtypes: entry.subtypes,
                hp: entry.hp,
                isStandardLegal: entry.isStandardLegal,
                imageURL: entry.imageURL,
                largeImageURL: entry.largeImageURL,
                rulesText: entry.rulesText
            ))
        }

        try? context.save()
        // Mark the card cache fresh so CardRepository skips the network sync on launch.
        UserDefaults.standard.set(Date(), forKey: CardRepository.lastRefreshKey)
        UserDefaults.standard.set(true, forKey: seededKey)
    }
}

// MARK: - Codable payload matching the scraped JSON schema

private struct CardSetPayload: Decodable {
    let cards: [CardSeedEntry]
}

struct CardSeedEntry: Decodable, Sendable {
    let id: String
    let name: String
    let setCode: String
    let setName: String
    let number: String
    let types: [String]
    let subtypes: [String]
    let hp: Int?
    let isStandardLegal: Bool
    let imageURL: String
    let largeImageURL: String?
    let rulesText: [String]
}
