import SwiftUI

struct TournamentsView: View {
    @State private var vm = TournamentListViewModel()
    @Environment(AppNavigationState.self) private var nav

    var body: some View {
        Group {
            if vm.tournaments.isEmpty && vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.tournaments.isEmpty && vm.error != nil {
                errorState
            } else {
                tournamentList
            }
        }
        .task { await vm.loadIfNeeded() }
        .refreshable { await vm.refresh() }
    }

    // MARK: - Tournament list

    private var tournamentList: some View {
        List {
            if let archetype = nav.tournamentsArchetypeFilter {
                archetypeFilterBanner(archetype)
                    .listRowBackground(Color.orange.opacity(0.08))
            }

            filterBar
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(vm.filtered) { tournament in
                NavigationLink {
                    TournamentDetailView(tournament: tournament)
                } label: {
                    TournamentRow(tournament: tournament)
                }
            }

            if let date = vm.lastFetchDate {
                Section {
                    Text("Last updated \(date, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .overlay {
            if vm.filtered.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    "No Tournaments",
                    systemImage: "trophy",
                    description: Text("No events match the selected filter.")
                )
            }
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", tier: nil)
                ForEach(TournamentTier.allCases) { tier in
                    filterChip(label: tier.rawValue, tier: tier)
                }
            }
        }
    }

    @ViewBuilder
    private func filterChip(label: String, tier: TournamentTier?) -> some View {
        let isSelected = vm.selectedTier == tier
        Button {
            vm.selectedTier = isSelected ? nil : tier
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? tierColor(tier).opacity(0.2) : Color.secondary.opacity(0.1),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? tierColor(tier) : .secondary)
                .overlay(
                    Capsule().strokeBorder(isSelected ? tierColor(tier).opacity(0.4) : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func tierColor(_ tier: TournamentTier?) -> Color {
        switch tier {
        case .worlds:   return .yellow
        case .ic:       return .purple
        case .regional: return .blue
        case .lc, nil:  return .secondary
        }
    }

    // MARK: - Archetype filter banner

    private func archetypeFilterBanner(_ archetype: String) -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.orange)
            Text("Finding deck lists for **\(archetype)** — tap a tournament to view standings")
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                nav.tournamentsArchetypeFilter = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Error state

    private var errorState: some View {
        ContentUnavailableView {
            Label("Couldn't Load Tournaments", systemImage: "wifi.slash")
        } description: {
            Text(vm.error ?? "An unknown error occurred.")
        } actions: {
            Button("Try Again") { Task { await vm.refresh() } }
        }
    }
}

// MARK: - Tournament row

private struct TournamentRow: View {
    let tournament: LimitlessTournament

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(tournament.name)
                    .font(.body.weight(.medium))
                Spacer()
                tierBadge(tournament.tier)
            }
            HStack(spacing: 12) {
                Label(tournament.date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                if !tournament.country.isEmpty {
                    Label(tournament.country, systemImage: "mappin")
                }
                Label("\(tournament.playerCount)", systemImage: "person.2")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func tierBadge(_ tier: TournamentTier) -> some View {
        let (label, color): (String, Color) = switch tier {
        case .worlds:   ("Worlds",    .yellow)
        case .ic:       ("IC",        .purple)
        case .regional: ("Regional",  .blue)
        case .lc:       ("LC",        .secondary)
        }
        Text(label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
