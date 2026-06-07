# M7-04 — Advanced Filter Sheet UI

**Status:** todo  
**Milestone:** M7 — Advanced Card Filters  
**Dependencies:** M7-03

## User Story

As a user, I want an intuitive filter sheet that lets me configure all basic and advanced filters in one place — with clear active-filter feedback — so that I can find any combination of cards without memorising search syntax.

## Acceptance Criteria

### Filter Sheet Layout

- [ ] The filter sheet is reorganised into four collapsible `Section`s:
  1. **Basic** — Type (existing), Subtype/Stage (existing)
  2. **Set & Legality** — Set multi-select (existing), Regulation Mark multi-select (A–J), Rarity multi-select
  3. **Stats** — HP range, Max Damage range, Retreat Cost picker, Has Ability toggle
  4. **Matchup** — Weakness type multi-select, Resistance type multi-select, Attacking Energy multi-select
- [ ] Sections are expanded by default; tapping the section header collapses/expands it
- [ ] A "Clear All" button in the toolbar resets the entire `CardFilterState` to default
- [ ] A "Done" button dismisses the sheet

### HP Range & Max Damage Range

- [ ] HP and Max Damage each use a dual-handle range control or two steppers (Min / Max) with 10-point steps
- [ ] Range spans: HP 0–350, Damage 0–350
- [ ] A nil bound shows as "Any" in the label (e.g. "HP: 80 – Any")
- [ ] Setting Min > Max is prevented: adjusting Min above current Max raises Max to match (and vice versa)

### Retreat Cost

- [ ] Displayed as a row of tappable chips: `0`, `1`, `2`, `3`, `4+`
  - `4+` maps to `retreatCosts` values `{4}` (no Pokémon in Standard has retreat > 4)
- [ ] Multiple values can be selected simultaneously (multi-select chips)
- [ ] Unselected chips are outlined; selected chips are filled with tint colour

### Regulation Mark

- [ ] Multi-select list of all regulation marks present in the current cache, sorted alphabetically (typically F–J for current Standard)
- [ ] Each row shows the mark letter and, if space allows, the series name (e.g. "H — Scarlet & Violet")

### Rarity

- [ ] Multi-select list of distinct rarity strings present in the cache, sorted by frequency (most common first)
- [ ] Common rarities: Common, Uncommon, Rare, Double Rare, Illustration Rare, Special Illustration Rare, Hyper Rare, ACE SPEC Rare

### Has Ability

- [ ] A three-state segmented control or toggle labelled **Ability**: `Any | Yes | No`
- [ ] "Yes" shows only cards where `hasAbility == true`; "No" shows only `hasAbility == false`; "Any" removes the filter

### Weakness / Resistance / Attacking Energy

- [ ] Each is a multi-select type picker using the same 10-type list as the Type filter
- [ ] "Weakness: Fire" means the card has a Fire weakness; multiple selections are OR'd (Fire OR Lightning)
- [ ] "Attacking Energy: Grass" means at least one of the card's attacks costs ≥1 Grass energy

### Active Filter Chips

- [ ] Filter chips below the search bar (existing pattern from M1-05) are extended to reflect all new filter categories
- [ ] HP range chip: `"HP: 80–200"` or `"HP: 80+"` or `"HP: ≤100"`
- [ ] Damage chip: `"Dmg: 60–180"` (same pattern)
- [ ] Retreat chip: `"Retreat: 0, 1"`
- [ ] Regulation mark chip: `"Mark: H, I"`
- [ ] Weakness chip: `"Weak: Fire"` (comma-separated if multiple)
- [ ] Resistance chip: `"Resist: Metal"`
- [ ] Energy chip: `"Energy: Grass, Water"`
- [ ] Ability chip: `"Has Ability"` or `"No Ability"`
- [ ] Rarity chip: `"Rarity: Rare, Double Rare"`
- [ ] Tapping any chip removes that filter group entirely

### Shared Across Views

- [ ] The same `CardFilterView` component is used in `CardsView` (browse) and `CardPickerView` (deck builder) — no duplication
- [ ] In `CardPickerView`, the Regulation Mark section is hidden by default since the picker already enforces Standard legality; it can be revealed via an "Advanced" disclosure group

## Technical Notes

- Use `DisclosureGroup` for collapsible sections; persist expanded/collapsed state in `@State` within the sheet (not in `CardFilterState`)
- The dual-range HP/Damage control can be built with two `Stepper` views side-by-side or a custom `RangeSlider`; prefer two `Stepper` views to avoid a custom component dependency
- Regulation marks and rarities available in the cache are derived at filter-sheet init from a `@Query` or passed in as constructor params (same pattern as `availableSets` today)
- Chip label formatting lives in a `CardFilterState` extension — `var activeChips: [(label: String, clearAction: () -> Void)]` — so the chip row is a simple `ForEach` with no formatting logic in the view
- When the filter sheet is dismissed with "Done", `CardsView` detects the change via `onChange(of: filterState)` and re-runs the fetch+filter; no explicit callback needed
