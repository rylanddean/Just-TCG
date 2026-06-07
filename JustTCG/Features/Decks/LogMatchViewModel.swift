import Foundation
import SwiftData
import Observation

@Observable
final class LogMatchViewModel {
    // MARK: - Required fields

    var archetypeQuery: String = "" {
        didSet { if oldValue != archetypeQuery { suppressSuggestions = false } }
    }
    private(set) var suppressSuggestions = false
    var result: MatchResult? = nil

    // MARK: - More details

    var eventType: EventType
    var format: MatchFormat
    var date: Date = .now
    var notes: String = ""
    var showMoreDetails: Bool = false

    // MARK: - Toast

    var showToast: Bool = false

    // MARK: - Derived

    var isValid: Bool {
        !archetypeQuery.trimmingCharacters(in: .whitespaces).isEmpty && result != nil
    }

    var suggestions: [Archetype] {
        guard !archetypeQuery.isEmpty, !suppressSuggestions else { return [] }
        return ArchetypeRepository.shared.search(query: archetypeQuery)
    }

    // MARK: - Private

    private let deck: Deck
    private let matchRepo: MatchRepository

    init(deck: Deck, modelContext: ModelContext) {
        self.deck = deck
        self.matchRepo = MatchRepository(modelContext: modelContext)
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "last_event_type"),
           let et = EventType(rawValue: raw) {
            eventType = et
        } else {
            eventType = .casual
        }
        if let raw = defaults.string(forKey: "last_match_format"),
           let mf = MatchFormat(rawValue: raw) {
            format = mf
        } else {
            format = .bo3
        }
    }

    func selectArchetype(_ archetype: Archetype) {
        archetypeQuery = archetype.name
        suppressSuggestions = true
    }

    func confirm() {
        guard isValid, let result else { return }
        let defaults = UserDefaults.standard
        defaults.set(eventType.rawValue, forKey: "last_event_type")
        defaults.set(format.rawValue, forKey: "last_match_format")
        matchRepo.logMatch(
            deck: deck,
            archetype: archetypeQuery.trimmingCharacters(in: .whitespaces),
            result: result,
            format: format,
            eventType: eventType,
            notes: notes,
            date: date
        )
        showToast = true
    }
}
