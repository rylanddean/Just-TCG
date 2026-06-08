# BUG-11 — Card Picker Blank When Cards Tab Has Never Been Opened

**Status:** done  
**Area:** M2 — Deck Builder / Data Seeding  
**Related stories:** M2-04, BUG-09

## Description

After BUG-09 was resolved (the "Add Cards" button is now tappable), the `CardPickerView` sheet opens but shows a blank, permanently-empty list. No cards ever appear, and no loading indicator is shown.

## Steps to Reproduce

1. Fresh install (or after seed key is bumped — e.g. v6 → v8)
2. Open the app and go directly to the **Decks** tab
3. Open any deck and tap **Add Cards**
4. Observe: the picker sheet opens but shows nothing

Note: the issue does NOT occur if the user visits the **Cards** tab before step 3, because `CardsView.initialLoad()` calls `BundledCardSeeder.seedIfNeeded`.

## Root Cause

`BundledCardSeeder.seedIfNeeded(context:)` is only called from `CardsView.initialLoad()`. This means the `CachedCard` SwiftData store is not populated until the user opens the Cards tab at least once.

`CardPickerView` fetches cards via `CardRepository.fetchPickerSeed`, which reads from the same `CachedCard` store. If seeding hasn't run, the store is empty and `fetchPickerSeed` returns `CardPickerSeed(cards: [], ...)`. The picker renders an empty `List` and stays that way.

The `if let seed = try? repo.fetchPickerSeed(...)` guard in `CardPickerView.loadInitial()` silently drops the result on error but also on an empty store — either way, `cards` stays `[]` and `isLoading` is cleared, leaving a permanently blank list.

## Fix

Move `BundledCardSeeder.seedIfNeeded(context:)` up to `ContentView` (the app root), so it fires at launch regardless of which tab the user opens first. The seeder is idempotent — when `CardsView` calls it later, it is a no-op.

## Acceptance Criteria

- [x] Opening "Add Cards" on a fresh install (or after a seed key bump) populates the picker with cards, even if the Cards tab has never been opened
- [x] Visiting the Cards tab first is no longer a prerequisite for the picker to work
- [x] No regression: the Cards tab still loads correctly

## Technical Notes

- Fix: add `.task { await BundledCardSeeder.seedIfNeeded(context: context) }` to `ContentView`
- `CardsView.initialLoad()` retains its own `seedIfNeeded` call — that call becomes a no-op once `ContentView` has already seeded, which is correct
- File changed: `JustTCG/App/ContentView.swift`
