# M12-03 — Favourite Star Toggle & Favourites List

**Status:** todo  
**Milestone:** M12 — Player Profiles  
**Dependencies:** M12-01, M12-02

## User Story

As a user, I want to star players as favourites from both the tournament standings and a player's profile page, and see my favourites listed at the top of the Tournaments tab, so I can quickly follow the players I care about.

## Acceptance Criteria

### Star Toggle on Player Detail View

- [ ] A star toolbar button (`star` / `star.fill`) appears in the top-right of `PlayerDetailView`
- [ ] The button reflects current favourite state on appear — filled and yellow if already a favourite, outlined otherwise
- [ ] Tapping the button toggles the favourite:
  - If not yet favourited: calls `FavouritePlayerRepository.add` with the loaded profile's `id`, `name`, and `country`
  - If already favourited: calls `FavouritePlayerRepository.remove(id:)`
- [ ] The button updates immediately (no async delay) — the repository write is synchronous on the main actor

### Star Action in Tournament Standings

- [ ] Each placement row in `TournamentDetailView` standings gains a leading swipe action: **"Favourite"** (star icon, yellow tint)
- [ ] If the player is already a favourite, the swipe action label reads **"Unfavourite"** (star.slash icon, gray tint)
- [ ] Performing the action toggles the favourite state, using the player's name from `LimitlessPlacement.playerName` and a placeholder country `""` — country is backfilled when the player's profile is eventually loaded
- [ ] The swipe action does **not** navigate away; it commits the toggle in place

### Favourites List in Tournaments Tab

- [ ] A **"Favourite Players"** section appears at the top of the Tournaments tab (`TournamentListView`) when `FavouritePlayerRepository.all` is non-empty
- [ ] The section shows a horizontal scroll row of player chips (name + country flag emoji), or a vertical list — either layout is acceptable
- [ ] Tapping a chip navigates to `PlayerDetailView` for that player
- [ ] When `FavouritePlayerRepository.all` is empty the section is hidden entirely — no empty state placeholder
- [ ] A player chip can be removed (long-press context menu: **"Remove from Favourites"**)

## Technical Notes

- Read `FavouritePlayerRepository` from the SwiftUI environment in `PlayerDetailView`, `TournamentDetailView`, and `TournamentListView` — it must be injected at the root in `ContentView` or the app entry point
- The star button state must re-evaluate when the view appears in case the user toggled from a different entry point (e.g. starred via swipe in standings, then opens the profile)
- Do not replicate `FavouritePlayer` data into the swipe action path — store only `id` + `name` + `""` country when starring from standings; `PlayerDetailView` will correct the country on next load automatically via `FavouritePlayerRepository.add` (no-op for duplicate `id`)
- The Tournaments tab section does not need its own view model — bind directly to `FavouritePlayerRepository.all` via `@Environment`
