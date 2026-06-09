import Foundation
import SwiftData
import Observation

@Observable
final class FavouritePlayerRepository {
    private let context: ModelContext
    private(set) var all: [FavouritePlayer] = []

    init(context: ModelContext) {
        self.context = context
        fetchAll()
    }

    func isFavourite(id: String) -> Bool {
        all.contains { $0.id == id }
    }

    func add(_ player: FavouritePlayer) {
        guard !isFavourite(id: player.id) else { return }
        context.insert(player)
        try? context.save()
        fetchAll()
    }

    func remove(id: String) {
        guard let player = all.first(where: { $0.id == id }) else { return }
        context.delete(player)
        try? context.save()
        fetchAll()
    }

    private func fetchAll() {
        let descriptor = FetchDescriptor<FavouritePlayer>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        all = (try? context.fetch(descriptor))?.filter { !$0.id.isEmpty } ?? []
    }
}
