# BUG-04 — Analytics View Renders Deck Names with Garbled Characters

**Status:** done  
**Area:** Analytics — `AnalyticsView`

## Description

In the Analytics tab, the deck picker and any other surface that renders `deck.name` displays garbled/replacement characters instead of the intended special characters (e.g. accented letters, em dashes, Pokémon-specific glyphs). A deck named "Gardevoir ex – Night Wanderer" might appear as "Gardevoir ex â€" Night Wanderer" or similar mojibake.

## Steps to Reproduce

1. Create or import a deck whose name contains a special character (e.g. an em dash `–`, an accented character like `é`, or a Unicode symbol).
2. Navigate to the **Analytics** tab.
3. Observe the deck picker label — the special character is replaced with one or more garbage bytes/replacement characters.

## Root Cause (suspected)

The `Deck.name` `String` value is stored and retrieved correctly by SwiftData, but somewhere in the display path the string is being round-tripped through a lossy encoding (e.g. `String(bytes:encoding:)` with `.ascii` or `.isoLatin1` instead of `.utf8`). The deck picker at `AnalyticsView.deckPicker` renders `Text(deck.name)` directly, so if the name arrives corrupted the issue is upstream — likely in the import path (`DeckListParser`) or a `Deck` initialiser that converts clipboard text.

## Acceptance Criteria

- [x] A deck named with an em dash (e.g. `Gardevoir ex – Night Wanderer`) is displayed correctly in the Analytics deck picker
- [x] A deck named with accented characters (e.g. `Miraidon ex / Raichu`) is displayed correctly
- [x] No regression in deck names that use only ASCII characters
- [x] Added `LimitlessHTMLParserTests` with 8 tests covering named entities, decimal and hex numeric references, and ASCII passthrough

## Technical Notes

- Deck picker: `JustTCG/Features/Analytics/AnalyticsView.swift` — `deckPicker` (line 186)
- Deck model: `JustTCG/Data/Models/Deck.swift` — `name: String`
- Likely culprit: any `String(bytes:encoding:)` or `String(data:encoding:)` call in the import or persistence layer that uses a non-UTF-8 encoding
