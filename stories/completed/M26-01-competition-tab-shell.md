# M26-01 — Competition Tab Shell

**Status:** done  
**Milestone:** M26 — Competition Tab  
**Dependencies:** M5-01, M12-01

## User Story

As a player, I want the tournament tab to be called "Competition" and split into a Tournaments segment and a Competitors segment, so I can navigate between event results and player profiles without leaving the tab.

## Acceptance Criteria

### Tab Rename
- [ ] The `TabView` item in `ContentView` changes from `Label("Tournaments", systemImage: "trophy")` to `Label("Competition", systemImage: "trophy")`
- [ ] `AppNavigationState.tabTournaments` is renamed to `tabCompetition` and all call sites updated (currently only used in `AnalyticsView` to deep-link to the tab)

### New `CompetitionView`
- [ ] A new view `CompetitionView` is created at `JustTCG/Features/Competition/CompetitionView.swift`
- [ ] `ContentView` replaces `TournamentsView()` with `CompetitionView()`
- [ ] `CompetitionView` owns a single `NavigationStack` (the existing one in `TournamentsView` is removed)
- [ ] A `Picker` with `.segmented` style is rendered as a sticky header above the list content:
  - Segment 0: "Tournaments"
  - Segment 1: "Competitors"
- [ ] When segment is "Tournaments", the tournaments list content is shown (extracted from `TournamentsView` into a private subview or a separate `TournamentsListContent` view)
- [ ] When segment is "Competitors", `CompetitorsView` is shown (M26-02)
- [ ] The navigation title is "Competition" regardless of the selected segment
- [ ] The `tournamentsArchetypeFilter` deep-link from `AppNavigationState` automatically switches to the Tournaments segment when a filter is set (same as current behaviour — the filter banner still appears)
- [ ] The Favourite Players horizontal chip strip is **removed** from the Tournaments segment (it moves to `CompetitorsView` in M26-02)

### File reorganisation
- [ ] A new folder `JustTCG/Features/Competition/` is created
- [ ] `TournamentsView.swift` moves to `JustTCG/Features/Competition/TournamentsView.swift` (or its content is inlined into `CompetitionView`; either is acceptable)
- [ ] No behaviour changes to the Tournaments content itself — only the navigation shell and tab label change

## Technical Notes

**New file:** `JustTCG/Features/Competition/CompetitionView.swift`

**Files to change:**
- `JustTCG/App/ContentView.swift` — swap `TournamentsView` → `CompetitionView`, update tab label
- `JustTCG/App/AppNavigationState.swift` — rename `tabTournaments` → `tabCompetition`
- `JustTCG/Features/Analytics/AnalyticsView.swift` — update `tabTournaments` reference

**`CompetitionView` skeleton:**
```swift
enum CompetitionSegment { case tournaments, competitors }

struct CompetitionView: View {
    @State private var segment: CompetitionSegment = .tournaments
    @Environment(AppNavigationState.self) private var nav

    var body: some View {
        NavigationStack {
            Group {
                switch segment {
                case .tournaments: TournamentsContent()
                case .competitors: CompetitorsView()
                }
            }
            .navigationTitle("Competition")
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("", selection: $segment) {
                    Text("Tournaments").tag(CompetitionSegment.tournaments)
                    Text("Competitors").tag(CompetitionSegment.competitors)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
        .onChange(of: nav.tournamentsArchetypeFilter) { _, filter in
            if filter != nil { segment = .tournaments }
        }
    }
}
```

> The segmented picker uses `.safeAreaInset(edge: .top)` so it sits below the navigation bar and stays pinned while the list scrolls underneath.
