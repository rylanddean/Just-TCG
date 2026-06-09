# M20-01 — Vision OCR Pipeline & Card Identifier Parser

**Status:** done  
**Milestone:** M20 — OCR Card Scanner  
**Dependencies:** none

## User Story

As a player, I want the app to recognise a physical Pokémon card held up to the camera so I don't have to search by name when building a deck from my collection.

## Acceptance Criteria

### OCR Capture
- [x] A new `CardScannerService` class accepts a `CVPixelBuffer` (from AVFoundation) and returns a `CardScanResult` asynchronously
- [x] It uses `VNRecognizeTextRequest` in `.accurate` recognition level
- [x] The request is performed on a background actor (`ScannerActor` using `@globalActor`) to avoid blocking the main thread
- [x] `CardScanResult` is:
  ```swift
  struct CardScanResult {
      let rawLines: [String]       // all recognised text lines
      let cardName: String?        // best candidate for card name
      let setCode: String?         // parsed set code (e.g. "SFA")
      let cardNumber: String?      // parsed card number (e.g. "010")
      let confidence: ScanConfidence  // .high / .medium / .low
  }
  enum ScanConfidence { case high, medium, low }
  ```

### Card Identifier Parser
- [x] A `CardIdentifierParser` struct (pure, no I/O) takes `[String]` raw OCR lines and produces a `CardScanResult`
- [x] **Set + number extraction:** scans lines for the pattern `\b(\d{1,3})\s*/\s*\d{1,3}\b` to find the card number; then looks for a 2–4 uppercase-letter token on the same or adjacent line as the set code
- [x] **Card name extraction:** treats the longest line in the top third of observations (by bounding-box y-position) that is ≥ 3 characters and not a number as the candidate card name
- [x] Confidence assignment:
  - `.high` — both set code and card number were found and matched a known set code in the local `CachedCard` store
  - `.medium` — card number found but set code is ambiguous; or name found with no number
  - `.low` — only raw lines, no structured data extracted
- [x] `CardIdentifierParser` is covered by unit tests in `CardIdentifierParserTests.swift` with at least 5 representative OCR input fixtures (standard card, basic energy, ex card, full-art card, partial OCR)

### Card Lookup
- [x] A `CardScanMatcher` takes a `CardScanResult` and a `ModelContext` and returns a `[CachedCard]` (ordered by match confidence, max 3 results):
  1. Exact `(setCode, number)` match → returns single result with `.high` confidence
  2. If no exact match, fuzzy name search using `CardRepository.search(query:filter:sort:context:)` → up to 3 results
- [x] The lookup is async and cancellable

## Technical Notes

**New files:**
- `JustTCG/Features/CardScanner/CardScannerService.swift`
- `JustTCG/Features/CardScanner/CardIdentifierParser.swift`
- `JustTCG/Features/CardScanner/CardScanMatcher.swift`
- `JustTCGTests/CardIdentifierParserTests.swift`

**Framework:** `import Vision` — no third-party OCR dependency.

**Known set codes:** `CardScanMatcher` derives the known set code list at runtime by querying `SELECT DISTINCT setCode FROM CachedCard` (via `CardRepository` or a direct `FetchDescriptor`). This avoids hard-coding a set list.

**AVFoundation integration** is deferred to M20-02. `CardScannerService` accepts `CVPixelBuffer` directly so it can be unit-tested with synthetic inputs without a camera.

**Pokémon card anatomy notes:**
- Card name: top of card, large bold font, always present
- Set number: bottom of card, printed as `NNN/TTT` where NNN is the card's set number
- Set code: printed as a 2–4 char uppercase code after the regulation mark at the bottom (e.g., `G SFA` where `G` is the regulation mark and `SFA` is the set code)
- Basic Energy cards print the energy type as the name with no number line — the parser should recognise "Fire Energy", "Water Energy" etc. and map them to the correct `CachedCard` via `isBasicEnergy == true && name == energyType + " Energy"`
