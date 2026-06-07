# BUG-07 — Clipboard Import Can't Import Basic Energy Cards

**Status:** open  
**Area:** M-Import — Deck Clipboard Import  
**Related stories:** Deck Import (`ImportDeckSheet`), BUG-06

## Description

Importing a deck list from the clipboard (PTCGL format) silently drops all Basic Energy lines — they never match a card in our records, so the imported deck is missing its energy.

Basic Energy should be treated as fungible: the only thing that matters is the **energy type**. We should match a line to whatever Basic Energy of that type we already have in our JSON records, regardless of the set code / collector number the user's list happens to reference.

Example line from a PTCGL export:

```
Basic {D} Energy MEE 7
```

This should resolve to **Basic Darkness Energy** (our `sve-7` "Darkness Energy" or `sv6pt5-98` "Basic Darkness Energy"). It does not need to be the exact same print — close enough is fine.

## Steps to Reproduce

1. Copy a PTCGL deck list that includes Basic Energy, e.g. a line like `Basic {D} Energy MEE 7`
2. Open a deck → Import → paste
3. Observe: Pokémon and Trainers resolve, but Basic Energy lines come back unmatched and are excluded from the imported deck

## Likely Cause

`DeckImportLookup.resolve(...)` matches **only** by `setCode == entry.setCode && number == entry.number`. PTCGL exports Basic Energy with whatever set/number the player owns (e.g. `MEE 7`, `SVE 7`, promo sets, etc.), and our bundled records only contain Basic Energy for `SVE` (`sve-1`…`sve-8`) and `SFA` (`sv6pt5-98/99`). So any Basic Energy whose set/number isn't one of those exact rows fails to match and is dropped.

Additionally, `DeckListParser` keeps the raw name including the energy symbol (`Basic {D} Energy`) and doesn't extract the energy **type**, so even a name-based fallback has nothing clean to match on.

## Acceptance Criteria

- [ ] A Basic Energy line in a pasted list resolves to a Basic Energy of the correct type in our records, regardless of its set code / number
- [ ] The `{D}`-style energy symbol is mapped to the right type (see table below)
- [ ] Lines that spell it out (e.g. "Darkness Energy", "Basic Darkness Energy") also resolve
- [ ] Non-energy cards continue to match by `setCode + number` exactly as before (no regression)
- [ ] Special Energy is **not** swallowed by the basic-energy path (it should still match by set/number)
- [ ] Quantity from the import line is preserved (Basic Energy can exceed 4 — see BUG-06)

## Technical Notes

- Parser: `JustTCG/Data/Import/DeckListParser.swift`
  - `parseLine` produces `name: "Basic {D} Energy"`, `setCode: "MEE"`, `number: "7"` for the example
  - Consider detecting Basic Energy here (name starts with `Basic` + contains an energy symbol, or matches `^Basic \{.\} Energy$`) and capturing the type
- Lookup: `JustTCG/Data/Import/DeckImportLookup.swift`
  - `resolve(...)` is strict `setCode + number`; add a Basic Energy branch that matches by type/name instead
- Basic Energy records available to match against (already in bundled JSON):
  - `sve-1` Grass, `sve-2` Fire, `sve-3` Water, `sve-4` Lightning, `sve-5` Psychic, `sve-6` Fighting, `sve-7` Darkness, `sve-8` Metal (all `SVE`)
  - `sv6pt5-98` Basic Darkness Energy, `sv6pt5-99` Basic Metal Energy (`SFA`)
- PTCGL energy symbol → type mapping:
  - `{G}` Grass · `{R}` Fire · `{W}` Water · `{L}` Lightning · `{P}` Psychic · `{F}` Fighting · `{D}` Darkness · `{M}` Metal · `{C}` Colorless · `{N}` Dragon · `{Y}` Fairy
  - Only the 8 standard basic types need to resolve; prefer the `SVE` print as the canonical Basic Energy for each type
- Matching can be lenient: strip `Basic`/`Energy`/symbols, derive the type word, and match the first Basic Energy record whose name contains that type. "No need to be perfect."
- Related: BUG-06 (Basic Energy detection / `supertype`) — a shared `isBasicEnergy` / type helper would serve both fixes.
