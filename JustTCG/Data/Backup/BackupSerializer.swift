import Foundation

enum BackupError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Could not access the selected file."
        }
    }
}

struct BackupSerializer {
    static func encode(decks: [Deck], streakDailyGoal: Int) throws -> Data {
        let payload = BackupPayload(
            version: 1,
            exportedAt: .now,
            streakDailyGoal: streakDailyGoal,
            decks: decks.map(DeckBackup.init)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    static func decode(from data: Data) throws -> BackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupPayload.self, from: data)
    }

    static func fileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "JustTCG-Backup-\(formatter.string(from: .now)).json"
    }
}
