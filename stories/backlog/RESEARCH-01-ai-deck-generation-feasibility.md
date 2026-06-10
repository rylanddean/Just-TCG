# RESEARCH-01 — AI Deck Generation: Feasibility & Path Forward

**Status:** backlog  
**Type:** Research / Spike  
**Area:** Deck Generator  
**Related features:** AI Deck Generator (Alpha), `DeckGeneratorView`, `DeckGeneratorEngine`

---

## Background

Just TCG currently ships an "AI Deck Generator (Alpha)" reachable from the Decks tab. The
feature is intentionally labelled Alpha because it is not reliably producing valid,
playable decks. Before investing further engineering time in this surface, we need to
understand whether AI-generated deck lists are even achievable at a quality bar worth
shipping — and if so, what approach gets us there.

---

## What We Have Today

### On-device generation (iOS 26+)
`DeckGeneratorEngine` uses Apple Foundation Models (`LanguageModelSession`) to run a
three-phase generation flow:

1. **Phase 1** — AI drafts a strategy narrative
2. **Phase 2** — AI produces a raw PTCGL-format deck list
3. **Phase 3** — AI self-critiques and refines the list

The result is parsed by `DeckListParser`, validated by `DeckGeneratorValidator`, and
surfaced in `DeckListPreviewCard` with any rule violations flagged.

### Fallback (iOS < 26)
`DeckGeneratorEngineFallback` is a stub that returns a static boilerplate message. It
does **not** generate a deck. Users on older OS versions see a placeholder, not a real
result.

### Competitive hybrid (current primary flow)
The main `DeckGeneratorView` now routes users through a Limitless TCG search first:
user picks a Pokémon → fetch competitive tournament decklists → select one → import.
AI generation is only surfaced as a fallback when no competitive decks are found for
that card. This is the most reliable path today and bypasses AI entirely.

---

## The Core Problem

A legal, competitive 60-card Pokémon deck requires:

| Requirement | Why AI Struggles With It |
|---|---|
| Exactly 60 cards | Models overshoot or undershoot; even minor hallucinations break the count |
| ≤ 4 copies of any named card (except Basic Energy) | No copy-limit awareness without explicit grounding |
| At least 1 Basic Pokémon to open with | May be violated if AI over-indexes on Stage 2 attackers |
| All cards must be Standard-legal (H, I, J regulation marks) | The model has no live knowledge of the current format or which sets rotated |
| Exact card names, set codes, and collector numbers | Pokémon card names are precise and version-specific; hallucinated names produce unmatched imports |
| Synergistic card choices | Requires meta knowledge the model may not have been trained on |

In practice, the current on-device generator regularly produces:
- Invented card names that don't exist in the DB
- Mixed-legality lists (rotated cards alongside legal ones)
- Wrong card totals (58–62 instead of 60)
- Evolution lines missing their Basic Pokémon
- No awareness of what's actually playable in the current format meta

---

## Research Questions

The following questions need to be answered before any further engineering work begins.

### 1. Can Apple Intelligence reliably follow structured, rule-bound output constraints?

The three-phase prompt approach was designed to coax the model into self-correcting, but
anecdotal results are inconsistent. We need to know:

- Does injecting the full card rule set (60 cards, 4-copy limit, 1 Basic requirement)
  into the system prompt meaningfully improve compliance?
- Does few-shot prompting with valid deck examples improve output quality?
- Is the model capable of parsing and respecting a card legality list if we inject one
  as context?

**Action:** Run structured prompt experiments on iOS 26 simulator. Measure: % of
outputs that are exactly 60 cards, % with no copy violations, % with only legal card
names (cross-checked against the local SwiftData DB).

---

### 2. Can we ground the model with live card data (RAG approach)?

The most promising mitigation for hallucinated card names is **retrieval-augmented
generation**: before calling the model, query the local SwiftData DB (or the Pokémon
TCG API) for legal cards and inject a subset as context. The model then picks from
real cards instead of inventing them.

Questions:
- Is the Apple Foundation Models context window large enough to hold a meaningful card
  pool (e.g., top 200 Standard-legal Pokémon + 100 Trainer staples)?
- Can we format a card list as structured context the model will reliably reference
  rather than ignore?
- What is the latency and memory cost of injecting ~300 card entries into the prompt?

**Action:** Prototype a RAG prompt: pull top-played Standard cards from the local DB,
format them as a `[Name] [SetCode] [Number]` list, inject into system prompt. Measure
output accuracy against the known card pool.

