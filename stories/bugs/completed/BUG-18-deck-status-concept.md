# BUG-18 — Decks Have No Status; No Way to Mark a Deck as Building, Playing, or Retired

**Status:** done  
**Area:** Decks — Deck Model / Deck List  

## Description

Decks currently have no concept of lifecycle status. Users cannot signal whether a deck is actively being built, currently being played in matches, or retired from use. This makes it hard to distinguish active decks from archived ones and clutters the deck list with decks that are no longer relevant.

## Steps to Reproduce

1. Open the deck list with several decks in different stages of use
2. Observe that there is no way to tell which decks are in-progress, competitive, or retired

## Desired Behaviour

Each deck has an explicit status — **Building**, **Playing**, or **Retired** — that is visible in the deck list row and editable from the deck detail or deck editor. The status can be used to filter or sort the deck list.

## Acceptance Criteria

- [x] The `Deck` model includes a `status` field with values: `building`, `playing`, `retired`
- [x] New decks default to `building`
- [x] The status is displayed on the deck list row (e.g., a label or badge)
- [x] The user can change the status from the deck editor or a context action on the deck row
- [x] Retired decks can be hidden from the main deck list (filtered out by default, accessible via a toggle or separate section)
- [x] Existing decks without a stored status are treated as `playing` for backwards compatibility
- [x] No regression: deck list, builder, and match logging all continue to function regardless of status

## Implementation

- Added `DeckStatus` enum (`building`, `playing`, `retired`) to `Deck.swift` as a `Codable` SwiftData property. Default value is `.playing` so existing persisted records fall back correctly; `init` explicitly sets `.building` for new decks.
- Added `DeckRepository.setStatus(_:for:)`.
- Added a `StatusBadge` view (coloured capsule chip) in the deck row next to the deck name: orange for building, green for playing, gray for retired.
- Leading swipe actions now include a purple "Status" action that opens a `confirmationDialog` to pick the three states.
- Retired decks are hidden by default; a toolbar archivebox toggle reveals them. Retired rows are additionally dimmed to 55% opacity.
