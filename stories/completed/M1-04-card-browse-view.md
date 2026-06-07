# M1-04 — Card Browse View

**Status:** done  
**Milestone:** M1 — Card Browser  
**Dependencies:** M1-02, M1-03

## User Story
As a user, I want to browse all Standard-legal cards in a scrollable grid so that I can visually scan the card pool.

## Acceptance Criteria

- [ ] Cards tab shows a 3-column grid of card thumbnails loaded from `CachedCard.imageURL`
- [ ] Each thumbnail shows the card image; tapping opens the card detail view (M1-06)
- [ ] Cards are sorted alphabetically by name by default
- [ ] A loading skeleton is shown while the card cache is syncing for the first time
- [ ] An empty state is shown if no cards are cached and the device is offline
- [ ] Images are loaded lazily and cached to disk — scrolling through 2,000+ cards does not cause memory pressure
- [ ] Pull-to-refresh triggers `CardRepository.refreshIfStale()` (force = true)

## Technical Notes

- Use `LazyVGrid` with `GridItem(.flexible(), minimum: 100)` columns
- Image loading: `AsyncImage` with a placeholder that matches card aspect ratio (~7:10) to avoid layout shift
- The view model exposes `@Published var cards: [CachedCard]` driven by a SwiftData `@Query`
- Do not load full card detail data in the grid — only `imageURL` and `id` needed at this level
