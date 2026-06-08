# M16-04 — Edit-Segmented Match Timeline

**Status:** done  
**Milestone:** M16 — Deck Edit Log  
**Dependencies:** M16-01, M16-02, M16-03

## User Story

As a player, I want to see my match results grouped by the version of the deck I was running, so that I can tell whether a card swap actually improved my win rate.

## Acceptance Criteria

- [x] `DeckBuilderView` (or a new dedicated view accessible from it) shows a timeline that interleaves deck edit events with match results
- [x] Matches are grouped into "version segments" — consecutive matches played between two edit events (or from the first match to the first edit, or from the last edit to today)
- [x] Each segment shows:
  - A header summarising the edit that started it (or "Initial build" for the first segment) with the date
  - All matches played in that segment, each row showing: opponent archetype, result (W/L/T badge), and date
  - A footer with the segment's W/L/T record and win rate (e.g. "7W 3L — 70%")
- [x] Segments are ordered most-recent first (newest at the top)
- [x] If a deck has matches but no edits, all matches appear in a single "Initial build" segment
- [x] If a deck has edits but no matches in a segment, the segment still appears with its header but shows "No matches played in this version"
- [x] Tapping a match row navigates to / presents the existing match detail (or does nothing if no detail view exists yet)

## Technical Notes

**New file:** `JustTCG/Features/Decks/DeckVersionTimelineView.swift`

**Segmentation logic** lives in a pure value-type engine (no SwiftData dependency):

```swift
struct DeckVersionSegment {
    let triggeringEdit: DeckEdit?   // nil for the initial-build segment
    let matches: [Match]
    var wins: Int { matches.filter { $0.result == .win }.count }
    var losses: Int { matches.filter { $0.result == .loss }.count }
    var ties: Int { matches.filter { $0.result == .tie }.count }
    var winRate: Double? { ... }
}

struct DeckVersionSegmenter {
    static func segments(edits: [DeckEdit], matches: [Match]) -> [DeckVersionSegment]
}
```

Algorithm: sort both arrays by date ascending. Walk through edits and assign each match to the segment whose edit immediately precedes it. The "initial build" segment collects matches that precede all edits.

Surface the timeline as a toolbar button ("Timeline" / `chart.bar.doc.horizontal`) in `DeckBuilderView`, presented as a `.sheet`, so it's a peer to the Changelog sheet from M16-03.

Rename-only edits (`kind == .rename`) still produce a segment boundary — the deck name change is meaningful context even if no cards changed.
