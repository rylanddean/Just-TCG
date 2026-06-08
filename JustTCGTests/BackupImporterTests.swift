import Testing
import Foundation
import SwiftData
@testable import JustTCG

@Suite("BackupImporter")
@MainActor
struct BackupImporterTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Deck.self, configurations: config)
        return ModelContext(container)
    }

    private func samplePayload(deckId: UUID = UUID(), matchCount: Int = 1) -> BackupPayload {
        let matches = (0..<matchCount).map { _ in
            MatchBackup(
                id: UUID(),
                date: .now,
                opponentArchetype: "Gardevoir ex",
                result: "win",
                format: "bo3",
                eventType: "casual",
                notes: ""
            )
        }
        return BackupPayload(
            version: 1,
            exportedAt: .now,
            streakDailyGoal: 2,
            decks: [
                DeckBackup(
                    id: deckId,
                    name: "Pikachu ex",
                    format: "Standard",
                    status: "playing",
                    createdAt: .now,
                    updatedAt: .now,
                    coverCardIds: [],
                    cards: [DeckCardBackup(cardId: "sv1-1", quantity: 4)],
                    edits: [],
                    matches: matches
                )
            ]
        )
    }

    // MARK: - Tests

    @Test func freshImport_createsAllRecords() throws {
        let context = try makeContext()
        let payload = samplePayload()

        let result = BackupImporter().importPayload(payload, into: context)

        #expect(result.decksImported == 1)
        #expect(result.decksSkipped == 0)
        #expect(result.matchesImported == 1)

        let decks = try context.fetch(FetchDescriptor<Deck>())
        #expect(decks.count == 1)
        #expect(decks.first?.name == "Pikachu ex")
        #expect(decks.first?.cards.count == 1)
        #expect(decks.first?.matches.count == 1)
    }

    @Test func duplicateDeckId_isSkipped() throws {
        let context = try makeContext()
        let deckId = UUID()

        let first = BackupImporter().importPayload(samplePayload(deckId: deckId), into: context)
        #expect(first.decksImported == 1)
        #expect(first.decksSkipped == 0)

        let second = BackupImporter().importPayload(samplePayload(deckId: deckId), into: context)
        #expect(second.decksImported == 0)
        #expect(second.decksSkipped == 1)

        let decks = try context.fetch(FetchDescriptor<Deck>())
        #expect(decks.count == 1)
    }

    @Test func matchesImported_countIsAccurate() throws {
        let context = try makeContext()
        let result = BackupImporter().importPayload(samplePayload(matchCount: 3), into: context)
        #expect(result.matchesImported == 3)
    }
}
