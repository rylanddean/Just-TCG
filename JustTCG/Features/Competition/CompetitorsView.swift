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
        .searchable(text: $searchQuery, prompt: "Search competitors")
        .task { await vm.loadLeaderboard() }
        .onChange(of: vm.sortBy) { _, _ in Task { await vm.loadLeaderboard() } }
        .onChange(of: vm.zone)   { _, _ in Task { await vm.loadLeaderboard() } }
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
                ForEach(favourites.all) { player in
                    NavigationLink {
                        PlayerDetailView(playerID: player.id)
                    } label: {
                        FavouritePlayerRow(player: player)
                    }
                }
                .onDelete { indices in
                    indices.forEach { favourites.remove(id: favourites.all[$0].id) }
                }
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
                        LeaderboardRow(
                            player: player,
                            isFavourite: favourites.isFavourite(id: player.id),
                            sort: vm.sortBy
                        )
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
        VStack(alignment: .leading, spacing: 6) {
            // Sort chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlayerRankSort.allCases, id: \.rawValue) { sort in
                        FilterChip(
                            title: sort.displayName,
                            isSelected: vm.sortBy == sort
                        ) { vm.sortBy = sort }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            }
            // Zone chips
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
        }
        .padding(.top, 8)
        .background(Color(.systemBackground))
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
                        LeaderboardRow(
                            player: result,
                            isFavourite: favourites.isFavourite(id: result.id),
                            sort: vm.sortBy
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Row subviews

private struct FavouritePlayerRow: View {
    let player: FavouritePlayer

    var body: some View {
        HStack(spacing: 10) {
            if !player.country.isEmpty {
                Text(countryFlag(player.country))
            }
            Text(player.name)
                .font(.body)
        }
    }
}

private struct LeaderboardRow: View {
    let player: LimitlessPlayerSearchResult
    let isFavourite: Bool
    let sort: PlayerRankSort

    var body: some View {
        HStack(spacing: 12) {
            if let rank = player.rank {
                Text("\(rank)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, alignment: .trailing)
            }
            if !player.country.isEmpty {
                Text(countryFlag(player.country))
            }
            Text(player.name)
                .font(.body)
            Spacer()
            if let pts = player.points {
                Text("\(pts) \(sort.columnLabel)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if isFavourite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline)
            }
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
