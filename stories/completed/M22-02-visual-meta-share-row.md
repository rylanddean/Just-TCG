# M22-02 — Visual Meta Share Row & Archetype Detail Header

**Status:** done  
**Milestone:** M22 — Visual Meta Share  
**Dependencies:** M22-01

## User Story

As a player, I want the meta share list to show the primary Pokémon card's art for each archetype so I can scan the meta at a glance without reading every name.

## Acceptance Criteria

### Meta Comparison Row (Analytics Tab)
- [x] `MetaComparisonRowView` (private struct in `AnalyticsView.swift`) gains a card thumbnail on the leading edge
- [x] The thumbnail is ~44 pt wide, uses the existing `AsyncImage` pattern with `card.imageURL`, and maintains the card's 7:10 aspect ratio
- [x] The thumbnail is resolved via `ArchetypePrimaryCardResolver` against the in-memory `CachedCard` store — pass cards via a `@Query` in `AnalyticsView`
- [x] If no card is resolved (nil), a rounded rectangle placeholder fills the same dimensions
- [x] The archetype name, meta share %, win rate, and status chip remain on the trailing side — layout is unchanged except for the leading thumbnail

### Archetype Detail Header (`MetaArchetypeDetailView`)
- [x] `MetaArchetypeDetailView` gains a full-width hero header above the `List`
- [x] The header shows the primary card's large image (`largeImageURL ?? imageURL`) filling the width at a 16:9 crop, with a linear gradient overlay (clear → `.systemBackground`) across the bottom third
- [x] The archetype name and meta share percentage are overlaid on the gradient in white/primary text
- [x] If no card is resolved, the header is omitted and the existing `navigationTitle` remains as the sole title
- [x] The header does not scroll away — it sits above the `List` using a `VStack` wrapper, not inside the list itself

## Technical Notes

**Files to change:**
- `JustTCG/Features/Analytics/AnalyticsView.swift` — update `MetaComparisonRowView`, pass card query
- `JustTCG/Features/Analytics/MetaArchetypeDetailView.swift` — add hero header

**Passing cards to the row view:**

In `AnalyticsView`, add:
```swift
@Query private var allCards: [CachedCard]
```

Resolve the card once per row in the `ForEach` and pass it as a parameter rather than running the resolver inside the view body on every render:
```swift
ForEach(metaVM.rows) { row in
    let primaryCard = ArchetypePrimaryCardResolver().resolve(archetype: row.archetype, from: allCards)
    NavigationLink {
        MetaArchetypeDetailView(row: row, allMatches: matches, primaryCard: primaryCard)
    } label: {
        MetaComparisonRowView(row: row, primaryCard: primaryCard)
    }
}
```

**Hero header layout:**
```swift
private var heroHeader: some View {
    GeometryReader { geo in
        AsyncImage(url: URL(string: primaryCard?.largeImageURL ?? primaryCard?.imageURL ?? "")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.width * 9/16)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, Color(.systemBackground)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .frame(height: geo.size.width * 9/16 * 0.4)
                    }
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.archetype)
                                .font(.title2.weight(.bold))
                            Text(String(format: "%.1f%% meta share", row.metaShare))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding([.horizontal, .bottom], 16)
                    }
            default:
                EmptyView()
            }
        }
    }
    .aspectRatio(16/9, contentMode: .fit)
}
```
