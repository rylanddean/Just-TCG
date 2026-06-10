# BUG-29 — Meta Share Bar Chart Looks Ugly

**Status:** done  
**Area:** Tournament Detail / Meta Share

## Description

The Meta Share tab in `TournamentDetailView` uses a raw `Chart` + `BarMark` block with no styling beyond `Color.accentColor.gradient`. The bars are unsized (height calculated as `entries.count * 28`), labels are tiny `.caption2`, there is no axis or grid, and the chart sits in a plain `Section` with default `List` row insets. The result looks like a developer placeholder, not a finished feature. Apple's Swift Charts offers `chartXAxis`, `chartYAxis`, `foregroundStyle`, and annotation modifiers that can make this look polished with minimal code.

## Steps to Reproduce

1. Open any tournament
2. Tap the "Meta Share" segment

## Observed Behaviour

- Unstyled horizontal bar chart with no visible gridlines, no tick labels, and very small percentage annotations
- Chart height is a rough calculation and often clips content or leaves excessive whitespace
- "Breakdown" section below the chart repeats the same information — double-presentation of data

## Desired Behaviour

The Meta Share chart is visually polished and self-contained. It uses Swift Charts natively and does not need the separate "Breakdown" text list below it.

## Acceptance Criteria

### Chart
- [ ] Each `BarMark` is given a `cornerRadius` of 4 via `.clipShape(RoundedRectangle(cornerRadius: 4))`
- [ ] `foregroundStyle` uses `by: .value("Archetype", entry.archetype)` to produce distinct per-bar colours from the `.automatic` chart palette (removing the plain `Color.accentColor.gradient`)
- [ ] Bar percentage annotation uses `.caption.weight(.semibold)` and `.primary` foreground (more readable than `.caption2 .secondary`)
- [ ] `.chartXAxis(.hidden)` is kept (percentages are shown via annotations)
- [ ] `.chartYAxis` is configured with `.categoryLabels` style so archetype names are visible on the leading axis rather than needing the "Breakdown" table
- [ ] Chart row insets are `EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 48)` to give annotation labels space to breathe
- [ ] Chart height uses `max(CGFloat(entries.count) * 36 + 24, 120)` to prevent collapsing on small entry counts

### Breakdown section
- [ ] The duplicate "Breakdown" `Section` (ForEach list of archetypes + counts + percentages) is **removed** — the chart already shows this information via axis labels and annotations

### No regressions
- [ ] Empty state (`ContentUnavailableView`) is unchanged
- [ ] The Standings tab is unaffected

## Technical Notes

**Files to change:**
- `JustTCG/Features/Tournaments/TournamentDetailView.swift` — `metaShareRows` computed var: chart styling + remove Breakdown section
