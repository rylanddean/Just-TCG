# M36-03 — Digest Feed View

**Status:** todo  
**Milestone:** M36 — Digest & Reading Queue  
**Dependencies:** M36-01 (DigestItem, ReadQueueItem), M36-02 (DigestFeedEngine), M35-02 (FeaturedDeckWidgetViewModel), M5-03 (DeckListViewer), M11-01 (HomeView shell)

## User Story

As a player, I want to scroll a single digest feed where I can read deck lists and meta insights inline — and queue anything for later with one tap — so I don't have to navigate away from my browsing context just to look at something interesting.

## Background

The current flow requires the user to navigate into a detail view to read any piece of content (deck list, tournament result, meta snapshot). This means browse sessions are interrupted by navigation: you tap into a deck, read it, back out, repeat. The digest view collapses that into a single scrollable surface — items expand in place to show their readable content, and the queue lets users defer a deep-dive without breaking their flow.

## Acceptance Criteria

### DigestViewModel

- [ ] New `@Observable final class DigestViewModel` at `JustTCG/Features/Home/DigestViewModel.swift`
- [ ] State:
  ```swift
  private(set) var items: [DigestItem] = []
  private(set) var isLoading = false
  private(set) var error: String? = nil
  private(set) var queuedIds: Set<UUID> = []
  ```
- [ ] `load(modelContext: ModelContext)` async method:
  1. Load today's `FeaturedDeckSnapshot` from disk cache (reuse `FeaturedDeckWidgetViewModel`'s cache path — do not re-fetch; if stale or absent, trigger a background refresh and proceed with `nil`)
  2. Fetch the 3 most recent tournaments via `LimitlessTCGClient.fetchRecentTournaments(limit: 3)`; for each, fetch detail concurrently — keep the top-4 placements from each
  3. Load the latest `[ArchetypeShare]` pair (current + one week prior) from `MetaTrendEngine`; compute `weekDelta` per archetype
  4. Fetch all `CachedCard`s from SwiftData via `modelContext.fetch(FetchDescriptor<CachedCard>())`
  5. Load all `ReadQueueItem` IDs from SwiftData into `queuedIds`
  6. Call `DigestFeedEngine.feed(...)` with the assembled inputs; assign result to `items`
- [ ] `queue(_ item: DigestItem, modelContext: ModelContext)`:
  - Inserts a `ReadQueueItem.from(item)` into the model context
  - Adds `item.id` to `queuedIds`
  - Does **not** remove the item from `items` — queued items remain visible in the feed (sorted to end by engine on next reload)
- [ ] `dequeue(_ item: DigestItem, modelContext: ModelContext)`:
  - Deletes the matching `ReadQueueItem` from the model context
  - Removes `item.id` from `queuedIds`
- [ ] `queueCount: Int` computed property — count of unread `ReadQueueItem`s loaded from SwiftData
- [ ] All network and file I/O off main actor; state updates on main actor

### DigestItemCard

- [ ] New SwiftUI view `DigestItemCard` at `JustTCG/Features/Home/DigestItemCard.swift`
- [ ] Accepts: `item: DigestItem`, `isQueued: Bool`, `onQueue: () -> Void`, `onDequeue: () -> Void`, `onOpenFull: () -> Void`
- [ ] Maintains `@State private var isExpanded = false`
- [ ] **Collapsed state** (default):
  - Leading: content type badge — `Text(item.contentTypeLabel)` in `.caption2.bold()` / `.white` inside a `Capsule` with `Color.accentColor` background, `3 × 8` padding
  - Title: `item.title` in `.headline`
  - Subtitle: `item.subtitle` in `.subheadline` / `.secondary`, one line max with truncation
  - Trailing: chevron `"chevron.right"` at `.caption` size, rotates 90° when expanded (animated)
  - Tapping anywhere on the row toggles `isExpanded` with `.spring(duration: 0.25)` animation
- [ ] **Expanded state** (inline, no navigation):
  - Thumbnail row: `HStack(spacing: 8)` of `CardThumbnailView` at `52 × 72 pt`, from `item`'s associated `primaryCards` (up to 3); hidden if `primaryCards` is empty
  - For `.metaTrend` items: in place of thumbnails, a trend indicator row — archetype name in `.title3.bold()`, share percent in `.body`, delta in `.subheadline` coloured green (`weekDelta > 0`) or red (`weekDelta < 0`)
  - Action row (always visible when expanded):
    - **Queue button**: `Button` with label `isQueued ? "Queued" : "Queue for Later"` and SF Symbol `isQueued ? "bookmark.fill" : "bookmark"` — taps `onQueue()` or `onDequeue()` based on current state; tapping while queued de-queues; button animates `.symbolEffect(.bounce)` on state change
    - **Open button**: `Button` with label `"Open Full View"` and SF Symbol `"arrow.up.right.square"` — taps `onOpenFull()`; hidden if `item.deckListId == nil` and item is `.metaTrend` (no full view to open for meta items without a deck list)
    - Buttons use `.bordered` style, laid out in an `HStack(spacing: 8)` with trailing `Spacer()`
  - Expanded content appears below the collapsed row header with a `Divider()` separating them; uses `if isExpanded` with `.transition(.opacity.combined(with: .move(edge: .top)))`
- [ ] The entire card uses the same chrome as other Home widgets: `RoundedRectangle(cornerRadius: 12)` background `Color(.secondarySystemBackground)`, `16 pt` padding inside

### DigestView

