# BUG-16 — Deck List Preview Cards Misaligned When Fewer Than Three Cards Shown

**Status:** done  
**Area:** Decks — Deck List  

## Description

The deck row preview card strip is not consistently aligned. When a deck has enough cards to show three previews the layout looks correct, but when only one or two preview cards are available the strip left-aligns the cards instead of centering them to match the fixed width of the three-card case. This makes the row look visually inconsistent across decks.

## Steps to Reproduce

1. Create or find a deck with only one card (or a deck whose cover images produce only one visible preview)
2. Navigate to the deck list
3. Compare that row to a deck row that shows three preview cards

## Desired Behaviour

The preview card strip is always centered and occupies the same fixed width regardless of how many preview cards are displayed. A single preview card sits centered within the same container that would hold three.

## Acceptance Criteria

- [x] One-card preview rows are horizontally centered to match the width of a three-card preview strip
- [x] Two-card preview rows are likewise centered within the same fixed-width container
- [x] Three-card preview rows are unaffected
- [x] Alignment is consistent across all deck rows in the list

## Root Cause

`thumbnailStack` in `DeckRowView` computed its frame width from the number of cards actually returned (`cards.count`), so a row with one cover card got width 44 pt while a row with two cards got 62 pt. Because the thumbnail stack was the left-fixed element of the `HStack`, the deck name and stats started at a different X offset per row.

## Fix

Changed the frame width formula to use `coverCardCount` (the configured maximum) instead of `cards.count`. The container is now always `44 + (coverCardCount - 1) × 18` pt wide regardless of how many cards are actually shown, keeping every row's text column aligned.
