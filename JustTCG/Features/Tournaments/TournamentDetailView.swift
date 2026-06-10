import SwiftUI
import Charts
import SwiftData

struct TournamentDetailView: View {
    let tournament: LimitlessTournament

    @State private var vm = TournamentDetailViewModel()
    @State private var selectedTab = 0
    @Environment(FavouritePlayerRepository.self) private var favourites
    @Query private var allCards: [CachedCard]
    private let resolver = ArchetypePrimaryCardResolver()

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
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private func placementRow(_ p: LimitlessPlacement) -> some View {
        Group {
            if p.hasDeckList, let listId = p.deckListId {
                NavigationLink {
                    DeckListViewerView(listId: listId, archetype: p.archetype, playerId: p.playerId)
                } label: {
                    PlacementCard(placement: p)
                }
            } else {
                PlacementCard(placement: p)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .leading) { favouriteAction(p) }
    }

    @ViewBuilder
    private func favouriteAction(_ p: LimitlessPlacement) -> some View {
        let isFav = favourites.isFavourite(id: p.playerId ?? p.playerName)
        Button {
            if isFav {
                favourites.remove(id: p.playerId ?? p.playerName)
            } else {
                favourites.add(FavouritePlayer(
                    id: p.playerId ?? p.playerName,
                    name: p.playerName,
                    country: p.country,
                    lastKnownRank: p.rank
                ))
            }
        } label: {
            Label(isFav ? "Unfavourite" : "Favourite",
                  systemImage: isFav ? "star.slash" : "star")
        }
        .tint(isFav ? .gray : .yellow)
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
            let chartEntries = Array(entries.prefix(8))
            Section {
                Chart(chartEntries) { entry in
                    BarMark(
                        x: .value("Share", entry.share),
                        y: .value("Archetype", String(entry.archetype.prefix(18)))
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Archetype", entry.archetype))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(String(format: "%.1f%%", entry.share))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .chartLegend(.hidden)
                .frame(height: max(CGFloat(chartEntries.count) * 36 + 24, 120))
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 48))
            }

            Section {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                    metaShareRow(entry: entry, rank: idx + 1)
                }
            }
        }
    }

    private func metaShareRow(entry: MetaShareEntry, rank: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(rank <= 3 ? .subheadline.monospacedDigit().weight(.bold) : .caption.monospacedDigit())
                .foregroundStyle(rankColor(rank))
                .frame(width: 24, alignment: .center)

            let resolvedCards = resolver.resolveMultiple(archetype: entry.archetype, from: allCards)
            if resolvedCards.isEmpty {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.quaternarySystemFill))
                    .overlay(
                        Text(String(entry.archetype.prefix(1)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    )
                    .frame(width: 32, height: 44)
            } else {
                HStack(spacing: resolvedCards.count > 1 ? -10 : 0) {
                    ForEach(Array(resolvedCards.enumerated()), id: \.element.id) { idx, card in
                        AsyncImage(url: URL(string: card.imageURL)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                        }
                        .frame(width: 32, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 0)
                        .zIndex(Double(resolvedCards.count - idx))
                    }
                }
                .frame(width: resolvedCards.count > 1 ? 54 : 32, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.archetype)
                    .font(.body)
                Text("\(entry.count) player\(entry.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.1f%%", entry.share))
                .font(.caption.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(rankColor(rank).opacity(0.15), in: Capsule())
                .foregroundStyle(rankColor(rank))
        }
        .padding(.vertical, 2)
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

// MARK: - Placement card

private struct PlacementCard: View {
    let placement: LimitlessPlacement

    var body: some View {
        HStack(spacing: 0) {
            // Left-edge accent strip for top-3
            if placement.rank <= 3 {
                rankColor(placement.rank)
                    .frame(width: 3)
            }

            // Content
            HStack(spacing: 12) {
                Text("#\(placement.rank)")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(rankColor(placement.rank))
                    .frame(width: 52, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(placement.playerName)
                        .font(.body)
                    Text(placement.archetype)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if placement.wins + placement.losses + placement.ties > 0 {
                        Text("\(placement.wins)–\(placement.losses)–\(placement.ties)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if !placement.hasDeckList {
                        Text("No decklist")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1:  return .yellow
        case 2:  return Color(white: 0.6)
        case 3:  return Color(red: 0.72, green: 0.45, blue: 0.2)
        default: return .secondary
        }
    }
}
