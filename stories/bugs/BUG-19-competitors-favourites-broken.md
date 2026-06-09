# BUG-19 — Competitors View: Favourite Players Section Is Broken

**Status:** todo  
**Area:** M26 — Competition Tab

## Description

The Favourites section in `CompetitorsView` is functionally incomplete and visually inconsistent. `FavouritePlayerRow` only shows a country flag and name with no secondary info, no rank badge, and no indication of whether the player currently has leaderboard data. Additionally, favourites are added via a leading swipe action in the standings, but there is no way to add a player as a favourite from the search results swipe actions — only leaderboard players can be favourited. The section needs a proper visual treatment and to be functionally complete.

## Steps to Reproduce

1. Open the Competition tab
2. Favourite a player via a leading swipe in the standings section
3. Observe the Favourites section at the top of the list

## Observed Behaviour

- Favourite rows show only a flag emoji and player name — no rank, no points, no secondary label
- Visually inconsistent with `LeaderboardRow` which shows rank, flag, name, points, and a star
- Swipe-to-delete works, but there is no "Unfavourite" label on the destructive action — it shows as a raw red delete icon
- No way to favourite a player from the search results section (swipe actions missing on search result rows)
- Tapping a favourite row navigates to `PlayerDetailView` — this works correctly

## Desired Behaviour

- Favourite rows look polished with a consistent layout: star icon, flag, player name, and a subtitle showing their most recent known rank/points (stored at time of favouriting)
- The swipe-to-delete action on favourite rows has an "Unfavourite" label and a yellow tint (matching the favourite action style)
- Leading swipe to favourite/unfavourite is available on search result rows, not just leaderboard rows

## Acceptance Criteria

### Data
- [ ] `FavouritePlayer` stores a `lastKnownPoints: Int?` and `lastKnownRank: Int?` — populated when the player is added from a leaderboard or search row
- [ ] When adding a favourite from `LeaderboardRow`, populate `lastKnownPoints` and `lastKnownRank` from `LimitlessPlayerSearchResult`

### Favourites Row
- [ ] `FavouritePlayerRow` shows: star icon (yellow) | country flag | player name | last-known rank or points as a secondary caption
- [ ] If `lastKnownPoints` and `lastKnownRank` are both nil, the subtitle is omitted
- [ ] Swipe-to-delete on a favourite row has label "Unfavourite", yellow tint, and a `star.slash` icon (not the default red trash)

### Search Results
- [ ] `LeaderboardRow` used in the search results section gains the same leading swipe-to-favourite action it has in the standings section
- [ ] Tapping the swipe action on a search result row adds the player as a favourite, capturing their current points/rank if present

## Technical Notes

**Files to change:**
- `JustTCG/Features/Players/Models/FavouritePlayer.swift` — add `lastKnownPoints`, `lastKnownRank` stored properties; bump seeder key not required (not a `CachedCard` change)
- `JustTCG/Features/Players/FavouritePlayerRepository.swift` — update `add(_:)` signature to accept the full model
- `JustTCG/Features/Competition/CompetitorsView.swift` — update `FavouritePlayerRow`, fix swipe delete label/tint, add swipe actions to search result rows
- `JustTCG/Features/Tournaments/TournamentDetailView.swift` — update `placementRow` swipe action to pass `lastKnownPoints`/`lastKnownRank` when adding a favourite
