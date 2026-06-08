# M19-02 — Live Game Setup Sheet

**Status:** done  
**Milestone:** M19 — Live Game Mode  
**Dependencies:** M19-01

## User Story

As a player, I want a quick setup sheet before a game starts so I can declare which deck I'm playing, who I'm facing, and who goes first — and then jump straight into the live HUD with a single tap.

## Acceptance Criteria

- [x] A "Start Live Game" entry point exists in `DeckDetailView` as a toolbar button (play icon) or prominent button in the deck actions area
- [x] Tapping the entry point presents a `LiveGameSetupSheet` as a `.sheet` with `.presentationDetents([.medium])`
- [x] The sheet contains:
  - **Opponent Archetype** — same text field + meta-deck quick-pick as `LogMatchSheet`; reuses `LogMatchViewModel`-style suggestions
  - **Who Goes First** — a segmented control with options "Me" / "Them" / "Undecided" (defaults to Undecided; stored as `isPlayerGoingFirst: Bool` when committed; if Undecided the game begins with an explicit coin-flip prompt)
  - **Event** — same `EventType` picker as `LogMatchSheet` (collapsed under "More Details" disclosure)
  - **Format** — same `MatchFormat` segmented picker (also under disclosure)
- [x] A "Start Game" button is enabled only when an opponent archetype has been entered
- [x] Tapping "Start Game" calls `LiveGameRepository.startGame(...)`, kicks off the first turn (player's or opponent's, based on "Who Goes First"), and navigates full-screen to `LiveGameHUDView` (M19-03)
- [x] If "Undecided" was selected, a coin-flip overlay appears on the HUD screen before the first turn timer starts; the player taps "Going First" or "Going Second" to confirm and begin

## Technical Notes

**New files:**
- `JustTCG/Features/LiveGame/LiveGameSetupSheet.swift`
- `JustTCG/Features/LiveGame/LiveGameSetupViewModel.swift`

**Navigation:** `LiveGameHUDView` is pushed as a full-screen cover (`.fullScreenCover`) from whichever view launches the setup sheet, not pushed onto a `NavigationStack` — the HUD is intentionally immersive and shouldn't show a back button mid-game.

**ViewModel sketch:**
```swift
@Observable
final class LiveGameSetupViewModel {
    var archetypeQuery = ""
    var suggestions: [Archetype] = []
    var selectedArchetype = ""
    var goesFirst: GoesFirst = .undecided  // enum: me, them, undecided
    var eventType: EventType = .casual
    var format: MatchFormat = .bo3
    var showMoreDetails = false

    var isValid: Bool { !selectedArchetype.trimmingCharacters(in: .whitespaces).isEmpty }

    func startGame(deck: Deck, context: ModelContext) -> LiveGame { ... }
}
```

The sheet reuses the archetype autocomplete logic already present in `LogMatchViewModel` — extract the shared suggestions/search behaviour into a free function or a small `ArchetypeSearchController` to avoid duplication.
