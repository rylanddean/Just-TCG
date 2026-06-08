# M14-01 — Edit Deck Name from Deck List

**Status:** done  
**Milestone:** M14 — Deck Management Polish  
**Dependencies:** none

## User Story

As a user, I want to rename a deck directly from the deck list so that I don't have to open the builder just to fix a name.

## Context

`DeckBuilderView` already supports inline rename (tap the nav title → text field). This story adds rename access from `DecksView` via a leading swipe action, so users can rename without leaving the list.

## Acceptance Criteria

- [x] Leading swipe action on each deck row shows a "Rename" button (orange, pencil icon)
- [x] Tapping "Rename" presents an alert with a text field pre-filled with the current deck name
- [x] Submitting the alert with a non-empty, changed name saves the rename immediately (no extra confirmation)
- [x] Submitting with an empty or whitespace-only string discards the change (name stays as-is)
- [x] The deck row reflects the new name immediately after rename (SwiftData auto-refresh)
- [x] `updatedAt` is bumped on rename (consistent with builder inline rename)

## Technical Notes

- Add `@State private var deckToRename: Deck? = nil` and `@State private var renameText = ""` to `DecksView`
- Use `.alert` with `presenting: deckToRename`, same pattern as the existing delete alert, adding a `TextField("Deck name", text: $renameText)` inside
- Call `DeckRepository(modelContext: context).renameDeck(deck, to: trimmed)` — the method already exists; `DeckBuilderViewModel.rename(to:)` delegates to it
- Leading swipe: `.swipeActions(edge: .leading)` with `Label("Rename", systemImage: "pencil")` and `.tint(.orange)`
- No changes needed to `DeckBuilderViewModel` or `DeckRepository` — all rename logic is already in place
