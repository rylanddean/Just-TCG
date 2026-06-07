# M9-02 — CachedCard Role Tags Model

**Status:** done  
**Milestone:** M9 — Card Role Tag Filtering  
**Dependencies:** M9-01

## User Story

As a developer, I want `CachedCard` to store a `roleTags` array so that filter predicates can match cards by functional role (Draw, Disruption, Energy Acceleration, etc.) without parsing text strings at query time.

## Acceptance Criteria

- [x] `CachedCard` gains one new stored property:
  - `roleTags: [String]` — sorted list of canonical role tag strings from the M9-01 taxonomy; empty array for cards with no classifiable abilities or attack effects
- [x] `BundledCardSeeder.seededKey` is bumped to `"bundled_cards_seeded_v6"`
- [x] All existing `CachedCard` `init` parameters compile without change (new property has a default of `[]`)
- [x] The app builds and launches cleanly; all existing cards are re-seeded with `roleTags: []` as placeholder until M9-03 populates the classifier

## Technical Notes

- Add `roleTags: [String] = []` to both the stored property declaration and the `init` signature — same pattern as `attackEnergyCosts`.
- SwiftData handles `[String]` properties natively; no `@Attribute` annotation needed beyond what already exists for other array properties.
- The seed key bump from v5 → v6 forces SwiftData to wipe and re-seed the store on next launch; this is the same mechanism used in M7-01 and subsequent stories. Do not skip it.
- `roleTags` will remain `[]` for all cards until M9-03 is implemented. That is fine — the filter simply shows no results when the tag set is non-empty, which is the correct "unclassified" behavior.
