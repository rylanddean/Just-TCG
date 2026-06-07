# M8-02 — Sort Controls UI

**Status:** done  
**Milestone:** M8 — Card Sorting  
**Dependencies:** M8-01

## User Story

As a user, I want a dedicated sort button in the card browser toolbar that lets me switch between sort orders with a single tap, with the current order clearly indicated, so that sorting feels distinct from filtering and is always one tap away.

## Acceptance Criteria

### Toolbar Button

- [x] A sort button appears in the trailing toolbar, to the **left** of the existing filter button
- [x] Icon: `arrow.up.arrow.down` when the active sort is `.expansion`; `arrow.up.arrow.down.circle.fill` when any non-default sort is active
- [x] Tapping the sort button presents a `Menu` inline listing all five sort options
- [x] Each menu item shows the sort name and a `checkmark` trailing icon next to the currently active option
- [x] Selecting the already-active sort is a no-op

### Sort Menu Labels

| Case | Menu Label |
|---|---|
| `.expansion` | Expansion (Newest First) |
| `.name` | Name (A → Z) |
| `.hp` | HP (Highest First) |
| `.attackDamage` | Attack Damage (Highest First) |
| `.regulationMark` | Regulation Mark (Latest First) |

### Behaviour

- [x] Changing the sort order immediately re-fetches and re-renders the card grid
- [x] Sort state is held in `@State private var sortOrder: CardSortOrder = .expansion` in `CardsView` and `CardPickerView`
- [x] `onChange(of: sortOrder)` triggers `loadCards()`
- [x] Sort state resets to `.expansion` on cold launch — no persistence to `UserDefaults`
- [x] The sort icon and menu are present in both `CardsView` and `CardPickerView`

### No Sort Chips

- [x] Sort order is **not** shown as a chip in the filter chips row

### Accessibility

- [x] The toolbar button has an `accessibilityLabel` of `"Sort cards"` and `accessibilityValue` equal to the current sort order's menu label

## Technical Notes

- Used SwiftUI's `Menu` with a `Label` initialiser for the toolbar button
- Both views update `loadCards()` to include `sortOrder` in the `CardRepository.fetch` call
