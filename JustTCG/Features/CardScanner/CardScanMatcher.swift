import Foundation
import SwiftData

final class CardScanMatcher {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func match(result: CardScanResult) async -> [CachedCard] {
        // High-confidence: exact set + number
        if let setCode = result.setCode, let number = result.cardNumber {
            let sc = setCode
            let num = number
            var descriptor = FetchDescriptor<CachedCard>(
                predicate: #Predicate { $0.setCode == sc && $0.number == num }
            )
            descriptor.fetchLimit = 1
            if let exact = try? context.fetch(descriptor), !exact.isEmpty {
                return exact
            }
        }

        // Medium-confidence fallback: number only, sorted by set recency
        if let number = result.cardNumber {
            let num = number
            var descriptor = FetchDescriptor<CachedCard>(
                predicate: #Predicate { $0.number == num }
            )
            descriptor.fetchLimit = 10
            if let candidates = try? context.fetch(descriptor), !candidates.isEmpty {
                return candidates
                    .sorted { ($0.setReleaseDate ?? .distantPast) > ($1.setReleaseDate ?? .distantPast) }
                    .prefix(3)
                    .map { $0 }
            }
        }

        // Name fallback
        if let name = result.cardName {
            let repo = CardRepository(modelContext: context)
            let candidates = (try? repo.fetch(matching: name, filterState: CardFilterState(), sortOrder: .expansion)) ?? []
            return Array(candidates.prefix(3))
        }

        return []
    }
}
