# M24-03 — Generated Deck Import

**Status:** todo  
**Milestone:** M24 — Natural Language Deck Generator  
**Dependencies:** M24-02, M10-01, M10-02

## User Story

As a player, I want to import a generated deck directly into my Decks list with one tap, so I can start using it immediately without copy-pasting anything.

## Acceptance Criteria

- [ ] Tapping "Import Deck" in `DeckListPreviewCard` triggers an import sheet that appears as a `.sheet` over `DeckGeneratorView`
- [ ] The import sheet shows:
  - A `TextField` pre-filled with a suggested deck name (derived from the first Pokémon name found in the deck list — e.g. "Charizard ex Deck")
  - A "Cancel" button and a "Create Deck" button
- [ ] Tapping "Create Deck":
  1. Parses the PTCGL-format deck list using the existing `DeckListParser` (M10-01)
  2. Resolves card IDs using the existing card lookup logic (M10-02)
  3. Creates a new `Deck` via `DeckRepository` and saves it to SwiftData
  4. Dismisses the full-screen cover and navigates to the new deck in `DecksView`
- [ ] If card lookup fails for one or more cards, a warning banner lists the unresolved card names and the deck is still created with the cards that were found
- [ ] The "Create Deck" button shows a `ProgressView` while import is in progress and is disabled to prevent double-tap
- [ ] After successful import a toast banner "Deck created" appears on `DecksView` (same pattern as other toast banners in the app)

## Technical Notes

**Files to change:**
- `JustTCG/Features/Decks/DeckListPreviewCard.swift` — wire "Import Deck" button to sheet presentation
- `JustTCG/Features/Decks/DeckGeneratorView.swift` — host the import sheet state + pass `modelContext`
- `JustTCG/Features/Decks/DecksView.swift` — receive a "new deck created" callback to show toast and navigate

**Suggested name derivation:**
```swift
private func suggestedName(from deckList: String) -> String {
    let firstLine = deckList
        .split(separator: "\n")
        .first { line in
            let tokens = line.split(separator: " ")
            return tokens.count >= 2 && Int(tokens[0]) != nil
        }
    guard let line = firstLine else { return "Generated Deck" }
    // Drop the count token and the trailing set/number tokens: "4 Charizard ex OBF 125" → "Charizard ex"
    let tokens = line.split(separator: " ").dropFirst()
    let name = tokens.prefix(while: { !$0.allSatisfy({ $0.isUppercase || $0.isNumber }) }).joined(separator: " ")
    return name.isEmpty ? "Generated Deck" : "\(name) Deck"
}
```

**Import flow reuses existing infrastructure:**
```swift
// Parse
let entries = DeckListParser.parse(deckList)

// Resolve cards (same as ImportDeckSheet / M10-02)
let lookup = DeckImportCardLookup(cards: allCachedCards)
let (resolved, unresolved) = lookup.resolve(entries: entries)

// Create deck
let deck = DeckRepository(modelContext: context).createDeck(name: deckName)
for entry in resolved {
    DeckRepository(modelContext: context).addCard(cardId: entry.card.id, to: deck, ...)
}
```
