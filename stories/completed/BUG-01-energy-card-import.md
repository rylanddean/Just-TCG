# BUG-01 — Energy Cards Fail to Import from PTCGL Clipboard

**Status:** done  
**Area:** M10 — Deck Import  
**Related stories:** M10-01, M10-02

## Description

When importing a deck from a PTCGL clipboard paste, basic energy cards are always shown as unmatched. They either fail to parse or fail the `CachedCard` lookup, so they are silently dropped from the imported deck.

## Root Cause

Two compounding issues:

1. **Parser** — PTCGL formats basic energy lines as `4 Basic Grass Energy SVE 1` (5+ tokens with "Basic" as the second token). The parser in `DeckListParser.parseLine` extracts `name = tokens[1..<tokens.count-2]`, which produces `"Basic Grass Energy"` instead of `"Grass Energy"`. This may cause a mismatch when the name is later used for display or validation.

2. **Lookup** — `DeckImportLookup` matches on `setCode` + `number` from `CachedCard`. Basic energy cards (set code `SVE`, `ENE`, etc.) are not present in the bundled JSON seed files, so the lookup always returns zero matches regardless of parse correctness. See BUG-02 for the data fix.

## Acceptance Criteria

- [ ] `DeckListParser` correctly parses a line like `4 Basic Grass Energy SVE 1` into `DeckImportEntry(quantity: 4, name: "Basic Grass Energy", setCode: "SVE", number: "1")`
- [ ] Parsing a full PTCGL paste that includes energy lines produces a `DeckImportEntry` for each energy line (not nil)
- [ ] After BUG-02 lands (SVE energy data in bundled JSON), energy entries resolve to a matched `CachedCard` in `DeckImportLookup`
- [ ] Unit test: `DeckListParserTests` covers a basic energy line with 5+ tokens

## Technical Notes

- Parser: `JustTCG/Data/Import/DeckListParser.swift` — `parseLine(_:)`
- Lookup: `JustTCG/Data/Import/DeckImportLookup.swift`
- The parser fix is likely minimal — verify the token extraction handles 5-token lines correctly and that the "Basic" prefix doesn't accidentally fall into a prefix-skip guard
