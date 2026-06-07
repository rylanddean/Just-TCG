# M7-04 — Advanced Filter Sheet UI

**Status:** done  
**Milestone:** M7 — Advanced Card Filters  
**Dependencies:** M7-03

## User Story

As a user, I want an intuitive filter sheet that lets me configure all basic and advanced filters in one place — with clear active-filter feedback — so that I can find any combination of cards without memorising search syntax.

## Acceptance Criteria

### Filter Sheet Layout

- [x] The filter sheet is reorganised into four collapsible `Section`s:
  1. **Basic** — Type (existing), Subtype/Stage (existing)
  2. **Set & Legality** — Set multi-select (existing), Regulation Mark multi-select (A–J), Rarity multi-select
  3. **Stats** — HP range, Max Damage range, Retreat Cost picker, Has Ability toggle
  4. **Matchup** — Weakness type multi-select, Resistance type multi-select, Attacking Energy multi-select
- [x] Sections are expanded by default; tapping the section header collapses/expands it
- [x] A "Clear All" button in the toolbar resets the entire `CardFilterState` to default
- [x] A "Done" button dismisses the sheet

### HP Range & Max Damage Range

- [x] HP and Max Damage each use two steppers (Min / Max) with 10-point steps
- [x] Range spans: HP 0–350, Damage 0–350
- [x] A nil bound shows as "Any" in the label
- [x] Setting Min > Max is prevented: adjusting Min above current Max raises Max to match (and vice versa)

### Retreat Cost

- [x] Displayed as a row of tappable chips: `0`, `1`, `2`, `3`, `4+`
- [x] Multiple values can be selected simultaneously (multi-select chips)
- [x] Unselected chips are outlined; selected chips are filled with tint colour

### Regulation Mark

- [x] Multi-select list of all regulation marks present in the current cache, sorted alphabetically

### Rarity

- [x] Multi-select list of distinct rarity strings present in the cache, sorted by frequency (most common first)

### Has Ability

- [x] A three-state segmented control labelled **Ability**: `Any | Yes | No`

### Weakness / Resistance / Attacking Energy

- [x] Each is a multi-select type picker using the same 10-type list as the Type filter

### Active Filter Chips

- [x] Filter chips below the search bar are extended to reflect all new filter categories
- [x] Tapping any chip removes that filter group entirely

### Shared Across Views

- [x] The same `CardFilterView` component is used in `CardsView` (browse) and `CardPickerView` (deck builder)
- [x] In `CardPickerView`, the Regulation Mark section is hidden (`hideRegulationMark: true`)

## Technical Notes

- Use `DisclosureGroup` for collapsible sections; persist expanded/collapsed state in `@State` within the sheet
- Two `Stepper` views for HP/Damage range — no custom RangeSlider dependency
- Regulation marks and rarities loaded from `CardRepository.fetchDistinctRegulationMarks()` / `fetchDistinctRarities()`
- Chip label formatting lives in `CardFilterState.activeChips` and `clearChip(id:)`
