import SwiftUI

struct CardFilterView: View {
    @Binding var filterState: CardFilterState
    let availableSets: [(code: String, name: String)]
    let availableRegulationMarks: [String]
    let availableRarities: [String]
    let hideRegulationMark: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var basicExpanded = true
    @State private var setLegalityExpanded = false
    @State private var statsExpanded = false
    @State private var matchupExpanded = false
    @State private var roleExpanded = false

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

    private let twoColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    private let threeColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        NavigationStack {
            List {
                basicSection
                setLegalitySection
                statsSection
                matchupSection
                roleSection
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
                VStack(alignment: .leading, spacing: 10) {
                    groupLabel("Type")
                    LazyVGrid(columns: threeColumns, alignment: .leading, spacing: 8) {
                        ForEach(allTypes, id: \.self) { type in
                            filterChip(label: type, isSelected: filterState.types.contains(type)) {
                                filterState.types.formSymmetricDifference([type])
                            }
                        }
                    }
                    groupLabel("Subtype")
                    LazyVGrid(columns: twoColumns, alignment: .leading, spacing: 8) {
                        ForEach(allSubtypes, id: \.self) { sub in
                            filterChip(label: sub, isSelected: filterState.subtypes.contains(sub)) {
                                filterState.subtypes.formSymmetricDifference([sub])
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            } label: {
                sectionLabel("Basic", count: filterState.types.count + filterState.subtypes.count)
            }
        }
    }

    private var setLegalitySection: some View {
        Section {
            DisclosureGroup(isExpanded: $setLegalityExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    if !availableSets.isEmpty {
                        groupLabel("Set")
                        LazyVGrid(columns: twoColumns, alignment: .leading, spacing: 8) {
                            ForEach(availableSets, id: \.code) { set in
                                filterChip(label: set.name, isSelected: filterState.sets.contains(set.code)) {
                                    filterState.sets.formSymmetricDifference([set.code])
                                }
                            }
                        }
                    }
                    if !hideRegulationMark && !availableRegulationMarks.isEmpty {
                        groupLabel("Regulation Mark")
                        HStack(spacing: 8) {
                            ForEach(availableRegulationMarks, id: \.self) { mark in
                                filterChip(label: mark, isSelected: filterState.regulationMarks.contains(mark)) {
                                    filterState.regulationMarks.formSymmetricDifference([mark])
                                }
                            }
                            Spacer()
                        }
                    }
                    if !availableRarities.isEmpty {
                        groupLabel("Rarity")
                        LazyVGrid(columns: twoColumns, alignment: .leading, spacing: 8) {
                            ForEach(availableRarities, id: \.self) { rarity in
                                filterChip(label: rarity, isSelected: filterState.rarities.contains(rarity)) {
                                    filterState.rarities.formSymmetricDifference([rarity])
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            } label: {
                sectionLabel("Set & Legality", count: filterState.sets.count + filterState.regulationMarks.count + filterState.rarities.count)
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
                let activeCount = (filterState.hpMin != nil || filterState.hpMax != nil ? 1 : 0)
                    + (filterState.damageMin != nil || filterState.damageMax != nil ? 1 : 0)
                    + (filterState.retreatCosts.isEmpty ? 0 : 1)
                    + (filterState.hasAbility != nil ? 1 : 0)
                sectionLabel("Stats", count: activeCount)
            }
        }
    }

    private var matchupSection: some View {
        Section {
            DisclosureGroup(isExpanded: $matchupExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    groupLabel("Weakness")
                    typeChipGrid(selection: $filterState.weaknessTypes)
                    groupLabel("Resistance")
                    typeChipGrid(selection: $filterState.resistanceTypes)
                    groupLabel("Attacking Energy")
                    typeChipGrid(selection: $filterState.attackingEnergyTypes)
                }
                .padding(.vertical, 6)
            } label: {
                sectionLabel("Matchup", count: filterState.weaknessTypes.count + filterState.resistanceTypes.count + filterState.attackingEnergyTypes.count)
            }
        }
    }

    private var roleSection: some View {
        Section {
            DisclosureGroup(isExpanded: $roleExpanded) {
                LazyVGrid(columns: twoColumns, alignment: .leading, spacing: 8) {
                    ForEach(CardFilterState.allRoleTags, id: \.self) { tag in
                        filterChip(label: tag, isSelected: filterState.roleTags.contains(tag)) {
                            filterState.roleTags.formSymmetricDifference([tag])
                        }
                    }
                }
                .padding(.vertical, 6)
            } label: {
                sectionLabel("Card Role", count: filterState.roleTags.count)
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

    // MARK: - Reusable components

    private func sectionLabel(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.headline)
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
            }
        }
    }

    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func typeChipGrid(selection: Binding<Set<String>>) -> some View {
        LazyVGrid(columns: threeColumns, alignment: .leading, spacing: 8) {
            ForEach(allTypes, id: \.self) { type in
                filterChip(label: type, isSelected: selection.wrappedValue.contains(type)) {
                    selection.wrappedValue.formSymmetricDifference([type])
                }
            }
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color.clear)
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 1))
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
