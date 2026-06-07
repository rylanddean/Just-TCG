# BUG-08 — Activity Chart Should Match Just Reps & Use Full Width

**Status:** open  
**Area:** M11 — Home / Activity Widget  
**Related stories:** M11-04

## Description

The Activity heatmap on the Home screen doesn't fill the available card width — it renders fixed-size cells inside a horizontal scroll view, leaving the card looking cramped/half-empty. It should match the **Just Reps** activity chart: a clean, week-aligned grid that spans the **full width** of the card, with day-of-week row labels, no month labels, and a "Less → More" intensity legend.

(Reference: Just Reps `HeatmapCalendar` — example screenshot provided by the user.)

## Current Behaviour

`ActivityHeatmapWidget` lays weeks out as columns inside `ScrollView(.horizontal)` with a hardcoded `cellSize = 10`. The grid is a fixed pixel width regardless of screen size, so on most devices the card has large empty space to the right, and the chart is horizontally scrollable instead of fitting the card.

## Target Behaviour (match Just Reps)

- Grid **fills the full width** of the card — cell size is computed from available width, not hardcoded; no horizontal scroll
- Week columns Sunday–Saturday aligned; days as rows
- Day-of-week labels `S M T W T F S` down the left edge
- **No month labels** (Just Reps removed these — cleaner)
- Future day slots render as empty/clear placeholders
- Intensity uses a 5-step scale with a **"Less ▢▢▢▢▢ More"** legend below the grid (matches the screenshot)
- Heatmap fill uses the green intensity ramp (Just Reps `successGreen` #5FD38D); use the app accent token, don't hardcode

## Acceptance Criteria

- [ ] The activity grid spans the full width of its card on all device sizes (no dead space, no horizontal scroll)
- [ ] Cell size is derived from available width (e.g. via `GeometryReader`) with consistent spacing
- [ ] Day-of-week labels `S M T W T F S` appear on the left; month labels removed
- [ ] A "Less / More" 5-swatch legend appears below the grid
- [ ] Future dates render as empty placeholders, today is still indicated
- [ ] Visual style (corner radius, green intensity ramp, spacing) matches the Just Reps reference
- [ ] No change to the underlying data (`ActivityHeatmapEngine` output) unless week count is intentionally adjusted

## Technical Notes

- File: `JustTCG/Features/Home/Widgets/ActivityHeatmapWidget.swift`
  - Remove `ScrollView(.horizontal)` + `LazyHStack`; lay the grid out to fill width
  - Replace hardcoded `cellSize: CGFloat = 10` with a width-derived size: `cellSize = (availableWidth - labelColumnWidth - totalSpacing) / CGFloat(weeks)` inside a `GeometryReader`
  - Drop `monthLabelHeight` / `monthLabel(for:)` and the month-label row in `columnView`
  - Add a "Less → More" legend row (5 swatches) beneath the grid, mirroring `cellFill` tiers
  - Current `cellFill` has 4 tiers (0 / 1 / 2–3 / 4+); align to a 5-step ramp to match the legend
- Engine: `JustTCG/Features/Home/ActivityHeatmapEngine.swift` — likely unchanged; Just Reps uses a 20-week view vs the current `weeks = 16`. Decide whether to bump to 20 to match (will affect cell size / density). Tests live in `JustTCGTests/ActivityHeatmapEngineTests.swift`.
- Just Reps reference: `HeatmapCalendar.swift` — "20-week view, week columns always Sunday–Saturday aligned, no month labels, S M T W T F S labels on left, nil future slots render as `Color.clear`."

## Open Question

The Just Reps screenshot also shows a **"Rest"** and **"Freeze"** legend (streak-day / streak-freeze concepts). Just-TCG tracks matches, not a daily streak with rest/freeze states, so these likely **don't apply** here. Recommend omitting Rest/Freeze and keeping only the "Less → More" legend — confirm before implementing.
