# M2-03 — New Deck Flow & Deck Detail View

**Status:** todo  
**Milestone:** M2 — Deck Builder  
**Dependencies:** M2-02

## User Story
As a user, I want to create a new deck by giving it a name, and then see a detail view of my deck that shows all the cards I've added and their quantities.

## Acceptance Criteria

- [ ] Tapping "+" opens a sheet with a single text field: "Deck name" — tapping "Create" calls `DeckRepository.createDeck` and navigates to the new deck's detail view
- [ ] Deck name is required; the Create button is disabled until at least 1 character is entered
- [ ] Deck detail view shows:
  - Deck name in the navigation title (tappable to rename inline)
  - Card count badge: "42 / 60" (red if < 60, green if exactly 60)
  - Cards grouped into sections: Pokémon, Trainer, Energy — each section shows card name, set, quantity stepper (+/−), and card thumbnail
  - An "Add Cards" button that opens the card picker (M2-04)
  - An export button in the toolbar (M2-06)
- [ ] Inline rename: tapping the deck name shows an inline text field; tapping elsewhere or pressing Return saves it
- [ ] Sections with zero cards are hidden

## Technical Notes

- Group cards by subtype into Pokémon (anything with a type colour), Trainer (Supporter, Item, Stadium, Tool), Energy
- The quantity stepper calls `DeckRepository.setQuantity` — decrement to 0 removes the card
- `DeckBuilderViewModel` owns the `Deck` object and exposes grouping logic
