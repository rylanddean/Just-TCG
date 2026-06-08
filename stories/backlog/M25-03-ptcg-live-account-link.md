# M25-03 — PTCG Live Account Link

**Status:** todo  
**Milestone:** M25 — Player Profile  
**Dependencies:** M25-02

## User Story

As a player, I want to connect my Pokémon TCG Live account to my profile so I can see my username and rank displayed alongside my in-app stats.

## Acceptance Criteria

### Data Model
- [ ] PTCG Live info is stored in `@AppStorage`:
  - `ptcgLiveUsername: String` (default `""`)
  - `ptcgLiveRank: String` (default `""` — free text, e.g. "Legend III", "Expert 1")
- [ ] No network calls to PTCG Live — this is manual entry only (there is no public PTCG Live API)

### Profile View Integration
- [ ] A "Pokémon TCG Live" section appears at the bottom of `ProfileView`
- [ ] **Connected state** (`ptcgLiveUsername` non-empty):
  - Displays the username with a PTCG Live icon (`gamecontroller.fill`)
  - Displays the rank below if non-empty
  - An "Open PTCG Live" button attempts to open the app via deep link `ptcglive://` — if the app is not installed, opens the App Store listing URL instead
  - An "Edit" button opens the edit sheet
- [ ] **Disconnected state** (`ptcgLiveUsername` empty):
  - A prompt: "Connect your Pokémon TCG Live account to display your username and rank."
  - A "Connect Account" button opens the edit sheet

### Edit Sheet
- [ ] Tapping "Connect Account" or "Edit" presents a sheet with:
  - `TextField("Username", text: $ptcgLiveUsername)` — free text, no validation
  - `TextField("Rank (optional)", text: $ptcgLiveRank)` — free text, placeholder "e.g. Legend III"
  - "Save" button (disabled if username is empty after trimming) and "Cancel"
- [ ] Saving dismisses the sheet and the profile view immediately reflects the new values
- [ ] A "Disconnect" button (destructive, shown only when already connected) clears both fields

### Settings Integration
- [ ] The same PTCG Live connection section is mirrored in `SettingsView` under a new "Accounts" group
- [ ] Editing from either location writes to the same `@AppStorage` keys and both views reflect changes

## Technical Notes

**Files to change:**
- `JustTCG/Features/Profile/ProfileView.swift` — add PTCG Live section + sheet state
- `JustTCG/Features/Settings/SettingsView.swift` — add Accounts group

**New file:**
- `JustTCG/Features/Profile/PTCGLiveEditSheet.swift`

**App Store URL (PTCG Live):**
```swift
// Deep link — will only work if PTCG Live is installed
let deepLink = URL(string: "ptcglive://")!
// Fallback App Store URL
let appStoreURL = URL(string: "https://apps.apple.com/app/pokemon-tcg-live/id1641569078")!

if UIApplication.shared.canOpenURL(deepLink) {
    UIApplication.shared.open(deepLink)
} else {
    UIApplication.shared.open(appStoreURL)
}
```

**`@AppStorage` keys:**
```swift
@AppStorage("ptcgLiveUsername") private var ptcgLiveUsername = ""
@AppStorage("ptcgLiveRank") private var ptcgLiveRank = ""
```

These keys are the same in both `ProfileView` and `SettingsView` — `@AppStorage` automatically stays in sync.
