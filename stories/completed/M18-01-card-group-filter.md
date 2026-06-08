# M18-01 — Card Group Filter in Cards Tab

**Status:** done  
**Milestone:** M18 — Card Browser UX  
**Dependencies:** none

## User Story

As a player, I want to filter the Cards tab by card group (Pokémon, Supporter, Item, Tool, Stadium, ACE SPEC, Energy) so I can quickly browse all Supporters or Pokémon without opening the full filter sheet.

## Acceptance Criteria

- [x] A horizontal scrollable chip strip appears below the search bar and above the card grid on the Cards tab
- [x] The chips are: **All · Pokémon · Supporter · Item · Tool · Stadium · ACE SPEC · Energy**
- [x] Tapping a chip selects it (filled/tinted style) and filters the grid; tapping the selected chip again (or tapping **All**) clears the filter
- [x] Only one group chip can be active at a time
- [x] The active group chip appears as an active filter chip in the existing `activeChips` row (if it is already visible) with a clear button — tapping clear on that chip resets the group to "All"
- [x] The group filter composes correctly with all existing `CardFilterState` filters (search text, sets, HP range, role tags, etc.)
- [x] `CardFilterState.isEmpty` returns `false` when a group is selected

## Technical Notes

**Files to change:**
- `JustTCG/Features/Cards/CardFilterState.swift`
- `JustTCG/Features/Cards/CardsView.swift`

### 1. New `CardGroup` enum

Add to `CardFilterState.swift`:

```swift
enum CardGroup: String, CaseIterable, Identifiable {
    case pokemon  = "Pokémon"
    case supporter = "Supporter"
    case item      = "Item"
    case tool      = "Tool"
    case stadium   = "Stadium"
    case aceSpec   = "ACE SPEC"
    case energy    = "Energy"

    var id: String { rawValue }
}
```

### 2. `CardFilterState` additions

```swift
// New stored property
var cardGroup: CardGroup? = nil
```

Update `isEmpty`:
```swift
var isEmpty: Bool {
    cardGroup == nil && /* existing checks */
}
```

Update `passes(_ card:)` — insert before `return true`:
```swift
if let group = cardGroup {
    switch group {
    case .pokemon:
        if card.types.isEmpty || card.supertype == "Energy" { return false }
    case .supporter:
        if !card.subtypes.contains("Supporter") { return false }
    case .item:
        if !card.subtypes.contains("Item") { return false }
    case .tool:
        if !card.subtypes.contains("Pokémon Tool") { return false }
    case .stadium:
        if !card.subtypes.contains("Stadium") { return false }
    case .aceSpec:
        if !card.subtypes.contains("ACE SPEC") { return false }
    case .energy:
        if card.supertype != "Energy" { return false }
    }
}
```

Update `activeChips`:
```swift
if let group = cardGroup {
    chips.append(FilterChipItem(id: "cardGroup", label: group.rawValue))
}
```

Update `clearChip`:
```swift
case "cardGroup": cardGroup = nil
```

### 3. Chip strip UI in `CardsView`

Add a `@State private var selectedGroup: CardGroup? = nil` that stays in sync with `filterState.cardGroup`.

Place the strip in a `.safeAreaInset(edge: .top)` or directly inside the `NavigationStack` content `VStack` above the `LazyVGrid`. The strip is a `ScrollView(.horizontal, showsIndicators: false)` containing an `HStack(spacing: 8)` of `CardGroupChip` views:

```swift
private var groupChipStrip: some View {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
            groupChip(nil, label: "All")
            ForEach(CardGroup.allCases) { group in
                groupChip(group, label: group.rawValue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private func groupChip(_ group: CardGroup?, label: String) -> some View {
    let isSelected = filterState.cardGroup == group
    return Text(label)
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor : Color(.secondarySystemFill))
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(Capsule())
        .onTapGesture {
            filterState.cardGroup = isSelected ? nil : group
        }
}
```

The strip always renders (even with zero active filters) so it's immediately accessible — it is not gated behind the advanced filter sheet.
