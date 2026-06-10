# M35-02 — Featured Deck Widget

**Status:** done  
**Milestone:** M35 — Featured Deck of the Day  
**Dependencies:** M35-01 (FeaturedDeckEngine), M11-01 (HomeView shell), M22-01 (ArchetypePrimaryCardResolver), M1-02 (CachedCard), M5-03 (DeckListViewer)

## User Story

As a player, I want to see a "Featured Deck of the Day" widget on the Home screen that highlights a random top-8 finish from a recent tournament — showing the player's name, the tournament, their placing, and the deck's main Pokémon — so that I can discover competitive lists and browse them with a single tap.

## Acceptance Criteria

### FeaturedDeckWidgetViewModel

- [ ] New `@Observable final class FeaturedDeckWidgetViewModel` at `JustTCG/Features/Home/FeaturedDeckWidgetViewModel.swift`
- [ ] State:
  ```swift
  private(set) var snapshot: FeaturedDeckSnapshot? = nil
  private(set) var primaryCards: [CachedCard] = []
  private(set) var isLoading = false
  private(set) var error: String? = nil
  ```
- [ ] `load(modelContext: ModelContext)` async method:
  1. Check disk cache (`featured_deck_today.json` in the caches directory) — if a valid, non-stale `FeaturedDeckSnapshot` exists for today, load it, resolve `primaryCards` from the local SwiftData card cache, and return early (no network call)
  2. Otherwise, fetch the 5 most recent tournaments via `LimitlessTCGClient.fetchRecentTournaments(limit: 5)`
  3. Fetch each tournament's detail concurrently using a `TaskGroup`; keep only those with at least one placement
  4. Build a `[FeaturedDeckCandidate]` array: for each tournament+detail pair, map every placement with `rank <= 8` into a `FeaturedDeckCandidate`
  5. Call `FeaturedDeckEngine.pick(from:)` — if `nil`, set an appropriate error message and return
  6. Persist the resulting `FeaturedDeckSnapshot` to disk (JSON, atomic write)
  7. Resolve `primaryCards` from the local SwiftData card cache using `ArchetypePrimaryCardResolver.resolveAll(names:from:)` where `names` = `snapshot.primaryCardNames`
- [ ] `refresh(modelContext:)` clears the disk cache then calls `load(modelContext:)`
- [ ] All network and file I/O runs off the main actor; `snapshot`, `primaryCards`, `isLoading`, `error` are updated on the main actor

### FeaturedDeckWidget

- [ ] New SwiftUI view `FeaturedDeckWidget` at `JustTCG/Features/Home/Widgets/FeaturedDeckWidget.swift`
- [ ] Instantiates and holds `@State private var vm = FeaturedDeckWidgetViewModel()`
- [ ] Calls `vm.load(modelContext:)` in `.task` on first appearance; passes `@Environment(\.modelContext)` to the VM
- [ ] Widget card uses the same card chrome as other Home widgets:
  - `RoundedRectangle` background with `Color(.secondarySystemBackground)`, corner radius `12`
  - `16 pt` horizontal and vertical padding inside the card
- [ ] **Header row** (always visible):
  - Leading: bold label `"Featured Deck"` in `.headline`
  - Trailing: `"Today"` pill — a `Text` in `.caption2` / `.secondary` inside a `Capsule` with `Color(.tertiarySystemFill)` background, `4 × 8` padding
- [ ] **Loading state** (`vm.isLoading == true`): show a `ProgressView()` centred in the card body; minimum card height `120 pt`
- [ ] **Error / empty state** (`vm.snapshot == nil && !vm.isLoading`): show `ContentUnavailableView("No featured deck", systemImage: "trophy")` with subtitle `"Check back when tournament data loads."`
- [ ] **Loaded state** (`vm.snapshot != nil`):

  **Player + tournament row:**
  - Player name in `.title3.bold()`
  - Below it: tournament name in `.subheadline` / `.secondary`, truncated to one line
  - Trailing: placing badge — `Text(ordinal(vm.snapshot.placing))` (e.g. `"1st"`, `"2nd"`, `"7th"`) in `.caption.bold()` / `.white` inside a `RoundedRectangle(cornerRadius: 6)` filled with `Color.accentColor`; badge is `28 × 28 pt` minimum

  **Pokémon card thumbnails:**
  - An `HStack(spacing: 8)` showing up to 3 card thumbnails using `CardThumbnailView` at **`52 × 72 pt`** each
  - Thumbnails are only shown for entries in `vm.primaryCards`; if `primaryCards` is empty, this row is hidden
  - Remaining space in the `HStack` is filled with a `Spacer()`

  **"See Deck" button:**
  - Shown only when `vm.snapshot?.deckListId != nil`
  - Style: full-width, `.bordered` button with label `"See Deck"` and SF Symbol `"list.bullet.rectangle"` leading
  - Tapping sets `@State private var showDeckViewer = true`
  - `.sheet(isPresented: $showDeckViewer)`: presents `NavigationStack { DeckListViewer(listId: vm.snapshot!.deckListId!, placement: nil) }` — pass `nil` for placement since the widget does not have a full `LimitlessPlacement` in scope; the viewer handles the nil case by hiding the import button
  - When `deckListId == nil`, this button is hidden entirely (no disabled state)

### HomeView integration

- [ ] In `HomeView`, add `FeaturedDeckWidget()` to the `LazyVStack` **above** `StreakWidget` — it should be the first widget the user sees on scroll

### Ordinal helper

- [ ] Private `ordinal(_ n: Int) -> String` function inside `FeaturedDeckWidget.swift` that returns `"1st"`, `"2nd"`, `"3rd"`, `"4th"`…`"8th"` using standard English ordinal rules

## Technical Notes

**New files:**
- `JustTCG/Features/Home/FeaturedDeckWidgetViewModel.swift`
- `JustTCG/Features/Home/Widgets/FeaturedDeckWidget.swift`

**Modified file:** `JustTCG/Features/Home/HomeView.swift` — insert `FeaturedDeckWidget()` at the top of the `LazyVStack`

**Disk cache:** `featured_deck_today.json` in `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]` — JSON-encoded `FeaturedDeckSnapshot`; stale check uses `FeaturedDeckSnapshot.isStale(now:)`

**DeckListViewer nil-placement handling:** verify that `DeckListViewer` already tolerates a `nil` placement before shipping — if not, add an optional `placement: LimitlessPlacement?` parameter and guard the import button on `placement != nil`

**No SwiftData `@Query` in the widget:** the VM fetches cards via `modelContext.fetch(FetchDescriptor<CachedCard>())` inside `load(modelContext:)` rather than using a `@Query` property wrapper, since the VM is not a `View`

**Thumbnail sizing:** `52 × 72 pt` preserves the standard Pokémon card aspect ratio (approximately 7:10) at a compact size that fits three cards side-by-side on all supported iPhone widths
