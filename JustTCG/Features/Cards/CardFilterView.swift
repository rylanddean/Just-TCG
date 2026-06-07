import SwiftUI

struct CardFilterView: View {
    @Binding var filterState: CardFilterState
    let availableSets: [(code: String, name: String)]
    @Environment(\.dismiss) private var dismiss

    private let allTypes = [
        "Colorless", "Darkness", "Dragon", "Fighting",
        "Fire", "Grass", "Lightning", "Metal", "Psychic", "Water",
    ]
    private let allSubtypes = [
        "Basic", "Stage 1", "Stage 2",
        "Pokémon ex", "Pokémon V", "VMAX", "VSTAR",
        "Item", "Supporter", "Stadium", "Tool", "Energy",
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Type") {
                    ForEach(allTypes, id: \.self) { type in
                        selectionRow(
                            label: type,
                            isSelected: filterState.types.contains(type)
                        ) { filterState.types.formSymmetricDifference([type]) }
                    }
                }
                Section("Subtype") {
                    ForEach(allSubtypes, id: \.self) { subtype in
                        selectionRow(
                            label: subtype,
                            isSelected: filterState.subtypes.contains(subtype)
                        ) { filterState.subtypes.formSymmetricDifference([subtype]) }
                    }
                }
                if !availableSets.isEmpty {
                    Section("Set") {
                        ForEach(availableSets, id: \.code) { set in
                            selectionRow(
                                label: set.name,
                                isSelected: filterState.sets.contains(set.code)
                            ) { filterState.sets.formSymmetricDifference([set.code]) }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") { filterState = CardFilterState() }
                        .disabled(filterState.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func selectionRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
