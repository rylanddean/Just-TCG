# BUG-25 — Card Scanner Unreliable Detection

**Status:** done  
**Area:** Card Scanner

## Description

The camera-based card scanner frequently fails to detect cards or produces low-confidence results, making it unreliable for quickly scanning a physical deck. The current pipeline runs VNRecognizeTextRequest on raw frames, then relies on `CardIdentifierParser` finding a set code near a `###/###` number pattern. Several real-world failure modes make this brittle: poor framing (card not centred), glare on foil cards, set codes containing only 2–3 chars being mistaken for excluded keywords, and the name extractor picking the wrong line from the top-third heuristic.

## Steps to Reproduce

1. Open a deck and tap the scan icon
2. Hold a Pokémon card in front of the camera at various angles

## Observed Behaviour

- Scanner frequently stays in `.scanning` state without transitioning to `.matched`
- Set code is sometimes parsed as `nil` even when clearly visible on-card
- Card name extraction picks up HP values or set identifiers as the card name
- Low-confidence results are silently discarded (no user feedback), so it appears as if nothing happened

## Desired Behaviour

The scanner reliably identifies cards in good lighting after 1–2 seconds. When confidence is medium, a best-guess result is shown with a visual indicator rather than silently dropped. The UI communicates scanning state (e.g. a pulsing border) so the user knows it is actively processing.

## Acceptance Criteria

### Parser improvements
- [ ] `extractSetCode` exclusion list is expanded to cover common false positives: `"HP"`, `"GX"`, `"EX"`, `"VS"`, `"TAG"`, `"ACE"`, `"ATK"`, `"DEF"`, `"SP"`, `"LV"`, `"V"`, `"VMAX"`, `"VSTAR"`, `"EX"` (deduplicated)
- [ ] `extractCardName` no longer returns a line that is purely uppercase (set code artifacts) — lines must contain at least one lowercase letter or be a proper-noun pattern
- [ ] `extractCardNumber` also accepts formats without spaces around `/` (e.g. `"023/196"`) and 3-digit set totals above 200 (e.g. `"123/264"`)

### Confidence & fallback
- [ ] Results with `.medium` confidence (number found, no set code) are **not** discarded — they trigger a match attempt using card number only
- [ ] `CardScanMatcher.match(result:)` adds a number-only path: if `setCode` is nil but `cardNumber` is non-nil, fetch all `CachedCard` where `number == cardNumber` and return up to 3 matches ranked by set recency
- [ ] The `.matched` UI state shows a `"Low confidence"` badge when the result was medium or the number-only path was used

### Camera / framing UX
- [ ] A scan target reticle (rounded rectangle overlay, `stroke` only, no fill) is drawn over the camera preview to guide card alignment
- [ ] A subtle animated pulse (opacity cycle 0.4→1.0, 1 s period) on the reticle communicates active scanning
- [ ] When the scanner is in `.scanning` state and no frame has produced a medium-or-higher result in the last 3 seconds, a small label "Move card into frame" is shown below the reticle

### No regressions
- [ ] Existing `.high`-confidence set+number exact match path is unchanged
- [ ] `addCard` and the 1-second pause-then-resume flow are unchanged

## Technical Notes

**Files to change:**
- `JustTCG/Features/CardScanner/CardIdentifierParser.swift` — parser hardening
- `JustTCG/Features/CardScanner/CardScanMatcher.swift` — number-only fallback path
- `JustTCG/Features/CardScanner/CardScannerViewModel.swift` — pass medium-confidence results through; add 3-second "no match" timer for hint label
- `JustTCG/Features/CardScanner/CardScannerView.swift` — reticle overlay, pulse animation, hint label
- `JustTCG/Features/CardScanner/CameraPreviewView.swift` — no changes expected
