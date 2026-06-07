# M13-01 — Meta Deck Picker in Log Match Sheet

**Status:** todo  
**Milestone:** M13 — Match Log UX  
**Dependencies:** M3-03

## User Story

As a player logging a match, I want to pick my opponent's deck from a dropdown of current meta archetypes, so that I can log quickly without typing and keep archetype names consistent across my match history.

## Acceptance Criteria

- [ ] The "Opponent Archetype" section in `LogMatchSheet` gains a `Picker` (`.menu` style) labelled **"Quick Pick"** that lists the current meta decks in prevalence order, with a **"Custom"** entry as the first/default option
- [ ] Selecting any non-Custom option from the picker pre-fills `archetypeQuery` with that archetype name and suppresses the type-ahead suggestions (same behaviour as tapping an existing suggestion row)
- [ ] After a Quick Pick selection the picker resets its own displayed value back to "Custom" — the chosen name lives in the text field, not the picker selection
- [ ] The `TextField` remains visible at all times; it is the fallback for any deck not in the list
- [ ] If the user types in the `TextField` after making a Quick Pick selection, the type-ahead suggestions resume as normal (existing `suppressSuggestions` logic is unchanged)
- [ ] The meta deck list is loaded from a bundled `metaDecks.json` file; if the file is missing or malformed the picker is hidden and the section falls back to text-only entry
- [ ] `metaDecks.json` ships with the current Standard meta at time of implementation — at minimum the top 10 archetypes by tournament share

## Technical Notes

**New file — `JustTCG/Resources/metaDecks.json`**

A flat JSON array of archetype name strings in prevalence order:

```json
["Charizard ex / Pidgeot ex", "Regidrago VSTAR", "Dragapult ex / Pidgeot ex", ...]
```

No model wrapper needed — decode as `[String]`.

**New file — `JustTCG/Domain/Entities/MetaDeckRepository.swift`**

```swift
struct MetaDeckRepository {
    static let shared = MetaDeckRepository()
    let all: [String]

    private init() {
        guard
            let url = Bundle.main.url(forResource: "metaDecks", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { all = []; return }
        all = decoded
    }
}
```

**`LogMatchViewModel` changes**

- Add `var metaDecks: [String] { MetaDeckRepository.shared.all }`
- Add `var quickPickSelection: String = "Custom"` — the picker binding
- In `selectArchetype(_:)`, also reset `quickPickSelection = "Custom"` so the picker label clears after selection

**`LogMatchSheet.archetypeSection` changes**

- Add a `Picker("Quick Pick", selection: $vm.quickPickSelection)` using `.pickerStyle(.menu)` above the `TextField`
- Options: `"Custom"` tag + one `Text(name)` per `vm.metaDecks` entry
- Wire an `.onChange(of: vm.quickPickSelection)` that calls `vm.selectArchetype(Archetype(id: name, name: name, primaryType: ""))` when the value is not `"Custom"`, then resets `vm.quickPickSelection = "Custom"`
- Guard the picker on `!vm.metaDecks.isEmpty` — hide it entirely when the list is empty

**Placement in the form row**

```
Section("Opponent Archetype") {
    if !vm.metaDecks.isEmpty {
        Picker("Quick Pick", selection: $vm.quickPickSelection) { ... }
    }
    TextField("e.g. Charizard ex / Pidgeot ex", text: $vm.archetypeQuery)
    // existing suggestions rows
}
```

No new view files needed — all changes live in the two existing files plus the new repository and JSON resource.
