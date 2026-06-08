# BUG-14 — App Crashes When Opening a Deck in the Deck Editor

**Status:** done  
**Area:** M16 — Deck Edit Log  

## Description

Tapping a deck to open it in the deck editor causes the entire app to crash. The crash occurs before the editor view is presented.

## Steps to Reproduce

1. Launch the app and navigate to the deck list
2. Tap any deck to open it in the deck editor
3. App crashes immediately

## Desired Behaviour

The deck editor opens without crashing and displays the selected deck's cards.

## Acceptance Criteria

- [x] Tapping a deck from the deck list opens the deck editor without crashing
- [x] The deck editor displays the correct deck and its cards
- [x] No regression: deck list still loads and displays all decks correctly

## Root Cause

`CardRepository.fetchBasicEnergies()` used a `#Predicate` with `$0.subtypes.contains("Basic")` on a `[String]` transformable attribute. CoreData translates this to a SQL CONTAINS check against the serialised blob. When any row has a null value for that column, CoreData passes `nil` to `CFStringGetLength` → `EXC_BAD_ACCESS (KERN_INVALID_ADDRESS 0x0)`.

## Fix

Fetch all `Energy` cards by `supertype` alone (a safe scalar predicate), then filter for the `"Basic"` subtype in memory inside `fetchBasicEnergies()`.
