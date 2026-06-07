# M12-02 — Player Detail View

**Status:** todo  
**Milestone:** M12 — Player Profiles  
**Dependencies:** M12-01, M5-03

## User Story

As a user, I want to tap a player's name in the tournament standings and see their full career stats and deck history, so I can research competitive players and understand what they've been playing.

## Acceptance Criteria

### API

- [ ] `LimitlessTCGClient` gains a new method:
  ```swift
  func fetchPlayerProfile(id: String) async throws -> LimitlessPlayerProfile
  ```
- [ ] `LimitlessPlayerProfile` is a value type with:
  - `id: String`
  - `name: String`
  - `country: String`
  - `totalPoints: Int`
  - `totalPrizeMoney: Int` (in USD cents or dollars — match whatever the API returns)
  - `travelAwards: Int`
  - `topCuts: PlayerTopCuts`
  - `results: [PlayerTournamentResult]`
- [ ] `PlayerTopCuts` breaks down top-cut finishes by tier and placement:
  - `internationalWins`, `internationalTop2`, `internationalTop4`, `internationalTop8: Int`
  - `regionalWins`, `regionalTop2`, `regionalTop4`, `regionalTop8: Int`
- [ ] `PlayerTournamentResult` contains:
  - `tournamentId: String`
  - `tournamentName: String`
  - `date: Date`
  - `placement: Int`
  - `record: String` (e.g. `"9-2-0"`)
  - `archetype: String`
  - `points: Int`
  - `prizeMoney: Int?`
  - `deckListId: String?` — `nil` if deck list is not public

### Player Detail View

- [ ] Tapping a player name in `TournamentDetailView` standings navigates to `PlayerDetailView(playerId:)`
- [ ] `PlayerDetailView` shows a loading state while the profile fetch is in flight
- [ ] On load error, an inline retry button is shown
- [ ] The view has three sections:

#### Header
- Player name as the navigation title (`.navigationBarTitleDisplayMode(.large)`)
- Country flag emoji + country name in secondary text beneath the name
- A row of summary chips: **X pts** · **$Y,000** · **Z travel awards**

#### Career Stats
- A 2×4 grid (Internationals / Regionals rows × 1st / T2 / T4 / T8 columns)
- Each cell shows the count in bold with a small label below (e.g. `"1st"`, `"T8"`)
- Zero counts are shown as `"—"` in secondary colour

#### Tournament History
- Full chronological list of `PlayerTournamentResult`, newest first
- Each row shows:
  - Placement badge: rank number in a small capsule, gold for 1st, silver for 2nd, bronze for 3rd, gray otherwise
  - Tournament name (bold) + date in secondary text on a second line
  - Archetype name (trailing, secondary)
  - Record (e.g. `"9-2-0"`) in tertiary text below archetype
  - Points earned (e.g. `"+27 pts"`) on the trailing edge
- Rows with a public deck list are tappable → push to `DeckListViewer` (M5-03) passing `deckListId`
- Rows without a public deck list are non-tappable; a `lock` SF Symbol appears instead of a chevron

## Technical Notes

- `PlayerDetailView.swift` lives at `JustTCG/Features/Players/PlayerDetailView.swift`
- `PlayerDetailViewModel.swift` lives alongside it; owns the fetch and exposes `@Published var state: LoadingState<LimitlessPlayerProfile>`
- The view model takes `playerID: String` in its init and begins fetching on `task { await viewModel.load() }`
- Reuse the existing `LimitlessTCGClient` singleton — do not create a new networking layer
- The career stats grid can be built with a `LazyVGrid(columns: [GridItem(.flexible())] × 4)`; no new shared component needed
