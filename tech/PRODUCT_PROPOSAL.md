# Just TCG — Product Proposal

## Overview

Just TCG is a focused iOS app for competitive Pokémon TCG players. It covers the full competitive loop: build a Standard-legal deck, track your results, understand your matchups, and follow the tournament circuit — all in one place.

---

## Problem

Competitive Pokémon TCG players today cobble together 3–5 separate tools:

- **PTCGL / PTCGO** to proxy decks (no analytics, no matchup data)
- **Limitless TCG** in a browser to look up tournament results
- **Spreadsheets or notes apps** to track wins/losses and matchup data
- **Discord or Reddit** to stay informed on the meta

There is no single app that closes the loop between deck building, personal performance tracking, and tournament meta intelligence.

---

## Target Users

| Segment | Description |
|---|---|
| **Competitive grinders** | Players who attend League Challenges, Regionals, and ICs. Care deeply about matchup data and the current meta. |
| **Aspiring competitors** | Players moving up from casual play who want to understand why they lose and how to improve. |
| **Deck brewers** | Players who build non-meta decks and want to track how they perform against the field. |

---

## Core Features

### 1. Deck Builder
- Browse all Standard-legal cards with search and filters (type, set, format legality, cost, HP, subtype)
- Build decks up to the 60-card limit with live legality validation
- Save, name, and manage multiple decks
- Export deck lists in standard `.ptcgl` copy-paste format
- Card images and full text pulled from Limitless TCG

### 2. Match Tracker
- Log match results (win/loss/tie) against an opponent's deck archetype
- Tag format (best-of-1, best-of-3), event type (casual, LC, Regionals, etc.), and date
- Per-match notes field for game observations

### 3. Matchup Analytics
- Win rate by opponent archetype, broken down per deck
- Strength/weakness radar — visualise which archetypes you beat, go even with, and struggle against
- Win rate trends over time (last 30, 90, all-time)
- Sample size indicator so sparse matchups are clearly flagged

### 4. Tournament Feed
- Recent major tournament results sourced from Limitless TCG
- Top 8 / Top 32 deck lists viewable inline
- Meta share percentages by archetype at recent events
- Filter by event tier (Regionals, ICs, Worlds, etc.)

### 5. Meta Comparison
- Compare your logged matchup data against the tournament meta
- Highlight archetypes that are popular on the circuit but underrepresented in your practice
- Surface your best and worst matchups against top-meta decks

---

## What Just TCG Is Not

- Not a card shop or marketplace
- Not a digital card game (no simulation)
- Not a casual card encyclopedia
- Not a collection tracker

This is a competitive tool. Every screen should serve a player who is trying to get better results at tournaments.

---

## Data Sources

**Limitless TCG** (`limitlesstcg.com`) is the primary external data source.

| Data | Source |
|---|---|
| Card database (Standard-legal) | Limitless TCG card API / web |
| Card images | Limitless TCG CDN |
| Tournament results & deck lists | Limitless TCG tournament data |
| Set legality / rotation info | Limitless TCG |

Limitless TCG does not publish an official public API. The integration strategy is documented in the Technical Design doc.

---

## Platform

- **iOS first** (iPhone, iPad support)
- Native SwiftUI
- Offline-capable for deck building and match logging
- Sync via iCloud for multi-device access

---

## Success Metrics

| Metric | Target (6 months post-launch) |
|---|---|
| DAU/MAU ratio | > 40% (sticky tool, not a browser) |
| Avg decks saved per active user | ≥ 3 |
| Avg matches logged per active user | ≥ 20 |
| D30 retention | > 35% |
| App Store rating | ≥ 4.5 |

---

## Competitive Landscape

| Product | Gap |
|---|---|
| Limitless TCG (web) | No personal match tracking; browser-only |
| PTCGL | No analytics; digital-only card pool |
| Pokémon TCG Pocket | Pocket format only; no tournament meta |
| Generic note apps | No card data, no structured analytics |

No existing iOS app closes all four pillars (deck building + match tracking + matchup analytics + tournament meta) for the Standard format.

---

## Risks

| Risk | Mitigation |
|---|---|
| Limitless TCG scraping/ToS changes | Build a thin abstraction layer; monitor for API availability |
| Rotation changes breaking deck legality | Pull legality data dynamically; never hardcode sets |
| Low match log retention | Make logging frictionless (< 5 taps per match) |
| Pokémon IP / card images | Use only Limitless-hosted images; no redistribution |
