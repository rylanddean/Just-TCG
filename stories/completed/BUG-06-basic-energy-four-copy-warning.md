# BUG-06 — Basic Energy Triggers False "Max 4 Copies" Warning

**Status:** completed  
**Area:** M2 — Deck Builder / Deck Validation  
**Related stories:** M2-04, BUG-01, BUG-02

## Description

Basic Energy cards are allowed in any quantity in a Pokémon deck (the 4-copy rule applies only to other named cards). You can set more than 4 Basic Energy in the deck editor — but the deck still shows a validation warning saying you can only have 4 copies of that card.

So the behaviour is inconsistent: the editor lets you add unlimited Basic Energy (correct), but the validator flags it as illegal (incorrect).

## Steps to Reproduce

1. Open a deck in the Deck Builder
2. Add a Basic Energy (e.g. Fire Energy from SVE) and raise its quantity above 4
3. Observe: a `.duplicateCard` warning appears — "more than 4 copies" — even though Basic Energy is exempt from the 4-copy limit

## Likely Cause

Basic Energy is detected everywhere via `card.subtypes.contains("Basic Energy")`, but **no card in the data has that subtype**. In the bundled card data, Basic Energy is:

- `supertype: "Energy"`, `subtypes: ["Basic"]`  (e.g. all of `SVE.json`)

while Special Energy is `supertype: "Energy"`, `subtypes: ["Special"]`. There is no `"Basic Energy"` subtype string. So `subtypes.contains("Basic Energy")` always returns `false`, and Basic Energy is treated like any other named card → capped/flagged at 4.

Two compounding problems:

1. **`CachedCard` does not store `supertype` at all.** The field exists on the API model (`PokemonTCGAPIClient.swift:81`) but is dropped during mapping/seed, so at runtime there's no clean way to tell a Basic Energy (`subtypes: ["Basic"]`) apart from a Basic Pokémon (`subtypes` also contains `"Basic"`, but `types` is non-empty). Energy cards have empty `types`.
2. The wrong `"Basic Energy"` literal is used in several places, all of which silently fail the check.

The reason the **warning** appears but the editor still **lets** you exceed 4: `DeckRepository.setQuantity(...)` (the editor stepper path) doesn't enforce any cap, while `DeckValidator` does — and the validator's Basic Energy exemption never fires.

## Acceptance Criteria

- [x] Basic Energy can be added/set in any quantity with **no** "max 4 copies" warning
- [x] Special Energy and all other named cards are still correctly capped at 4 (warning still fires for them)
- [x] Basic Energy is distinguished from Basic Pokémon (both share the `"Basic"` subtype) reliably
- [x] `addCard` cap, `CardPickerView` `isAtMax`/`addCard`, and `DeckValidator` all agree on what counts as Basic Energy
- [x] No regression to the "no Basic Pokémon" warning or the 60-card total check

## Technical Notes

- Broken detection (`subtypes.contains("Basic Energy")`) appears in:
  - `JustTCG/Domain/Entities/DeckValidator.swift:18` (drives the false warning)
  - `JustTCG/Features/Decks/CardPickerView.swift` — `isAtMax(_:)` (~line 188) and `addCard(_:)` (~line 200)
  - `JustTCG/Data/Repositories/DeckRepository.swift:39` (cap = `isBasicEnergy ? 60 : 4`, but caller passes the broken flag)
- Recommended fix: persist `supertype` on `CachedCard` and define a single helper, e.g.
  `var isBasicEnergy: Bool { supertype == "Energy" && subtypes.contains("Basic") }`,
  then use it in all four sites above.
  - **This requires bumping the bundled seed key `bundled_cards_seeded_v6` → `v7`** (per project convention: bump whenever a new `CachedCard` stored property is added) so existing installs re-seed with `supertype` populated.
  - Update `CachedCard.init`, `init(from:)`, and `update(from:)`; map `supertype` through `LimitlessCard` / the bundled JSON decode in `BundledCardSeeder`.
- Interim (no model change) fallback: detect Basic Energy as `types.isEmpty && subtypes.contains("Basic")` — works because Energy cards have empty `types` and Basic Pokémon do not. Less explicit than storing `supertype`.
- Also confirm whether `DeckRepository.setQuantity(...)` should enforce the 4-copy cap for non-Basic-Energy cards, since it currently allows any quantity (the editor's only guard is the validator warning).
