# M11-04 — Activity Heatmap Widget

**Status:** done  
**Milestone:** M11 — Home Screen  
**Dependencies:** M3-01, M11-01

## User Story

As a user, I want to see a GitHub-style activity heatmap on the Home screen so that I can instantly gauge how consistently I've been logging matches over the past several months.

## Acceptance Criteria

### Heatmap Engine

- [x] `ActivityHeatmapEngine` is a `struct` (or `enum` with no cases) with a single static method:
  ```swift
  static func compute(matches: [Match], weeks: Int = 16, calendar: Calendar = .current) -> [HeatmapDay]
  ```
- [x] `HeatmapDay` is a value type (`struct`) with:
  - `date: Date` — the calendar day (time component is irrelevant; comparisons use `isDate(_:inSameDayAs:)`)
  - `count: Int` — number of `Match` records whose `date` falls within that calendar day
  - `isFuture: Bool` — true when `date` is after today
  - `isToday: Bool` — true when `date` is today
- [x] The returned array covers exactly `weeks × 7` days, starting from the **Sunday** on or before the date `(weeks - 1)` full weeks ago (i.e., the grid always begins on a Sunday column boundary) and ending on the **Saturday** on or after today — so the grid is always a complete number of columns
- [x] Days after today have `count = 0` and `isFuture = true`
- [x] The engine performs no SwiftUI or SwiftData imports — pure Swift logic only
- [x] Unit tests cover:
  - Empty match array → all days have `count = 0`
  - Matches on today → today's `HeatmapDay.count` is correct, `isToday = true`
  - Matches older than the window are excluded from all day counts
  - `isFuture = false` for today, `true` for tomorrow, `false` for yesterday
  - Grid always starts on a Sunday and ends on a Saturday

### Home Screen Widget

- [x] `ActivityHeatmapWidget` is a SwiftUI `View` at `JustTCG/Features/Home/Widgets/ActivityHeatmapWidget.swift`
- [x] The widget renders the `[HeatmapDay]` array as a 7-row × N-column grid where:
  - Rows represent days of the week (row 0 = Sunday, row 6 = Saturday)
  - Columns represent weeks (leftmost = oldest, rightmost = current week)
- [x] Each cell is a rounded rectangle with size **10 × 10 pt** and corner radius **2 pt**, separated by **2 pt** gaps
- [x] Cell fill uses four intensity levels based on `count`:
  - `0` → `Color(.systemFill)` (neutral, no activity)
  - `1` → app accent at 30 % opacity
  - `2–3` → app accent at 65 % opacity
  - `4+` → app accent at full opacity
- [x] Future cells (`isFuture = true`) use `Color(.systemFill)` at 40 % opacity to visually distinguish them from past empty days
- [x] Today's cell has a 1 pt stroke in the app accent colour so it is identifiable at a glance
- [x] Day-of-week labels (`S M T W T F S`) appear to the **left** of the grid, aligned to each row, in `.caption2` / `.secondary` style — only the labels for Sun, Tue, Thu, Sat are shown (every other row) to avoid crowding
- [x] Month labels appear **above** the grid: the abbreviated month name (`Jan`, `Feb`, …) is printed above the first column of each new month, in `.caption2` / `.secondary` style
- [x] The grid scrolls horizontally (via `ScrollView(.horizontal, showsIndicators: false)`) so it fits on all screen widths without wrapping
- [x] The widget card has:
  - A section header `"Activity"` in bold at the top left
  - A subtitle `"last 16 weeks"` in `.caption` / `.secondary` beside or below the header
  - Padding consistent with other Home widgets (`16 pt` insets)
  - A `RoundedRectangle` card background using `Color(.secondarySystemBackground)` with corner radius `12`
- [x] `ActivityHeatmapWidget` fetches all matches via `@Query(sortBy: [SortDescriptor(\Match.date, order: .reverse)])` and passes them to `ActivityHeatmapEngine.compute`
- [x] The widget is inserted in `HomeView`'s `LazyVStack` **below** `StreakWidget` (M11-03) and **above** `MatchLogWidget` (M11-02)

## Technical Notes

- `ActivityHeatmapEngine` lives at `JustTCG/Features/Home/ActivityHeatmapEngine.swift`
- `ActivityHeatmapWidget` lives at `JustTCG/Features/Home/Widgets/ActivityHeatmapWidget.swift`
- Do **not** store derived heatmap data in SwiftData — always derive from the match log at render time
- The grid column count is always `weeks` (default 16); partial weeks at either end are padded to a full Sunday–Saturday column so the layout is always rectangular
- `Color.accentColor` is the intended accent — it picks up the global app tint automatically; do not hardcode a colour value
- Use `LazyHStack` inside the `ScrollView` for column rendering to avoid layout overhead on large grids
- Build the column data structure as `[[HeatmapDay]]` (outer = columns/weeks, inner = days Sun–Sat) before passing to the grid view
