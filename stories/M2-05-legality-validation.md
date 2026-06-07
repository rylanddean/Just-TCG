# M2-05 — Deck Legality Validation

**Status:** todo  
**Milestone:** M2 — Deck Builder  
**Dependencies:** M2-04

## User Story
As a user, I want real-time feedback on whether my deck is tournament-legal so that I know exactly what I need to fix before I finish building.

## Acceptance Criteria

- [ ] The deck detail view shows a validation status banner:
  - Green "Legal deck" when all rules pass
  - Yellow warning(s) for non-blocking issues
  - Red error(s) for blocking issues
- [ ] Validation rules enforced:
  - **Error:** Total card count ≠ 60
  - **Error:** Any non-Standard-legal card present
  - **Error:** More than 4 copies of a named card (excluding basic Energy)
  - **Warning:** No Basic Pokémon in the deck
- [ ] Tapping a validation error scrolls to / highlights the offending card(s)
- [ ] Validation runs reactively — updates within 100ms of any deck change

## Technical Notes

- `DeckValidator` is a pure function / static struct in `Domain/Entities/`: `func validate(_ deck: Deck, cards: [CachedCard]) -> [DeckValidationError]`
- `DeckValidationError` is an enum with associated values: `.tooManyCards(count: Int)`, `.duplicateCard(name: String, count: Int)`, `.illegalCard(name: String)`, `.noBasicPokemon`
- `DeckBuilderViewModel` calls `DeckValidator.validate` in a `onChange(of: deck)` handler
- Basic Energy detection: `CachedCard.subtypes.contains("Basic Energy")`
