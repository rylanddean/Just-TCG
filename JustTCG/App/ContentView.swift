import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var nav = AppNavigationState()

    var body: some View {
        TabView(selection: $nav.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            DecksView()
                .tabItem { Label("Decks", systemImage: "rectangle.stack") }
                .tag(1)
            CardsView()
                .tabItem { Label("Cards", systemImage: "square.grid.2x2") }
                .tag(2)
            CompetitionView()
                .tabItem { Label("Competition", systemImage: "trophy") }
                .tag(3)
            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar") }
                .tag(4)
        }
        .environment(nav)
        .task { await BundledCardSeeder.seedIfNeeded(context: context) }
    }
}
