import SwiftUI

struct PlayerDetailView: View {
    let playerID: String

    @State private var vm: PlayerDetailViewModel
    @Environment(FavouritePlayerRepository.self) private var favourites

    init(playerID: String) {
        self.playerID = playerID
        self._vm = State(initialValue: PlayerDetailViewModel(playerID: playerID))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.profile == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMsg = vm.error, vm.profile == nil {
                errorState(errorMsg)
            } else if let profile = vm.profile {
                content(profile)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(vm.profile?.name ?? "Player")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.refresh() }
        .toolbar {
            if let profile = vm.profile {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if favourites.isFavourite(id: profile.id) {
                            favourites.remove(id: profile.id)
                        } else {
                            favourites.add(FavouritePlayer(
                                id: profile.id,
                                name: profile.name,
                                country: profile.country
                            ))
                        }
                    } label: {
                        Image(systemName: favourites.isFavourite(id: profile.id) ? "star.fill" : "star")
                            .foregroundStyle(favourites.isFavourite(id: profile.id) ? .yellow : .secondary)
                    }
                }
            }
        }
    }

    // MARK: - Content

    private func content(_ profile: LimitlessPlayerProfile) -> some View {
        List {
            headerSection(profile)
            careerStatsSection(profile.topCuts)
            historySection(profile.results)
        }
        .listStyle(.plain)
    }

    // MARK: - Header

    private func headerSection(_ profile: LimitlessPlayerProfile) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if !profile.country.isEmpty {
                    Text("\(countryFlag(profile.country)) \(profile.country)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    statChip("\(profile.totalPoints) pts")
                    if profile.totalPrizeMoney > 0 {
                        statChip("$\(profile.totalPrizeMoney.formatted())")
                    }
                    if profile.travelAwards > 0 {
                        statChip("\(profile.travelAwards) travel")
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowSeparator(.hidden)
    }

    private func statChip(_ label: String) -> some View {
        Text(label)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(.systemGray5), in: Capsule())
    }

    // MARK: - Career Stats

    private func careerStatsSection(_ cuts: PlayerTopCuts) -> some View {
        Section("Career Top Cuts") {
            VStack(spacing: 16) {
                topCutRow(
                    label: "Internationals",
                    counts: [cuts.internationalWins, cuts.internationalTop2, cuts.internationalTop4, cuts.internationalTop8]
                )
                topCutRow(
                    label: "Regionals",
                    counts: [cuts.regionalWins, cuts.regionalTop2, cuts.regionalTop4, cuts.regionalTop8]
                )
            }
            .padding(.vertical, 8)
        }
    }

    private func topCutRow(label: String, counts: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                ForEach(Array(zip(["1st", "T2", "T4", "T8"], counts)), id: \.0) { tier, count in
                    VStack(spacing: 2) {
                        Text(count == 0 ? "—" : "\(count)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(count == 0 ? .secondary : .primary)
                        Text(tier)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Tournament History

    @ViewBuilder
    private func historySection(_ results: [PlayerTournamentResult]) -> some View {
        Section("Tournament History") {
            if results.isEmpty {
                Text("No tournament results found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { result in
                    resultRow(result)
                }
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ result: PlayerTournamentResult) -> some View {
        let row = HStack(spacing: 12) {
            placementBadge(result.placement)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.tournamentName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(result.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(result.archetype)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !result.record.isEmpty {
                    Text(result.record)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Text("+\(result.points) pts")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if result.deckListId == nil {
                Image(systemName: "lock")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)

        if let listId = result.deckListId {
            NavigationLink {
                DeckListViewerView(listId: listId, archetype: result.archetype)
            } label: {
                row
            }
        } else {
            row
        }
    }

    private func placementBadge(_ rank: Int) -> some View {
        Text("\(rank)")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(badgeForeground(rank))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(badgeBackground(rank), in: Capsule())
            .frame(minWidth: 32)
    }

    private func badgeForeground(_ rank: Int) -> Color {
        switch rank {
        case 1:  return .black
        case 2:  return .black
        case 3:  return .white
        default: return .secondary
        }
    }

    private func badgeBackground(_ rank: Int) -> Color {
        switch rank {
        case 1:  return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2:  return Color(white: 0.75)
        case 3:  return Color(red: 0.72, green: 0.45, blue: 0.2)
        default: return Color(.systemGray5)
        }
    }

    // MARK: - Error

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Load Profile", systemImage: "wifi.slash")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { Task { await vm.refresh() } }
        }
    }

    // MARK: - Helpers

    private func countryFlag(_ code: String) -> String {
        let base: UInt32 = 127397
        return code.uppercased().unicodeScalars.compactMap {
            Unicode.Scalar(base + $0.value).map { String($0) }
        }.joined()
    }
}
