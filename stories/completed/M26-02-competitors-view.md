# M26-02 — Competitors View

**Status:** done  
**Milestone:** M26 — Competition Tab  
**Dependencies:** M26-01, M12-01, M12-02

## User Story

As a player, I want a dedicated Competitors screen where I can search for any player by name, view their profile, and manage the players I follow, so I don't have to remember Limitless player IDs or dig through the Tournaments tab to find a specific competitor.

## Acceptance Criteria

### `CompetitorsView`
- [ ] New view at `JustTCG/Features/Competition/CompetitorsView.swift`
- [ ] Uses `.searchable(text:, placement: .navigationBarDrawer)` for a persistent search bar
- [ ] While the search query is empty: shows only the **Favourites** section
- [ ] While the search query is non-empty (≥ 1 character): shows **Search Results** (with a loading/error state) and hides the Favourites section

### Favourites Section
- [ ] Replaces the horizontal chip strip previously in `TournamentsView` with a vertical `List` of `FavouritePlayerRow` items
- [ ] Each row shows: country flag emoji + player name, with a chevron indicating it's navigable
- [ ] Tapping navigates to `PlayerDetailView(playerID:)` (existing view, unchanged)
- [ ] Swipe-to-delete removes the player from `FavouritePlayerRepository`
- [ ] Empty state (no favourites, empty search): centred prompt "Search for a competitor to view their profile and follow them."

### Player Search
- [ ] Submitting or debouncing (300 ms) the search query calls `LimitlessTCGClient.searchPlayers(query:)` (new method — see below)
- [ ] Results are displayed as `PlayerSearchResultRow` items: flag + name + country chip
- [ ] Tapping a result navigates to `PlayerDetailView(playerID: result.id)`
- [ ] A loading `ProgressView` replaces the list while the search is in-flight
- [ ] Network error state shows a "Couldn't search players" message with a retry button
- [ ] Empty search results state: "No players found for '\(query)'."
- [ ] A favourited player appears in results with a filled star icon trailing the row

### New Client Method: `LimitlessTCGClient.searchPlayers(query:)`
- [ ] New method added to `LimitlessTCGClient`:
  ```swift
  func searchPlayers(query: String) async throws -> [LimitlessPlayerSearchResult]
  ```
- [ ] Fetches `https://limitlesstcg.com/players?q=<url-encoded-query>` and parses the HTML response
- [ ] New struct `LimitlessPlayerSearchResult: Identifiable` added to `LimitlessModels.swift`:
  ```swift
  struct LimitlessPlayerSearchResult: Identifiable {
      let id: String    // Limitless player slug used in the profile URL
      let name: String
      let country: String
  }
  ```
- [ ] New parser method `LimitlessHTMLParser.parsePlayerSearchResults(from html: String) -> [LimitlessPlayerSearchResult]` added to `LimitlessHTMLParser.swift`
- [ ] Returns an empty array (not an error) when no results are found

### `CompetitorsViewModel`
- [ ] New `@Observable` class `CompetitorsViewModel` at `JustTCG/Features/Competition/CompetitorsViewModel.swift`
- [ ] Manages: `searchResults: [LimitlessPlayerSearchResult]`, `isSearching: Bool`, `searchError: String?`
- [ ] `func search(query: String) async` debounces and triggers `searchPlayers`
- [ ] `func cancelSearch()` clears results and resets state

## Technical Notes

**New files:**
- `JustTCG/Features/Competition/CompetitorsView.swift`
- `JustTCG/Features/Competition/CompetitorsViewModel.swift`

**Files to change:**
- `JustTCG/Data/LimitlessTCGClient/LimitlessTCGClient.swift` — add `searchPlayers(query:)`
- `JustTCG/Data/LimitlessTCGClient/LimitlessModels.swift` — add `LimitlessPlayerSearchResult`
- `JustTCG/Data/LimitlessTCGClient/LimitlessHTMLParser.swift` — add `parsePlayerSearchResults(from:)`
- `JustTCG/Features/Tournaments/TournamentsView.swift` — remove `favouritePlayersSection` and all related helpers

**Debounce pattern:**
```swift
.onChange(of: searchQuery) { _, query in
    searchTask?.cancel()
    guard !query.isEmpty else {
        vm.cancelSearch()
        return
    }
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await vm.search(query: query)
    }
}
```

**`FavouritePlayerRow`:**
```swift
private struct FavouritePlayerRow: View {
    let player: FavouritePlayer

    var body: some View {
        HStack(spacing: 10) {
            if !player.country.isEmpty {
                Text(countryFlag(player.country))
            }
            Text(player.name)
                .font(.body)
        }
    }
}
```

**Search result URL:**
`https://limitlesstcg.com/players?q=<query>` — the player `id` is the slug that appears in each result's profile link (e.g. `/players/ryland-dean` → id is `ryland-dean`).
