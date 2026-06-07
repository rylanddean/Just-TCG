import SwiftUI

struct MatchDetailView: View {
    let match: Match

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var editArchetype: String = ""
    @State private var editResult: MatchResult = .win
    @State private var editEventType: EventType = .casual
    @State private var editFormat: MatchFormat = .bo3
    @State private var editDate: Date = .now
    @State private var editNotes: String = ""

    var body: some View {
        Form {
            if isEditing {
                editSections
            } else {
                readSections
            }
        }
        .navigationTitle("Match Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Done") { commitEdit() }
                        .fontWeight(.semibold)
                } else {
                    Button("Edit") { beginEdit() }
                }
            }
        }
    }

    // MARK: - Read view

    private var readSections: some View {
        Group {
            Section("Opponent") {
                Text(match.opponentArchetype)
            }
            Section("Result") {
                resultPill(match.result)
            }
            Section("Details") {
                LabeledContent("Event", value: eventLabel(match.eventType))
                LabeledContent("Format", value: formatLabel(match.format))
                LabeledContent("Date", value: match.date.formatted(date: .abbreviated, time: .omitted))
            }
            if !match.notes.isEmpty {
                Section("Notes") {
                    Text(match.notes)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Edit view

    private var editSections: some View {
        Group {
            Section("Opponent Archetype") {
                TextField("Archetype", text: $editArchetype)
                    .autocorrectionDisabled()
            }
            Section("Result") {
                HStack(spacing: 10) {
                    editResultButton(.win,  label: "Win",  color: .green)
                    editResultButton(.loss, label: "Loss", color: .red)
                    editResultButton(.tie,  label: "Tie",  color: .secondary)
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
            Section("Details") {
                Picker("Event", selection: $editEventType) {
                    Text("Casual").tag(EventType.casual)
                    Text("League Challenge").tag(EventType.leagueChallenge)
                    Text("Regionals").tag(EventType.regionals)
                    Text("Internationals").tag(EventType.internationalChampionship)
                    Text("Worlds").tag(EventType.worldChampionship)
                }
                Picker("Format", selection: $editFormat) {
                    Text("Best-of-1").tag(MatchFormat.bo1)
                    Text("Best-of-3").tag(MatchFormat.bo3)
                }
                .pickerStyle(.segmented)
                DatePicker("Date", selection: $editDate, displayedComponents: .date)
            }
            Section("Notes") {
                TextField("Notes (optional)", text: $editNotes, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
    }

    @ViewBuilder
    private func editResultButton(_ r: MatchResult, label: String, color: Color) -> some View {
        let isSelected = editResult == r
        Button { editResult = r } label: {
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

    // MARK: - Actions

    private func beginEdit() {
        editArchetype = match.opponentArchetype
        editResult    = match.result
        editEventType = match.eventType
        editFormat    = match.format
        editDate      = match.date
        editNotes     = match.notes
        isEditing     = true
    }

    private func commitEdit() {
        match.opponentArchetype = editArchetype.trimmingCharacters(in: .whitespaces)
        match.result            = editResult
        match.eventType         = editEventType
        match.format            = editFormat
        match.date              = editDate
        match.notes             = editNotes
        try? context.save()
        isEditing = false
    }

    // MARK: - Helpers

    @ViewBuilder
    private func resultPill(_ result: MatchResult) -> some View {
        let (label, color): (String, Color) = switch result {
        case .win:  ("Win",  .green)
        case .loss: ("Loss", .red)
        case .tie:  ("Tie",  .secondary)
        }
        Text(label)
            .font(.body.weight(.semibold))
            .foregroundStyle(color)
    }

    private func eventLabel(_ event: EventType) -> String {
        switch event {
        case .casual:                    return "Casual"
        case .leagueChallenge:           return "League Challenge"
        case .regionals:                 return "Regionals"
        case .internationalChampionship: return "Internationals"
        case .worldChampionship:         return "Worlds"
        }
    }

    private func formatLabel(_ format: MatchFormat) -> String {
        switch format {
        case .bo1: return "Best-of-1"
        case .bo3: return "Best-of-3"
        }
    }
}
