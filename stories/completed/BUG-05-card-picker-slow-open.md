# BUG-05 — "Add Cards" Card Picker Is Slow to Open With No Loading Indicator

**Status:** completed  
**Area:** M2 — Deck Builder  
**Related stories:** M2-04, BUG-03

## Description

Tapping "Add Cards" in the Deck Builder opens `CardPickerView`, but the sheet takes multiple seconds to become usable. During that time there is no spinner or any indication that work is happening — the list just appears empty, so it looks frozen/broken rather than loading.

Yes, it is reading from the locally seeded/scraped cards (the `CachedCard` SwiftData store), not the network — so the delay is local query cost, not a download.

## Steps to Reproduce

1. Open any deck in the Deck Builder
2. Tap "Add Cards"
3. Observe: the sheet presents, but the card list stays blank for ~1–3 seconds with no loading affordance before cards populate

## Likely Cause

`CardPickerView.loadInitial()` runs three separate full-table reads against the main-actor `ModelContext`, back to back, the moment the sheet appears:

- `fetchDistinctSets()` — fetches **every** standard-legal `CachedCard`, sorted, then de-dupes in Swift
- `fetchDistinctRarities()` — fetches **every** standard-legal `CachedCard` again, then builds a frequency map in Swift
- `loadCards()` → `fetchFromDB(...)` — fetches the full standard-legal set a **third** time to populate the list

With the bundled card data (15 sets, thousands of rows) this means three full materializations of the table — including all stored properties / arrays on each `CachedCard` — on the main context before the first frame of content. There is also no `ProgressView` while `cards` is still empty, so the user sees a blank list instead of a loading state.

## Acceptance Criteria

- [x] Opening the card picker shows content (or a loading indicator) within a fraction of a second
- [x] A visible loading affordance (e.g. `ProgressView`) is shown while the initial fetch is in flight, instead of a blank list
- [x] Distinct sets / rarities are derived without scanning the full table multiple times (or are computed lazily / cached, not on every open)
- [x] No regression to search, filter, and sort behaviour
- [x] Cards still come from the local `CachedCard` store (no network call on open)

## Technical Notes

- View: `JustTCG/Features/Decks/CardPickerView.swift`
  - `loadInitial()` (~line 162) calls `fetchDistinctSets()`, `fetchDistinctRarities()`, then `await loadCards()`
  - `body` `Group` has no loading branch — when `cards` is empty and there's no query/filter it falls through to `pickerList` (an empty `List`)
- Repository: `JustTCG/Data/Repositories/CardRepository.swift`
  - `fetchDistinctSets()` (~line 130) and `fetchDistinctRarities()` (~line 153) each do a full `context.fetch` of all standard-legal cards
  - `fetchFromDB(...)` (~line 166) does a third full fetch for the `(true, true)` case
- Possible directions:
  - Add a `@State private var isLoading` and show a `ProgressView` until the first load completes
  - Collapse the distinct-sets / distinct-rarities derivation so the table is only scanned once (or fetch only the needed columns), and/or cache the results since they don't change between opens
  - Consider `fetchLimit` / pagination for the initial list, mirroring the `hasAnyStandardCards()` `fetchLimit: 1` pattern already in the repo
