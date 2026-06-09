# M31-01 — Tournament Prep Plan Models

**Status:** done  
**Milestone:** M31 — Tournament Prep Planner  
**Dependencies:** M2-01 (Deck model), M3-01 (Match model)

## User Story

As a competitive player, I want to create a tournament prep plan that specifies which matchups I need to practice and how many sessions I want before the event, so I can track my readiness in a structured way.

## Acceptance Criteria

### PrepPlan SwiftData Model

- [ ] New file `JustTCG/Data/Models/PrepPlan.swift`
- [ ] `@Model final class PrepPlan`:
  - `id: UUID` — `@Attribute(.unique)` default `UUID()`
  - `name: String` — e.g. "Regional – Seattle"
  - `tournamentDate: Date` — target event date
  - `deckID: UUID?` — optional reference to the `Deck` being prepared (soft reference by ID)
  - `createdAt: Date` — default `Date.now`
  - `matchupGoals: [MatchupGoal]` — cascade delete

- [ ] `@Model final class MatchupGoal`:
  - `id: UUID` — `@Attribute(.unique)` default `UUID()`
  - `archetypeName: String` — opponent archetype name (free text, consistent with match logging)
  - `targetSessionCount: Int` — how many practice games the player wants to complete
  - `plan: PrepPlan?` — inverse relationship
  - `sessions: [PrepSession]` — cascade delete

- [ ] `@Model final class PrepSession`:
  - `id: UUID` — `@Attribute(.unique)` default `UUID()`
  - `playedAt: Date` — default `Date.now`
  - `result: MatchResult` — reuse the existing `MatchResult` enum (win/loss/tie)
  - `notes: String` — optional free text, default `""`
  - `goal: MatchupGoal?` — inverse relationship

### PrepPlanRepository

- [ ] New file `JustTCG/Data/Repositories/PrepPlanRepository.swift`
- [ ] `@Observable` class receiving `ModelContext`
- [ ] Methods:
  - `fetchAll() -> [PrepPlan]` — sorted by `tournamentDate` ascending
  - `create(name:tournamentDate:deckID:) -> PrepPlan`
  - `delete(_ plan: PrepPlan)`
  - `addGoal(to plan: PrepPlan, archetypeName: String, targetCount: Int) -> MatchupGoal`
  - `removeGoal(_ goal: MatchupGoal)`
  - `logSession(for goal: MatchupGoal, result: MatchResult, notes: String) -> PrepSession`
  - `deleteSession(_ session: PrepSession)`

### Schema Registration

- [ ] `PrepPlan`, `MatchupGoal`, `PrepSession` are added to the `Schema` in `JustTCGApp.swift`

### Computed Properties

- [ ] `MatchupGoal.completedCount: Int` — `sessions.count`
- [ ] `MatchupGoal.winRate: Double?` — win sessions / total sessions; `nil` if 0 sessions
- [ ] `MatchupGoal.isComplete: Bool` — `completedCount >= targetSessionCount`
- [ ] `PrepPlan.overallProgress: Double` — sum of min(completedCount, targetSessionCount) across all goals / sum of targetSessionCount; `0` if no goals
- [ ] `PrepPlan.daysUntilTournament: Int` — calendar days from now to `tournamentDate`; negative if past

## Technical Notes

**Files to create:**
- `JustTCG/Data/Models/PrepPlan.swift` (contains `PrepPlan`, `MatchupGoal`, `PrepSession`)
- `JustTCG/Data/Repositories/PrepPlanRepository.swift`

**Files to change:**
- `JustTCG/App/JustTCGApp.swift` — add 3 new model types to `Schema([…])`
- `JustTCG/App/ContentView.swift` — inject `PrepPlanRepository` into the environment

**`MatchResult` reuse:**
The existing `MatchResult` enum in `JustTCG/Data/Models/Match.swift` is imported directly — no duplication needed.
