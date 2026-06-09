import SwiftUI

struct LogPrepSessionSheet: View {
    let goal: MatchupGoal
    @Environment(PrepPlanRepository.self) private var repo
    @Environment(\.dismiss) private var dismiss

    @State private var result: MatchResult = .win
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Result") {
                    Picker("Result", selection: $result) {
                        Text("Win").tag(MatchResult.win)
                        Text("Loss").tag(MatchResult.loss)
                        Text("Tie").tag(MatchResult.tie)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                }
            }
            .navigationTitle("Log Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { log() }
                }
            }
        }
    }

    private func log() {
        repo.logSession(for: goal, result: result, notes: notes.trimmingCharacters(in: .whitespaces))
        dismiss()
    }
}
