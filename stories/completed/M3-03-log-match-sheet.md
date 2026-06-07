# M3-03 — Log Match Sheet

**Status:** done  
**Milestone:** M3 — Match Tracker  
**Dependencies:** M3-01, M3-02

## User Story
As a user, I want to log a match result in fewer than 5 taps from my deck's detail view so that recording results doesn't interrupt my play session.

## Acceptance Criteria

- [x] A "+" button on the deck detail view opens a `LogMatchSheet`
- [x] The sheet contains, in order:
  1. **Opponent archetype** — a search field with fuzzy suggestions from the archetype list; freeform text accepted
  2. **Result** — three large tappable buttons: Win / Loss / Tie (one must be selected to confirm)
  3. **Confirm** button — saves the match and dismisses the sheet
- [x] The Confirm button is disabled until both archetype and result are filled
- [x] An expandable "More details" section (collapsed by default) contains:
  - Event type picker (defaults to last used event type, stored in `UserDefaults`)
  - Format picker: Best-of-1 / Best-of-3 (defaults to last used)
  - Date picker (defaults to today)
  - Notes text field
- [x] After confirming, a brief success toast appears ("Match logged")
- [x] The match history count on the deck detail view updates immediately

## Technical Notes

- Sheet height: `.presentationDetents([.medium, .large])` — medium fits the required 3 elements; expand for more details
- Store last-used event type in `UserDefaults` key `"last_event_type"`
- Store last-used format in `UserDefaults` key `"last_match_format"`
- `LogMatchViewModel` owns form state and calls `MatchRepository.logMatch` on confirm
