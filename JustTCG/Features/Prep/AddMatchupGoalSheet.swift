import SwiftUI

struct AddMatchupGoalSheet: View {
    let plan: PrepPlan
    @Environment(PrepPlanRepository.self) private var repo
    @Environment(\.dismiss) private var dismiss

    private let archetypeNames = ArchetypeRepository.shared.metaOrdered.map(\.name)

    @State private var selectedArchetype: String = ""
    @State private var customName = ""
    @State private var targetCount = 5
    @State private var useCustom = false

    private var effectiveName: String {
        useCustom ? customName.trimmingCharacters(in: .whitespaces) : selectedArchetype
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Opponent Archetype") {
                    if !archetypeNames.isEmpty {
                        Toggle("Enter manually", isOn: $useCustom)
                    }
                    if useCustom || archetypeNames.isEmpty {
                        TextField("e.g. Charizard ex", text: $customName)
                    } else {
                        Picker("Archetype", selection: $selectedArchetype) {
                            ForEach(archetypeNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxHeight: 140)
                        .clipped()
                    }
                }
                Section {
                    Stepper("Target sessions: \(targetCount)", value: $targetCount, in: 1...20)
                }
            }
            .navigationTitle("Add Matchup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(effectiveName.isEmpty)
                }
            }
            .onAppear {
                if let first = archetypeNames.first { selectedArchetype = first }
            }
        }
    }

    private func add() {
        repo.addGoal(to: plan, archetypeName: effectiveName, targetCount: targetCount)
        dismiss()
    }
}