---

### 3. Is the Pokémon TCG API a viable real-time grounding source?

The Pokémon TCG API (`https://api.pokemontcg.io/v2`) returns card legality data in
real-time and is the authoritative source for what is Standard-legal today. However,
using it during deck generation adds:

- A network round-trip per archetype query
- Dependency on third-party API availability and rate limits
- Latency that may make the generation feel slow

Questions:
- Can we pre-cache a "current legal card pool" snapshot on app launch (similar to the
  card sync we already do) and use that as the grounding source instead of live API
  calls?
- How often does the legal pool change (new sets, ban list updates) and is a daily
  refresh acceptable?

**Action:** Assess whether the existing `CardRepository` + `BundledCardSeeder`
pipeline already gives us everything needed for grounding, or whether we need an
additional dedicated "staples + meta cards" cache layer.

---

### 4. Is Apple Intelligence the right model, or should we evaluate alternatives?

Apple Foundation Models run fully on-device and respect user privacy, which is a
strong advantage. But they are:

- iOS 26+ only (excludes all users on iOS 17–25)
- Smaller models with weaker instruction-following than cloud alternatives
- Not fine-tuned on Pokémon TCG knowledge

Alternatives worth evaluating:

| Option | Pros | Cons |
|---|---|---|
| Apple Foundation Models (current) | On-device, private, no API cost | iOS 26+ only, weaker reasoning, no TCG knowledge |
| Claude API (Anthropic) | Strong instruction-following, large context, current training | Requires network, API cost, needs key management |
| OpenAI API | Widely benchmarked, large context | API cost, network dependency |
| Local fine-tuned model (e.g., Core ML export) | On-device, TCG-specific | Significant ML engineering effort, large binary |

**Action:** Run the same structured deck-generation prompt against Claude API (using a
test key) and compare output quality to Apple Foundation Models on the same 5 test
archetypes. Measure: legality accuracy, copy-limit compliance, total card count,
subjective deck quality.

---

### 5. What is the minimum viable bar for shipping AI generation?

Even if we solve legality and card names, there's a higher bar question: is the
generated deck any good? A 60-card legal deck that no competitive player would run is
not useful. We need to define what "good enough" means:

- Does the deck pass `DeckGeneratorValidator` with zero violations?
- Does it score ≥ 60 on the `ConsistencyEngine` overall score?
- Does a human player familiar with the format consider it at least "playable"?

**Action:** Define a rubric. Once defined, run 10 generation attempts per archetype
(Charizard ex, Gardevoir ex, Dragapult ex) and score them. If fewer than 7 of 10
attempts pass the rubric, the approach needs more work before shipping.

---

## What We Already Know Works

The Limitless TCG competitive deck lookup is the reliable path:
- Real tournament data
- Verified 60-card legal lists
- No hallucination risk
- Updated as the meta evolves

AI generation should be positioned as a complement — useful when no competitive data
exists for a niche or rogue archetype — not a replacement for this flow.

---

## Proposed Acceptance Criteria for This Research

- [ ] Prompt experiments run and results documented (question 1)
- [ ] RAG prototype built and accuracy measured against card DB (question 2)
- [ ] Decision made on grounding source: existing card sync vs. dedicated cache (question 3)
- [ ] Apple Foundation Models vs. Claude API comparison completed on 5 archetypes (question 4)
- [ ] Minimum viable quality rubric defined and baseline pass rate measured (question 5)
- [ ] Recommendation written: proceed with AI generation (with chosen approach) or
  deprioritise and focus on expanding the Limitless competitive deck coverage instead

---

## Out of Scope for This Research

- Implementing a new generation approach (that is a follow-on story)
- UI changes to the deck generator surface
- Fine-tuning a custom model

---

## Files of Interest

| File | Relevance |
|---|---|
| `JustTCG/Features/Decks/DeckGeneratorView.swift` | Full generation + competitive deck flow |
| `JustTCG/Domain/Entities/DeckGeneratorEngine.swift` | Apple Foundation Models integration + fallback stub |
| `JustTCG/Domain/Entities/DeckGeneratorValidator.swift` | Rule validation (60 cards, 4-copy limit) |
| `JustTCG/Data/Import/DeckListParser.swift` | Parses AI-generated PTCGL text into entries |
| `JustTCG/Data/LimitlessTCGClient/` | Competitive deck fetch — the working alternative |
| `JustTCG/Data/Repositories/CardRepository.swift` | SwiftData card pool — candidate grounding source |
