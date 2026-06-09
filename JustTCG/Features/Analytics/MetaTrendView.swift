import SwiftUI
import Charts

struct MetaTrendView: View {
    @Environment(MetaTrendEngine.self) private var engine

    @State private var selectedNames: Set<String> = []
    private static let trendPalette: [Color] = [
        .blue, .orange, .purple, .green, .red,
        .teal, .pink, .yellow, .indigo, .mint, .cyan, .brown
    ]

    var body: some View {
        Group {
            if engine.isLoading && engine.snapshots.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = engine.loadError, engine.snapshots.isEmpty {
                errorView(error)
            } else if engine.snapshots.count < 2 {
                ContentUnavailableView(
                    "Not enough data",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("More tournament results are needed to show trends.")
                )
            } else {
                contentView
            }
        }
        .task {
            if engine.snapshots.isEmpty {
                try? await engine.loadTrends()
                preselectTopArchetypes()
            }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        let trends = engine.topArchetypes(n: 15)
        let selected = trends.filter { selectedNames.contains($0.archetypeName) }

        return List {
            Section {
                pillRow(trends: trends)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if !selected.isEmpty {
                Section {
                    trendChart(selected: selected)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            Section("Archetypes") {
                ForEach(trends) { trend in
                    trendRow(trend, color: color(for: trend.archetypeName, in: trends))
                }
            }
        }
    }

    // MARK: - Pill row

    private func pillRow(trends: [ArchetypeTrend]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(trends) { trend in
                    let isSelected = selectedNames.contains(trend.archetypeName)
                    let pillColor = color(for: trend.archetypeName, in: trends) ?? .secondary
                    Button {
                        toggleSelection(trend.archetypeName)
                    } label: {
                        Text(trend.archetypeName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                isSelected ? pillColor.opacity(0.2) : Color(.tertiarySystemFill),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().strokeBorder(isSelected ? pillColor : .clear, lineWidth: 1.5)
                            )
                            .foregroundStyle(isSelected ? pillColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Chart

    private func trendChart(selected: [ArchetypeTrend]) -> some View {
        let snapshots = engine.snapshots
        let maxShare = (selected.flatMap(\.weeklyShares).max() ?? 10) + 5

        return Chart {
            ForEach(selected) { trend in
                ForEach(snapshots.indices, id: \.self) { i in
                    LineMark(
                        x: .value("Week", snapshots[i].weekLabel),
                        y: .value("Share", trend.weeklyShares[safe: i] ?? 0)
                    )
                    .foregroundStyle(by: .value("Archetype", trend.archetypeName))
                    .symbol(Circle())
                }
            }
        }
        .chartForegroundStyleScale(domain: selected.map(\.archetypeName),
                                    range: selected.map { color(for: $0.archetypeName, in: engine.topArchetypes(n: 15)) ?? .blue })
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                    }
                }
            }
        }
        .chartYScale(domain: 0...maxShare)
        .chartLegend(.hidden)
        .frame(height: 220)
    }

    // MARK: - Trend row

    private func trendRow(_ trend: ArchetypeTrend, color: Color?) -> some View {
        let isSelected = selectedNames.contains(trend.archetypeName)
        return Button {
            toggleSelection(trend.archetypeName)
        } label: {
            HStack(spacing: 12) {
                if let c = color {
                    Circle()
                        .fill(c)
                        .frame(width: 10, height: 10)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(trend.archetypeName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(String(format: "%.1f%%", trend.recentShare))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                trendIndicator(trend.trend)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
    }

    @ViewBuilder
    private func trendIndicator(_ trend: Double) -> some View {
        let delta = String(format: "%+.1f%%", trend)
        if trend > 1 {
            Label(delta, systemImage: "chevron.up.circle.fill")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.green)
        } else if trend < -1 {
            Label(delta, systemImage: "chevron.down.circle.fill")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.red)
        } else {
            Label(delta, systemImage: "minus.circle")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error view

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { try? await engine.loadTrends(forceRefresh: true) }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func toggleSelection(_ name: String) {
        if selectedNames.contains(name) {
            selectedNames.remove(name)
        } else if selectedNames.count < Self.trendPalette.count {
            selectedNames.insert(name)
        }
    }

    private func preselectTopArchetypes() {
        let top3 = engine.topArchetypes(n: 3).map(\.archetypeName)
        selectedNames = Set(top3)
    }

    private func color(for name: String, in trends: [ArchetypeTrend]) -> Color? {
        guard let idx = trends.firstIndex(where: { $0.archetypeName == name }),
              idx < Self.trendPalette.count else { return nil }
        return Self.trendPalette[idx]
    }
}

// MARK: - Safe index

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
