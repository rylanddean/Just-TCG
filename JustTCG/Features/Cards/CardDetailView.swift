import SwiftUI

struct CardDetailView: View {
    let card: CachedCard
    // Non-nil only when opened from the deck builder (M2-04).
    var onAddToDeck: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZoomableCardImage(urlString: card.largeImageURL ?? card.imageURL)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(card.name)
                            .font(.title2.bold())
                        Spacer()
                        if let hp = card.hp {
                            Text("HP \(hp)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(card.setName)
                        Text("·")
                        Text("#\(card.number)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if !card.types.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(card.types, id: \.self) { EnergyBadge(type: $0) }
                        }
                    }

                    if !card.subtypes.isEmpty {
                        Text(card.subtypes.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    let hasCombatStats = card.weaknessType != nil || card.resistanceType != nil || card.retreatCost != nil
                    if hasCombatStats {
                        Divider().padding(.vertical, 4)
                        HStack(alignment: .top, spacing: 0) {
                            CombatStatColumn(label: "Weakness") {
                                if let w = card.weaknessType {
                                    HStack(spacing: 4) {
                                        EnergyBadge(type: w)
                                        Text("×2")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("—").font(.callout).foregroundStyle(.tertiary)
                                }
                            }
                            Divider().frame(maxHeight: 36)
                            CombatStatColumn(label: "Resistance") {
                                if let r = card.resistanceType {
                                    HStack(spacing: 4) {
                                        EnergyBadge(type: r)
                                        Text("-30")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("—").font(.callout).foregroundStyle(.tertiary)
                                }
                            }
                            Divider().frame(maxHeight: 36)
                            CombatStatColumn(label: "Retreat") {
                                if let cost = card.retreatCost {
                                    if cost == 0 {
                                        Text("Free")
                                            .font(.callout)
                                            .foregroundStyle(.tertiary)
                                    } else {
                                        HStack(spacing: 3) {
                                            ForEach(0..<min(cost, 5), id: \.self) { _ in
                                                Circle()
                                                    .fill(Color.secondary.opacity(0.5))
                                                    .frame(width: 14, height: 14)
                                            }
                                        }
                                    }
                                } else {
                                    Text("—").font(.callout).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }

                    if !card.rulesText.isEmpty {
                        Divider().padding(.vertical, 4)
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(card.rulesText, id: \.self) { line in
                                Text(line)
                                    .font(.callout)
                            }
                        }
                    }

                    if let addAction = onAddToDeck {
                        Button(action: addAction) {
                            Label("Add to Deck", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Zoomable image

private struct ZoomableCardImage: View {
    let urlString: String

    @State private var scale: CGFloat = 1
    @GestureState private var magnifyBy: CGFloat = 1

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .scaleEffect(scale * magnifyBy)
                    .gesture(
                        MagnificationGesture()
                            .updating($magnifyBy) { value, state, _ in state = value }
                            .onEnded { value in
                                scale = max(1, min(4, scale * value))
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) { scale = scale > 1 ? 1 : 2 }
                    }
            case .empty:
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.15))
                    .aspectRatio(7/10, contentMode: .fit)
                    .overlay { ProgressView() }
            case .failure:
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.15))
                    .aspectRatio(7/10, contentMode: .fit)
                    .overlay {
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    }
            @unknown default:
                EmptyView()
            }
        }
    }
}

// MARK: - Combat stat column

private struct CombatStatColumn<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Energy type badge

struct EnergyBadge: View {
    let type: String

    var body: some View {
        Text(type)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch type {
        case "Fire":       return .red
        case "Water":      return .blue
        case "Grass":      return .green
        case "Lightning":  return Color(red: 0.85, green: 0.7, blue: 0.0)
        case "Psychic":    return .purple
        case "Fighting":   return .orange
        case "Darkness":   return Color(red: 0.3, green: 0.2, blue: 0.5)
        case "Metal":      return Color(red: 0.5, green: 0.55, blue: 0.6)
        case "Dragon":     return .indigo
        default:           return .secondary
        }
    }
}
