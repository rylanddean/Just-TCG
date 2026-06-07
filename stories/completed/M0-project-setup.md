# M0 — Project Setup

**Status:** done  
**Milestone:** Foundation  
**Dependencies:** none

## User Story
As a developer, I need a working Xcode project with the correct folder structure, SwiftData container, tab navigation skeleton, and app entry point so that all subsequent stories have a consistent foundation to build on.

## Acceptance Criteria

- [ ] Xcode project named `JustTCG` targeting iOS 17.0+, SwiftUI lifecycle
- [ ] Folder structure matches the architecture in `TECHNICAL_DESIGN.md`:
  - `App/`, `Features/`, `Data/Models/`, `Data/Repositories/`, `Data/LimitlessTCGClient/`, `Domain/Entities/`, `Shared/Components/`, `Shared/Extensions/`
- [ ] SwiftData `ModelContainer` configured in `JustTCGApp.swift` with all models registered (stubs acceptable at this stage)
- [ ] Bottom tab navigation with 4 tabs: **Decks**, **Cards**, **Tournaments**, **Analytics** — each tab shows a placeholder view with its title
- [ ] App builds and runs on simulator without warnings or errors
- [ ] `.gitignore` configured for Xcode (excludes `xcuserdata`, `DerivedData`, etc.)
- [ ] Git repo initialised with an initial commit

## Technical Notes

- Use `@main` + `WindowGroup` + `.modelContainer(for:)` modifier
- Tab icons: use SF Symbols — `rectangle.stack` (Decks), `square.grid.2x2` (Cards), `trophy` (Tournaments), `chart.bar` (Analytics)
- The `ModelContainer` should list all `@Model` types even if they're empty structs for now — prevents migration headaches later
