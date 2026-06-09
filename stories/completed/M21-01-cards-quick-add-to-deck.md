# M21-01 — Cards View: Long-Press Quick-Add to Deck

**Status:** done  
**Milestone:** M21 — Cards Tab Quick-Add  
**Dependencies:** M2-01, M18-01

## User Story

As a player, I want to long-press a card in the Cards tab to instantly add it to one of my decks, so I can build or update a deck without leaving the card browser.

## Acceptance Criteria

- [x] Long-pressing any card thumbnail in the card grid reveals a context menu
- [x] The context menu contains an **Add to Deck** submenu listing all of the user's decks sorted alphabetically by name
- [x] Tapping a deck name adds one copy of the card to that deck (respecting the 4-copy cap, or 60 for Basic Energy)
- [x] A toast banner reading **"Added to [Deck Name]"** appears at the bottom of the screen for 2 seconds after a successful add
- [x] If the user has no decks, the context menu shows a single disabled label **"No Decks Yet"** instead of the submenu
- [x] The context menu preview shows the card thumbnail at a comfortable size
- [x] Long-pressing still works while a group chip or text filter is active
- [x] The `NavigationLink` to the card detail view continues to work on a normal tap

## Technical Notes

**Files to change:**
- `JustTCG/Features/Cards/CardsView.swift`

### 1. Fetch decks

Add a SwiftData query to `CardsView`:

```swift
@Query(sort: \Deck.name) private var decks: [Deck]
```

### 2. Toast state

```swift
@State private var toastMessage: String? = nil
```

### 3. Context menu on each card

In `cardGrid`, wrap each `NavigationLink` with a `.contextMenu`:

```swift
NavigationLink(destination: CardDetailView(card: card)) {
    CardThumbnailView(card: card)
}
.buttonStyle(.plain)
.contextMenu {
    if decks.isEmpty {
        Text("No Decks Yet")
    } else {
        Menu("Add to Deck") {
            ForEach(decks) { deck in
                Button(deck.name) {
                    quickAdd(card, to: deck)
                }
            }
        }
    }
} preview: {
    CardThumbnailView(card: card)
        .frame(width: 160)
        .padding(8)
}
```

### 4. Quick-add helper

```swift
private func quickAdd(_ card: CachedCard, to deck: Deck) {
    let isEnergy = card.supertype == "Energy"
    DeckRepository(modelContext: context)
        .addCard(cardId: card.id, to: deck, isBasicEnergy: isEnergy, cardName: card.name)
    withAnimation {
        toastMessage = deck.name
    }
    Task {
        try? await Task.sleep(for: .seconds(2))
        withAnimation { toastMessage = nil }
    }
}
```

### 5. Toast overlay

Apply to the `NavigationStack` (same pattern as `DeckBuilderView`):

```swift
.overlay(alignment: .bottom) {
    if let name = toastMessage {
        Text("Added to \(name)")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor, in: Capsule())
            .padding(.bottom, 32)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
.animation(.easeInOut(duration: 0.25), value: toastMessage)
```
