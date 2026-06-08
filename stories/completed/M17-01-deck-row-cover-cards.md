# M17-01 — Deck Row Cover Card Thumbnails

**Status:** done  
**Milestone:** M17 — Deck List UX  
**Dependencies:** none

## User Story

As a player, I want to see card art thumbnails next to each deck name on the Decks tab so that I can visually identify my decks at a glance without having to open them.

## Acceptance Criteria

- [x] Each row in the Decks list displays 1–3 overlapping Pokémon card thumbnails to the right of the deck name/info column
- [x] Cover cards are selected by picking the Pokémon cards in the deck with the highest quantities (ties broken alphabetically by card name), taking the top N where N is the user's cover-card-count preference
- [x] If the deck contains no Pokémon cards, the thumbnail area is empty and the row layout does not shift
- [x] A user preference (1, 2, or 3 cards) is stored in `@AppStorage("deckRowCoverCardCount")` with a default of `2`
- [x] The preference is exposed as a segmented picker in `SettingsView` labelled "Cover cards"
- [x] Card images load asynchronously via `AsyncImage`; while loading a placeholder rectangle (`.fill(.quaternary)`) is shown at the same size
- [x] The thumbnail stack uses a leading-overlap layout: cards are arranged right-to-left in a `ZStack`, each successive card offset `+18 pt` on the x-axis and placed lower in the z-stack so the first card is always on top
- [x] Each thumbnail is clipped to a rounded rectangle with `cornerRadius: 4` and rendered at `44 × 60 pt`
- [x] The overall thumbnail cluster is right-aligned within the row and does not truncate the deck name

## Technical Notes

**Files to change:**
- `JustTCG/Features/Decks/DecksView.swift`
- `JustTCG/Features/Settings/SettingsView.swift` (add segmented picker)

**Resolving card images:** `DecksView` should fetch a `[String: CachedCard]` lookup map once (via `@Query var allCards: [CachedCard]` converted to a dictionary keyed by `id`). Pass the map down to `DeckRowView` so card lookups are O(1) per row with no per-row SwiftData queries.

**Cover card selection helper** (private to `DeckRowView` or a free function):
```swift
func coverCards(for deck: Deck, in cardMap: [String: CachedCard], count: Int) -> [CachedCard] {
    deck.cards
        .compactMap { dc -> (DeckCard, CachedCard)? in
            guard let card = cardMap[dc.cardId], !card.types.isEmpty else { return nil }
            return (dc, card)
        }
        .sorted { lhs, rhs in
            lhs.0.quantity != rhs.0.quantity
                ? lhs.0.quantity > rhs.0.quantity
                : lhs.1.name < rhs.1.name
        }
        .prefix(count)
        .map(\.1)
}
```

**Thumbnail ZStack layout** (for N = 3, total width ≈ 44 + 2 × 18 = 80 pt):
```swift
ZStack(alignment: .leading) {
    ForEach(Array(cards.enumerated().reversed()), id: \.offset) { index, card in
        AsyncImage(url: URL(string: card.imageURL)) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: 4).fill(.quaternary)
        }
        .frame(width: 44, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .offset(x: CGFloat(index) * 18)
    }
}
.frame(width: 44 + CGFloat(max(cards.count - 1, 0)) * 18, height: 60)
```

**Row layout:** Replace the current `VStack` body of `DeckRowView` with an `HStack(alignment: .center)` — the existing `VStack` (name + count/win-rate) on the left (`.frame(maxWidth: .infinity, alignment: .leading)`) and the thumbnail `ZStack` on the right.
