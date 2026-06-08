import SwiftUI
import SwiftData

struct LiveGameSetupSheet: View {
    let deck: Deck
    let onStart: (LiveGame) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var vm = LiveGameSetupViewModel()

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Form {
                archetypeSection
                goesFirstSection
                moreDetailsSection
            }
            .navigationTitle("Start Live Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Game") {
                        let game = vm.startGame(deck: deck, context: context)
                        dismiss()
                        onStart(game)
                    }
                    .fontWeight(.semibold)
                    .disabled(!vm.isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Archetype

    @ViewBuilder
    private var archetypeSection: some View {
        @Bindable var vm = vm
        Section("Opponent Archetype") {
            if !vm.metaDecks.isEmpty {
                Picker("Quick Pick", selection: $vm.quickPickSelection) {
                    Text("Custom").tag("Custom")
                    ForEach(vm.metaDecks, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: vm.quickPickSelection) { _, newValue in
                    guard newValue != "Custom" else { return }
                    vm.selectArchetype(Archetype(id: newValue, name: newValue, primaryType: ""))
                }
            }
            TextField("e.g. Dragapult ex", text: $vm.archetypeQuery)
                .autocorrectionDisabled()
            ForEach(vm.suggestions) { arch in
                Button {
                    vm.selectArchetype(arch)
                } label: {
                    HStack {
                        Text(arch.name)
                        Spacer()
                        Text(arch.primaryType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Who goes first

    private var goesFirstSection: some View {
        @Bindable var vm = vm
        return Section("Who Goes First") {
            Picker("", selection: $vm.goesFirst) {
                Text("Me").tag(GoesFirst.me)
                Text("Them").tag(GoesFirst.them)
                Text("Undecided").tag(GoesFirst.undecided)
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
    }

    // MARK: - More details

    @ViewBuilder
    private var moreDetailsSection: some View {
        @Bindable var vm = vm
        DisclosureGroup("More Details", isExpanded: $vm.showMoreDetails) {
            Picker("Event", selection: $vm.eventType) {
                Text("Casual").tag(EventType.casual)
                Text("League Challenge").tag(EventType.leagueChallenge)
                Text("Regionals").tag(EventType.regionals)
                Text("Internationals").tag(EventType.internationalChampionship)
                Text("Worlds").tag(EventType.worldChampionship)
            }
            Picker("Format", selection: $vm.format) {
                Text("Best-of-1").tag(MatchFormat.bo1)
                Text("Best-of-3").tag(MatchFormat.bo3)
            }
            .pickerStyle(.segmented)
        }
    }
}
