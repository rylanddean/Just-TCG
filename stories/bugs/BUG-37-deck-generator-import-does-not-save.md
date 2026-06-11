# BUG-37 — Deck Generator Import Navigates Away Without Saving

**Status:** open  
**Area:** Deck Generator — `DeckGeneratorView` / `DeckRepository`

## Description

After generating a deck and tapping "Create Deck" in the naming sheet, the app dismisses back to the Decks list but the new deck never appears. The deck is not persisted — restarting the app confirms it is gone.

## Root Cause

`DeckGeneratorView.performImport()` creates two **short-lived, local** `DeckRepository` instances — one for `createDeck`, one per `addCard` loop iteration. `DeckRepository.save()` is debounced: it schedules a `Task` that sleeps 300 ms before calling `context.save()`. The task retains `self` via `[weak self]`.

```swift
// DeckGeneratorView.performImport()
let deck = DeckRepository(modelContext: context).createDeck(...)   // schedules save after 300 ms
for match in matches where match.isMatched {
    DeckRepository(modelContext: context).addCard(...)             // each cancels previous, schedules new save
}
isImporting = false
showImportSheet = false
dismiss()   // view torn down immediately
```

Each `DeckRepository` is a temporary local value — the final instance is released at the end of `performImport()`, well before the 300 ms debounce fires. The `Task` holds only a `[weak self]` reference, which is already nil by the time the sleep completes, so `context.save()` is never called. The deck and its cards exist in the in-memory `ModelContext` graph but are never written to disk.

## Steps to Reproduce

1. Open the Deck Generator.
2. Type any archetype prompt (e.g. "Charizard ex") and send.
3. Tap "Import" on the returned deck list.
4. Enter a name and tap **"Create Deck"**.
5. Observe: app navigates to the Decks list — new deck is absent.
6. Force-quit and relaunch — deck is still absent.

## Observed Behaviour

- Navigation jumps to the Decks view after tapping "Create Deck."
- The new deck does not appear in the list.
- The deck is not found after a relaunch.

## Desired Behaviour

- Tapping "Create Deck" persists the deck synchronously before dismissing.
- The new deck appears in the Decks list immediately after the sheet closes.

## Acceptance Criteria

- [ ] `DeckGeneratorView.performImport()` calls `context.save()` (or `DeckRepository.saveNow()`) **before** calling `dismiss()`, ensuring the write completes while the view is still alive.
- [ ] A single `DeckRepository` instance is used throughout the import to avoid re-scheduling the debounce on every `addCard` call.
- [ ] Card quantities from the parsed deck list are respected — the current code calls `addCard` once per matched card but `match.entry.quantity` may be > 1; the loop should call `addCard` `quantity` times, or a bulk `setQuantity` helper should be used.
- [ ] After the fix, generating and importing a deck results in the deck appearing immediately in the Decks list with the correct name and card count.
- [ ] Force-quitting and relaunching after an import still shows the deck.

## Technical Notes

**File to change:** `JustTCG/Features/Decks/DeckGeneratorView.swift` — `performImport()`, lines ~277–304.

**Minimal fix** (call `saveNow()` on a single repo before dismiss):

```swift
private func performImport() {
    guard let deckList = importDeckList else { return }
    isImporting = true
    let name = importName.trimmingCharacters(in: .whitespaces)

    let entries = DeckListParser.parse(deckList)
    let matches = DeckImportLookup().resolve(entries, in: context)
    let unresolved = matches.filter { !$0.isMatched }

    if !unresolved.isEmpty {
        let names = unresolved.prefix(3).map { $0.entry.name }.joined(separator: ", ")
        importWarning = "Could not match: \(names)\(unresolved.count > 3 ? " and \(unresolved.count - 3) more" : "")"
    }

    let repo = DeckRepository(modelContext: context)
    let deck = repo.createDeck(name: name.isEmpty ? "Generated Deck" : name)
    for match in matches where match.isMatched {
        let entry = match.entry
        for _ in 0 ..< entry.quantity {
            repo.addCard(
                cardId: match.cardId!,
                to: deck,
                isBasicEnergy: entry.name.contains("Energy"),
                cardName: entry.name
            )
        }
    }
    repo.saveNow()   // flush before dismissing

    isImporting = false
    showImportSheet = false
    dismiss()
}
```

**Also note:** the `entry.quantity` loop fix above also addresses a secondary bug where multi-copy cards (e.g. 4× Professor's Research) would only ever be added as 1 copy because `addCard` increments by 1 each call and the original loop called it only once per match entry.
