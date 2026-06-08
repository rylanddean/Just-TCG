# M28-01 — Unmatched Card Swap in Import Sheet

**Status:** done  
**Milestone:** M28 — Deck Import Card Swap  
**Dependencies:** M10-01, M10-02, M10-03

## User Story

As a player, when I import a deck and some cards fail to match (because the set or print isn't in my local cache), I want to tap the unmatched row and pick a substitute card from my card cache, so I can complete the import without losing those slots.

## Acceptance Criteria

### Unmatched Row Interaction
- [x] Unmatched rows in `ImportDeckSheet` are tappable (`.contentShape(Rectangle())` + `Button` or `onTapGesture`)
- [x] Tapping an unmatched row opens a `CardSwapSheet` sheet, passing the unmatched `DeckImportEntry`
- [x] The existing yellow triangle icon gains a secondary label "Tap to fix" in caption / tertiary style beneath it to signal the row is interactive
- [x] Matched rows remain non-interactive (no tap target, no "tap to fix" label)

### `CardSwapSheet`
- [x] New view at `JustTCG/Features/Decks/CardSwapSheet.swift`
- [x] Presented as a `.sheet` from `ImportDeckSheet`
- [x] Navigation bar title: "Replace Card", with a "Cancel" dismiss button
- [x] A `TextField` search bar pre-filled with the unmatched entry's name on appear
- [x] Results list: `CachedCard` records where `name` contains the current search string (case-insensitive), filtered to non-empty results only
- [x] Each result row shows:
  - Small card thumbnail (same `AsyncImage` pattern as `CardThumbnailView`, ~36 pt wide)
  - Card name (body weight)
  - Set code + number in caption / secondary style
  - A "Select" label or chevron on the trailing edge
- [x] Tapping a result row:
  1. Calls the `onSelect: (CachedCard) -> Void` callback passed in from `ImportDeckSheet`
  2. Dismisses the sheet
- [x] Empty state (no results for the current query): "No cards found matching '\(query)'." in secondary style
- [x] Loading state: a `ProgressView` while the fetch runs (fetches are SwiftData queries — should be near-instant, but show a spinner for the first render)
- [x] The search fires on every keystroke (`.onChange(of: searchText)`) with no debounce needed — SwiftData fetch predicates are local and fast

### State Update in `ImportDeckSheet`
- [x] `DeckImportMatch.cardId` is changed from `let` to `var` so it can be mutated after the initial resolve
- [x] `ImportDeckSheet` passes an `onSelect` closure to `CardSwapSheet` that:
  1. Finds the index of the tapped unmatched match in `matches`
  2. Sets `matches[index].cardId = selectedCard.id`
- [x] After a swap, the row immediately re-renders with the green checkmark and the "Tap to fix" label disappears
- [x] The "N matched · M unmatched" summary line in the header updates reactively
- [x] The "Import Deck" button enables as soon as `matchedCount > 0` — no change needed to the existing button logic

### Card Search Query
- [x] `CardSwapSheet` uses a local `@State private var searchText` and a manual SwiftData fetch (not `@Query`, since the predicate needs to be dynamic):
  ```swift
  @Environment(\.modelContext) private var context

  private func fetchResults(query: String) -> [CachedCard] {
      guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
      var descriptor = FetchDescriptor<CachedCard>(
          predicate: #Predicate { $0.name.localizedStandardContains(query) },
          sortBy: [SortDescriptor(\.name)]
      )
      descriptor.fetchLimit = 50
      return (try? context.fetch(descriptor)) ?? []
  }
  ```
- [x] Results are stored in `@State private var results: [CachedCard] = []` and recomputed in `.onAppear` and `.onChange(of: searchText)`

## Technical Notes

**New file:** `JustTCG/Features/Decks/CardSwapSheet.swift`

**Files to change:**
- `JustTCG/Data/Import/DeckImportLookup.swift` — change `DeckImportMatch.cardId` from `let` to `var`
- `JustTCG/Features/Decks/ImportDeckSheet.swift` — make unmatched rows tappable, add sheet state, wire `onSelect` callback

**Sheet presentation in `ImportDeckSheet`:**
```swift
@State private var swapEntry: DeckImportMatch? = nil

// In matchRow:
.onTapGesture {
    if !match.isMatched { swapEntry = match }
}

// On the List or outer VStack:
.sheet(item: $swapEntry) { match in
    CardSwapSheet(entry: match.entry) { selectedCard in
        if let idx = matches.firstIndex(where: { $0.entry.name == match.entry.name && !$0.isMatched }) {
            matches[idx].cardId = selectedCard.id
        }
    }
}
```

> `DeckImportMatch` needs to conform to `Identifiable` for `.sheet(item:)` — add `var id: String { entry.name + entry.setCode + entry.number }`.

**`CardSwapSheet` signature:**
```swift
struct CardSwapSheet: View {
    let entry: DeckImportEntry
    let onSelect: (CachedCard) -> Void
    ...
}
```

**`CardSwapSheet` result row:**
```swift
Button {
    onSelect(card)
    dismiss()
} label: {
    HStack(spacing: 12) {
        AsyncImage(url: URL(string: card.imageURL)) { phase in
            if case .success(let img) = phase {
                img.resizable().aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15))
            }
        }
        .frame(width: 36, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 4))

        VStack(alignment: .leading, spacing: 2) {
            Text(card.name).font(.body)
            Text("\(card.setCode) \(card.number)").font(.caption).foregroundStyle(.secondary)
        }

        Spacer()
        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
    }
}
.buttonStyle(.plain)
```
