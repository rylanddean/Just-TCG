import SwiftUI

struct CompetitorsView: View {
    @State private var vm = CompetitorsViewModel()
    @State private var searchQuery = ""
    @State private var searchTask: Task<Void, Never>? = nil
    @Environment(FavouritePlayerRepository.self) private var favourites

    var body: some View {
        List {
            if searchQuery.isEmpty {
                defaultContent
            } else {
                searchResultsSection
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .searchable(text: $searchQuery, prompt: "Search competitors")
        .task { await vm.loadLeaderboard() }
        .onChange(of: vm.zone) { _, _ in Task { await vm.loadLeaderboard() } }
        .onChange(of: searchQuery) { _, query in
            searchTask?.cancel()
            guard !query.isEmpty else {
                vm.cancelSearch()
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await vm.search(query: query)
            }
        }
    }

    // MARK: - Default (no search)

    @ViewBuilder
    private var defaultContent: some View {
        if !favourites.all.isEmpty {
            Section("Favourites") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(favourites.all) { player in
                            NavigationLink {
                                PlayerDetailView(playerID: player.id)
                            } label: {
                                FavouriteChip(player: player)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    favourites.remove(id: player.id)
                                } label: {
                                    Label("Remove from Favourites", systemImage: "star.slash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
        }

        Section {
            if vm.isLoadingLeaderboard {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(vm.leaderboard) { player in
                    NavigationLink {
                        PlayerDetailView(playerID: player.id)
                    } label: {
                        PlayerCard(
                            player: player,
                            isFavourite: favourites.isFavourite(id: player.id)
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .leading) {
                        let isFav = favourites.isFavourite(id: player.id)
                        Button {
                            if isFav {
                                favourites.remove(id: player.id)
                            } else {
                                favourites.add(FavouritePlayer(
                                    id: player.id,
                                    name: player.name,
                                    country: player.country,
                                    lastKnownPoints: player.points,
                                    lastKnownRank: player.rank
                                ))
                            }
                        } label: {
                            Label(isFav ? "Unfavourite" : "Favourite",
                                  systemImage: isFav ? "star.slash" : "star")
                        }
                        .tint(isFav ? .gray : .yellow)
                    }
                }
            }
        } header: {
            filterHeader
        }
        .textCase(nil)
    }

    // MARK: - Filter header (sticky, sits above rankings)

    private var filterHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlayerZone.allCases, id: \.rawValue) { zone in
                    FilterChip(
                        title: zone.displayName,
                        isSelected: vm.zone == zone
                    ) { vm.zone = zone }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color(.systemBackground)
                .padding(.horizontal, -1000)
        }
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchResultsSection: some View {
        if vm.isSearching {
            Section {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        } else if let error = vm.searchError {
            Section {
                VStack(spacing: 12) {
                    Text("Couldn't search players")
                        .font(.subheadline.weight(.medium))
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await vm.search(query: searchQuery) }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }
        } else if vm.hasSearched && vm.searchResults.isEmpty {
            Section {
                Text("No players found for '\(searchQuery)'.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        } else {
            Section("Search Results") {
                ForEach(vm.searchResults) { result in
                    NavigationLink {
                        PlayerDetailView(playerID: result.id)
                    } label: {
                        PlayerCard(
                            player: result,
                            isFavourite: favourites.isFavourite(id: result.id)
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .leading) {
                        let isFav = favourites.isFavourite(id: result.id)
                        Button {
                            if isFav {
                                favourites.remove(id: result.id)
                            } else {
                                favourites.add(FavouritePlayer(
                                    id: result.id,
                                    name: result.name,
                                    country: result.country,
                                    lastKnownPoints: result.points,
                                    lastKnownRank: result.rank
                                ))
                            }
                        } label: {
                            Label(isFav ? "Unfavourite" : "Favourite",
                                  systemImage: isFav ? "star.slash" : "star")
                        }
                        .tint(isFav ? .gray : .yellow)
                    }
                }
            }
        }
    }
}

// MARK: - Row subviews

private struct FavouriteChip: View {
    let player: FavouritePlayer

    var body: some View {
        let displayName = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
        Text(displayName.isEmpty ? player.id : displayName)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.yellow.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.35), lineWidth: 1))
            .foregroundStyle(.primary)
    }
}

private struct PlayerCard: View {
    let player: LimitlessPlayerSearchResult
    let isFavourite: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Left accent strip for top 3
            if let rank = player.rank, rank <= 3 {
                rankColor(rank).frame(width: 3)
            }

            HStack(spacing: 12) {
                if let rank = player.rank {
                    Text("#\(rank)")
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(rankColor(rank))
                        .frame(width: 52, alignment: .center)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.body)
                    if !player.country.isEmpty {
                        Text(countryFlag(player.country))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let pts = player.points {
                        Text("\(pts) pts")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if isFavourite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
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

// MARK: - Filter chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .overlay(Capsule().strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.4) : .clear,
                    lineWidth: 1
                ))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Helpers

private func countryFlag(_ code: String) -> String {
    let base: UInt32 = 127397
    return code.uppercased().unicodeScalars.compactMap {
        Unicode.Scalar(base + $0.value).map { String($0) }
    }.joined()
}
