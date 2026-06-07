# M1-06 — Card Detail View

**Status:** todo  
**Milestone:** M1 — Card Browser  
**Dependencies:** M1-04

## User Story
As a user, I want to tap a card and see its full details — image, type, set, HP, and rules text — so that I can evaluate whether it belongs in my deck.

## Acceptance Criteria

- [ ] Tapping a card thumbnail navigates to a full-screen detail view
- [ ] Detail view shows: full-resolution card image (top half), card name, set name + number, types, subtypes, HP (if applicable), and the card's rules text / attack text
- [ ] The card image supports pinch-to-zoom
- [ ] An "Add to Deck" button is visible if the detail view is opened from within the deck builder flow (M2-04); it is hidden when browsing standalone
- [ ] Back navigation returns to the card grid at the same scroll position

## Technical Notes

- Full card rules text may require a second API call to `fetchCard(id:)` if the list endpoint does not return it — check during M1-01 investigation and update this story if needed
- Use `NavigationStack` push for this transition, not a sheet
- Pinch-to-zoom: wrap image in a `MagnifyGesture` or use a third-party-free `ZoomableScrollView` UIViewRepresentable
- Cache the full-res image separately from the thumbnail — use a larger URLCache partition for full-res images
