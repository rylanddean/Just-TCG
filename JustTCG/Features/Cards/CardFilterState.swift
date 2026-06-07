struct CardFilterState: Equatable {
    var types: Set<String> = []
    var sets: Set<String> = []
    var subtypes: Set<String> = []

    var isEmpty: Bool { types.isEmpty && sets.isEmpty && subtypes.isEmpty }
}
