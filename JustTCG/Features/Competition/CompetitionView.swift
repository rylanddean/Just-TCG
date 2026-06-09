import SwiftUI

enum CompetitionSegment { case tournaments, competitors }

struct CompetitionView: View {
    @State private var segment: CompetitionSegment = .tournaments
    @Environment(AppNavigationState.self) private var nav

    var body: some View {
        NavigationStack {
            Group {
                switch segment {
                case .tournaments: TournamentsView()
                case .competitors: CompetitorsView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $segment) {
                        Text("Tournaments").tag(CompetitionSegment.tournaments)
                        Text("Competitors").tag(CompetitionSegment.competitors)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
        }
        .onChange(of: nav.tournamentsArchetypeFilter) { _, filter in
            if filter != nil { segment = .tournaments }
        }
    }
}
