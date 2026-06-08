import Foundation
import SwiftData

struct BackupImportResult {
    let decksImported: Int
    let decksSkipped: Int
    let matchesImported: Int
}

struct BackupImporter {
    func importPayload(_ payload: BackupPayload, into context: ModelContext) -> BackupImportResult {
        let existingIds = (try? context.fetch(FetchDescriptor<Deck>()))?.map(\.id) ?? []
        let existingSet = Set(existingIds)

        var decksImported = 0
        var decksSkipped = 0
        var matchesImported = 0

        for deckBackup in payload.decks {
            guard !existingSet.contains(deckBackup.id) else {
                decksSkipped += 1
                continue
            }
            let deck = Deck(name: deckBackup.name, format: deckBackup.format)
            deck.id = deckBackup.id
            deck.status = DeckStatus(rawValue: deckBackup.status) ?? .playing
            deck.createdAt = deckBackup.createdAt
            deck.updatedAt = deckBackup.updatedAt
            deck.coverCardIds = deckBackup.coverCardIds

            deck.cards = deckBackup.cards.map { DeckCard(cardId: $0.cardId, quantity: $0.quantity) }
            deck.edits = deckBackup.edits.map { editBackup in
                let edit = DeckEdit(
                    date: editBackup.date,
                    kind: DeckEditKind(rawValue: editBackup.kind) ?? .addCard,
                    cardId: editBackup.cardId,
                    cardName: editBackup.cardName,
                    quantityBefore: editBackup.quantityBefore,
                    quantityAfter: editBackup.quantityAfter,
                    nameBefore: editBackup.nameBefore,
                    nameAfter: editBackup.nameAfter
                )
                edit.id = editBackup.id
                return edit
            }
            deck.matches = deckBackup.matches.map { matchBackup in
                let match = Match(
                    date: matchBackup.date,
                    opponentArchetype: matchBackup.opponentArchetype,
                    result: MatchResult(rawValue: matchBackup.result) ?? .win,
                    format: MatchFormat(rawValue: matchBackup.format) ?? .bo3,
                    eventType: EventType(rawValue: matchBackup.eventType) ?? .casual,
                    notes: matchBackup.notes
                )
                match.id = matchBackup.id
                return match
            }

            context.insert(deck)
            decksImported += 1
            matchesImported += deckBackup.matches.count
        }

        // Only overwrite streak goal if user hasn't customised it (default is 1)
        let storedGoal = UserDefaults.standard.object(forKey: "streak_daily_goal") as? Int ?? 1
        if storedGoal == 1 {
            UserDefaults.standard.set(payload.streakDailyGoal, forKey: "streak_daily_goal")
        }

        try? context.save()
        return BackupImportResult(
            decksImported: decksImported,
            decksSkipped: decksSkipped,
            matchesImported: matchesImported
        )
    }
}
