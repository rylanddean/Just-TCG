# BUG-33 — Card Scanner: Dismiss Wrong Guesses & Cycle Through Candidates

**Status:** done  
**Area:** M20 — Card Scanner / Deck Editor

## Description

The card scanner in the Deck Editor (`CardScannerView` + `CardScannerViewModel`) is still unreliable in practice. When the scanner shows a wrong guess in the match sheet, the only option is "Not right?" which calls `vm.resumeScanning()` — this just resumes the camera, and on the next frame the same OCR result typically matches to the **same wrong card** again. The user has no way to tell the scanner "this guess is wrong, show me the next-best candidate or a different card." 

The matcher already returns ranked `alternatives` alongside the `primary` (see `state = .matched(primary:, alternatives:)`), but the UI does not surface them, and there is no mechanism to **dismiss** the primary candidate so that subsequent OCR scans skip it.

## Steps to Reproduce

1. Open a deck in the Deck Editor
2. Tap "Scan Cards"
3. Scan a card the matcher gets wrong (common with similar names or holos with reflections)
4. Tap "Not right?" to resume scanning
5. Re-scan the same card → the same wrong primary is matched again

## Observed Behaviour

- "Not right?" only re-enters scanning state; it does not change which card the matcher picks next time
- Alternatives returned by `CardScanMatcher` are silently discarded
- No way to manually pick a different candidate or force the matcher to skip a known-wrong guess
- The user ends up cancelling the scanner and adding the card manually

## Desired Behaviour

- "Not right?" dismisses the current primary guess for the rest of the scanning session — the matcher won't propose it again
- The match sheet exposes the next-best alternatives so the user can pick one directly instead of waiting for another OCR pass
- A reset/clear option (or automatic clear on scanner dismiss) restores dismissed guesses so they're back in the pool for the next session

## Acceptance Criteria

### Dismiss Wrong Guesses
- [ ] `CardScannerViewModel` holds a `dismissedCardIds: Set<UUID>` (or `Set<String>` matching `CachedCard.id`) for the current scanning session
- [ ] A new `dismissCurrentMatch()` method adds the primary's id to the set and resumes scanning
- [ ] `processFrame` filters matches by `dismissedCardIds` before picking the new primary — if all top candidates are dismissed, fall back to the next-ranked candidate; if everything is dismissed, leave the state as `.scanning` (don't pop the sheet)
- [ ] `CardScanMatcher.match(result:)` is called with the dismiss set (or the VM filters its return value) so that dismissed cards never resurface for the rest of the session

### Show & Pick Alternatives
- [ ] The match sheet in `CardScannerView.matchSheet` shows up to 3 alternatives below the primary card row (small horizontal scroller with card name + set/number + thumbnail), pulled from `alternatives` in the `.matched` state
- [ ] Tapping an alternative makes it the new primary in the sheet (it doesn't add yet — user still confirms with "+ Add")
- [ ] The previous primary is auto-dismissed when the user picks an alternative

### Update "Not right?" Behaviour
- [ ] "Not right?" calls `dismissCurrentMatch()` instead of just `resumeScanning()`
- [ ] Label remains "Not right?" — no copy change required

### Reset Dismissals at End of Session
- [ ] `dismissedCardIds` is cleared when the scanner view is dismissed (in `stopSession()` or `onDisappear`) so opening the scanner again starts from a clean slate
- [ ] No persistence across scanner opens — this is intentionally session-scoped

### No Regressions
- [ ] "+ Add" flow still adds the currently displayed card to the deck and resumes scanning after the 1-second pause
- [ ] Torch toggle, low-confidence pill, and framing hint all work as before

## Technical Notes

**Files to change:**
- `JustTCG/Features/CardScanner/CardScannerViewModel.swift` — add `dismissedCardIds`, `dismissCurrentMatch()`, filter logic in `processFrame`, currentPrimary override for alternatives selection, clear set in `stopSession`
- `JustTCG/Features/CardScanner/CardScannerView.swift` — add alternatives strip to `matchSheet`; route "Not right?" through `dismissCurrentMatch()`
- `JustTCG/Features/CardScanner/CardScanMatcher.swift` — optional: accept an `excluding: Set<...>` parameter so dismissed cards don't even appear in the candidate ranking

**Existing structure to leverage:**
The matcher already exposes alternatives:
```swift
state = .matched(primary: matches.first, alternatives: Array(matches.dropFirst()))
```
The dismiss flow is the missing piece — the alternatives just need a UI affordance and the dismiss set needs to feed back into the matcher loop.
