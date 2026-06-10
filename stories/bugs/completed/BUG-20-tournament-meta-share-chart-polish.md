# BUG-20 — Tournament Detail: Meta Share Chart Needs Card Images and Visual Polish

**Status:** done  
**Area:** M28 — Tournament Detail / Meta Analysis

## Description

The Meta Share tab in `TournamentDetailView` uses a plain horizontal bar chart with a single accent-colour gradient and a separate text-only breakdown table below it. The `ArchetypePrimaryCardResolver` already exists and can resolve the primary Pokémon card for any archetype name — it should be used here to show card thumbnails next to each archetype entry, matching the pattern used in `AnalyticsView`. The current chart and breakdown sections are visually rough and should be merged into a single polished list.

## Steps to Reproduce

1. Open any tournament from the Tournaments tab
2. Switch to the "Meta Share" segment

## Observed Behaviour

- Chart shows horizontal bars labelled only with archetype names — no card art
- A separate "Breakdown" section below the chart duplicates the archetype list as plain text rows
- All bars are the same accent-colour gradient with no visual differentiation
- Percentage annotations on bar trailing edges are small and hard to read

## Desired Behaviour

- The chart and breakdown are replaced by a single polished ranked list
- Each archetype row shows: rank position number | card thumbnail (via `ArchetypePrimaryCardResolver`) | archetype name | player count | share percentage as a pill badge
- A compact bar chart remains at the top of the section as a summary visual (not the sole UI element), using the card's type colour or a tiered colour scale instead of flat accent
- Rows are sorted by share descending, with top-3 visually distinguished (e.g. coloured rank number)

## Acceptance Criteria

### Chart
- [x] A compact horizontal `BarMark` chart is rendered at the top of the Meta Share section, limited to the top 8 archetypes
- [x] Each bar uses a colour derived from the archetype's position (top 1 = yellow, 2 = silver, 3 = bronze, rest = accent) rather than a flat gradient
- [x] The chart height is capped and does not grow unbounded with entry count

### Archetype Rows
- [x] Below the chart, each archetype is shown as a `HStack` row containing:
  - Rank number (coloured: gold/silver/bronze for top 3, secondary for rest)
  - `AsyncImage` or inline `CachedCard` image thumbnail (32×44 pt, rounded corners, from `ArchetypePrimaryCardResolver`)
  - If no card is resolved, a placeholder with the archetype initial letter
  - Archetype name as `.body` weight
  - Player count as `.caption` secondary
  - Share percentage as a capsule-badge (`.caption.monospacedDigit()`, coloured by rank position)
- [x] `ArchetypePrimaryCardResolver` is used with the current model context card list to resolve the image URL from `CachedCard.imageURL`
- [x] The separate "Breakdown" `Section` is removed — all info lives in the combined rows

### No Regressions
- [x] The Standings tab is unaffected
- [x] Empty-state (`ContentUnavailableView`) still displays when `metaShare` is empty

## Technical Notes

**Files to change:**
- `JustTCG/Features/Tournaments/TournamentDetailView.swift` — replace `metaShareRows` with new combined view; inject `CardRepository` or pass resolved cards
- `JustTCG/Features/Tournaments/TournamentDetailViewModel.swift` — may need to expose resolved primary cards per archetype (or resolve in-view using `ArchetypePrimaryCardResolver`)

**Resolver pattern:**
```swift
// ArchetypePrimaryCardResolver.resolve(archetype:from:) returns CachedCard?
// CachedCard.imageSmall → String URL → AsyncImage
let card = ArchetypePrimaryCardResolver().resolve(archetype: entry.archetype, from: allCards)
```

The resolver takes a flat `[CachedCard]` array — fetch all cards once from `CardRepository` in `onAppear` and pass it through, or resolve lazily per row.
