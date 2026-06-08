import SwiftUI

// MARK: - Segmentation model

struct DeckVersionSegment {
    let triggeringEdit: DeckEdit?
    let matches: [Match]

    var wins:   Int { matches.filter { $0.result == .win  }.count }
    var losses: Int { matches.filter { $0.result == .loss }.count }
    var ties:   Int { matches.filter { $0.result == .tie  }.count }

    var winRate: Double? {
        let total = wins + losses + ties
        guard total > 0 else { return nil }
        return Double(wins) / Double(total) * 100
    }

    var recordSummary: String {
        var parts = ["\(wins)W", "\(losses)L"]
        if ties > 0 { parts.append("\(ties)T") }
        let record = parts.joined(separator: " ")
        if let pct = winRate {
            return "\(record) — \(Int(pct))%"
        }
        return record
    }
}

// MARK: - Segmenter

struct DeckVersionSegmenter {
    static func segments(edits: [DeckEdit], matches: [Match]) -> [DeckVersionSegment] {
        let sortedEdits   = edits.sorted   { $0.date < $1.date }
        let sortedMatches = matches.sorted { $0.date < $1.date }

        guard !sortedEdits.isEmpty else {
            return [DeckVersionSegment(triggeringEdit: nil, matches: sortedMatches)]
        }

        var result: [DeckVersionSegment] = []

        // Initial build: matches before the first edit
        let initial = sortedMatches.filter { $0.date < sortedEdits[0].date }
        result.append(DeckVersionSegment(triggeringEdit: nil, matches: initial))

        // One segment per edit
        for (i, edit) in sortedEdits.enumerated() {
            let segStart = edit.date
            let segEnd   = i + 1 < sortedEdits.count ? sortedEdits[i + 1].date : nil
            let segMatches = sortedMatches.filter { m in
                guard m.date >= segStart else { return false }
                if let end = segEnd { return m.date < end }
                return true
            }
            result.append(DeckVersionSegment(triggeringEdit: edit, matches: segMatches))
        }

        return result.reversed()
    }
}

// MARK: - View

struct DeckVersionTimelineView: View {
    let deck: Deck

    private var segments: [DeckVersionSegment] {
        DeckVersionSegmenter.segments(edits: deck.edits, matches: deck.matches)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Section {
                        if segment.matches.isEmpty {
                            Text("No matches played in this version")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(segment.matches.sorted { $0.date > $1.date }) { match in
                                NavigationLink {
                                    MatchDetailView(match: match)
                                } label: {
                                    MatchRow(match: match)
                                }
                            }
                            Text(segment.recordSummary)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                    } header: {
                        segmentHeader(segment)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func segmentHeader(_ segment: DeckVersionSegment) -> some View {
        if let edit = segment.triggeringEdit {
            VStack(alignment: .leading, spacing: 1) {
                Text(edit.displayDescription)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(edit.date.editDisplayString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .textCase(nil)
        } else {
            Text("Initial build")
                .font(.caption.weight(.semibold))
                .textCase(nil)
        }
    }
}