- [ ] New SwiftUI view `DigestView` at `JustTCG/Features/Home/DigestView.swift`
- [ ] Holds `@State private var vm = DigestViewModel()`
- [ ] Holds `@State private var showQueueSheet = false`
- [ ] `@State private var navigationTarget: DigestNavigationTarget? = nil` — see Navigation below
- [ ] Calls `vm.load(modelContext:)` in `.task` on first appearance
- [ ] Body: `ScrollView { LazyVStack(spacing: 12) { ForEach(vm.items) { item in DigestItemCard(...) } } }` with `.padding(.vertical)`
- [ ] **Empty state**: when `!vm.isLoading && vm.items.isEmpty`, show `ContentUnavailableView("Nothing to read yet", systemImage: "newspaper")` with subtitle `"Tournament data loads in the background."`
- [ ] **Loading state**: when `vm.isLoading && vm.items.isEmpty`, show a `ProgressView()` centred
- [ ] **Toolbar**: trailing button with SF Symbol `"bookmark"` badged with `vm.queueCount` (using `.badge(vm.queueCount)` when count > 0) — taps `showQueueSheet = true`
- [ ] `.sheet(isPresented: $showQueueSheet)`: presents `ReadQueueSheet()`
- [ ] `.navigationDestination(item: $navigationTarget)`: see Navigation below

### Navigation

- [ ] `enum DigestNavigationTarget: Hashable` with cases:
  - `.deckList(deckListId: String)`
  - `.archetypeDetail(archetypeName: String)` (for meta trend items — future; for now opens an alert saying "Archetype detail coming soon")
- [ ] When the user taps "Open Full View" on a `.tournamentDeck` or `.featuredDeck` item with a non-nil `deckListId`, set `navigationTarget = .deckList(deckListId: ...)` — navigates to `DeckListViewer` via `NavigationStack`
- [ ] When the user taps "Open Full View" on a `.metaTrend` item, set `navigationTarget = .archetypeDetail(archetypeName: ...)` — shows the "coming soon" alert for now; placeholder navigation target ensures the architecture is wired correctly for M37+

### ReadQueueSheet

- [ ] New SwiftUI view `ReadQueueSheet` at `JustTCG/Features/Home/ReadQueueSheet.swift`
- [ ] `@Query(sort: \ReadQueueItem.addedAt, order: .reverse) private var queueItems: [ReadQueueItem]`
- [ ] Shows a `List` of queued items, grouped into two sections: `"Unread"` (`isRead == false`) and `"Read"` (`isRead == true`); hide the `"Read"` section if empty
- [ ] Each row: title in `.headline`, subtitle in `.subheadline / .secondary`, `"bookmark.fill"` trailing icon for unread items
- [ ] Swipe leading action: `"Mark as Read"` — sets `item.isRead = true`
- [ ] Swipe trailing action: `"Remove"` (destructive) — deletes the item from the model context
- [ ] Tapping an unread row marks it as read and, if it has a `deckListId`, opens `DeckListViewer` as a `.sheet`
- [ ] Empty state (no items at all): `ContentUnavailableView("Queue is empty", systemImage: "bookmark.slash")` with subtitle `"Tap the bookmark on any item to save it for later."`

### HomeView integration

- [ ] In `HomeView`, replace `FeaturedDeckWidget()` with `DigestView()` rendered inline as a widget-height preview (the first N items collapsed, with a "See all" button that pushes `DigestView` as a full-screen `NavigationLink`)

  **OR** (preferred if the widget replacement feels too heavy): add a `DigestPreviewWidget` that shows the top 2 collapsed `DigestItemCard`s and a `"See all (\(totalCount))"` footer button that navigates to the full `DigestView` — the full digest lives as a pushed view from Home, not a tab

  Decision: choose the `DigestPreviewWidget` approach — it preserves the Home screen's widget rhythm and avoids making Home feel like a tab-within-a-tab.

- [ ] `FeaturedDeckWidget` is **removed** from `HomeView`; its content is superseded by the digest (the featured deck always appears as the first item in the digest feed)

## Technical Notes

**Why items expand in-place instead of navigating:** The core UX insight is that navigation breaks browse flow. An inline expand lets the user read a deck list preview (3 thumbnails + player/tournament context) without losing their scroll position or their mental model of "where I am in the feed." The "Open Full View" button still exists for users who want the full detail — the expand is a preview, not a replacement.

**Queue vs. navigation:** The queue action and the "Open Full View" action are intentionally separate affordances. Queue = "I want to come back to this later." Open = "I want to read this now in detail." A user can queue something without opening it, open it without queuing it, or do both.

**Why queued items stay in the feed:** Removing an item on queue creates an awkward disappearance mid-scroll. Keeping the item visible (sorted to the end on next reload) means the queue is additive — it doesn't change the browse surface, it just marks the item with a filled bookmark.

**`DigestPreviewWidget` sizing:** Show exactly 2 collapsed rows. The "See all" footer should display the total item count so users know how much is in the full digest.

**Files to create:**
- `JustTCG/Features/Home/DigestViewModel.swift`
- `JustTCG/Features/Home/DigestItemCard.swift`
- `JustTCG/Features/Home/DigestView.swift`
- `JustTCG/Features/Home/ReadQueueSheet.swift`
- `JustTCG/Features/Home/DigestPreviewWidget.swift`

**Files to modify:**
- `JustTCG/Features/Home/HomeView.swift` — replace `FeaturedDeckWidget()` with `DigestPreviewWidget()`
