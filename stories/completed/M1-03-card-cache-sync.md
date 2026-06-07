# M1-03 — Card Cache Sync

**Status:** done  
**Milestone:** M1 — Card Browser  
**Dependencies:** M1-01, M1-02

## User Story
As a user, I want the app to automatically keep a local copy of all Standard-legal cards up to date so that I can browse and search cards instantly without waiting for a network request every time.

## Acceptance Criteria

- [ ] On first app launch, all Standard-legal cards are fetched from Limitless and stored in `CachedCard`
- [ ] Sync is skipped if `lastRefreshedAt` (stored in `UserDefaults`) is less than 7 days ago
- [ ] Pull-to-refresh on the card browse screen forces a full sync regardless of staleness
- [ ] Cards are fetched in paginated batches; progress is visible (indeterminate progress bar or spinner)
- [ ] If sync fails mid-way, already-fetched cards are retained — the app never wipes existing cache on failure
- [ ] After a successful sync, `lastRefreshedAt` is updated in `UserDefaults`
- [ ] Sync runs on a background task — UI remains interactive during sync
- [ ] If the device is offline on first launch, a "Couldn't load cards — connect to the internet and pull to refresh" empty state is shown

## Technical Notes

- Sync entry point: `CardRepository.refreshIfStale()` called from the Cards tab `onAppear`
- Batch size: 100 cards per page — loop until the response returns fewer than 100 cards
- Use Swift's structured concurrency (`Task { }`) to run the sync off the main actor
- `lastRefreshedAt` key: `"card_cache_last_refreshed"`
