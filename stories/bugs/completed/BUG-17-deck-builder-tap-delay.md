# BUG-17 — Deck Builder Card Taps Are Delayed, Causing Missed or Double Taps

**Status:** done  
**Area:** Decks — Deck Builder  

## Description

Tapping to add or remove a card in the deck builder has a noticeable delay before the UI responds. Because the tap feedback is slow, users frequently tap again thinking the first tap did not register, resulting in missed increments or double-increments. The sluggishness makes the builder feel unresponsive and leads to incorrect card counts.

## Steps to Reproduce

1. Open any deck in the deck builder
2. Tap the + or − control on any card at a normal interaction pace
3. Observe the delay before the count updates
4. Tap again at a natural follow-up pace — the second tap either does not register or double-counts

## Desired Behaviour

Tap response is immediate (< 100 ms perceived latency). Users can add or remove cards at a quick, natural pace without misregistered taps.

## Acceptance Criteria

- [x] The card count updates visually on the same frame as the tap gesture ends
- [x] Rapid successive taps correctly increment/decrement by the number of taps, with no missed or double inputs
- [x] No regression: card count still persists correctly after leaving and re-entering the builder
- [x] Scrolling and other interactions in the builder are not degraded

## Root Cause

The deck builder's "Add Basic Energy" section embedded a `ScrollView(.horizontal)` inside a `List`. SwiftUI's gesture recognizer system has to arbitrate between the outer `List`'s vertical scroll, the inner `ScrollView`'s horizontal scroll, and button tap gestures on every row. This arbitration introduced a ~300 ms delay on all tap gestures in the list, not just those in the scroll view section.

## Fix

Removed the inline basic-energy quick-add section entirely. Energy cards are now added via the per-section "Add more" button (which opens the card picker pre-filtered to energy), eliminating the nested `ScrollView` and restoring immediate tap response throughout the builder.
