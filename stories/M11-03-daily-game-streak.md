# M11-03 — Daily Game Streak

**Status:** todo  
**Milestone:** M11 — Home Screen  
**Dependencies:** M11-01, M3-01

## User Story

As a user, I want to see a games-played streak on the Home screen so that I'm motivated to log at least a set number of games each day and can track how consistently I'm practising.

## Acceptance Criteria

### Streak Engine

- [ ] `StreakEngine` is a `struct` (or `enum` with no cases) with a single static method:
  ```swift
  static func compute(matches: [Match], dailyGoal: Int, calendar: Calendar = .current) -> StreakResult
  ```
- [ ] `StreakResult` is a value type with:
  - `currentStreak: Int` — number of consecutive calendar days (ending today or yesterday) on which `dailyGoal` or more matches were logged
  - `todayCount: Int` — matches logged on the current calendar day
  - `goalMet: Bool` — `todayCount >= dailyGoal`
- [ ] Streak logic:
  - Walk backwards from **today** by calendar day
  - A day "counts" if the number of `Match` records whose `date` falls within that day is `>= dailyGoal`
  - The streak continues as long as consecutive days count; it stops (and does **not** reset to zero from a partial day today) on the first day that doesn't count
  - If today does not yet meet the goal, today is **not** counted in `currentStreak` but the streak is still live if **yesterday** and prior days counted — i.e., the streak is not broken until the calendar day rolls past without meeting the goal
  - Example: goal = 1 game/day. Logged yesterday and the day before but not yet today → `currentStreak = 2`, `goalMet = false`
- [ ] Unit tests cover:
  - Zero matches → streak 0, todayCount 0, goalMet false
  - Met goal today only → streak 1, goalMet true
  - Met goal yesterday and today → streak 2, goalMet true
  - Met goal yesterday but not today → streak 1, goalMet false
  - Gap two days ago breaks the streak even if yesterday and today are met
  - `dailyGoal = 3`: only days with 3+ matches count

### Home Screen Widget

- [ ] A `StreakWidget` view appears in the `HomeView` scroll stack, directly **above** `MatchLogWidget`
- [ ] The widget displays:
  - A large flame icon (`flame.fill`) coloured orange when `goalMet`, gray when not
  - The current streak count in large bold text (e.g. `"7"`)
  - The label `"day streak"` in secondary style beneath the count
  - A progress indicator for today: `"X / Y games today"` where Y is `dailyGoal`
  - If `goalMet`, replace the progress line with `"Goal met today ✓"` in green
- [ ] The daily goal is read from `UserDefaults` with key `"streak_daily_goal"` and defaults to `1`
- [ ] `StreakWidget` recomputes on appear and whenever the match list changes (via `@Query`)

### Settings Integration

- [ ] A **"Daily game goal"** stepper (range 1–10) is added to `SettingsView` in a new "Streak" section
- [ ] Changing the stepper writes to `UserDefaults` key `"streak_daily_goal"` immediately
- [ ] The stepper label reads `"Goal: X games / day"`

## Technical Notes

- `StreakEngine` lives at `JustTCG/Features/Home/StreakEngine.swift` — no SwiftUI, no SwiftData imports
- `StreakWidget` lives at `JustTCG/Features/Home/Widgets/StreakWidget.swift`
- `StreakWidget` fetches all matches via `@Query(sortBy: [SortDescriptor(\Match.date, order: .reverse)])` and passes the array to `StreakEngine.compute`
- Do not store streak state in SwiftData — it is always derived from the match log
- Use `Calendar.current.isDate(_:inSameDayAs:)` for day-boundary checks inside `StreakEngine`
