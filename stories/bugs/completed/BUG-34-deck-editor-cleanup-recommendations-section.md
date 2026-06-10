# BUG-34 — Add "Cleanup" Section to Deck Editor Recommendations

**Status:** done  
**Area:** Deck Builder — Recommendations / Deck Profile

## Description

The Deck Editor has a Recommendations section that surfaces cards to **add** to the deck (via `DeckRecommendationEngine`), but there is no equivalent for cards to **cut**. Once a deck is close to 60, the user has to manually reason about what's underperforming. The Deck Profile section already produces a rich set of per-axis scores (`abilityImpactScore`, `energyScore`, `mobilityScore`, `prizeResilienceScore`, `disruptionScore`, `evolutionScore`, `recoveryScore`, `itemDependencyScore` — see `ConsistencyBreakdown`). These scores carry enough signal to flag cards that are pulling the deck down (e.g., a Stage 2 with no Rare Candy and no Stage 1, an attacker whose energy type isn't supplied, a single Item filler in an Item-lock-vulnerable build).

Add a "Cleanup" section right after the existing Recommendations section that calls out specific cards as cut candidates, each with a one-line reason tied to the deck profile axis that flagged it.

## Steps to Reproduce

1. Open a deck in the Deck Editor
2. Scroll past Recommendations
3. There is no surface for "what should I cut?"

## Observed Behaviour

- Recommendations only suggests additions
- Deck Profile shows low scores but doesn't say which specific cards drove the low score
- User has to manually correlate "Evolution Reliability is 30" with "this 1-1-1 Hisuian Zoroark line"

## Desired Behaviour

A new "Cleanup" section in `DeckBuilderView` (rendered between the existing Recommendations section and Deck Stats) lists specific cards in the deck that look like cut candidates, each with a single-sentence justification anchored to a profile axis. The section is hidden entirely when no meaningful cleanup items are found.

## Acceptance Criteria

### Engine
- [ ] New `DeckCleanupEngine` in `JustTCG/Domain/Entities/` exposes `func suggestCuts(deck: [DeckCardEntry], breakdown: ConsistencyBreakdown, roleTags: (String) -> [String]) -> [CleanupSuggestion]`
- [ ] `CleanupSuggestion` carries: `cardName`, `quantity`, `reasonShort` (≤ 60 chars, e.g. "Stage 2 with no Rare Candy + thin Stage 1"), `axis: CleanupAxis` (enum mapping to a profile score), and `severity` (e.g. low/medium/high) for sort ordering
- [ ] Each rule is grounded in a specific profile axis and only fires when that axis is below a defined threshold. Initial rule set (non-exhaustive):
  - **Evolution Reliability < 60** → flag top-of-line Pokémon (Stage 1/2) whose supporting basics or middle stage are too thin (e.g. 2 Stage 2 with 1 Basic and 0 Rare Candy)
  - **Energy Setup < 50** → flag attackers whose energy type isn't represented in the energy package
  - **Recovery < 40** → flag single-prize attackers running 3+ copies with no `Night Stretcher` / `Super Rod` / `Pal Pad` analog in the deck
  - **Mobility < 40** → flag high-retreat-cost (≥ 3) attackers in a deck with no switching cards / free-retreat abilities
  - **Item Dependency colour-inverted, > 90** → flag the lowest-impact Items (low-utility role tags) as candidates if a Supporter slot is open
  - **Disruption Power < 30 and Recovery > 70** → flag duplicated recovery Trainers as candidates to swap toward disruption (optional rule)
- [ ] Engine is pure / synchronous, mirrors `DeckRecommendationEngine`'s style

### UI
- [ ] New `cleanupSection` view in `DeckBuilderView`, rendered after `recommendationsSection` and before `deckStatsSection`
- [ ] Section header: "Cleanup" with subtitle "Cards that may not be earning their slot"
- [ ] Each row shows: card thumbnail (small), card name + quantity, the `reasonShort`, and the profile axis name as a small chip (e.g. "Evolution")
- [ ] Swipe / context action on a row to **dismiss** the suggestion for the session (mirrors recommendation dismissal pattern with `dismissedRecommendationNames` — use a parallel `dismissedCleanupNames: Set<String>`)
- [ ] Tapping a row opens the card detail sheet (reuse `RecommendationCardDetailSheet` or analogous flow)
- [ ] Section is hidden entirely when no suggestions remain (no empty state)
- [ ] Max 5 suggestions shown at once, sorted by `severity` then by quantity-descending

### Refresh
- [ ] Cleanup suggestions recompute whenever the deck changes (same trigger as `computeRecommendations()`), with `dismissedCleanupNames` filtered out
- [ ] Dismissals reset when the deck editor is closed

## Technical Notes

**Files to add:**
- `JustTCG/Domain/Entities/DeckCleanupEngine.swift` — engine + `CleanupSuggestion` + `CleanupAxis`

**Files to change:**
- `JustTCG/Features/Decks/DeckBuilderView.swift` — wire engine, add `cleanupSection`, dismissed-set state, refresh in `computeRecommendations()` (or a new sibling function)

**Inputs already available:**
- `deckBreakdown: ConsistencyBreakdown` is computed in `DeckBuilderView`
- `DeckCardEntry` projection (with `roleTags`, `quantity`, `supertype`, `types`, `weaknessType`, `hasAbility`) is the same one fed to `ConsistencyEngine` and `MetaMatchupEngine`

**Reasoning pattern:**
Each rule should be a small pure function on `(deck, breakdown)`. Avoid hand-tuned per-card logic — anchor everything to score thresholds and role-tag presence so the section gracefully degrades as the meta evolves.
