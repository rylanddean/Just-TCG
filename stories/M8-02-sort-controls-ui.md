# M8-02 — Sort Controls UI

**Status:** todo  
**Milestone:** M8 — Card Sorting  
**Dependencies:** M8-01

## User Story

As a user, I want a dedicated sort button in the card browser toolbar that lets me switch between sort orders with a single tap, with the current order clearly indicated, so that sorting feels distinct from filtering and is always one tap away.

## Acceptance Criteria

### Toolbar Button

- [ ] A sort button appears in the trailing toolbar, to the **left** of the existing filter button
- [ ] Icon: `arrow.up.arrow.down` (SF Symbols) when the active sort is the default (`.expansion`); switches to `arrow.up.arrow.down.circle.fill` when any non-default sort is active — mirroring the filled/unfilled pattern of the existing filter button
- [ ] Tapping the sort button presents a `Menu` inline (not a sheet) listing all five sort options
- [ ] Each menu item shows the sort name and a `checkmark` trailing icon next to the currently active option
- [ ] Selecting the already-active sort is a no-op

### Sort Menu Labels

| Case | Menu Label |
|---|---|
| `.expansion` | Expansion (Newest First) |
| `.name` | Name (A → Z) |
| `.hp` | HP (Highest First) |
| `.attackDamage` | Attack Damage (Highest First) |
| `.regulationMark` | Regulation Mark (Latest First) |

### Behaviour

- [ ] Changing the sort order immediately re-fetches and re-renders the card grid — no manual "Apply" step
- [ ] Sort state is held in `@State private var sortOrder: CardSortOrder = .expansion` in `CardsView` and `CardPickerView` independently
- [ ] `onChange(of: sortOrder)` triggers `loadCards()` (same pattern as `filterState`)
- [ ] Sort state resets to `.expansion` on cold launch — no persistence to `UserDefaults`
- [ ] The sort icon and menu are present in both `CardsView` and `CardPickerView`

### No Sort Chips

- [ ] Sort order is **not** shown as a chip in the filter chips row — sort is not a restriction on results and should not be mixed with filter chips
- [ ] The filled icon variant alone communicates that a non-default sort is active

### Accessibility

- [ ] The toolbar button has an `accessibilityLabel` of `"Sort cards"` and an `accessibilityValue` equal to the current sort order's menu label (e.g. `"Name (A → Z)"`)
- [ ] Menu items are announced with their label and `"Selected"` for the active option (standard `Menu` behaviour in SwiftUI)

## Technical Notes

- Use SwiftUI's `Menu` with a `Label` initialiser for the toolbar button — this gives the native popover presentation without a sheet
- `CardsView.loadCards()` already passes `filterState` properties to `CardRepository.fetch(...)`; add `sortOrder: sortOrder` to that call
- The `CardPickerView` has its own `loadCards()` with the same pattern — update it in the same pass; do not extract a shared view model for this change alone
- Example toolbar snippet:

```swift
ToolbarItem(placement: .navigationBarTrailing) {
    Menu {
        ForEach(CardSortOrder.allCases) { order in
            Button {
                sortOrder = order
            } label: {
                Label(order.menuLabel, systemImage: sortOrder == order ? "checkmark" : "")
            }
        }
    } label: {
        Image(systemName: sortOrder == .expansion
              ? "arrow.up.arrow.down"
              : "arrow.up.arrow.down.circle.fill")
    }
    .accessibilityLabel("Sort cards")
    .accessibilityValue(sortOrder.menuLabel)
}
```

- Place the sort `ToolbarItem` before the filter `ToolbarItem` so the visual order left-to-right is: sort → filter → sync indicator
