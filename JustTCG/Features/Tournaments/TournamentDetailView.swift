import SwiftUI
import Charts

struct TournamentDetailView: View {
    let tournament: LimitlessTournament

    @State private var vm = TournamentDetailViewModel()
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if vm.isLoading && vm.detail == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.error, vm.detail == nil {
                errorState(error)
            } else {
                content
            }
        }
        .navigationTitle(tournament.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(tournamentId: tournament.id) }
        .refreshable { await vm.refresh(tournamentId: tournament.id) }
    }

    // MARK: - Content

    private var content: some View {
        List {
            headerSection
            segmentPicker
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if selectedTab == 0 {
                standingsRows
            } else {
                metaShareRows
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tournament.date.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !tournament.country.isEmpty {
                    Label(tournament.country, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(tournament.playerCount)")
                    .font(.title2.weight(.semibold))
                Text("Players")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Segment picker

    private var segmentPicker: some View {
        Picker("View", selection: $selectedTab) {
            Text("Standings").tag(0)
            Text("Meta Share").tag(1)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Standings

    @ViewBuilder
    private var standingsRows: some View {
        Section {
            ForEach(vm.visiblePlacements) { placement in
                placementRow(placement)
            }
        }

        if vm.canShowMore {
            Section {
                Button(vm.showLimit == 8 ? "Show Top 32" : "Show All") {
                    vm.showMore()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    @ViewBuilder
    private func placementRow(_ p: LimitlessPlacement) -> some View {
        let row = HStack(spacing: 12) {
            Text("#\(p.rank)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(rankColor(p.rank))
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(p.playerName)
                    .font(.body)
                Text(p.archetype)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if p.wins + p.losses + p.ties > 0 {
                    Text("\(p.wins)–\(p.losses)–\(p.ties)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if !p.hasDeckList {
                    Text("Decklist not public")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)

        if p.hasDeckList, let listId = p.deckListId {
            NavigationLink {
                DeckListViewerView(listId: listId, archetype: p.archetype)
            } label: {
                row
            }
        } else {
            row
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1:  return .yellow
        case 2:  return Color(white: 0.6)
        case 3:  return Color(red: 0.72, green: 0.45, blue: 0.2)
        default: return .secondary
        }
    }

    // MARK: - Meta Share

    @ViewBuilder
    private var metaShareRows: some View {
        let entries = vm.metaShare
        if entries.isEmpty {
            Section {
                ContentUnavailableView("No Data", systemImage: "chart.bar")
            }
        } else {
            Section {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Share", entry.share),
                        y: .value("Archetype", entry.archetype)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(String(format: "%.1f%%", entry.share))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(entries.count) * 28 + 16)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Breakdown") {
                ForEach(entries) { entry in
                    HStack {
                        Text(entry.archetype)
                            .font(.body)
                        Spacer()
                        Text("\(entry.count) player\(entry.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", entry.share))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Error

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Load Standings", systemImage: "wifi.slash")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { Task { await vm.refresh(tournamentId: tournament.id) } }
        }
    }
}
