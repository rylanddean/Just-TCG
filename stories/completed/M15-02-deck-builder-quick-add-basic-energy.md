# M15-02 — Deck Builder: Quick-Add Basic Energy

**Status:** done  
**Area:** M2 — Deck Builder  
**Related stories:** M15-01, BUG-06, BUG-07

## Description

Adding Basic Energy cards currently requires opening the full Card Picker, waiting for it to load, searching for the energy type, then tapping to add. Basic Energies are structurally different from all other cards — there is no copy limit, every deck runs them, and there are only nine types. They deserve a dedicated fast-path directly in `DeckBuilderView`.

## Desired Behaviour

An **Energy** sub-section button (or inline quick-add row) appears at the bottom of the Energy section (or as a separate section below Energy). It lets the player tap a basic energy type icon to increment that energy's count by one without ever opening the Card Picker.

### Quick-add strip

Render a horizontally scrollable strip of tappable energy type chips inside the Energy section footer (or as its own section):

```
[ ⚡ Lightning ] [ 🔥 Fire ] [ 💧 Water ] [ 🌿 Grass ] [ ❤️ Fighting ] [ 🌀 Psychic ] [ 🪨 Darkness ] [ 🧲 Metal ] [ ⭐ Colorless ]
```

- Each chip shows the energy type name (and optionally a colour-matched dot/icon)
- Tapping a chip: if that energy card is already in the deck, increment its quantity by 1; if not, look it up in the card cache and add it with quantity 1
- The chip is disabled only if the total deck size is already 60
- No copy cap applies (Basic Energy is unlimited)

### Energy type → card resolution

Each basic energy type maps to a canonical card in the local card cache (`CachedCard` where `isBasicEnergy == true` and `name == "<Type> Energy"`). If multiple printings exist in the cache, prefer the one whose `setCode` matches the most recently released legal set (highest `setReleaseDate`). If no match exists in the cache the chip is hidden (avoids a broken state on fresh install before sync).

## Implementation Plan

### 1. `DeckBuilderViewModel`

Add a new computed property listing the nine basic energy types and their resolved `CachedCard?`:

```swift
var basicEnergyTypes: [(typeName: String, card: CachedCard?)] {
    let types = ["Fire", "Water", "Grass", "Lightning", "Fighting",
                 "Psychic", "Darkness", "Metal", "Colorless"]
    return types.map { t in
        let match = cachedCards.values
            .filter { $0.isBasicEnergy && $0.name == "\(t) Energy" }
            .max(by: { ($0.setReleaseDate ?? .distantPast) < ($1.setReleaseDate ?? .distantPast) })
        return (typeName: t, card: match)
    }
}
```

Add a method:

```swift
func quickAddBasicEnergy(card: CachedCard) {
    if let existing = deck.cards.first(where: { $0.cardId == card.id }) {
        deckRepo.setQuantity(existing.quantity + 1, cardId: card.id, in: deck)
    } else {
        deckRepo.addCard(cardId: card.id, to: deck)
        cachedCards[card.id] = card
    }
    revalidate()
}
```

`basicEnergyTypes` must also search cards that are in the full card repo (not just `cachedCards`), since a basic energy won't be in `cachedCards` until it has been added to the deck. Update `loadCards()` (or add a separate `loadBasicEnergyIndex()` call) to pre-fetch all `isBasicEnergy == true` cards from `CardRepository` into a separate `basicEnergyIndex: [String: CachedCard]` dictionary.

### 2. `DeckBuilderView`

Add a `basicEnergyQuickAddSection(vm:)` builder method that renders the horizontal strip below the Energy section:

```swift
@ViewBuilder
private func basicEnergyQuickAddSection(vm: DeckBuilderViewModel) -> some View {
    let available = vm.basicEnergyTypes.filter { $0.card != nil }
    if !available.isEmpty {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(available, id: \.typeName) { entry in
                        Button {
                            vm.quickAddBasicEnergy(card: entry.card!)
                        } label: {
                            Text(entry.typeName)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.totalCount >= 60)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Add Basic Energy")
        }
    }
}
```

Insert `basicEnergyQuickAddSection(vm: vm)` in `builderList` immediately after `energySection(vm: vm)` and before the "Add Cards" section.

### 3. `CardRepository`

Ensure `CardRepository` exposes a method to fetch all basic energy cards:

```swift
func fetchBasicEnergies() throws -> [CachedCard]
```

Use a SwiftData predicate: `supertype == "Energy" && subtypes contains "Basic"`.

## Acceptance Criteria

- [x] A "Add Basic Energy" section appears below the Energy section
- [x] The section contains a horizontally scrollable row of chips, one per basic energy type available in the local card cache
- [x] Tapping a chip with no existing copies in the deck adds the card at quantity 1
- [x] Tapping a chip with existing copies increments the count by 1
- [x] The energy section count (`"Energy · N"`) and the total count (`N / 60`) both update immediately after a tap
- [x] Chips are disabled when the deck is full (60 cards)
- [x] Basic Energy types with no matching card in the local cache are hidden (not shown as disabled chips)
- [x] The quick-add section does not appear for cards with no basic energy cards at all in cache
- [x] No regression in opening the full Card Picker, which can still be used for adding non-basic energy and adjusting quantities

## Technical Notes

- Files to change: `DeckBuilderViewModel.swift`, `DeckBuilderView.swift`, `CardRepository.swift`
- `isBasicEnergy` is already defined on `CachedCard` as `supertype == "Energy" && subtypes.contains("Basic")` — use it as the predicate anchor
- The preferred printing resolution (latest set) keeps the exported deck list using a current printing, which matters for clipboard export compatibility
- Type names must match actual card names exactly: `"Fire Energy"`, `"Water Energy"`, etc. — confirm against bundled card data if any differ
- Consider storing `basicEnergyIndex` as a `[String: CachedCard]` keyed by `typeName` (e.g. `"Fire"`) for O(1) lookup in `quickAddBasicEnergy`
