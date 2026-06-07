# M11-01 — Home Screen Shell & Settings Relocation

**Status:** done  
**Milestone:** M11 — Home Screen  
**Dependencies:** none

## User Story

As a user, I want a dedicated Home tab that gives me a glanceable overview of my activity, with Settings accessible via an icon instead of occupying a full tab, so that the tab bar focuses on core navigational destinations.

## Acceptance Criteria

- [x] `HomeView` is added as the **first tab** in `ContentView` with the label "Home" and the system image `house`
- [x] The Settings tab is **removed** from the `TabView`
- [x] `HomeView` wraps in a `NavigationStack` and shows a `NavigationLink` (or sheet) to `SettingsView` via a gear toolbar button in the top-right (`placement: .navigationBarTrailing`)
- [x] `HomeView` displays a `ScrollView` with a `LazyVStack(spacing: 16)` as its content container — widget views will be inserted here in subsequent stories
- [x] The navigation title is `"Home"` with `.navigationBarTitleDisplayMode(.large)`
- [x] A placeholder `Text("More coming soon")` row is present at the bottom of the scroll view so the screen is not empty before widgets land
- [x] All existing tabs (Decks, Cards, Tournaments, Analytics) retain their current position and behaviour — only their tab index shifts by +1

## Technical Notes

- `HomeView` lives at `JustTCG/Features/Home/HomeView.swift`
- No new view models are needed for this story — the shell is purely structural
- The gear button should navigate to `SettingsView` wrapped in a `NavigationStack` presented as a `.sheet` (not a push) so Settings retains its own nav stack and title
- Do not delete `SettingsView` or its supporting types — only remove it from `ContentView`'s `TabView`
