import SwiftUI

struct CardFilterView: View {
    @Binding var filterState: CardFilterState
    let availableSets: [(code: String, name: String)]
    let availableRegulationMarks: [String]
    let availableRarities: [String]
    let hideRegulationMark: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var basicExpanded = true
    @State private var setLegalityExpanded = true
    @State private var statsExpanded = true
    @State private var matchupExpanded = true

    init(
        filterState: Binding<CardFilterState>,
        availableSets: [(code: String, name: String)],
        availableRegulationMarks: [String] = [],
        availableRarities: [String] = [],
        hideRegulationMark: Bool = false
    ) {
        self._filterState = filterState
        self.availableSets = availableSets
        self.availableRegulationMarks = availableRegulationMarks
        self.availableRarities = availableRarities
        self.hideRegulationMark = hideRegulationMark
    }

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
                basicSection
                setLegalitySection
                statsSection
                matchupSection
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

    // MARK: - Sections

    private var basicSection: some View {
        Section {
            DisclosureGroup(isExpanded: $basicExpanded) {
                groupLabel("Type")
                ForEach(allTypes, id: \.self) { type in
                    selectionRow(label: type, isSelected: filterState.types.contains(type)) {
                        filterState.types.formSymmetricDifference([type])
                    }
                }
                groupLabel("Subtype")
                ForEach(allSubtypes, id: \.self) { sub in
                    selectionRow(label: sub, isSelected: filterState.subtypes.contains(sub)) {
                        filterState.subtypes.formSymmetricDifference([sub])
                    }
                }
            } label: {
                Text("Basic").font(.headline)
            }
        }
    }

    private var setLegalitySection: some View {
        Section {
            DisclosureGroup(isExpanded: $setLegalityExpanded) {
                if !availableSets.isEmpty {
                    groupLabel("Set")
                    ForEach(availableSets, id: \.code) { set in
                        selectionRow(label: set.name, isSelected: filterState.sets.contains(set.code)) {
                            filterState.sets.formSymmetricDifference([set.code])
                        }
                    }
                }
                if !hideRegulationMark && !availableRegulationMarks.isEmpty {
                    groupLabel("Regulation Mark")
                    ForEach(availableRegulationMarks, id: \.self) { mark in
                        selectionRow(label: mark, isSelected: filterState.regulationMarks.contains(mark)) {
                            filterState.regulationMarks.formSymmetricDifference([mark])
                        }
                    }
                }
                if !availableRarities.isEmpty {
                    groupLabel("Rarity")
                    ForEach(availableRarities, id: \.self) { rarity in
                        selectionRow(label: rarity, isSelected: filterState.rarities.contains(rarity)) {
                            filterState.rarities.formSymmetricDifference([rarity])
                        }
                    }
                }
            } label: {
                Text("Set & Legality").font(.headline)
            }
        }
    }

    private var statsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $statsExpanded) {
                hpRangeRow
                damageRangeRow
                retreatCostRow
                abilityRow
            } label: {
                Text("Stats").font(.headline)
            }
        }
    }

    private var matchupSection: some View {
        Section {
            DisclosureGroup(isExpanded: $matchupExpanded) {
                groupLabel("Weakness")
                typeMultiSelect(selection: $filterState.weaknessTypes)
                groupLabel("Resistance")
                typeMultiSelect(selection: $filterState.resistanceTypes)
                groupLabel("Attacking Energy")
                typeMultiSelect(selection: $filterState.attackingEnergyTypes)
            } label: {
                Text("Matchup").font(.headline)
            }
        }
    }

    // MARK: - Stats controls

    private var hpRangeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HP")
                .font(.subheadline.weight(.medium))
            HStack(spacing: 16) {
                rangeField(
                    label: "Min",
                    value: Binding(
                        get: { filterState.hpMin ?? 0 },
                        set: { v in
                            let clamped = max(0, min(v, filterState.hpMax ?? 350))
                            filterState.hpMin = clamped == 0 ? nil : clamped
                        }
                    ),
                    placeholder: "Any",
                    hasValue: filterState.hpMin != nil
                )
                Text("–").foregroundStyle(.secondary)
                rangeField(
                    label: "Max",
                    value: Binding(
                        get: { filterState.hpMax ?? 350 },
                        set: { v in
                            let clamped = max(filterState.hpMin ?? 0, min(v, 350))
                            filterState.hpMax = clamped == 350 ? nil : clamped
                        }
                    ),
                    placeholder: "Any",
                    hasValue: filterState.hpMax != nil
                )
            }
        }
        .padding(.vertical, 4)
    }

    private var damageRangeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Max Damage")
                .font(.subheadline.weight(.medium))
            HStack(spacing: 16) {
                rangeField(
                    label: "Min",
                    value: Binding(
                        get: { filterState.damageMin ?? 0 },
                        set: { v in
                            let clamped = max(0, min(v, filterState.damageMax ?? 350))
                            filterState.damageMin = clamped == 0 ? nil : clamped
                        }
                    ),
                    placeholder: "Any",
                    hasValue: filterState.damageMin != nil
                )
                Text("–").foregroundStyle(.secondary)
                rangeField(
                    label: "Max",
                    value: Binding(
                        get: { filterState.damageMax ?? 350 },
                        set: { v in
                            let clamped = max(filterState.damageMin ?? 0, min(v, 350))
                            filterState.damageMax = clamped == 350 ? nil : clamped
                        }
                    ),
                    placeholder: "Any",
                    hasValue: filterState.damageMax != nil
                )
            }
        }
        .padding(.vertical, 4)
    }

    private var retreatCostRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Retreat Cost")
                .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                ForEach([0, 1, 2, 3, 4], id: \.self) { cost in
                    let label = cost == 4 ? "4+" : "\(cost)"
                    let selected = filterState.retreatCosts.contains(cost)
                    Button(action: { filterState.retreatCosts.formSymmetricDifference([cost]) }) {
                        Text(label)
                            .font(.callout.weight(.medium))
                            .frame(minWidth: 40, minHeight: 32)
                            .background(selected ? Color.accentColor : Color.clear)
                            .foregroundStyle(selected ? Color.white : Color.accentColor)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.accentColor, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var abilityRow: some View {
        HStack {
            Text("Ability")
                .font(.subheadline.weight(.medium))
            Spacer()
            Picker("Ability", selection: Binding(
                get: { filterState.hasAbility.map { $0 ? 1 : 2 } ?? 0 },
                set: { val in
                    switch val {
                    case 1:  filterState.hasAbility = true
                    case 2:  filterState.hasAbility = false
                    default: filterState.hasAbility = nil
                    }
                }
            )) {
                Text("Any").tag(0)
                Text("Yes").tag(1)
                Text("No").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
    }

    private func typeMultiSelect(selection: Binding<Set<String>>) -> some View {
        ForEach(allTypes, id: \.self) { type in
            selectionRow(label: type, isSelected: selection.wrappedValue.contains(type)) {
                selection.wrappedValue.formSymmetricDifference([type])
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
        .buttonStyle(.plain)
    }

    private func rangeField(
        label: String,
        value: Binding<Int>,
        placeholder: String,
        hasValue: Bool
    ) -> some View {
        Stepper(
            value: value,
            in: 0...350,
            step: 10
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(hasValue ? "\(value.wrappedValue)" : placeholder)
                    .font(.body)
                    .foregroundStyle(hasValue ? .primary : .secondary)
            }
        }
    }
}
