# M11-02 — Match Log Widget

**Status:** todo  
**Milestone:** M11 — Home Screen  
**Dependencies:** M11-01, M3-01, M3-03

## User Story

As a user, I want a match log widget on the Home screen that shows my most recent matches and lets me log a new match in one tap, so I can record results without hunting through tabs.

## Acceptance Criteria

- [ ] A `MatchLogWidget` view appears in the `HomeView` scroll stack above the placeholder row
- [ ] The widget has a header row with the title **"Recent Matches"** and a **"Log Match"** button (pill or tappable text) on the trailing edge
- [ ] Tapping **"Log Match"** opens `LogMatchSheet` as a sheet — deck selection should default to the most recently used deck if one exists, otherwise prompt for deck selection as normal
- [ ] Up to **5 most recent matches** are displayed, ordered by `date` descending, across all decks
- [ ] Each match row shows:
  - Deck name (leading, bold)
  - Opponent archetype (secondary, truncated to one line)
  - Result badge — "W" / "L" / "T" in a small capsule coloured green / red / gray
  - Relative date (e.g. "2h ago", "Yesterday") using `.formatted(.relative(presentation: .named))`
- [ ] If no matches have been logged yet, the widget body shows an empty-state message: **"No matches yet — log your first game."**
- [ ] A **"See All"** link at the bottom of the widget navigates to the full match history (can be a `NavigationLink` to a placeholder `MatchHistoryView` if M3-04 is not yet built)
- [ ] Widget data refreshes when the sheet dismisses (use `.onDismiss` or observe the model context)

## Technical Notes

- `MatchLogWidget` lives at `JustTCG/Features/Home/Widgets/MatchLogWidget.swift`
- Use a `@Query` with `sortBy: [SortDescriptor(\Match.date, order: .reverse)]` and `fetchLimit: 5` — no view model needed
- Most recently used deck: read `UserDefaults.standard.string(forKey: "last_deck_id")` written by `LogMatchViewModel`; if missing, pass `nil` and let the sheet handle deck selection as it does today
- Do not build a new deck picker — reuse the existing `LogMatchSheet` interface unchanged
- The result capsule uses `.background(Capsule().fill(color))` — keep it inline, no shared component needed yet
