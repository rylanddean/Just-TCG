import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]
    @State private var vm = AnalyticsViewModel()
    @State private var metaVM = MetaComparisonViewModel()
    @State private var prepareCardDismissed = false
    @Environment(AppNavigationState.self) private var nav

    private let gapEngine = PracticeGapEngine()

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    emptyDecksState
                } else {
                    analyticsContent
                }
            }
            .navigationTitle("Analytics")
            .onAppear {
                if vm.selectedDeck == nil {
                    vm.selectedDeck = decks.first
                }
            }
            .onChange(of: decks.first) { _, deck in
                if vm.selectedDeck == nil { vm.selectedDeck = deck }
            }
        }
    }

    // MARK: - Deck picker + content

    private var analyticsContent: some View {
        let matches = vm.selectedDeck?.matches ?? []
        let stats = vm.stats(for: matches)
        let record = vm.overallRecord(for: matches)
        let weekly = vm.weeklyRecords(for: matches)

        let recommendations = gapEngine.recommendations(
            meta: metaVM.rows.map { MetaShare(archetype: $0.archetype, sharePercent: $0.metaShare, tournaments: $0.tournamentCount) },
            stats: vm.stats(for: matches)
        )

        return List {
            if !prepareCardDismissed && metaVM.hasData {
                prepareCard(recommendations: recommendations)
            }

            Section {
                deckPicker
                timeFilterPicker
            }

            Section {
                overallRecordRow(record)
            }

            Section("Win Rate Trend") {
                WinRateChartView(records: weekly)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if stats.isEmpty {
                Section {
                    emptyMatchesState
                }
            } else {
                Section("Matchups") {
                    ForEach(stats, id: \.archetype) { stat in
                        MatchupRow(
                            stat: stat,
                            recentMatches: vm.recentMatches(against: stat.archetype, in: matches)
                        )
                    }
                }
            }

            metaSection(matches: matches)
        }
        .task(id: vm.selectedDeck?.id) {
            await metaVM.load(matches: matches)
        }
        .onChange(of: matches.count) {
            metaVM.recompute(matches: matches)
        }
    }

    // MARK: - Prepare card

    @ViewBuilder
    private func prepareCard(recommendations: [Recommendation]) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Prepare for tournament", systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                    Spacer()
                    Button {
                        withAnimation { prepareCardDismissed = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(recommendations) { rec in
                    recommendationRow(rec)
                }

                Text("Based on last 5 Regionals+")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func recommendationRow(_ rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: rec.type == .dangerMatchup ? "exclamationmark.triangle.fill"
                                : rec.type == .practiceGap  ? "figure.mind.and.body"
                                                             : "checkmark.circle.fill")
                    .foregroundStyle(rec.type == .dangerMatchup ? .red
                                   : rec.type == .practiceGap   ? .orange
                                                                 : .green)
                    .font(.subheadline)
                Text(rec.message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if rec.type != .allClear {
                Button {
                    @Bindable var navBinding = nav
                    nav.tournamentsArchetypeFilter = rec.archetype
                    nav.selectedTab = AppNavigationState.tabTournaments
                } label: {
                    Label("Find deck lists", systemImage: "arrow.right")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.leading, 22)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Meta section

    @ViewBuilder
    private func metaSection(matches: [Match]) -> some View {
        Section("Meta") {
            if metaVM.isLoading {
                HStack {
                    ProgressView()
                    Text("Loading tournament meta…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if metaVM.rows.isEmpty {
                Text("Connect to the internet to load tournament meta data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(metaVM.rows) { row in
                    NavigationLink {
                        MetaArchetypeDetailView(row: row, allMatches: matches)
                    } label: {
                        MetaComparisonRowView(row: row)
                    }
                }
            }
        }
    }

    // MARK: - Deck picker

    private var deckPicker: some View {
        Picker("Deck", selection: $vm.selectedDeck) {
            ForEach(decks) { deck in
                Text(deck.name).tag(Optional(deck))
            }
        }
        .pickerStyle(.menu)
    }

    // MARK: - Time filter

    private var timeFilterPicker: some View {
        Picker("Period", selection: $vm.timeFilter) {
            ForEach(TimeFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Overall record

    private func overallRecordRow(_ record: (wins: Int, losses: Int, ties: Int, winPct: Double)) -> some View {
        HStack {
            Text("\(record.wins)W – \(record.losses)L – \(record.ties)T")
                .font(.headline)
            Spacer()
            Text(String(format: "%.1f%%", record.winPct))
                .font(.headline)
                .foregroundStyle(winPctColor(record.winPct))
        }
        .padding(.vertical, 2)
    }

    private func winPctColor(_ pct: Double) -> Color {
        if pct >= 60 { return .green }
        if pct <= 40 { return .red }
        return .primary
    }

    // MARK: - Empty states

    private var emptyDecksState: some View {
        ContentUnavailableView(
            "No Decks",
            systemImage: "rectangle.stack",
            description: Text("Create a deck to start tracking analytics.")
        )
    }

    private var emptyMatchesState: some View {
        ContentUnavailableView(
            "No Matches Logged Yet",
            systemImage: "sportscourt",
            description: Text("Log your first match from the deck detail view.")
        )
    }
}

// MARK: - Meta comparison row

private struct MetaComparisonRowView: View {
    let row: MetaComparisonRow

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.archetype)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(String(format: "%.1f%% meta share", row.metaShare))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let stat = row.matchupStat, stat.sampleSize > 0 {
                Text(String(format: "%.0f%%", stat.winRate * 100))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }

            if let status = row.status {
                statusChip(status)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusChip(_ status: MetaStatus) -> some View {
        let (label, color): (String, Color) = switch status {
        case .ready:          ("Ready",           .green)
        case .danger:         ("Danger",          .red)
        case .practiceNeeded: ("Practice needed", .orange)
        }
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Matchup row

private struct MatchupRow: View {
    let stat: MatchupStat
    let recentMatches: [Match]

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stat.archetype)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(recordString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(winRateString)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    tagChip
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.vertical, 6)
                ForEach(recentMatches) { match in
                    miniMatchRow(match)
                }
            }
        }
    }

    private var recordString: String {
        var parts: [String] = []
        if stat.wins   > 0 { parts.append("\(stat.wins)W")   }
        if stat.losses > 0 { parts.append("\(stat.losses)L") }
        if stat.ties   > 0 { parts.append("\(stat.ties)T")   }
        return parts.joined(separator: " ")
    }

    private var winRateString: String {
        guard stat.sampleSize > 0 else { return "—" }
        return String(format: "%.0f%%", stat.winRate * 100)
    }

    @ViewBuilder
    private var tagChip: some View {
        let (label, color, filled): (String, Color, Bool) = switch stat.tag {
        case .favourable:     ("Favourable",   .green,     true)
        case .even:           ("Even",         .secondary, true)
        case .unfavourable:   ("Unfavourable", .red,       true)
        case .insufficientData: ("Low data",   .secondary, false)
        }

        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                filled
                    ? AnyShapeStyle(color.opacity(0.15))
                    : AnyShapeStyle(Color.clear),
                in: Capsule()
            )
            .overlay(
                filled ? nil : Capsule().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
            )
            .foregroundStyle(filled ? color : .secondary)
    }

    @ViewBuilder
    private func miniMatchRow(_ match: Match) -> some View {
        HStack(spacing: 10) {
            resultDot(match.result)
            Text(match.date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !match.notes.isEmpty {
                Image(systemName: "note.text")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func resultDot(_ result: MatchResult) -> some View {
        let (label, color): (String, Color) = switch result {
        case .win:  ("W", .green)
        case .loss: ("L", .red)
        case .tie:  ("T", .secondary)
        }
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(color, in: Circle())
    }
}
