import SwiftUI
import SwiftData

struct NewPrepPlanSheet: View {
    @Environment(PrepPlanRepository.self) private var repo
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Deck.updatedAt, order: .reverse) private var decks: [Deck]

    @State private var name = ""
    @State private var tournamentDate = Date.now.addingTimeInterval(14 * 86400)
    @State private var selectedDeckID: UUID? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Plan name", text: $name)
                    DatePicker("Tournament date", selection: $tournamentDate, in: Date.now..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                Section("Deck (optional)") {
                    Picker("Deck", selection: $selectedDeckID) {
                        Text("None").tag(Optional<UUID>(nil))
                        ForEach(decks) { deck in
                            Text(deck.name).tag(Optional(deck.id))
                        }
                    }
                }
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        repo.create(
            name: name.trimmingCharacters(in: .whitespaces),
            tournamentDate: tournamentDate,
            deckID: selectedDeckID
        )
        dismiss()
    }
}
