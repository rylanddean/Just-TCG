# M20-02 — Scan-to-Deck Camera UI

**Status:** todo  
**Milestone:** M20 — OCR Card Scanner  
**Dependencies:** M20-01

## User Story

As a player, I want to point my camera at a physical card, see it recognised on screen, and add it to my deck with a single tap — so I can build a deck directly from my collection without any typing.

## Acceptance Criteria

### Entry Point
- [ ] A "Scan Cards" option appears alongside the existing "Add Cards" button in `DeckDetailView`
- [ ] Tapping it requests camera permission (`NSCameraUsageDescription` must be added to `Info.plist`) and presents `CardScannerView` as a `.fullScreenCover`
- [ ] If camera permission is denied, a descriptive alert is shown with a link to Settings

### Camera View
- [ ] The live camera feed fills the screen using `AVCaptureVideoPreviewLayer` wrapped in a `UIViewRepresentable`
- [ ] A card-shaped rounded rectangle overlay (aspect ratio ~5:7, roughly 70% of screen width) guides the user to frame the card
- [ ] The overlay border pulses green when a `.high` confidence match is detected, yellow for `.medium`, and white/grey for `.low` or no match
- [ ] Still frames are captured at ~2fps when the scanner is active; captured via `AVCaptureVideoDataOutput` on a background queue and passed to `CardScannerService`
- [ ] The scan pipeline runs continuously — the user does not need to tap a shutter button

### Match Preview
- [ ] When a card is identified (confidence `.medium` or `.high`), a bottom sheet slides up showing:
  - Card art (`AsyncImage` from `imageURL`)
  - Card name + set name + number
  - Current quantity in deck
  - **"+ Add"** button (increments quantity, shows haptic feedback)
  - **"Not right?"** button that freezes the match and opens the existing card picker pre-filled with the parsed card name as the search query
- [ ] Adding a card via **"+ Add"** calls `DeckRepository.addCard(...)` and immediately updates the in-deck badge without dismissing the scanner
- [ ] The "quantity in deck" badge and cap enforcement (max 4, unlimited for Basic Energy) match the behaviour in the existing card picker

### Scan Session
- [ ] After tapping **"+ Add"**, the scanner resets and resumes scanning for the next card after a 1-second pause (to let the user move to the next physical card)
- [ ] A running tally at the top of the screen shows "N cards added" during the session
- [ ] A **"Done"** button in the top-right corner dismisses the scanner and returns to `DeckDetailView`
- [ ] If the user has added cards and taps "Done", no confirmation prompt is needed — cards are already persisted

## Technical Notes

**New files:**
- `JustTCG/Features/CardScanner/CardScannerView.swift`
- `JustTCG/Features/CardScanner/CameraPreviewView.swift` (UIViewRepresentable wrapping AVCaptureVideoPreviewLayer)
- `JustTCG/Features/CardScanner/CardScannerViewModel.swift`

**Files to change:**
- `JustTCG/Features/Decks/DeckDetailView.swift` — add "Scan Cards" entry point
- `Info.plist` — add `NSCameraUsageDescription`

**AVCapture setup** (inside `CameraPreviewView.Coordinator`):
```swift
let session = AVCaptureSession()
session.sessionPreset = .hd1280x720   // balance quality vs. processing cost
let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
// add input, add AVCaptureVideoDataOutput with 2fps throttle via timestamp check
```

**2fps throttle** — check `CMSampleBufferGetPresentationTimeStamp` in `captureOutput(_:didOutput:from:)` and skip frames closer than 0.5s to the last processed frame.

**ViewModel state machine:**
```swift
enum ScanState {
    case scanning           // actively processing frames
    case matched(CachedCard, [CachedCard])  // primary match + alternatives
    case paused             // briefly after adding a card
}
```

**Permissions:** The `CardScannerViewModel` checks `AVCaptureDevice.authorizationStatus(for: .video)` on init and requests access if `.notDetermined`. The view observes a `permissionDenied: Bool` flag to show the Settings alert.
