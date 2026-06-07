# M4-03 — Win Rate Trend Chart

**Status:** done  
**Milestone:** M4 — Analytics  
**Dependencies:** M4-02

## User Story
As a user, I want to see how my overall win rate has trended over time so that I can tell whether I'm improving with a deck.

## Acceptance Criteria

- [ ] A line chart on the analytics view shows rolling win rate over time (last 30 games or last 90 days — matches the active time filter)
- [ ] The X-axis is date; Y-axis is win rate % (0–100)
- [ ] Data points are plotted per calendar week — not per individual game (avoids a noisy line)
- [ ] A horizontal reference line at 50% is shown
- [ ] If fewer than 5 total matches exist, the chart is replaced with "Not enough data — log more matches to see trends"
- [ ] The chart is interactive: tapping a week data point shows a tooltip with that week's record

## Technical Notes

- Use Swift Charts (`import Charts`) — available iOS 16+, no extra dependency
- Weekly bucketing: `Calendar.current.dateInterval(of: .weekOfYear, for: match.date)`
- Win rate per bucket: wins / (wins + losses + ties) for that bucket — ignore ties in rate calculation for cleaner signal
- Chart lives in `WinRateChartView` — a standalone SwiftUI view accepting `[WeeklyRecord]` data
