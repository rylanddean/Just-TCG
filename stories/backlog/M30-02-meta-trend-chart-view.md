# M30-02 — Meta Trend Chart View

**Status:** todo  
**Milestone:** M30 — Meta Trend Tracker  
**Dependencies:** M30-01

## User Story

As a competitive player, I want a visual chart showing archetype meta share trends over the past 8 weeks so I can quickly see which decks are rising or falling in the meta.

## Acceptance Criteria

### Entry Point

- [ ] A **"Trends"** tab is added to the segmented picker at the top of `AnalyticsView` (alongside the existing tabs)
- [ ] Selecting "Trends" swaps the content area to `MetaTrendView`

### MetaTrendView

- [ ] New file `JustTCG/Features/Analytics/MetaTrendView.swift`
- [ ] On appear, calls `MetaTrendEngine.loadTrends()` if not already loaded or cache is stale
- [ ] Shows a `ProgressView` while `isLoading == true`
- [ ] Shows an error state with a "Retry" button if `loadError` is non-nil

**Top Archetypes Selector:**
- [ ] A horizontal `ScrollView` of pill-toggle buttons showing the top 8 archetype names
- [ ] Up to 3 archetypes can be selected simultaneously (any deselection re-enables others)
- [ ] By default, the top 3 archetypes by average share are pre-selected
- [ ] Pill colour matches the line colour in the chart

**Trend Line Chart:**
- [ ] Uses `Swift Charts` (`Chart` + `LineMark` + `PointMark`)
- [ ] X-axis: week labels from `WeekSnapshot.weekLabel` (e.g. "May 26")
- [ ] Y-axis: `0%` to `max(share) + 5%`, formatted as `"%"` with `maximumFractionDigits: 0`
- [ ] One `LineMark` series per selected archetype, with `.symbol(Circle())` point marks
- [ ] Each series uses a distinct colour from a fixed 3-colour palette (e.g. blue, orange, purple)
- [ ] Chart has a legend below showing archetype name + colour

**Trend Indicator List:**
- [ ] Below the chart, a `List` showing all top 8 archetypes with one row each:
  - Archetype name
  - Current share (`"12.4%"`)
  - Trend indicator: `chevron.up.circle.fill` (green) if `trend > 1`, `chevron.down.circle.fill` (red) if `trend < -1`, `minus.circle` (secondary) otherwise
  - Trend delta label (`"+3.1%"` or `"−2.0%"`)
- [ ] Tapping a row toggles its selection in the chart (same as tapping the pill)

### Empty State

- [ ] If `weeklyShares` has fewer than 2 data points, show `ContentUnavailableView("Not enough data", systemImage: "chart.line.uptrend.xyaxis", description: Text("More tournament results are needed to show trends."))`

## Technical Notes

**Files to create:**
- `JustTCG/Features/Analytics/MetaTrendView.swift`

**Files to change:**
- `JustTCG/Features/Analytics/AnalyticsView.swift` — add "Trends" segment and render `MetaTrendView`

**Colour palette:**
```swift
static let trendPalette: [Color] = [.blue, .orange, .purple]
```

**Swift Charts LineMark:**
```swift
ForEach(selectedArchetypes) { archetype in
    ForEach(archetype.weeklyShares.indices, id: \.self) { i in
        LineMark(
            x: .value("Week", snapshots[i].weekLabel),
            y: .value("Share", archetype.weeklyShares[i])
        )
        .foregroundStyle(by: .value("Archetype", archetype.archetypeName))
    }
}
```
