# M16-03 — Deck Edit Log View

**Status:** done  
**Milestone:** M16 — Deck Edit Log  
**Dependencies:** M16-01, M16-02

## User Story

As a player, I want to see a reverse-chronological list of every change I've made to a deck so that I can review how it evolved without having to remember it myself.

## Acceptance Criteria

- [x] A "Changelog" tab or section is accessible from `DeckBuilderView` (toolbar button or a dedicated tab — see Technical Notes)
- [x] The edit log lists entries in reverse-chronological order (newest first)
- [x] Each entry shows:
  - A short one-line description (e.g. "Added Dragapult ex ×1", "Removed Bibarel", "Changed Fezandipiti ×2→3", "Renamed "Drag ex v1" → "Drag ex v2"")
  - The date/time of the edit (relative for recent: "2 hours ago", absolute for older: "Jun 3")
- [x] Card add/remove/set entries show the card name when available; fall back to the card ID if `cardName` is nil
- [x] If the deck has no edits yet, an empty-state message is shown: "No changes recorded yet. Edits you make will appear here."
- [x] The view is read-only — no delete or undo actions in this milestone

## Technical Notes

**New file:** `JustTCG/Features/Decks/DeckEditLogView.swift`

Surface via a toolbar button on `DeckBuilderView` (person.crop.rectangle.stack or clock.arrow.circlepath system image). Present as a `.sheet` so the builder stays on screen underneath.

**Description helper:**

```swift
extension DeckEdit {
    var displayDescription: String {
        switch kind {
        case .addCard:
            let name = cardName ?? cardId ?? "Unknown"
            return "Added \(name) ×\(quantityAfter)"
        case .removeCard:
            let name = cardName ?? cardId ?? "Unknown"
            return "Removed \(name)"
        case .setQuantity:
            let name = cardName ?? cardId ?? "Unknown"
            return "Changed \(name) ×\(quantityBefore)→\(quantityAfter)"
        case .rename:
            return "Renamed "\(nameBefore ?? "")" → "\(nameAfter ?? "")""
        }
    }
}
```

Use `RelativeDateTimeFormatter` for dates within the last 24 hours; `DateFormatter` with `dateStyle: .medium, timeStyle: .none` for older entries.
