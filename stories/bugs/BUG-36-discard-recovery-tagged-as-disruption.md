# BUG-36 — Discard-Recovery Cards Incorrectly Tagged as Disruption

**Status:** open  
**Area:** Card Data — `BundledCardSeeder` / `CardTagClassifier`

## Description

Cards whose primary function is to retrieve cards **from** the discard pile (e.g. Night Stretcher, Jirachi) are displayed with a "Disruption" role tag when they should show only "Recovery." The misclassification affects the Deck Profile sub-scores and any filter/search that relies on role tags.

## Root Cause

`CardTagClassifier.tags(...)` in `BundledCardSeeder.swift` (around line 162) assigns "Disruption" to any card text that contains the word "discard":

```swift
if text.localizedCaseInsensitiveContains("discard")
    || text.localizedCaseInsensitiveContains("lost zone")
    ...
{
    result.insert("Disruption")
}
```

Cards like Night Stretcher say _"Put a card from your discard pile into your hand."_ That text already earns "Recovery" (line 142–144), but the same substring `"discard"` then also triggers "Disruption." The classifier has no guard to exclude recovery effects, so both tags are written to the card.

## Steps to Reproduce

1. Build and seed the app (any seeded version with Night Stretcher or Jirachi).
2. Open the Cards browser and find **Night Stretcher** or **Jirachi**.
3. Inspect the role-tag chips shown on the card detail — "Disruption" appears alongside "Recovery."
4. Alternatively, add either card to a deck and open the Deck Profile — the Disruption score is inflated.

## Observed Behaviour

- Night Stretcher, Jirachi, and any other retrieval Item/Ability that references "discard" carry both "Disruption" and "Recovery" tags.
- Disruption sub-score in the Deck Profile is overstated for decks running these cards.
- Filtering by "Disruption" returns recovery cards that don't pressure the opponent at all.

## Desired Behaviour

- Cards whose effect is to retrieve FROM the discard pile should carry **"Recovery"** only.
- "Disruption" should be reserved for cards that force the opponent to discard, send cards to the Lost Zone, restrict the opponent's plays, or discard your own cards as a cost to an offensive effect.

## Acceptance Criteria

### Audit
- [ ] Run a full audit of cards currently carrying "Disruption" that should be "Recovery" only. Confirmed examples to verify as fixed: **Night Stretcher**, **Jirachi** (Stellar Crown / Promo versions), **Klefki**, **Ordinary Rod**, **Super Rod**, **Brock's Grit**, **Rescue Stretcher**, **Salvager** variants.
- [ ] Confirm that true disruption cards (**Iono**, **Judge**, **Roxanne**, **Team Rocket's Giovanni**, **Lost Vacuum**, **Crushing Hammer**) still carry "Disruption" after the fix.

### Fix
- [ ] Update `CardTagClassifier.tags(...)` in `BundledCardSeeder.swift` so the "Disruption" branch excludes texts where the primary discard reference is a retrieval effect — e.g. add a guard:
  ```swift
  // Only tag as Disruption if the text isn't describing a recovery effect
  let isRecoveryEffect = text.localizedCaseInsensitiveContains("from your discard pile")
  if !isRecoveryEffect && (
      text.localizedCaseInsensitiveContains("discard")
      || ...
  ) {
      result.insert("Disruption")
  }
  ```
  Alternatively, scope the disruption check to patterns that target the opponent or use discard as an offensive cost (regex: `"opponent.*discard"`, `"discard.*opponent"`, `"lost zone"`, etc.).
- [ ] Bump the seeder key (`bundledCardsSeededKey` / `bundled_cards_seeded_vN`) so existing installs re-run the seed and pick up the corrected tags on next launch.

### Verification
- [ ] Unit tests in `BundledCardSeederTests` (or a new `CardTagClassifierTests`) cover at minimum: Night Stretcher → `["Recovery"]`, Iono → `["Disruption"]`, cards with both an offensive discard cost AND retrieval get both tags only when warranted.

## Technical Notes

**File to change:** `JustTCG/Data/BundledCardSeeder.swift` — `CardTagClassifier.tags(...)`, lines ~162–168.  
**Also update:** seeder version key so the tag fix propagates on re-launch.  
**Watch out for:** cards like **Survival Brace** or **Dark Patch** that move energy FROM the discard — those should remain "Energy Acceleration", not earn "Recovery." The guard should be scoped to Pokémon/Trainer retrieval, not energy attachment.
