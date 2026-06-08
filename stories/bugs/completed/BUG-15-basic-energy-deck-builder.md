# BUG-15 — Add Basic Energy Does Not Work; Basic Energy Cards Appear in Pokémon Section

**Status:** done  
**Area:** Deck Builder  

## Description

The "Add Basic Energy" feature in the deck builder does not function — tapping it has no effect or fails to add energy cards to the deck. Additionally, Basic Energy cards are incorrectly surfaced in the Pokémon section of the deck view instead of the Energy section.

## Steps to Reproduce

1. Open the deck builder with any deck
2. Attempt to add a Basic Energy card using the dedicated add basic energy control
3. Observe that no energy card is added to the deck
4. Scroll to the Pokémon section of the deck — Basic Energy cards are listed there instead of in the Energy section

## Desired Behaviour

- The add basic energy control successfully adds the selected Basic Energy card to the deck
- Basic Energy cards appear in the Energy section of the deck, not the Pokémon section

## Acceptance Criteria

- [x] Tapping add basic energy adds the correct energy card to the deck
- [x] Basic Energy cards are displayed in the Energy section of the deck builder
- [x] Basic Energy cards do not appear in the Pokémon section
- [x] No regression: non-energy Pokémon cards continue to display correctly in the Pokémon section

## Root Cause

`DeckGrouper.group()` used `!c.types.isEmpty` as the sole test for routing a card to the Pokémon bucket. Basic Energy cards have a non-empty `types` array (e.g., `["Fire"]`), so they passed that check and landed in `pokemon` instead of `energy`. The quick-add button was correctly adding the card to `deck.cards`, but it appeared in the wrong section, making the feature seem non-functional.

## Fix

Added a `c.supertype == "Energy"` guard at the top of the grouper loop. Energy cards (both Basic and Special) are now routed to `energy` before the `types` check is evaluated.
