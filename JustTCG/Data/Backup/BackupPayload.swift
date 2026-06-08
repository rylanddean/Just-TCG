import Foundation
import SwiftData

struct BackupPayload: Codable {
    let version: Int
    let exportedAt: Date
    let streakDailyGoal: Int
    let decks: [DeckBackup]
}

struct DeckBackup: Codable {
    let id: UUID
    let name: String
    let format: String
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let coverCardIds: [String]
    let cards: [DeckCardBackup]
    let edits: [DeckEditBackup]
    let matches: [MatchBackup]
}

extension DeckBackup {
    init(_ deck: Deck) {
        id = deck.id
        name = deck.name
        format = deck.format
        status = deck.status.rawValue
        createdAt = deck.createdAt
        updatedAt = deck.updatedAt
        coverCardIds = deck.coverCardIds
        cards = deck.cards.map { DeckCardBackup(cardId: $0.cardId, quantity: $0.quantity) }
        edits = deck.edits.map(DeckEditBackup.init)
        matches = deck.matches.map(MatchBackup.init)
    }
}

struct DeckCardBackup: Codable {
    let cardId: String
    let quantity: Int
}

struct DeckEditBackup: Codable {
    let id: UUID
    let date: Date
    let kind: String
    let cardId: String?
    let cardName: String?
    let quantityBefore: Int
    let quantityAfter: Int
    let nameBefore: String?
    let nameAfter: String?
}

extension DeckEditBackup {
    init(_ edit: DeckEdit) {
        id = edit.id
        date = edit.date
        kind = edit.kind.rawValue
        cardId = edit.cardId
        cardName = edit.cardName
        quantityBefore = edit.quantityBefore
        quantityAfter = edit.quantityAfter
        nameBefore = edit.nameBefore
        nameAfter = edit.nameAfter
    }
}

struct MatchBackup: Codable {
    let id: UUID
    let date: Date
    let opponentArchetype: String
    let result: String
    let format: String
    let eventType: String
    let notes: String
}

extension MatchBackup {
    init(_ match: Match) {
        id = match.id
        date = match.date
        opponentArchetype = match.opponentArchetype
        result = match.result.rawValue
        format = match.format.rawValue
        eventType = match.eventType.rawValue
        notes = match.notes
    }
}
