# BUG-02 — Basic Energy Cards Missing from Bundled Card JSON

**Status:** done  
**Area:** Data / BundledCardSeeder  
**Related stories:** M10-02  
**Blocks:** BUG-01

## Description

The bundled card seed (`BundledCardSeeder`) only loads expansion set JSON files (TEF, TWM, SFA, etc.). Basic energy cards live in a separate set (e.g. `SVE` — Scarlet & Violet Energy) and are not included, so they are absent from the `CachedCard` store entirely. Users cannot add them to decks via the card picker, and deck imports that include energy lines will always show them as unmatched.

## Acceptance Criteria

- [ ] A `SVE.json` (and any other standard-legal basic energy set) is added to the Xcode project as a bundled resource
- [ ] `"SVE"` (and other energy set codes) is added to `BundledCardSeeder.setFiles`
- [ ] After seeding, `CachedCard` records exist for all 9 basic energy types (Grass, Fire, Water, Lightning, Psychic, Fighting, Darkness, Metal, Colorless/Fairy if applicable)
- [ ] Each energy card has `subtypes` containing `"Basic"` and `types` set to the appropriate energy type
- [ ] `seededKey` is bumped to `bundled_cards_seeded_v7` so existing installs re-seed with the new data
- [ ] Energy cards are visible and searchable in the Card Browse view

## Technical Notes

- Seeder: `JustTCG/Data/BundledCardSeeder.swift` — `setFiles` array and `seededKey`
- JSON schema must match `CardSeedEntry` — fields: `id`, `name`, `setCode`, `setName`, `number`, `types`, `subtypes`, `hp` (nil for energy), `isStandardLegal`, `imageURL`, `largeImageURL`, `rulesText`, `regulationMark`, `rarity`, `attacks` (empty array), `abilities` (empty array), `retreatCost` (nil), `weaknessType` (nil), `resistanceType` (nil)
- Source the energy card data from the same Limitless TCG scraper pipeline used for expansion sets, or hand-author the small SVE set (9 cards)
- After this fix, BUG-01's lookup step should resolve correctly
