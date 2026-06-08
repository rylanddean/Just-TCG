# M23-01 — Pokémon TCG Rulebook Content Bundle

**Status:** todo  
**Milestone:** M23 — Rules Assistant  
**Dependencies:** none

## User Story

As a developer, I need the official Pokémon TCG rulebook content available as structured in-bundle data so the Rules Assistant can answer questions grounded in accurate, up-to-date rules.

## Acceptance Criteria

- [ ] A JSON file `JustTCG/Resources/PokemonTCGRules.json` is added to the app bundle
- [ ] The file contains an array of rule sections, each with a `title` (string) and `body` (string) field
- [ ] Sections map directly to the official Pokémon TCG rulebook structure — at minimum:
  - Setup
  - Your Turn (Draw, Bench, Evolve, Attach Energy, Play Trainer, Attack, End Turn)
  - Attacking (Weakness, Resistance, damage application)
  - Special Conditions (Asleep, Confused, Burned, Paralyzed, Poisoned)
  - Prizes and Winning
  - Rule Box Pokémon (ex, VSTAR, V, GX) — 2-prize rule
  - Stadium Cards
  - Ace Spec Cards
  - Mulligan
  - Abilities vs Attacks
  - Frequently misplayed rules (e.g., evolving restrictions, when effects are applied)
- [ ] A `RulebookSection` struct is defined in Swift at `JustTCG/Data/Rules/RulebookSection.swift`:
  ```swift
  struct RulebookSection: Codable, Identifiable {
      var id: String { title }
      let title: String
      let body: String
  }
  ```
- [ ] A `RulebookLoader` struct at `JustTCG/Data/Rules/RulebookLoader.swift` exposes:
  - `static func load() -> [RulebookSection]` — decodes the bundle JSON
  - `static func fullText() -> String` — concatenates all sections as "## {title}\n{body}" for use as LLM context
- [ ] The bundled content is sourced from the official Pokémon TCG Rulebook (publicly available at pokemon.com/us/pokemon-tcg/rules-and-formats/) — no copyrighted art or images, rules text only

## Technical Notes

**New files:**
- `JustTCG/Resources/PokemonTCGRules.json`
- `JustTCG/Data/Rules/RulebookSection.swift`
- `JustTCG/Data/Rules/RulebookLoader.swift`

**JSON structure example:**
```json
[
  {
    "title": "Setup",
    "body": "Each player shuffles their 60-card deck and draws 7 cards. Place 6 Prize cards face-down. Each player places a Basic Pokémon face-down as their Active Pokémon; they may also place up to 5 Basic Pokémon on their Bench. If a player has no Basic Pokémon, they reveal their hand, shuffle it back, draw 7 new cards, and the opponent may draw 1 extra card (Mulligan)."
  },
  ...
]
```

**`RulebookLoader` implementation:**
```swift
struct RulebookLoader {
    static func load() -> [RulebookSection] {
        guard
            let url = Bundle.main.url(forResource: "PokemonTCGRules", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return [] }
        return (try? JSONDecoder().decode([RulebookSection].self, from: data)) ?? []
    }

    static func fullText() -> String {
        load()
            .map { "## \($0.title)\n\($0.body)" }
            .joined(separator: "\n\n")
    }
}
```
