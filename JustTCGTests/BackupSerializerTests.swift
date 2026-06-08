import Testing
import Foundation
@testable import JustTCG

@Suite("BackupSerializer")
struct BackupSerializerTests {

    // MARK: - encode / decode round-trip

    @Test func roundTrip_emptyDecks() throws {
        let data = try BackupSerializer.encode(decks: [], streakDailyGoal: 2)
        let decoded = try BackupSerializer.decode(from: data)
        #expect(decoded.version == 1)
        #expect(decoded.streakDailyGoal == 2)
        #expect(decoded.decks.isEmpty)
    }

    @Test func roundTrip_deckWithMatchesAndEdits() throws {
        let deckId = UUID()
        let matchId = UUID()
        let editId = UUID()
        let now = Date(timeIntervalSince1970: 1_000_000)

        let payload = BackupPayload(
            version: 1,
            exportedAt: now,
            streakDailyGoal: 3,
            decks: [
                DeckBackup(
                    id: deckId,
                    name: "Charizard ex",
                    format: "Standard",
                    status: "playing",
                    createdAt: now,
                    updatedAt: now,
                    coverCardIds: ["sv3-125"],
                    cards: [DeckCardBackup(cardId: "sv3-125", quantity: 4)],
                    edits: [
                        DeckEditBackup(
                            id: editId,
                            date: now,
                            kind: "addCard",
                            cardId: "sv3-125",
                            cardName: "Charizard ex",
                            quantityBefore: 0,
                            quantityAfter: 4,
                            nameBefore: nil,
                            nameAfter: nil
                        )
                    ],
                    matches: [
                        MatchBackup(
                            id: matchId,
                            date: now,
                            opponentArchetype: "Gardevoir ex",
                            result: "win",
                            format: "bo3",
                            eventType: "casual",
                            notes: "Good game"
                        )
                    ]
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let decoded = try BackupSerializer.decode(from: data)
        let deck = try #require(decoded.decks.first)

        #expect(deck.id == deckId)
        #expect(deck.name == "Charizard ex")
        #expect(deck.coverCardIds == ["sv3-125"])
        #expect(deck.cards.first?.quantity == 4)

        let match = try #require(deck.matches.first)
        #expect(match.id == matchId)
        #expect(match.result == "win")
        #expect(match.notes == "Good game")

        let edit = try #require(deck.edits.first)
        #expect(edit.id == editId)
        #expect(edit.kind == "addCard")
        #expect(edit.quantityAfter == 4)
    }

    // MARK: - fileName

    @Test func fileName_hasCorrectFormat() {
        let name = BackupSerializer.fileName()
        #expect(name.hasPrefix("JustTCG-Backup-"))
        #expect(name.hasSuffix(".json"))
        let prefix = "JustTCG-Backup-"
        let suffix = ".json"
        let dateStart = name.index(name.startIndex, offsetBy: prefix.count)
        let dateEnd = name.index(name.endIndex, offsetBy: -suffix.count)
        let datePart = String(name[dateStart..<dateEnd])
        #expect(datePart.count == 10) // yyyy-MM-dd
    }
}
