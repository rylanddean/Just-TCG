import SwiftUI

struct ContentView: View {
    @State private var nav = AppNavigationState()

    var body: some View {
        TabView(selection: $nav.selectedTab) {
            DecksView()
                .tabItem { Label("Decks", systemImage: "rectangle.stack") }
                .tag(0)
            CardsView()
                .tabItem { Label("Cards", systemImage: "square.grid.2x2") }
                .tag(1)
            TournamentsView()
                .tabItem { Label("Tournaments", systemImage: "trophy") }
                .tag(2)
            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
        .environment(nav)
    }
}
