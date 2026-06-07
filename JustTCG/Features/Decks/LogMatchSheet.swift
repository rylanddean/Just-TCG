import SwiftUI
import SwiftData

struct LogMatchSheet: View {
    let deck: Deck

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var vm: LogMatchViewModel? = nil

    var body: some View {
        Group {
            if let vm {
                sheetContent(vm: vm)
            }
        }
        .task {
            if vm == nil {
                vm = LogMatchViewModel(deck: deck, modelContext: context)
            }
        }
    }

    // MARK: - Sheet content

    @ViewBuilder
    private func sheetContent(vm: LogMatchViewModel) -> some View {
        @Bindable var vm = vm
        NavigationStack {
            Form {
                archetypeSection(vm: vm)
                resultSection(vm: vm)
                moreDetailsSection(vm: vm)
            }
            .navigationTitle("Log Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { vm.confirm() }
                        .fontWeight(.semibold)
                        .disabled(!vm.isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .overlay(alignment: .bottom) {
            if vm.showToast {
                Text("Match logged")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.showToast)
        .onChange(of: vm.showToast) { _, isShowing in
            guard isShowing else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                dismiss()
            }
        }
    }

    // MARK: - Archetype section

    @ViewBuilder
    private func archetypeSection(vm: LogMatchViewModel) -> some View {
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

    // MARK: - Result section

    @ViewBuilder
    private func resultSection(vm: LogMatchViewModel) -> some View {
        Section("Result") {
            HStack(spacing: 10) {
                resultButton(.win,  label: "Win",  color: .green,  vm: vm)
                resultButton(.loss, label: "Loss", color: .red,    vm: vm)
                resultButton(.tie,  label: "Tie",  color: .secondary, vm: vm)
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
    }

    @ViewBuilder
    private func resultButton(
        _ r: MatchResult,
        label: String,
        color: Color,
        vm: LogMatchViewModel
    ) -> some View {
        let isSelected = vm.result == r
        Button { vm.result = r } label: {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    isSelected ? color : Color.secondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - More details section

    @ViewBuilder
    private func moreDetailsSection(vm: LogMatchViewModel) -> some View {
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

            DatePicker("Date", selection: $vm.date, displayedComponents: .date)

            TextField("Notes (optional)", text: $vm.notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }
}
