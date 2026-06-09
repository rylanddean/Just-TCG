# M31-02 — Tournament Prep View

**Status:** done  
**Milestone:** M31 — Tournament Prep Planner  
**Dependencies:** M31-01

## User Story

As a competitive player, I want a dedicated tournament prep screen where I can create a prep plan, add matchup goals, and log practice sessions so I always know my readiness heading into an event.

## Acceptance Criteria

### Entry Point

- [ ] A **"Prep"** tab item is added to the main `TabView` in `ContentView` using the `trophy` SF Symbol, positioned between "Decks" and "Analytics"
- [ ] Tab navigates to `TournamentPrepView`

### TournamentPrepView

- [ ] New file `JustTCG/Features/Prep/TournamentPrepView.swift`
- [ ] Shows a `List` of `PrepPlan` objects sorted by `tournamentDate` ascending
- [ ] Each row displays:
  - Plan name (bold)
  - Deck name (if `deckID` resolves) or "No deck selected" in secondary colour
  - Days until tournament: `"In N days"` (green if > 7, yellow if 2–7, red if ≤ 1); `"Past"` if negative
  - `ProgressView(value: plan.overallProgress)` bar with percentage label (`"67% ready"`)
- [ ] Empty state: `ContentUnavailableView("No Prep Plans", systemImage: "trophy", description: Text("Create a plan to start tracking your tournament readiness."))`
- [ ] Toolbar: **"+"** button presents `NewPrepPlanSheet`
- [ ] Tapping a row navigates to `PrepPlanDetailView`

### NewPrepPlanSheet

- [ ] New file `JustTCG/Features/Prep/NewPrepPlanSheet.swift`
- [ ] Fields:
  - `TextField("Plan name", …)` — required; "Save" disabled if empty
  - `DatePicker("Tournament date", …)` — `.datePickerStyle(.compact)`, min date = today
  - `Picker("Deck (optional)", …)` — shows all decks from `DeckRepository`; "None" option at top
- [ ] "Save" creates via `PrepPlanRepository.create(…)` and dismisses
- [ ] "Cancel" dismisses without saving

### PrepPlanDetailView

- [ ] New file `JustTCG/Features/Prep/PrepPlanDetailView.swift`
- [ ] Navigation title: plan name
- [ ] Header card: tournament date, days until, overall progress gauge (reuse `ConsistencyGauge` style — `Gauge` arc 0–1)
- [ ] Section **"Matchup Goals"**: one row per `MatchupGoal` showing:
  - Archetype name
  - Progress: `"N / M sessions"` with inline `ProgressView(value:total:)` 
  - Win rate badge: `"XX% W"` (secondary, hidden if 0 sessions)
  - Checkmark overlay if `isComplete`
- [ ] Swipe-to-delete on goal rows calls `PrepPlanRepository.removeGoal(_:)`
- [ ] Toolbar: **"Add Matchup"** button presents `AddMatchupGoalSheet`
- [ ] Tapping a goal row navigates to `MatchupGoalDetailView`

### AddMatchupGoalSheet

- [ ] New file `JustTCG/Features/Prep/AddMatchupGoalSheet.swift`
- [ ] Archetype name picker: a `Picker` showing all archetype names from the bundled meta deck list (same source as `LogMatchSheet`), plus a manual text field as "Other"
- [ ] `Stepper("Target sessions: \(count)", value: $count, in: 1...20)`
- [ ] "Add" creates goal; "Cancel" dismisses

### MatchupGoalDetailView

- [ ] New file `JustTCG/Features/Prep/MatchupGoalDetailView.swift`
- [ ] Navigation title: archetype name
- [ ] Stats header: sessions logged, win rate, goal progress
- [ ] `List` of `PrepSession` rows:
  - Date (formatted `"MMM d"`)
  - Result icon: `checkmark.circle.fill` (green) / `xmark.circle.fill` (red) / `minus.circle` (gray)
  - Notes (1-line truncated, secondary colour)
- [ ] Swipe-to-delete on session rows
- [ ] Toolbar: **"Log Session"** button presents `LogPrepSessionSheet`

### LogPrepSessionSheet

- [ ] New file `JustTCG/Features/Prep/LogPrepSessionSheet.swift`
- [ ] Result picker: segmented `Picker` with Win / Loss / Tie
- [ ] `TextField("Notes (optional)", …)` — multiline, 3-line min height
- [ ] "Log" saves via `PrepPlanRepository.logSession(…)` and dismisses

## Technical Notes

**Files to create:**
- `JustTCG/Features/Prep/TournamentPrepView.swift`
- `JustTCG/Features/Prep/NewPrepPlanSheet.swift`
- `JustTCG/Features/Prep/PrepPlanDetailView.swift`
- `JustTCG/Features/Prep/AddMatchupGoalSheet.swift`
- `JustTCG/Features/Prep/MatchupGoalDetailView.swift`
- `JustTCG/Features/Prep/LogPrepSessionSheet.swift`

**Files to change:**
- `JustTCG/App/ContentView.swift` — add Prep tab
- `JustTCG/App/AppNavigationState.swift` — add `.prep` case if using enum-based tab state

**Deck lookup for plan row:**
```swift
// Resolve deck name from deckID — guard against deleted decks gracefully
let deckName = deckID.flatMap { id in decks.first { $0.id == id }?.name }
```
